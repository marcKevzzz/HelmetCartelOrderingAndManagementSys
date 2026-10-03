-- ============================================================================
-- Migration 37: Drop Deprecated Fields (Contract Phase)
-- Purpose:
--   1. Drop unused table dbo.ProductDiscounts (all active discounts reside on dbo.Products)
--   2. Drop index IX_Products_RidingStyle and default constraints on dbo.Products
--   3. Update all views and stored procedures to completely eliminate dependencies
--      on RidingStyle and IsFeatured
--   4. Drop columns IsFeatured and RidingStyle from dbo.Products
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- 1. Drop Unused dbo.ProductDiscounts Table
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.ProductDiscounts', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.ProductDiscounts;
    PRINT 'Dropped unused table dbo.ProductDiscounts.';
END
GO

-- ----------------------------------------------------------------------------
-- 2. Drop Constraints and Indexes on dbo.Products (IsFeatured & RidingStyle)
-- ----------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Products_RidingStyle' AND object_id = OBJECT_ID(N'dbo.Products'))
BEGIN
    DROP INDEX IX_Products_RidingStyle ON dbo.Products;
    PRINT 'Dropped index IX_Products_RidingStyle.';
END
GO

DECLARE @ConstraintName NVARCHAR(200);

-- Drop default constraint on IsFeatured
SELECT @ConstraintName = dc.name
FROM sys.default_constraints dc
JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Products') AND c.name = N'IsFeatured';

IF @ConstraintName IS NOT NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.Products DROP CONSTRAINT [' + @ConstraintName + N'];');
    PRINT 'Dropped default constraint on IsFeatured: ' + @ConstraintName;
END

-- Drop default constraint on RidingStyle if any
SET @ConstraintName = NULL;
SELECT @ConstraintName = dc.name
FROM sys.default_constraints dc
JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Products') AND c.name = N'RidingStyle';

IF @ConstraintName IS NOT NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.Products DROP CONSTRAINT [' + @ConstraintName + N'];');
    PRINT 'Dropped default constraint on RidingStyle: ' + @ConstraintName;
END
GO

-- ----------------------------------------------------------------------------
-- 3. Update View: dbo.v_VisibleProducts
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_VisibleProducts
AS
SELECT 
    p.Id,
    p.CategoryId,
    p.BrandId,
    p.Name,
    p.Slug,
    p.Description,
    p.BasePrice,
    p.DiscountPercentage,
    p.DiscountType,
    p.DiscountAmount,
    p.DiscountStartDate,
    p.DiscountEndDate,
    p.DiscountIsActive,
    p.MainImageUrl,
    p.IsActive,
    p.PublicationStatus,
    p.CreatedAt,
    p.UpdatedAt
FROM dbo.Products p
WHERE p.IsActive = 1
  AND (p.PublicationStatus IS NULL OR p.PublicationStatus = N'Published');
GO

-- ----------------------------------------------------------------------------
-- 4. Update Procedure: dbo.sp_GetProductsPaged
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetProductsPaged
    @CategoryId INT = NULL,
    @BrandId INT = NULL,
    @Brand NVARCHAR(200) = NULL,
    @Category NVARCHAR(100) = NULL,
    @RidingStyle NVARCHAR(50) = NULL, -- Deprecated, kept for backward compatibility
    @Search NVARCHAR(200) = NULL,
    @OnSale BIT = 0,
    @MinPrice DECIMAL(18,2) = NULL,
    @MaxPrice DECIMAL(18,2) = NULL,
    @Colors NVARCHAR(200) = NULL,
    @Sizes NVARCHAR(100) = NULL,
    @SortBy NVARCHAR(50) = 'popular',
    @PageNumber INT = 1,
    @PageSize INT = 9,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Colors = NULLIF(LTRIM(RTRIM(@Colors)), N'');
    SET @Sizes = NULLIF(LTRIM(RTRIM(@Sizes)), N'');
    IF @PageNumber IS NULL OR @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 9;
    IF @PageSize > 100 SET @PageSize = 100;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    -- Calculate total count
    SELECT @TotalCount = COUNT(*)
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    WHERE p.IsActive = 1
      AND (
          ISNULL(@OnSale, 0) = 0 
          OR (
              (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
              AND ISNULL(p.DiscountIsActive, 1) = 1
              AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
              AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
          )
      )
      AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
      AND (@BrandId IS NULL OR p.BrandId = @BrandId)
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand OR CHARINDEX(N',' + UPPER(b.Name) + N',', N',' + UPPER(@Brand) + N',') > 0)
      AND (@Category IS NULL OR @Category = 'all' OR c.Slug = @Category OR c.Name LIKE '%' + @Category + '%')
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%'
          OR b.Name LIKE N'%' + @Search + N'%'
          OR c.Name LIKE N'%' + @Search + N'%'
          OR p.Description LIKE N'%' + @Search + N'%'
          OR EXISTS (
              SELECT 1 
              FROM dbo.v_VisibleProductColors pc_s
              JOIN dbo.v_VisibleProductVariants pv_s ON pv_s.ProductColorId = pc_s.Id
              WHERE pc_s.ProductId = p.Id AND pv_s.SKU LIKE N'%' + @Search + N'%'
          )
      )
      AND (@MinPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) >= @MinPrice)
      AND (@MaxPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) <= @MaxPrice)
      AND EXISTS
      (
          SELECT 1
          FROM dbo.v_VisibleProductColors pc
          JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
            AND (@Colors IS NULL OR CHARINDEX(N',' + UPPER(dbo.fn_BaseColorFromHex(pc.ColorHex)) + N',', N',' + UPPER(@Colors) + N',') > 0)
            AND (@Sizes IS NULL OR CHARINDEX(N',' + UPPER(pv.Size) + N',', N',' + UPPER(@Sizes) + N',') > 0)
      );

    -- Paged rows
    SELECT 
        p.Id,
        p.Name,
        p.Slug,
        b.Name AS Brand,
        c.Name AS Category,
        p.BasePrice,
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        CASE 
            WHEN ISNULL(p.DiscountIsActive, 1) = 1 
                 AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
                 AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
                 AND (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
            THEN 1 
            ELSE 0 
        END AS IsDiscountActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        p.MainImageUrl,
        p.Description,
        p.PublicationStatus,
        sales.UnitsSold
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    OUTER APPLY (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    OUTER APPLY (
        SELECT ISNULL(SUM(oi.Quantity), 0) AS UnitsSold
        FROM dbo.OrderItems oi
        INNER JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
        INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
        WHERE pc.ProductId = p.Id
          AND o.Status NOT IN (N'Cancelled', N'Refunded', N'PendingPayment')
    ) sales
    WHERE p.IsActive = 1
      AND (
          ISNULL(@OnSale, 0) = 0 
          OR (
              (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
              AND ISNULL(p.DiscountIsActive, 1) = 1
              AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
              AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
          )
      )
      AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
      AND (@BrandId IS NULL OR p.BrandId = @BrandId)
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand OR CHARINDEX(N',' + UPPER(b.Name) + N',', N',' + UPPER(@Brand) + N',') > 0)
      AND (@Category IS NULL OR @Category = 'all' OR c.Slug = @Category OR c.Name LIKE '%' + @Category + '%')
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%'
          OR b.Name LIKE N'%' + @Search + N'%'
          OR c.Name LIKE N'%' + @Search + N'%'
          OR p.Description LIKE N'%' + @Search + N'%'
          OR EXISTS (
              SELECT 1 
              FROM dbo.v_VisibleProductColors pc_s
              JOIN dbo.v_VisibleProductVariants pv_s ON pv_s.ProductColorId = pc_s.Id
              WHERE pc_s.ProductId = p.Id AND pv_s.SKU LIKE N'%' + @Search + N'%'
          )
      )
      AND (@MinPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) >= @MinPrice)
      AND (@MaxPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) <= @MaxPrice)
      AND EXISTS
      (
          SELECT 1
          FROM dbo.v_VisibleProductColors pc
          JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
            AND (@Colors IS NULL OR CHARINDEX(N',' + UPPER(dbo.fn_BaseColorFromHex(pc.ColorHex)) + N',', N',' + UPPER(@Colors) + N',') > 0)
            AND (@Sizes IS NULL OR CHARINDEX(N',' + UPPER(pv.Size) + N',', N',' + UPPER(@Sizes) + N',') > 0)
      )
    ORDER BY 
        CASE WHEN @SortBy = 'top_selling' THEN sales.UnitsSold END DESC,
        CASE WHEN @SortBy = 'price_asc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END ASC,
        CASE WHEN @SortBy = 'price_desc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END DESC,
        CASE WHEN @SortBy = 'newest' THEN p.CreatedAt END DESC,
        CASE WHEN @SortBy = 'rating' THEN review.Rating END DESC,
        CASE WHEN @SortBy = 'popular' OR @SortBy IS NULL THEN review.ReviewCount END DESC,
        p.CreatedAt DESC,
        p.Id ASC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ----------------------------------------------------------------------------
-- 5. Update Procedure: dbo.sp_GetProductById
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetProductById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    SELECT
        p.Id,
        p.Name,
        p.Slug,
        b.Name AS Brand,
        c.Name AS Category,
        p.BasePrice,
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        CASE
            WHEN ISNULL(p.DiscountIsActive, 1) = 1
                 AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
                 AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
                 AND (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
            THEN 1 ELSE 0
        END AS IsDiscountActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage,
            p.DiscountType, p.DiscountAmount, p.DiscountStartDate,
            p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        orders.OrderCount,
        p.MainImageUrl,
        p.Description,
        p.PublicationStatus
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    OUTER APPLY
    (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    OUTER APPLY
    (
        SELECT COUNT(DISTINCT oi.OrderId) AS OrderCount
        FROM dbo.v_VisibleProductColors pc
        INNER JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
        INNER JOIN dbo.OrderItems oi ON oi.VariantId = pv.Id
        INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
        WHERE pc.ProductId = p.Id AND o.Status <> N'Cancelled'
    ) orders
    WHERE p.Id = @Id AND p.IsActive = 1;

    SELECT
        pv.Id,
        pc.ProductId,
        pv.SKU,
        pv.Size,
        pc.Color,
        pc.ColorHex,
        pv.PriceAdjustment,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, pv.PriceAdjustment,
            p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
            p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        ISNULL(i.CurrentStock, 0) AS CurrentStock,
        ISNULL(i.ReservedStock, 0) AS ReservedStock,
        ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) AS AvailableStock,
        ISNULL(i.IsLowStock, 0) AS IsLowStock
    FROM dbo.v_VisibleProductVariants pv
    INNER JOIN dbo.v_VisibleProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.v_VisibleProducts p ON pc.ProductId = p.Id
    LEFT JOIN dbo.v_VisibleInventories i ON pv.Id = i.VariantId
    WHERE pc.ProductId = @Id AND pv.IsActive = 1
    ORDER BY pv.Id ASC;

    SELECT ImageUrl,
           COALESCE(AltText, N'Product view') AS AltText,
           CONVERT(INT, DisplayOrder) AS DisplayOrder
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @Id AND IsActive = 1
    ORDER BY DisplayOrder ASC, Id ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 6. Update Procedure: dbo.sp_GetProductBySlug
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetProductBySlug
    @Slug NVARCHAR(220)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Id INT;
    SELECT @Id = Id FROM dbo.v_VisibleProducts WHERE Slug = @Slug;

    IF @Id IS NULL
    BEGIN
        SELECT TOP 0 1 AS ProductNotFound;
        RETURN;
    END

    EXEC dbo.sp_GetProductById @Id = @Id;
END;
GO

-- ----------------------------------------------------------------------------
-- 7. Update Procedure: dbo.sp_GetRelatedProducts
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetRelatedProducts
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (4)
        p.Id,
        p.Name,
        p.Slug,
        b.Name AS Brand,
        c.Name AS Category,
        p.BasePrice,
        p.DiscountPercentage,
        CAST(p.BasePrice * (1.0 - p.DiscountPercentage / 100.0) AS DECIMAL(18,2)) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        p.MainImageUrl,
        p.Description,
        p.PublicationStatus
    FROM dbo.v_VisibleProducts sourceProduct
    INNER JOIN dbo.v_VisibleProducts p ON p.Id <> sourceProduct.Id AND p.IsActive = 1
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    OUTER APPLY (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    WHERE sourceProduct.Id = @ProductId AND sourceProduct.IsActive = 1
      AND EXISTS (
          SELECT 1 FROM dbo.v_VisibleProductColors pc
          INNER JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
      )
    ORDER BY CASE
                 WHEN p.CategoryId = sourceProduct.CategoryId AND p.BrandId = sourceProduct.BrandId THEN 0
                 WHEN p.CategoryId = sourceProduct.CategoryId THEN 1
                 WHEN p.BrandId = sourceProduct.BrandId THEN 2
                 ELSE 3
             END,
             review.Rating DESC,
             review.ReviewCount DESC,
             p.CreatedAt DESC,
             p.Id ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 8. Update Procedure: dbo.sp_AdminCatalogProducts
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminCatalogProducts
    @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');

    SELECT 
        p.Id, 
        p.Name, 
        p.Slug, 
        p.Description, 
        p.CategoryId, 
        c.Name AS Category,
        p.BrandId, 
        b.Name AS Brand, 
        p.BasePrice, 
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        p.DiscountIsActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        p.MainImageUrl, 
        p.IsActive, 
        p.PublicationStatus,
        p.CreatedAt,
        (
            SELECT COUNT(*) 
            FROM dbo.ProductVariants v 
            JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId 
            WHERE pc.ProductId = p.Id AND v.IsActive = 1
        ) AS VariantCount
    FROM dbo.Products p 
    JOIN dbo.Categories c ON c.Id = p.CategoryId 
    JOIN dbo.Brands b ON b.Id = p.BrandId
    WHERE @Search IS NULL 
       OR p.Name LIKE N'%' + @Search + N'%' 
       OR p.Slug LIKE N'%' + @Search + N'%'
       OR b.Name LIKE N'%' + @Search + N'%'
       OR c.Name LIKE N'%' + @Search + N'%'
       OR EXISTS (
           SELECT 1 
           FROM dbo.ProductVariants v 
           JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId 
           WHERE pc.ProductId = p.Id AND v.SKU LIKE N'%' + @Search + N'%'
       )
    ORDER BY p.Id DESC;
END;
GO

-- ----------------------------------------------------------------------------
-- 9. Update Procedure: dbo.sp_AdminGetProductComplete
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminGetProductComplete
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result 1: Product Header Info
    SELECT p.Id, p.CategoryId, p.BrandId, p.Name, p.Slug, p.Description,
           p.BasePrice, p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
           p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive,
           p.MainImageUrl, p.IsActive, p.PublicationStatus,
           b.Name AS BrandName, c.Name AS CategoryName
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    WHERE p.Id = @ProductId;

    -- Result 2: Product Specifications
    SELECT d.SpecificationKey, d.DisplayName, v.SpecificationValue,
           ISNULL(cs.DisplayOrder, 99) AS DisplayOrder
    FROM dbo.ProductSpecificationValues v
    INNER JOIN dbo.SpecificationDefinitions d ON d.Id = v.SpecificationId
    LEFT JOIN dbo.CategorySpecifications cs ON cs.SpecificationId = d.Id AND cs.CategoryId = (SELECT CategoryId FROM dbo.Products WHERE Id = @ProductId)
    WHERE v.ProductId = @ProductId
    ORDER BY cs.DisplayOrder ASC, d.DisplayName ASC;

    -- Result 3: Product Colors
    SELECT Id, Color, ColorHex
    FROM dbo.ProductColors
    WHERE ProductId = @ProductId
    ORDER BY Id ASC;

    -- Result 4: Product Variants
    SELECT pv.Id, pv.ProductColorId, pv.SKU, pv.Size, pv.PriceAdjustment,
           ISNULL(i.CurrentStock, 0) AS CurrentStock,
           ISNULL(i.ReorderPoint, 5) AS ReorderPoint,
           pv.IsActive
    FROM dbo.ProductVariants pv
    JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    LEFT JOIN dbo.Inventories i ON i.VariantId = pv.Id
    WHERE pc.ProductId = @ProductId
    ORDER BY pv.Id ASC;

    -- Result 5: Gallery Images
    SELECT Id, ImageUrl, AltText, DisplayOrder, IsActive
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @ProductId
    ORDER BY DisplayOrder ASC, Id ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 10. Update Procedure: dbo.sp_AdminInventoryProducts
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryProducts
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
        p.Id AS ProductId,
        p.Name AS ProductName,
        p.Slug,
        b.Id AS BrandId,
        b.Name AS BrandName,
        c.Id AS CategoryId,
        c.Name AS CategoryName,
        p.BasePrice,
        p.DiscountPercentage,
        CAST(p.BasePrice * (1.0 - (p.DiscountPercentage / 100.0)) AS DECIMAL(18,2)) AS EffectivePrice,
        p.MainImageUrl,
        p.IsActive,
        ISNULL(SUM(i.CurrentStock), 0) AS TotalStock,
        ISNULL(SUM(i.ReservedStock), 0) AS ReservedStock,
        ISNULL(SUM(i.CurrentStock), 0) - ISNULL(SUM(i.ReservedStock), 0) AS AvailableStock,
        COUNT(DISTINCT pv.Id) AS VariantCount,
        ISNULL(MIN(pv.SKU), N'HC-DEFAULT') AS SampleSKU,
        CASE 
            WHEN ISNULL(SUM(i.CurrentStock), 0) <= 0 THEN 'out_of_stock'
            WHEN ISNULL(SUM(i.CurrentStock), 0) <= 15 THEN 'low_stock'
            ELSE 'in_stock'
        END AS StockStatus
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    LEFT JOIN dbo.v_VisibleProductColors pc ON pc.ProductId = p.Id
    LEFT JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id AND pv.IsActive = 1
    LEFT JOIN dbo.v_VisibleInventories i ON i.VariantId = pv.Id
    WHERE (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%' OR b.Name LIKE N'%' + @Search + N'%' OR pv.SKU LIKE N'%' + @Search + N'%')
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR c.Name = @Category OR c.Slug = @Category)
    GROUP BY p.Id, p.Name, p.Slug, b.Id, b.Name, c.Id, c.Name, p.BasePrice, p.DiscountPercentage, p.MainImageUrl, p.IsActive
    HAVING (@StockStatus = 'all')
        OR (@StockStatus = 'in_stock' AND ISNULL(SUM(i.CurrentStock), 0) > 15)
        OR (@StockStatus = 'low_stock' AND ISNULL(SUM(i.CurrentStock), 0) > 0 AND ISNULL(SUM(i.CurrentStock), 0) <= 15)
        OR (@StockStatus = 'out_of_stock' AND ISNULL(SUM(i.CurrentStock), 0) <= 0)
    ORDER BY p.Id ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 11. Update Procedure: dbo.sp_AdminGlobalSearch
-- ----------------------------------------------------------------------------
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
        CONCAT('/Admin/Inventory.aspx?brand=', b.Name) AS Url,
        'Brand' AS Badge
    FROM dbo.Brands b
    WHERE b.Name LIKE '%' + @Query + '%'

    UNION ALL

    -- 3. Catalog Models
    SELECT TOP (@Limit)
        'Catalog' AS Category,
        CONCAT(b.Name, ' ', p.Name) AS Title,
        CONCAT(cat.Name, NCHAR(32), NCHAR(8226), NCHAR(32), 'Base: ', NCHAR(8369), FORMAT(p.BasePrice, 'N2')) AS Subtitle,
        CONCAT('/Admin/Catalog.aspx?id=', p.Id) AS Url,
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
        CONCAT('/Admin/Inventory.aspx?q=', v.SKU) AS Url,
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
        CONCAT(u.Email, NCHAR(32), NCHAR(8226), NCHAR(32), ISNULL(u.PhoneNumber, 'No phone')) AS Subtitle,
        CONCAT('/Admin/Users.aspx?q=', u.Email) AS Url,
        r.Name AS Badge
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id = u.RoleId
    WHERE CONCAT(u.FirstName, N' ', u.LastName) LIKE '%' + @Query + '%'
       OR u.Email LIKE '%' + @Query + '%'
       OR u.PhoneNumber LIKE '%' + @Query + '%';
END;
GO

-- ----------------------------------------------------------------------------
-- 12. Update Procedure: dbo.sp_AdminDeleteProduct
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminDeleteProduct
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Id = @ProductId)
    BEGIN
        THROW 52020, N'Product not found.', 1;
    END

    BEGIN TRANSACTION;

    DECLARE @ProductName NVARCHAR(200);
    SELECT @ProductName = Name FROM dbo.Products WHERE Id = @ProductId;

    -- Check if product variants have historical customer orders
    DECLARE @HasOrders BIT = 0;
    IF EXISTS (
        SELECT 1 
        FROM dbo.OrderItems oi
        JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        WHERE pc.ProductId = @ProductId
    )
    BEGIN
        SET @HasOrders = 1;
    END

    IF @HasOrders = 1
    BEGIN
        -- Soft delete: Deactivate the product and its variants to preserve financial order history
        UPDATE dbo.Products 
        SET IsActive = 0, 
            PublicationStatus = N'Archived',
            UpdatedAt = SYSUTCDATETIME() 
        WHERE Id = @ProductId;

        UPDATE pv
        SET pv.IsActive = 0
        FROM dbo.ProductVariants pv
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        WHERE pc.ProductId = @ProductId;

        COMMIT TRANSACTION;

        SELECT 
            @ProductId AS ProductId,
            @ProductName AS ProductName,
            N'SoftDeleted' AS Status,
            N'Product has historical order transactions. It has been deactivated and archived.' AS Message;
    END
    ELSE
    BEGIN
        -- Hard delete: No order history exists, safely remove child records in dependency order
        DELETE FROM dbo.StockAuditLogs 
        WHERE VariantId IN (
            SELECT pv.Id 
            FROM dbo.ProductVariants pv
            JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
            WHERE pc.ProductId = @ProductId
        );

        DELETE FROM dbo.Inventories 
        WHERE VariantId IN (
            SELECT pv.Id 
            FROM dbo.ProductVariants pv
            JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
            WHERE pc.ProductId = @ProductId
        );

        DELETE FROM dbo.ProductGalleryImages 
        WHERE ProductId = @ProductId;

        DELETE FROM dbo.ProductSpecificationValues 
        WHERE ProductId = @ProductId;

        DELETE pv
        FROM dbo.ProductVariants pv
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        WHERE pc.ProductId = @ProductId;

        DELETE FROM dbo.ProductColorStops
        WHERE ProductColorId IN (SELECT Id FROM dbo.ProductColors WHERE ProductId = @ProductId);

        DELETE FROM dbo.ProductColors 
        WHERE ProductId = @ProductId;

        DELETE FROM dbo.Products 
        WHERE Id = @ProductId;

        COMMIT TRANSACTION;

        SELECT 
            @ProductId AS ProductId,
            @ProductName AS ProductName,
            N'Deleted' AS Status,
            N'Product and its configuration were successfully deleted.' AS Message;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- 13. Update Procedure: dbo.sp_AdminSaveProduct
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveProduct
    @Id INT,
    @CategoryId INT,
    @BrandId INT,
    @Name NVARCHAR(200),
    @Slug NVARCHAR(220),
    @Description NVARCHAR(MAX) = NULL,
    @RidingStyle NVARCHAR(50) = NULL, -- Deprecated, kept optional for backwards compatibility
    @BasePrice DECIMAL(18,2),
    @DiscountPercentage INT = 0,
    @DiscountType NVARCHAR(20) = N'PERCENTAGE',
    @DiscountAmount DECIMAL(18,2) = 0.00,
    @DiscountStartDate DATETIME2 = NULL,
    @DiscountEndDate DATETIME2 = NULL,
    @MainImageUrl NVARCHAR(500) = NULL,
    @IsFeatured BIT = 0,             -- Deprecated, kept optional for backwards compatibility
    @IsActive BIT = 1,
    @PublicationStatus NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
       OR @BasePrice < 0 OR @DiscountPercentage NOT BETWEEN 0 AND 100
        THROW 52101, N'Invalid product details.', 1;

    -- Resolve PublicationStatus: if omitted, derive from IsActive
    IF @PublicationStatus IS NULL OR @PublicationStatus NOT IN (N'Draft', N'Published', N'Archived')
    BEGIN
        SET @PublicationStatus = CASE WHEN @IsActive = 1 THEN N'Published' ELSE N'Draft' END;
    END;

    DECLARE @UniqueSlug NVARCHAR(220) = @Slug;
    DECLARE @SlugCounter INT = 1;
    WHILE EXISTS (SELECT 1 FROM dbo.Products WHERE Slug = @UniqueSlug AND Id <> @Id)
    BEGIN
        SET @SlugCounter = @SlugCounter + 1;
        SET @UniqueSlug = SUBSTRING(@Slug, 1, 200) + N'-' + CAST(@SlugCounter AS NVARCHAR(10));
    END;
    SET @Slug = @UniqueSlug;

    IF @Id = 0
    BEGIN
        INSERT INTO dbo.Products (
            CategoryId, BrandId, Name, Slug, Description, BasePrice,
            DiscountPercentage, DiscountType, DiscountAmount, DiscountStartDate, DiscountEndDate, DiscountIsActive,
            MainImageUrl, IsActive, PublicationStatus, CreatedAt, UpdatedAt
        )
        VALUES (
            @CategoryId, @BrandId, @Name, @Slug, @Description, @BasePrice,
            ISNULL(@DiscountPercentage, 0), ISNULL(@DiscountType, N'PERCENTAGE'), ISNULL(@DiscountAmount, 0.00),
            @DiscountStartDate, @DiscountEndDate, 1,
            NULLIF(LTRIM(RTRIM(@MainImageUrl)), N''), @IsActive, @PublicationStatus,
            SYSUTCDATETIME(), SYSUTCDATETIME()
        );
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Products
        SET CategoryId = @CategoryId,
            BrandId = @BrandId,
            Name = @Name,
            Slug = @Slug,
            Description = @Description,
            BasePrice = @BasePrice,
            DiscountPercentage = ISNULL(@DiscountPercentage, 0),
            DiscountType = ISNULL(@DiscountType, N'PERCENTAGE'),
            DiscountAmount = ISNULL(@DiscountAmount, 0.00),
            DiscountStartDate = @DiscountStartDate,
            DiscountEndDate = @DiscountEndDate,
            MainImageUrl = NULLIF(LTRIM(RTRIM(@MainImageUrl)), N''),
            IsActive = @IsActive,
            PublicationStatus = @PublicationStatus,
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;
    END;

    SELECT 
        p.Id, p.CategoryId, p.BrandId, p.Name, p.Slug, p.Description,
        p.BasePrice, p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
        p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive,
        p.MainImageUrl, p.IsActive, p.PublicationStatus,
        b.Name AS BrandName, c.Name AS CategoryName
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    WHERE p.Id = @Id;
END;
GO

-- ----------------------------------------------------------------------------
-- 14. Update Procedure: dbo.sp_AdminCreateProductWithVariants
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminCreateProductWithVariants
    @CategoryId INT,
    @BrandId INT,
    @Name NVARCHAR(200),
    @Slug NVARCHAR(220),
    @Description NVARCHAR(MAX),
    @RidingStyle NVARCHAR(50) = NULL, -- Deprecated, kept optional
    @BasePrice DECIMAL(18,2),
    @DiscountPercentage INT = 0,
    @DiscountType NVARCHAR(20) = N'PERCENTAGE',
    @DiscountAmount DECIMAL(18,2) = 0.00,
    @DiscountStartDate DATETIME2 = NULL,
    @DiscountEndDate DATETIME2 = NULL,
    @MainImageUrl NVARCHAR(500),
    @VariantsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
       OR @BasePrice < 0
        THROW 52301, N'Invalid product basic details.', 1;

    BEGIN TRANSACTION;

    INSERT INTO dbo.Products (
        CategoryId, BrandId, Name, Slug, Description, BasePrice,
        DiscountPercentage, DiscountType, DiscountAmount, DiscountStartDate, DiscountEndDate, DiscountIsActive,
        MainImageUrl, IsActive, PublicationStatus, CreatedAt, UpdatedAt
    )
    VALUES (
        @CategoryId, @BrandId, @Name, @Slug, @Description, @BasePrice,
        ISNULL(@DiscountPercentage, 0), ISNULL(@DiscountType, N'PERCENTAGE'), ISNULL(@DiscountAmount, 0.00),
        @DiscountStartDate, @DiscountEndDate, 1,
        @MainImageUrl, 1, N'Published', SYSUTCDATETIME(), SYSUTCDATETIME()
    );

    DECLARE @ProductId INT = SCOPE_IDENTITY();

    -- Parse and insert variants JSON if provided
    DECLARE @ParsedVariants TABLE (
        Color NVARCHAR(100),
        ColorHex NVARCHAR(20),
        Size NVARCHAR(20),
        SKU NVARCHAR(100),
        PriceAdjustment DECIMAL(18,2),
        Stock INT,
        ReorderPoint INT
    );

    IF @VariantsJson IS NOT NULL AND ISJSON(@VariantsJson) = 1
    BEGIN
        INSERT INTO @ParsedVariants (Color, ColorHex, Size, SKU, PriceAdjustment, Stock, ReorderPoint)
        SELECT 
            Color,
            ColorHex,
            Size,
            SKU,
            ISNULL(PriceAdjustment, 0.00),
            ISNULL(Stock, 0),
            ISNULL(ReorderPoint, 5)
        FROM OPENJSON(@VariantsJson)
        WITH (
            Color NVARCHAR(100) '$.Color',
            ColorHex NVARCHAR(20) '$.ColorHex',
            Size NVARCHAR(20) '$.Size',
            SKU NVARCHAR(100) '$.SKU',
            PriceAdjustment DECIMAL(18,2) '$.PriceAdjustment',
            Stock INT '$.Stock',
            ReorderPoint INT '$.ReorderPoint'
        );
    END;

    -- Color deduplication mapping
    DECLARE @ColorMap TABLE (Color NVARCHAR(100), ColorHex NVARCHAR(20), ColorId INT);

    INSERT INTO dbo.ProductColors (ProductId, Color, ColorHex)
    OUTPUT inserted.Color, inserted.ColorHex, inserted.Id INTO @ColorMap (Color, ColorHex, ColorId)
    SELECT DISTINCT @ProductId, Color, ColorHex
    FROM @ParsedVariants;

    -- Insert variants and stock
    DECLARE @VariantId INT, @Size NVARCHAR(20), @SKU NVARCHAR(100), @Adj DECIMAL(18,2), @Stock INT, @Reorder INT, @MappedColorId INT;

    DECLARE cur_vars CURSOR LOCAL FAST_FORWARD FOR 
        SELECT m.ColorId, v.Size, v.SKU, v.PriceAdjustment, v.Stock, v.ReorderPoint
        FROM @ParsedVariants v
        JOIN @ColorMap m ON m.Color = v.Color;

    OPEN cur_vars;
    FETCH NEXT FROM cur_vars INTO @MappedColorId, @Size, @SKU, @Adj, @Stock, @Reorder;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO dbo.ProductVariants (ProductColorId, SKU, Size, PriceAdjustment, IsActive)
        VALUES (@MappedColorId, @SKU, @Size, @Adj, 1);
        SET @VariantId = SCOPE_IDENTITY();

        INSERT INTO dbo.Inventories (VariantId, CurrentStock, ReservedStock, ReorderPoint, LastRestockedAt)
        VALUES (@VariantId, @Stock, 0, @Reorder, SYSUTCDATETIME());

        IF @Stock > 0
        BEGIN
            INSERT INTO dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
            VALUES (@VariantId, 1, 'STOCK_IN', 0, @Stock, 'INIT-CATALOG', 'Initial stock on product creation');
        END;

        FETCH NEXT FROM cur_vars INTO @MappedColorId, @Size, @SKU, @Adj, @Stock, @Reorder;
    END;

    CLOSE cur_vars;
    DEALLOCATE cur_vars;

    COMMIT TRANSACTION;

    SELECT @ProductId AS Id;
END;
GO

-- ----------------------------------------------------------------------------
-- 15. Drop Columns IsFeatured and RidingStyle from dbo.Products
-- ----------------------------------------------------------------------------
IF COL_LENGTH(N'dbo.Products', N'IsFeatured') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Products DROP COLUMN IsFeatured;
    PRINT 'Dropped column dbo.Products.IsFeatured.';
END
GO

IF COL_LENGTH(N'dbo.Products', N'RidingStyle') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Products DROP COLUMN RidingStyle;
    PRINT 'Dropped column dbo.Products.RidingStyle.';
END
GO

PRINT 'Migration 37 completed successfully.';
GO
