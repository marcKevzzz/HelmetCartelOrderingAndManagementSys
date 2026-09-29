-- =====================================================================================
-- 09_inventory_audit_and_global_search.sql
-- Adds dbo.sp_AdminStockAuditLogs and updates dbo.sp_AdminGlobalSearch to include
-- brand-level aggregation and comprehensive catalog matches.
-- =====================================================================================

USE HelmetCartelDB;
GO

-- 1. Create or alter procedure dbo.sp_AdminStockAuditLogs
CREATE OR ALTER PROCEDURE dbo.sp_AdminStockAuditLogs
    @VariantId INT = NULL,
    @Search NVARCHAR(200) = NULL,
    @Limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');

    SELECT TOP (@Limit)
        l.Id,
        l.VariantId,
        b.Name AS BrandName,
        p.Id AS ProductId,
        p.Name AS ProductName,
        c.Color,
        v.Size,
        v.SKU,
        l.ChangeType,
        l.PreviousStock,
        l.QuantityChanged,
        l.NewStock,
        l.ReferenceNumber,
        l.Notes,
        l.CreatedAt,
        ISNULL(NULLIF(LTRIM(RTRIM(CONCAT(u.FirstName, N' ', u.LastName))), N''), N'Staff Admin') AS PerformedBy
    FROM dbo.StockAuditLogs l
    JOIN dbo.ProductVariants v ON v.Id = l.VariantId
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    LEFT JOIN dbo.Users u ON u.Id = l.UserId
    WHERE (@VariantId IS NULL OR l.VariantId = @VariantId)
      AND (
          @Search IS NULL
          OR b.Name LIKE N'%' + @Search + N'%'
          OR p.Name LIKE N'%' + @Search + N'%'
          OR v.SKU LIKE N'%' + @Search + N'%'
          OR c.Color LIKE N'%' + @Search + N'%'
          OR l.ReferenceNumber LIKE N'%' + @Search + N'%'
      )
    ORDER BY l.CreatedAt DESC, l.Id DESC;
END;
GO

-- 2. Create or alter procedure dbo.sp_AdminGlobalSearch
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

    UNION ALL

    -- 3. Inventory Variants (Color, Size, SKU)
    SELECT TOP (@Limit)
        'Inventory' AS Category,
        CONCAT(b.Name, ' ', p.Name, ' (', c.Color, ' - ', v.Size, ')') AS Title,
        CONCAT('Stock: ', RIGHT('000' + CAST(ISNULL(i.CurrentStock,0) AS VARCHAR(10)), 3), ' • SKU: ', v.SKU) AS Subtitle,
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

    -- 5. Users / People
    SELECT TOP (@Limit)
        'Users' AS Category,
        u.FullName AS Title,
        CONCAT(u.Email, ' • ', u.PhoneNumber, ' • Role: ', r.Name) AS Subtitle,
        CONCAT('/Admin/Users.aspx?q=', u.Email) AS Url,
        r.Name AS Badge
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id = u.RoleId
    WHERE u.FullName LIKE '%' + @Query + '%'
       OR u.Email LIKE '%' + @Query + '%'
       OR u.PhoneNumber LIKE '%' + @Query + '%';
END;
GO
