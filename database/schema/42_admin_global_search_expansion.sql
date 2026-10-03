-- ============================================================================
-- Migration 42: Admin Global Search Expansion (Vouchers, Reviews, Returns)
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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
        CONCAT('/Pages/Admin/POS/POS.aspx?search=', v.SKU) AS Url,
        'Sell in POS' AS Badge
    FROM dbo.v_VisibleProductVariants v
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    LEFT JOIN dbo.v_VisibleInventories i ON i.VariantId = v.Id
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
        CONCAT((SELECT COUNT(*) FROM dbo.v_VisibleProducts p WHERE p.BrandId = b.Id), ' Helmet Models in Catalog') AS Subtitle,
        CONCAT('/Pages/Admin/Inventory/Inventory.aspx?brand=', b.Name) AS Url,
        'Brand' AS Badge
    FROM dbo.Brands b
    WHERE b.Name LIKE '%' + @Query + '%'

    UNION ALL

    -- 3. Catalog Models
    SELECT TOP (@Limit)
        'Catalog' AS Category,
        CONCAT(b.Name, ' ', p.Name) AS Title,
        CONCAT(cat.Name, NCHAR(32), NCHAR(8226), NCHAR(32), 'Base: ', NCHAR(8369), FORMAT(p.BasePrice, 'N2')) AS Subtitle,
        CONCAT('/Pages/Admin/Catalog/Catalog.aspx?id=', p.Id) AS Url,
        b.Name AS Badge
    FROM dbo.v_VisibleProducts p
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
        CONCAT('/Pages/Admin/Inventory/Inventory.aspx?q=', v.SKU) AS Url,
        CASE WHEN ISNULL(i.CurrentStock,0) <= 0 THEN 'Out of Stock' 
             WHEN ISNULL(i.CurrentStock,0) <= ISNULL(i.ReorderPoint,3) THEN 'Low Stock' 
             ELSE 'In Stock' END AS Badge
    FROM dbo.v_VisibleProductVariants v
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    LEFT JOIN dbo.v_VisibleInventories i ON i.VariantId = v.Id
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
        CONCAT(o.OrderNumber, ' - ', o.CustomerName) AS Title,
        CONCAT(NCHAR(8369), FORMAT(o.TotalAmount, 'N2'), NCHAR(32), NCHAR(8226), NCHAR(32), o.Status, NCHAR(32), NCHAR(8226), NCHAR(32), o.OrderSource) AS Subtitle,
        CONCAT('/Pages/Admin/Orders/Orders.aspx?q=', o.OrderNumber) AS Url,
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
        CONCAT(u.Email, NCHAR(32), NCHAR(8226), NCHAR(32), ISNULL(u.PhoneNumber, 'No phone')) AS Subtitle,
        CONCAT('/Pages/Admin/Users/Users.aspx?q=', u.Email) AS Url,
        r.Name AS Badge
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id = u.RoleId
    WHERE CONCAT(u.FirstName, N' ', u.LastName) LIKE '%' + @Query + '%'
       OR u.Email LIKE '%' + @Query + '%'
       OR u.PhoneNumber LIKE '%' + @Query + '%'

    UNION ALL

    -- 7. Vouchers
    SELECT TOP (@Limit)
        'Vouchers' AS Category,
        v.Code AS Title,
        CONCAT(
            CASE WHEN v.DiscountType = 'PERCENTAGE' THEN CONCAT(FORMAT(v.DiscountValue, 'G29'), '% OFF')
                 ELSE CONCAT(NCHAR(8369), FORMAT(v.DiscountValue, 'N2'), ' OFF') END,
            NCHAR(32), NCHAR(8226), NCHAR(32),
            (SELECT COUNT(*) FROM dbo.VoucherRedemptions r WHERE r.VoucherId = v.Id AND r.ReleasedAt IS NULL), ' redeemed',
            CASE WHEN v.MinimumSpend > 0 THEN CONCAT(NCHAR(32), NCHAR(8226), NCHAR(32), 'Min. ', NCHAR(8369), FORMAT(v.MinimumSpend, 'N2')) ELSE '' END
        ) AS Subtitle,
        CONCAT('/Pages/Admin/Vouchers/Vouchers.aspx?q=', v.Code) AS Url,
        CASE WHEN v.IsActive = 1 AND (v.ExpiresAt IS NULL OR v.ExpiresAt > SYSUTCDATETIME()) AND (v.UsageLimit IS NULL OR (SELECT COUNT(*) FROM dbo.VoucherRedemptions r WHERE r.VoucherId = v.Id AND r.ReleasedAt IS NULL) < v.UsageLimit) THEN 'Active'
             ELSE 'Inactive' END AS Badge
    FROM dbo.Vouchers v
    WHERE v.Code LIKE '%' + @Query + '%'
       OR v.DiscountType LIKE '%' + @Query + '%'
       OR CAST(v.DiscountValue AS NVARCHAR(20)) LIKE '%' + @Query + '%'

    UNION ALL

    -- 8. Reviews
    SELECT TOP (@Limit)
        'Reviews' AS Category,
        CONCAT(r.ReviewerName, ' - ', p.Name, ' (', r.Rating, NCHAR(9733), ')') AS Title,
        CONCAT(
            ISNULL(r.Title, 'Review'), NCHAR(32), NCHAR(8226), NCHAR(32),
            SUBSTRING(r.Comment, 1, 60),
            CASE WHEN LEN(r.Comment) > 60 THEN '...' ELSE '' END
        ) AS Subtitle,
        CONCAT('/Pages/Admin/Reviews/Reviews.aspx?q=', r.ReviewerName) AS Url,
        CASE WHEN r.IsHidden = 1 THEN 'Hidden'
             ELSE 'Published' END AS Badge
    FROM dbo.ProductReviews r
    JOIN dbo.Products p ON p.Id = r.ProductId
    WHERE r.ReviewerName LIKE '%' + @Query + '%'
       OR p.Name LIKE '%' + @Query + '%'
       OR ISNULL(r.Title, '') LIKE '%' + @Query + '%'
       OR r.Comment LIKE '%' + @Query + '%'

    UNION ALL

    -- 9. Returns
    SELECT TOP (@Limit)
        'Returns' AS Category,
        CONCAT(ret.RmaNumber, ' - ', o.CustomerName) AS Title,
        CONCAT(
            ret.RequestType, NCHAR(32), NCHAR(8226), NCHAR(32),
            ret.Reason, NCHAR(32), NCHAR(8226), NCHAR(32),
            o.OrderNumber
        ) AS Subtitle,
        CONCAT('/Pages/Admin/Returns/Returns.aspx?q=', ret.RmaNumber) AS Url,
        ret.Status AS Badge
    FROM dbo.ReturnRequests ret
    JOIN dbo.Orders o ON o.Id = ret.OrderId
    WHERE ret.RmaNumber LIKE '%' + @Query + '%'
       OR o.CustomerName LIKE '%' + @Query + '%'
       OR o.OrderNumber LIKE '%' + @Query + '%'
       OR ret.Reason LIKE '%' + @Query + '%'
       OR ret.RequestType LIKE '%' + @Query + '%';
END;
GO
