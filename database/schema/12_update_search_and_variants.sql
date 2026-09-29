-- ============================================================================
-- SCRIPT: 12_update_search_and_variants.sql
-- PURPOSE: Improves product search so multi-word and composite queries 
--          (e.g., 'AGV K3', 'Shoei RF-1400', 'Gille Falcon Black') match
--          correctly across Inventory and Global Search, ensuring all stock 
--          actions and details are preserved.
-- ============================================================================

USE [HelmetCartelDB];
GO

-- 1. UPDATE STORED PROCEDURE: sp_AdminInventoryVariants
CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryVariants
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL,
    @StockStatus NVARCHAR(50) = 'all'
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    IF @Brand = 'all' SET @Brand = NULL;
    IF @Category = 'all' SET @Category = NULL;
    IF @StockStatus IS NULL OR LTRIM(RTRIM(@StockStatus)) = '' SET @StockStatus = 'all';

    SELECT 
        v.Id AS VariantId,
        p.Id AS ProductId,
        b.Name AS BrandName,
        p.Name AS ProductName,
        cat.Name AS CategoryName,
        c.Color,
        c.ColorHex,
        v.Size,
        ISNULL(i.CurrentStock, 0) AS CurrentStock,
        ISNULL(i.ReservedStock, 0) AS ReservedStock,
        ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) AS AvailableStock,
        ISNULL(i.ReorderPoint, 3) AS ReorderPoint,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        v.SKU,
        p.MainImageUrl,
        CASE 
            WHEN ISNULL(i.CurrentStock, 0) <= 0 THEN 'out_of_stock'
            WHEN ISNULL(i.CurrentStock, 0) <= ISNULL(i.ReorderPoint, 3) THEN 'low_stock'
            ELSE 'in_stock'
        END AS StockStatus
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE v.IsActive = 1 AND p.IsActive = 1
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%' 
          OR b.Name LIKE N'%' + @Search + N'%' 
          OR cat.Name LIKE N'%' + @Search + N'%'
          OR v.SKU LIKE N'%' + @Search + N'%' 
          OR c.Color LIKE N'%' + @Search + N'%'
          OR CONCAT(b.Name, ' ', p.Name) LIKE N'%' + @Search + N'%'
          OR CONCAT(b.Name, ' ', p.Name, ' ', c.Color) LIKE N'%' + @Search + N'%'
          OR CONCAT(b.Name, ' ', p.Name, ' ', c.Color, ' ', v.Size) LIKE N'%' + @Search + N'%'
          OR CONCAT(p.Name, ' ', c.Color) LIKE N'%' + @Search + N'%'
      )
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR cat.Name = @Category OR cat.Slug = @Category)
      AND (
          (@StockStatus = 'all')
          OR (@StockStatus = 'in_stock' AND ISNULL(i.CurrentStock, 0) > ISNULL(i.ReorderPoint, 3))
          OR (@StockStatus = 'low_stock' AND ISNULL(i.CurrentStock, 0) > 0 AND ISNULL(i.CurrentStock, 0) <= ISNULL(i.ReorderPoint, 3))
          OR (@StockStatus = 'out_of_stock' AND ISNULL(i.CurrentStock, 0) <= 0)
      )
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;
GO

-- 2. UPDATE STORED PROCEDURE: sp_AdminGlobalSearch
CREATE OR ALTER PROCEDURE dbo.sp_AdminGlobalSearch
    @Query NVARCHAR(100),
    @Limit INT = 8
AS
BEGIN
    SET NOCOUNT ON;
    SET @Query = LTRIM(RTRIM(@Query));
    IF @Query IS NULL OR LEN(@Query) < 1
    BEGIN
        SELECT TOP 0 '' AS Category, '' AS Title, '' AS Subtitle, '' AS Url, '' AS Badge;
        RETURN;
    END;

    -- 1. Brands Matching Query
    SELECT TOP (@Limit)
        'Brands' AS Category,
        b.Name AS Title,
        CONCAT((SELECT COUNT(*) FROM dbo.Products p WHERE p.BrandId = b.Id), ' Helmet Models in Catalog') AS Subtitle,
        CONCAT('/Admin/Inventory.aspx?brand=', b.Name) AS Url,
        'Brand' AS Badge
    FROM dbo.Brands b
    WHERE b.Name LIKE '%' + @Query + '%'

    UNION ALL

    -- 2. Catalog Models
    SELECT TOP (@Limit)
        'Catalog' AS Category,
        CONCAT(b.Name, ' ', p.Name) AS Title,
        CONCAT(cat.Name, ' • ', p.RidingStyle, ' • Base: ₱', FORMAT(p.BasePrice, 'N2')) AS Subtitle,
        CONCAT('/Admin/Catalog.aspx?id=', p.Id) AS Url,
        b.Name AS Badge
    FROM dbo.Products p
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    WHERE p.Name LIKE '%' + @Query + '%'
       OR b.Name LIKE '%' + @Query + '%'
       OR CONCAT(b.Name, ' ', p.Name) LIKE '%' + @Query + '%'

    UNION ALL

    -- 3. Inventory Variants (Color, Size, SKU)
    SELECT TOP (@Limit)
        'Inventory' AS Category,
        CONCAT(b.Name, ' ', p.Name, ' (', c.Color, ' - ', v.Size, ')') AS Title,
        CONCAT('Stock: ', ISNULL(i.CurrentStock,0), ' units • SKU: ', v.SKU) AS Subtitle,
        CONCAT('/Admin/Inventory.aspx?q=', v.SKU) AS Url,
        CASE WHEN ISNULL(i.CurrentStock,0) <= 0 THEN 'Out of Stock' 
             WHEN ISNULL(i.CurrentStock,0) <= ISNULL(i.ReorderPoint,3) THEN 'Low Stock' 
             ELSE 'In Stock' END AS Badge
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE p.Name LIKE '%' + @Query + '%'
       OR b.Name LIKE '%' + @Query + '%'
       OR CONCAT(b.Name, ' ', p.Name) LIKE '%' + @Query + '%'
       OR CONCAT(b.Name, ' ', p.Name, ' ', c.Color) LIKE '%' + @Query + '%'
       OR v.SKU LIKE '%' + @Query + '%'
       OR c.Color LIKE '%' + @Query + '%'

    UNION ALL

    -- 4. Orders
    SELECT TOP (@Limit)
        'Orders' AS Category,
        CONCAT(o.OrderNumber, ' — ', o.CustomerName) AS Title,
        CONCAT('₱', FORMAT(o.TotalAmount, 'N2'), ' • ', o.Status, ' • ', o.OrderSource) AS Subtitle,
        CONCAT('/Admin/Orders.aspx?q=', o.OrderNumber) AS Url,
        o.Status AS Badge
    FROM dbo.Orders o
    WHERE o.OrderNumber LIKE '%' + @Query + '%'
       OR o.CustomerName LIKE '%' + @Query + '%'
       OR o.CustomerEmail LIKE '%' + @Query + '%'
       OR o.CustomerPhone LIKE '%' + @Query + '%'

    UNION ALL

    -- 5. Users
    SELECT TOP (@Limit)
        'Users' AS Category,
        u.FullName AS Title,
        CONCAT(u.Email, ' • ', ISNULL(u.PhoneNumber, 'No phone')) AS Subtitle,
        CONCAT('/Admin/Users.aspx?q=', u.Email) AS Url,
        r.Name AS Badge
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id = u.RoleId
    WHERE u.FullName LIKE '%' + @Query + '%'
       OR u.Email LIKE '%' + @Query + '%'
       OR u.PhoneNumber LIKE '%' + @Query + '%';
END;
GO
