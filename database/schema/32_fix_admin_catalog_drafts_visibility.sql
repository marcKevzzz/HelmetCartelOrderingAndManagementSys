-- ====================================================================
-- Migration: 32_fix_admin_catalog_drafts_visibility.sql
-- Description: Update dbo.sp_AdminCatalogProducts to query dbo.Products
--              directly so drafts (IsActive = 0) are visible to Admins.
-- ====================================================================

USE HelmetCartelDB;
GO

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
        p.RidingStyle, 
        p.BasePrice, 
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        p.DiscountIsActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        p.MainImageUrl, 
        p.IsFeatured, 
        p.IsActive, 
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
