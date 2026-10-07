-- Migration 56: Fix sp_GetProductById discount calculation & bit casts
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
        CONVERT(BIT, CASE
            WHEN ISNULL(p.DiscountIsActive, 1) = 1
                 AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
                 AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
                 AND (p.DiscountPercentage > 0 OR (UPPER(LTRIM(RTRIM(ISNULL(p.DiscountType, '')))) IN (N'FIXED_AMOUNT', N'FIXEDAMOUNT') AND p.DiscountAmount > 0))
            THEN 1 ELSE 0
        END) AS IsDiscountActive,
        CONVERT(BIT, CASE
            WHEN ISNULL(p.DiscountIsActive, 1) = 1
                 AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
                 AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
                 AND (p.DiscountPercentage > 0 OR (UPPER(LTRIM(RTRIM(ISNULL(p.DiscountType, '')))) IN (N'FIXED_AMOUNT', N'FIXEDAMOUNT') AND p.DiscountAmount > 0))
            THEN 1 ELSE 0
        END) AS HasActiveDiscount,
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
        ISNULL(i.IsLowStock, 0) AS IsLowStock,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        CONVERT(BIT, CASE
            WHEN ISNULL(p.DiscountIsActive, 1) = 1
                 AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
                 AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
                 AND (p.DiscountPercentage > 0 OR (UPPER(LTRIM(RTRIM(ISNULL(p.DiscountType, '')))) IN (N'FIXED_AMOUNT', N'FIXEDAMOUNT') AND p.DiscountAmount > 0))
            THEN 1 ELSE 0
        END) AS HasActiveDiscount
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
