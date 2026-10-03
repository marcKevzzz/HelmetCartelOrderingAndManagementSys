-- ============================================================================
-- Migration 34: Fix Admin Product Complete & Variants to Support Draft Helmets
-- Description: Update dbo.sp_AdminGetProductComplete, dbo.sp_AdminColors, and
--              dbo.sp_AdminVariants to query base tables directly instead of
--              v_Visible views so administrators can view, edit, and configure
--              draft helmet models (IsActive = 0) and inactive variants.
-- ============================================================================
USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Retrieve full product details for the admin editor (Drafts + Published)
CREATE OR ALTER PROCEDURE dbo.sp_AdminGetProductComplete
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result 1: Product Header Info
    SELECT p.Id, p.CategoryId, p.BrandId, p.Name, p.Slug, p.Description, p.RidingStyle,
           p.BasePrice, p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
           p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive,
           p.MainImageUrl, p.IsFeatured, p.IsActive,
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
    ORDER BY DisplayOrder, d.DisplayName;

    -- Result 3: Product Colors & Color Stops
    SELECT pc.Id, pc.Color, pc.ColorHex, pc.ColorType, pc.GradientAngle
    FROM dbo.ProductColors pc
    WHERE pc.ProductId = @ProductId
    ORDER BY pc.Id;

    -- Result 4: Product Variants & Stocks
    SELECT pv.Id AS VariantId, pv.ProductColorId, pc.Color, pc.ColorHex, pv.Size, pv.SKU,
           pv.PriceAdjustment, pv.IsActive,
           ISNULL(inv.CurrentStock, 0) AS CurrentStock,
           ISNULL(inv.ReorderPoint, 3) AS ReorderPoint
    FROM dbo.ProductVariants pv
    INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    LEFT JOIN dbo.Inventories inv ON inv.VariantId = pv.Id
    WHERE pc.ProductId = @ProductId
    ORDER BY pc.Id, pv.Size;

    -- Result 5: Product Gallery Images
    SELECT Id, ImageUrl, AltText, DisplayOrder
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @ProductId
    ORDER BY DisplayOrder;
END;
GO

-- 2. Retrieve product colors for admin API
CREATE OR ALTER PROCEDURE dbo.sp_AdminColors
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.Id, c.ProductId, c.Color, c.ColorHex, c.ColorType, c.GradientAngle,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 1) AS Stop1,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 2) AS Stop2,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 3) AS Stop3,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 4) AS Stop4
    FROM dbo.ProductColors c
    WHERE c.ProductId = @ProductId
    ORDER BY c.Color;
END;
GO

-- 3. Retrieve product variants for admin API
CREATE OR ALTER PROCEDURE dbo.sp_AdminVariants
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.Id, v.ProductColorId, c.Color, v.SKU, v.Size, v.PriceAdjustment, v.IsActive,
           ISNULL(i.CurrentStock, 0) AS CurrentStock,
           ISNULL(i.ReservedStock, 0) AS ReservedStock,
           ISNULL(i.ReorderPoint, 3) AS ReorderPoint
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE c.ProductId = @ProductId
    ORDER BY c.Color, v.Size;
END;
GO
