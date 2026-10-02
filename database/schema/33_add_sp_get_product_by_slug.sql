-- ============================================================================
-- Migration 33: Add stored procedure dbo.sp_GetProductBySlug
-- Enables looking up products and variants by slug for clean SEO URLs
-- ============================================================================
USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetProductBySlug
    @Slug NVARCHAR(220)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();
    DECLARE @ProductId INT;

    SELECT @ProductId = Id
    FROM dbo.v_VisibleProducts
    WHERE Slug = @Slug AND IsActive = 1;

    IF @ProductId IS NULL
    BEGIN
        -- Return empty result sets
        SELECT TOP 0 NULL AS Id;
        RETURN;
    END;

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
        p.IsFeatured
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
    WHERE p.Id = @ProductId AND p.IsActive = 1;

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
    WHERE pc.ProductId = @ProductId AND pv.IsActive = 1
    ORDER BY pv.Id ASC;

    SELECT ImageUrl,
           COALESCE(AltText, N'Product view') AS AltText,
           CONVERT(INT, DisplayOrder) AS DisplayOrder
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @ProductId AND IsActive = 1
    ORDER BY DisplayOrder ASC, Id ASC;
END;
GO
