-- ============================================================================
-- Migration 39: Inventory Variant Active Toggle and Visibility
-- Description:
--   1. Updates dbo.sp_AdminInventoryVariants to return v.IsActive and allow
--      inventory management across all active and inactive variants.
--      Supports 'active' and 'inactive' stockStatus filter tabs.
--   2. Creates dbo.sp_AdminToggleVariantActive for instant atomic toggle
--      of variant active/inactive status with concurrency safety.
-- ============================================================================

USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- 1. Procedure: dbo.sp_AdminInventoryVariants
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryVariants
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL,
    @StockStatus NVARCHAR(50) = N'all',
    @ProductId INT = NULL,
    @VariantId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    IF @Brand = N'all' SET @Brand = NULL;
    IF @Category = N'all' SET @Category = NULL;
    IF @StockStatus IS NULL OR LTRIM(RTRIM(@StockStatus)) = N'' SET @StockStatus = N'all';

    SELECT 
        v.Id AS VariantId, 
        p.Id AS ProductId, 
        b.Name AS BrandName,
        p.Name AS ProductName, 
        cat.Name AS CategoryName, 
        c.Color, 
        c.ColorHex,
        v.Size, 
        ISNULL(i.CurrentStock, 0) AS CurrentStock,
        ISNULL(i.ReservedStock, 0) AS ReservedStock,
        ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) AS AvailableStock,
        ISNULL(i.ReorderPoint, 3) AS ReorderPoint,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
            p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
            p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        v.SKU, 
        p.MainImageUrl,
        CASE 
            WHEN ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) <= 0 THEN N'out_of_stock'
            WHEN ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) <= ISNULL(i.ReorderPoint, 3) THEN N'low_stock'
            ELSE N'in_stock' 
        END AS StockStatus,
        v.IsActive,
        p.IsActive AS ProductIsActive,
        p.PublicationStatus
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE (@ProductId IS NULL OR p.Id = @ProductId)
      AND (@VariantId IS NULL OR v.Id = @VariantId)
      AND (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%'
           OR b.Name LIKE N'%' + @Search + N'%' OR cat.Name LIKE N'%' + @Search + N'%'
           OR v.SKU LIKE N'%' + @Search + N'%' OR c.Color LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name) LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name, N' ', c.Color) LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name, N' ', c.Color, N' ', v.Size) LIKE N'%' + @Search + N'%'
           OR CONCAT(p.Name, N' ', c.Color) LIKE N'%' + @Search + N'%')
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR cat.Name = @Category OR cat.Slug = @Category)
      AND (
           (@StockStatus = N'all')
           OR (@StockStatus = N'active' AND v.IsActive = 1)
           OR (@StockStatus = N'inactive' AND v.IsActive = 0)
           OR (@StockStatus = N'in_stock' AND ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) > ISNULL(i.ReorderPoint, 3))
           OR (@StockStatus = N'low_stock' AND ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) BETWEEN 1 AND ISNULL(i.ReorderPoint, 3))
           OR (@StockStatus = N'out_of_stock' AND ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) <= 0)
      )
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;
GO

-- ----------------------------------------------------------------------------
-- 2. Procedure: dbo.sp_AdminToggleVariantActive
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminToggleVariantActive
    @VariantId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @VariantId IS NULL OR @VariantId <= 0
    BEGIN
        THROW 52120, N'Invalid variant ID.', 1;
    END;

    BEGIN TRANSACTION;

    DECLARE @NewStatus BIT;

    UPDATE dbo.ProductVariants WITH (UPDLOCK, ROWLOCK)
    SET IsActive = CASE WHEN IsActive = 1 THEN 0 ELSE 1 END
    WHERE Id = @VariantId;

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 52119, N'Variant not found.', 1;
    END;

    SELECT @NewStatus = IsActive
    FROM dbo.ProductVariants
    WHERE Id = @VariantId;

    COMMIT TRANSACTION;

    SELECT @VariantId AS VariantId, @NewStatus AS IsActive;
END;
GO
