-- ============================================================================
-- 10_product_edit_and_gallery.sql
-- Helmet Cartel Ordering & Management System
-- Product edit stored procedure and gallery image upload procedures
-- ============================================================================

USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Ensure dbo.sp_AdminSaveProduct supports full product editing and discounts
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveProduct
    @Id INT,
    @CategoryId INT,
    @BrandId INT,
    @Name NVARCHAR(200),
    @Slug NVARCHAR(220),
    @Description NVARCHAR(MAX) = NULL,
    @RidingStyle NVARCHAR(50) = N'Sport/Street',
    @BasePrice DECIMAL(18,2),
    @DiscountPercentage INT = 0,
    @DiscountType NVARCHAR(20) = N'PERCENTAGE',
    @DiscountAmount DECIMAL(18,2) = 0.00,
    @DiscountStartDate DATETIME2 = NULL,
    @DiscountEndDate DATETIME2 = NULL,
    @MainImageUrl NVARCHAR(500) = NULL,
    @IsFeatured BIT = 0,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
       OR @BasePrice < 0 OR @DiscountPercentage NOT BETWEEN 0 AND 100
        THROW 52101, N'Invalid product details.', 1;

    IF @Id = 0
    BEGIN
        INSERT INTO dbo.Products (
            CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice,
            DiscountPercentage, DiscountType, DiscountAmount, DiscountStartDate, DiscountEndDate, DiscountIsActive,
            MainImageUrl, IsFeatured, IsActive, CreatedAt, UpdatedAt
        )
        VALUES (
            @CategoryId, @BrandId, @Name, @Slug, @Description, @RidingStyle, @BasePrice,
            ISNULL(@DiscountPercentage, 0), ISNULL(@DiscountType, N'PERCENTAGE'), ISNULL(@DiscountAmount, 0.00),
            @DiscountStartDate, @DiscountEndDate, 1,
            ISNULL(@MainImageUrl, N'/Content/images/products/helmets/agv/images.jpg'), @IsFeatured, @IsActive,
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
            RidingStyle = @RidingStyle,
            BasePrice = @BasePrice,
            DiscountPercentage = ISNULL(@DiscountPercentage, 0),
            DiscountType = ISNULL(@DiscountType, N'PERCENTAGE'),
            DiscountAmount = ISNULL(@DiscountAmount, 0.00),
            DiscountStartDate = @DiscountStartDate,
            DiscountEndDate = @DiscountEndDate,
            MainImageUrl = CASE WHEN @MainImageUrl IS NOT NULL AND LTRIM(RTRIM(@MainImageUrl)) <> N'' THEN @MainImageUrl ELSE MainImageUrl END,
            IsFeatured = @IsFeatured,
            IsActive = @IsActive,
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 52102, N'Product not found for update.', 1;
    END;

    SELECT @Id AS Id;
END;
GO

-- 2. Add Stored Procedure for Product Gallery Image
CREATE OR ALTER PROCEDURE dbo.sp_AdminAddProductGalleryImage
    @ProductId INT,
    @ImageUrl NVARCHAR(500),
    @AltText NVARCHAR(200) = NULL,
    @DisplayOrder INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Id = @ProductId)
        THROW 52107, N'Invalid product ID for gallery.', 1;

    INSERT INTO dbo.ProductGalleryImages (ProductId, ImageUrl, AltText, DisplayOrder)
    VALUES (@ProductId, @ImageUrl, @AltText, @DisplayOrder);

    SELECT SCOPE_IDENTITY() AS GalleryImageId;
END;
GO

PRINT '10_product_edit_and_gallery.sql applied successfully.';
GO
