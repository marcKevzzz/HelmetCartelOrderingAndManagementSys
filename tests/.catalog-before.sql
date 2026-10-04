
-- ----------------------------------------------------------------------------
-- 4. Update Procedure: dbo.sp_GetProductsPaged
-- ----------------------------------------------------------------------------
CREATE   PROCEDURE dbo.sp_GetProductsPaged
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
