-- =====================================================================================
-- 20_multi_brand_and_color_enhancement.sql
-- Enables comma-delimited multi-brand selection in sp_GetProductsPaged
-- Refines fn_BaseColorFromHex for realistic motorcycle helmet color families (including Yellow)
-- =====================================================================================

USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. REFINED COLOR FAMILY HELPER
CREATE OR ALTER FUNCTION dbo.fn_BaseColorFromHex(@ColorHex NVARCHAR(255))
RETURNS NVARCHAR(20)
AS
BEGIN
    IF @ColorHex IS NULL OR LEN(LTRIM(RTRIM(@ColorHex))) = 0
        RETURN NULL;

    DECLARE @CleanHex NVARCHAR(255) = LTRIM(RTRIM(@ColorHex));

    DECLARE @HashIdx INT = CHARINDEX(N'#', @CleanHex);
    IF @HashIdx > 0 AND LEN(@CleanHex) >= @HashIdx + 6
    BEGIN
        SET @CleanHex = SUBSTRING(@CleanHex, @HashIdx, 7);
    END
    ELSE
    BEGIN
        RETURN N'Multi';
    END

    IF LEN(@CleanHex) <> 7 OR LEFT(@CleanHex, 1) <> N'#'
        RETURN N'Multi';

    DECLARE @Hex NVARCHAR(16) = N'0123456789ABCDEF';
    DECLARE @R INT = (CHARINDEX(UPPER(SUBSTRING(@CleanHex, 2, 1)), @Hex) - 1) * 16
                   + CHARINDEX(UPPER(SUBSTRING(@CleanHex, 3, 1)), @Hex) - 1;
    DECLARE @G INT = (CHARINDEX(UPPER(SUBSTRING(@CleanHex, 4, 1)), @Hex) - 1) * 16
                   + CHARINDEX(UPPER(SUBSTRING(@CleanHex, 5, 1)), @Hex) - 1;
    DECLARE @B INT = (CHARINDEX(UPPER(SUBSTRING(@CleanHex, 6, 1)), @Hex) - 1) * 16
                   + CHARINDEX(UPPER(SUBSTRING(@CleanHex, 7, 1)), @Hex) - 1;

    IF @R < 0 OR @G < 0 OR @B < 0 RETURN N'Multi';

    DECLARE @MaxChannel INT = CASE
        WHEN @R >= @G AND @R >= @B THEN @R
        WHEN @G >= @B THEN @G
        ELSE @B
    END;
    DECLARE @MinChannel INT = CASE
        WHEN @R <= @G AND @R <= @B THEN @R
        WHEN @G <= @B THEN @G
        ELSE @B
    END;
    DECLARE @Delta DECIMAL(10,4) = @MaxChannel - @MinChannel;
    DECLARE @Hue DECIMAL(10,4);

    IF @MaxChannel <= 64 RETURN N'Black';
    IF @MinChannel >= 200 RETURN N'White';
    IF @Delta <= 32 RETURN N'Grey';

    SET @Hue = CASE
        WHEN @MaxChannel = @R THEN 60.0 * (@G - @B) / @Delta
        WHEN @MaxChannel = @G THEN 60.0 * ((@B - @R) / @Delta + 2)
        ELSE 60.0 * ((@R - @G) / @Delta + 4)
    END;
    IF @Hue < 0 SET @Hue = @Hue + 360;

    IF @Hue < 15 OR @Hue >= 345 RETURN N'Red';
    IF @Hue < 45 RETURN N'Orange';
    IF @Hue < 70 RETURN N'Yellow';
    IF @Hue < 165 RETURN N'Green';
    IF @Hue < 195 RETURN N'Cyan';
    IF @Hue < 255 RETURN N'Blue';
    IF @Hue < 315 RETURN N'Purple';
    RETURN N'Pink';
END;
GO

-- 2. UPDATE sp_GetProductsPaged FOR MULTI-BRAND SELECTION
CREATE OR ALTER PROCEDURE dbo.sp_GetProductsPaged
    @CategoryId INT = NULL,
    @BrandId INT = NULL,
    @Brand NVARCHAR(200) = NULL,
    @Category NVARCHAR(100) = NULL,
    @RidingStyle NVARCHAR(50) = NULL,
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
      AND (@RidingStyle IS NULL OR @RidingStyle = 'all' OR p.RidingStyle = @RidingStyle)
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%'
          OR b.Name LIKE N'%' + @Search + N'%'
          OR c.Name LIKE N'%' + @Search + N'%'
          OR p.RidingStyle LIKE N'%' + @Search + N'%'
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
        p.RidingStyle,
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
        p.IsFeatured
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    OUTER APPLY (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
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
      AND (@RidingStyle IS NULL OR @RidingStyle = 'all' OR p.RidingStyle = @RidingStyle)
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%'
          OR b.Name LIKE N'%' + @Search + N'%'
          OR c.Name LIKE N'%' + @Search + N'%'
          OR p.RidingStyle LIKE N'%' + @Search + N'%'
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
        CASE WHEN @SortBy = 'price_asc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END ASC,
        CASE WHEN @SortBy = 'price_desc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END DESC,
        CASE WHEN @SortBy = 'newest' THEN p.CreatedAt END DESC,
        CASE WHEN @SortBy = 'rating' THEN review.Rating END DESC,
        CASE WHEN @SortBy = 'popular' OR @SortBy IS NULL THEN review.ReviewCount END DESC,
        p.Id ASC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO
