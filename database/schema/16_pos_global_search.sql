-- ============================================================================
-- SCRIPT: 16_pos_global_search.sql
-- PURPOSE: Update dbo.sp_AdminGlobalSearch to include Point of Sale sellable
--          items, linking directly to /Admin/POS.aspx?search=...
--          Uses NCHAR(8369) for Peso symbol and NCHAR(8226) for bullet dot
--          to prevent any encoding corruption or question mark replacements.
-- ============================================================================

USE [HelmetCartelDB];
GO

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

    -- 1. Point of Sale (Direct POS Action for sellable in-stock items)
    SELECT TOP (@Limit)
        'Point of Sale' AS Category,
        CONCAT(b.Name, ' ', p.Name, ' (', c.Color, ' - ', v.Size, ')') AS Title,
        CONCAT(NCHAR(8369), FORMAT(dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive), 'N2'), NCHAR(32), NCHAR(8226), NCHAR(32), ISNULL(i.CurrentStock, 0), ' in stock', NCHAR(32), NCHAR(8226), NCHAR(32), 'SKU: ', v.SKU) AS Subtitle,
        CONCAT('/Admin/POS.aspx?search=', v.SKU) AS Url,
        'Sell in POS' AS Badge
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE v.IsActive = 1 AND p.IsActive = 1 AND ISNULL(i.CurrentStock, 0) > 0
      AND (
          p.Name LIKE '%' + @Query + '%'
          OR b.Name LIKE '%' + @Query + '%'
          OR CONCAT(b.Name, ' ', p.Name) LIKE '%' + @Query + '%'
          OR CONCAT(b.Name, ' ', p.Name, ' ', c.Color) LIKE '%' + @Query + '%'
          OR v.SKU LIKE '%' + @Query + '%'
          OR c.Color LIKE '%' + @Query + '%'
      )

    UNION ALL

    -- 2. Brands Matching Query
    SELECT TOP (@Limit)
        'Brands' AS Category,
        b.Name AS Title,
        CONCAT((SELECT COUNT(*) FROM dbo.Products p WHERE p.BrandId = b.Id), ' Helmet Models in Catalog') AS Subtitle,
        CONCAT('/Admin/Inventory.aspx?brand=', b.Name) AS Url,
        'Brand' AS Badge
    FROM dbo.Brands b
    WHERE b.Name LIKE '%' + @Query + '%'

    UNION ALL

    -- 3. Catalog Models
    SELECT TOP (@Limit)
        'Catalog' AS Category,
        CONCAT(b.Name, ' ', p.Name) AS Title,
        CONCAT(cat.Name, NCHAR(32), NCHAR(8226), NCHAR(32), p.RidingStyle, NCHAR(32), NCHAR(8226), NCHAR(32), 'Base: ', NCHAR(8369), FORMAT(p.BasePrice, 'N2')) AS Subtitle,
        CONCAT('/Admin/Catalog.aspx?id=', p.Id) AS Url,
        b.Name AS Badge
    FROM dbo.Products p
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    WHERE p.Name LIKE '%' + @Query + '%'
       OR b.Name LIKE '%' + @Query + '%'
       OR CONCAT(b.Name, ' ', p.Name) LIKE '%' + @Query + '%'

    UNION ALL

    -- 4. Inventory Variants (Color, Size, SKU)
    SELECT TOP (@Limit)
        'Inventory' AS Category,
        CONCAT(b.Name, ' ', p.Name, ' (', c.Color, ' - ', v.Size, ')') AS Title,
        CONCAT('Stock: ', ISNULL(i.CurrentStock,0), ' units', NCHAR(32), NCHAR(8226), NCHAR(32), 'SKU: ', v.SKU) AS Subtitle,
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

    -- 5. Orders
    SELECT TOP (@Limit)
        'Orders' AS Category,
        CONCAT(o.OrderNumber, ' — ', o.CustomerName) AS Title,
        CONCAT(NCHAR(8369), FORMAT(o.TotalAmount, 'N2'), NCHAR(32), NCHAR(8226), NCHAR(32), o.Status, NCHAR(32), NCHAR(8226), NCHAR(32), o.OrderSource) AS Subtitle,
        CONCAT('/Admin/Orders.aspx?q=', o.OrderNumber) AS Url,
        o.Status AS Badge
    FROM dbo.Orders o
    WHERE o.OrderNumber LIKE '%' + @Query + '%'
       OR o.CustomerName LIKE '%' + @Query + '%'
       OR o.CustomerEmail LIKE '%' + @Query + '%'
       OR o.CustomerPhone LIKE '%' + @Query + '%'

    UNION ALL

    -- 6. Users
    SELECT TOP (@Limit)
        'Users' AS Category,
        CONCAT(u.FirstName, N' ', u.LastName) AS Title,
        CONCAT(u.Email, NCHAR(32), NCHAR(8226), NCHAR(32), u.PhoneNumber) AS Subtitle,
        CONCAT('/Admin/Users.aspx?q=', u.Email) AS Url,
        r.Name AS Badge
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id = u.RoleId
    WHERE CONCAT(u.FirstName, N' ', u.LastName) LIKE '%' + @Query + '%'
       OR u.Email LIKE '%' + @Query + '%'
       OR u.PhoneNumber LIKE '%' + @Query + '%';
END;
GO
