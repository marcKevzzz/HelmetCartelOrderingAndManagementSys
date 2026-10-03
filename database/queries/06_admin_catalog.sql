USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminCatalogProducts @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.Id, p.Name, p.Slug, p.Description, p.CategoryId, c.Name AS Category,
           p.BrandId, b.Name AS Brand, p.RidingStyle, p.BasePrice, p.DiscountPercentage,
           p.MainImageUrl, p.IsFeatured, p.IsActive, p.CreatedAt,
           (SELECT COUNT(*) FROM dbo.ProductVariants v JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId WHERE pc.ProductId = p.Id) AS VariantCount
    FROM dbo.Products p JOIN dbo.Categories c ON c.Id = p.CategoryId JOIN dbo.Brands b ON b.Id = p.BrandId
    WHERE @Search IS NULL OR p.Name LIKE N'%' + @Search + N'%' OR p.Slug LIKE N'%' + @Search + N'%'
    ORDER BY p.CreatedAt DESC, p.Id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminCategories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Name, Slug, Description, DisplayOrder, IsActive FROM dbo.Categories ORDER BY DisplayOrder, Name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminBrands
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Name, LogoUrl, Website, IsActive FROM dbo.Brands ORDER BY Name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminColors @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.Id, c.ProductId, c.Color, c.ColorHex, c.ColorType, c.GradientAngle,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 1) AS Stop1,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 2) AS Stop2,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 3) AS Stop3,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 4) AS Stop4
    FROM dbo.ProductColors c WHERE c.ProductId = @ProductId ORDER BY c.Color;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminVariants @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.Id, v.ProductColorId, c.Color, v.SKU, v.Size, v.PriceAdjustment, v.IsActive,
           ISNULL(i.CurrentStock, 0) AS CurrentStock, ISNULL(i.ReservedStock, 0) AS ReservedStock,
           ISNULL(i.ReorderPoint, 3) AS ReorderPoint
    FROM dbo.ProductVariants v JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE c.ProductId = @ProductId ORDER BY c.Color, v.Size;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveProduct
    @Id INT, @CategoryId INT, @BrandId INT, @Name NVARCHAR(200), @Slug NVARCHAR(220),
    @Description NVARCHAR(MAX), @RidingStyle NVARCHAR(50), @BasePrice DECIMAL(18,2),
    @DiscountPercentage INT, @MainImageUrl NVARCHAR(500), @IsFeatured BIT, @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
       OR @BasePrice < 0 OR @DiscountPercentage NOT BETWEEN 0 AND 100
        THROW 52101, N'Invalid product details.', 1;
    IF @Id = 0
    BEGIN
        INSERT dbo.Products (CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice,
            DiscountPercentage, MainImageUrl, IsFeatured, IsActive)
        VALUES (@CategoryId, @BrandId, @Name, @Slug, @Description, @RidingStyle, @BasePrice,
            @DiscountPercentage, @MainImageUrl, @IsFeatured, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Products SET CategoryId = @CategoryId, BrandId = @BrandId, Name = @Name, Slug = @Slug,
            Description = @Description, RidingStyle = @RidingStyle, BasePrice = @BasePrice,
            DiscountPercentage = @DiscountPercentage, MainImageUrl = @MainImageUrl,
            IsFeatured = @IsFeatured, IsActive = @IsActive, UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;
        IF @@ROWCOUNT = 0 THROW 52102, N'Product not found.', 1;
    END;
    SELECT @Id AS Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveCategory
    @Id INT, @Name NVARCHAR(100), @Slug NVARCHAR(100), @Description NVARCHAR(500), @DisplayOrder INT, @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
        THROW 52103, N'Category name and slug are required.', 1;
    IF @Id = 0
    BEGIN
        INSERT dbo.Categories (Name, Slug, Description, DisplayOrder, IsActive)
        VALUES (@Name, @Slug, @Description, @DisplayOrder, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Categories SET Name = @Name, Slug = @Slug, Description = @Description,
            DisplayOrder = @DisplayOrder, IsActive = @IsActive WHERE Id = @Id;
        IF @@ROWCOUNT = 0 THROW 52104, N'Category not found.', 1;
    END;
    SELECT @Id AS Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveBrand
    @Id INT, @Name NVARCHAR(100), @LogoUrl NVARCHAR(255), @Website NVARCHAR(255), @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL THROW 52105, N'Brand name is required.', 1;
    IF @Id = 0
    BEGIN
        INSERT dbo.Brands (Name, LogoUrl, Website, IsActive) VALUES (@Name, @LogoUrl, @Website, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Brands SET Name = @Name, LogoUrl = @LogoUrl, Website = @Website, IsActive = @IsActive WHERE Id = @Id;
        IF @@ROWCOUNT = 0 THROW 52106, N'Brand not found.', 1;
    END;
    SELECT @Id AS Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveColor
    @Id INT, @ProductId INT, @Color NVARCHAR(50), @ColorType NVARCHAR(20), @SolidHex NCHAR(7),
    @GradientAngle INT, @Stop1 NCHAR(7), @Stop2 NCHAR(7), @Stop3 NCHAR(7), @Stop4 NCHAR(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@Color)), N'') IS NULL THROW 52107, N'Color name is required.', 1;
    IF @ColorType NOT IN (N'SOLID', N'LINEAR_GRADIENT') THROW 52108, N'Invalid color type.', 1;
    IF @ColorType = N'SOLID' AND (@SolidHex IS NULL OR @SolidHex NOT LIKE N'#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')
        THROW 52109, N'Solid color must use six-digit hex.', 1;
    IF @ColorType = N'LINEAR_GRADIENT' AND (@GradientAngle NOT BETWEEN 0 AND 359 OR @Stop1 IS NULL OR @Stop2 IS NULL)
        THROW 52110, N'Gradient needs angle and at least two stops.', 1;
    IF @ColorType = N'LINEAR_GRADIENT' AND @Stop4 IS NOT NULL AND @Stop3 IS NULL
        THROW 52117, N'Gradient stops must be ordered.', 1;
    IF @ColorType = N'LINEAR_GRADIENT' AND EXISTS
       (SELECT 1 FROM (VALUES (@Stop1), (@Stop2), (@Stop3), (@Stop4)) AS s(Hex)
        WHERE s.Hex IS NOT NULL AND s.Hex NOT LIKE N'#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')
        THROW 52111, N'Gradient stops must use six-digit hex.', 1;
    DECLARE @Value NVARCHAR(255) = @SolidHex;
    IF @ColorType = N'LINEAR_GRADIENT'
        SET @Value = CONCAT(N'linear-gradient(', @GradientAngle, N'deg, ', @Stop1, N', ', @Stop2,
                            CASE WHEN @Stop3 IS NULL THEN N'' ELSE CONCAT(N', ', @Stop3) END,
                            CASE WHEN @Stop4 IS NULL THEN N'' ELSE CONCAT(N', ', @Stop4) END, N')');
    BEGIN TRANSACTION;
    IF @Id = 0
    BEGIN
        INSERT dbo.ProductColors (ProductId, Color, ColorHex, ColorType, GradientAngle)
        VALUES (@ProductId, @Color, @Value, @ColorType, CASE WHEN @ColorType = N'SOLID' THEN NULL ELSE @GradientAngle END);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.ProductColors SET Color = @Color, ColorHex = @Value, ColorType = @ColorType,
            GradientAngle = CASE WHEN @ColorType = N'SOLID' THEN NULL ELSE @GradientAngle END
        WHERE Id = @Id AND ProductId = @ProductId;
        IF @@ROWCOUNT = 0 THROW 52112, N'Product color not found.', 1;
    END;
    DELETE dbo.ProductColorStops WHERE ProductColorId = @Id;
    IF @ColorType = N'LINEAR_GRADIENT'
        INSERT dbo.ProductColorStops (ProductColorId, StopOrder, ColorHex)
        SELECT @Id, s.StopOrder, s.Hex FROM (VALUES (1, @Stop1), (2, @Stop2), (3, @Stop3), (4, @Stop4)) s(StopOrder, Hex)
        WHERE s.Hex IS NOT NULL;
    COMMIT TRANSACTION;
    SELECT @Id AS Id, @Value AS ColorHex;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveVariant
    @Id INT, @ProductColorId INT, @SKU NVARCHAR(100), @Size NVARCHAR(20),
    @PriceAdjustment DECIMAL(18,2), @ReorderPoint INT, @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @IsActive IS NULL SET @IsActive = 1;
    IF NULLIF(LTRIM(RTRIM(@SKU)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Size)), N'') IS NULL
       OR @ReorderPoint < 0 THROW 52113, N'Invalid variant details.', 1;
    BEGIN TRANSACTION;
    IF @Id = 0
    BEGIN
        INSERT dbo.ProductVariants (ProductColorId, SKU, Size, PriceAdjustment, IsActive)
        VALUES (@ProductColorId, @SKU, @Size, @PriceAdjustment, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
        INSERT dbo.Inventories (VariantId, CurrentStock, ReorderPoint) VALUES (@Id, 0, @ReorderPoint);
    END
    ELSE
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.OrderItems oi
            JOIN dbo.ProductVariants v WITH (UPDLOCK, ROWLOCK) ON v.Id = oi.VariantId
            WHERE oi.VariantId = @Id
              AND (v.ProductColorId <> @ProductColorId OR v.SKU <> @SKU OR v.Size <> @Size)
        )
            THROW 52118, N'Cannot change color, SKU, or size of a variant linked to an order.', 1;
        UPDATE dbo.ProductVariants SET ProductColorId = @ProductColorId, SKU = @SKU, Size = @Size,
            PriceAdjustment = @PriceAdjustment, IsActive = @IsActive WHERE Id = @Id;
        IF @@ROWCOUNT = 0 THROW 52114, N'Variant not found.', 1;
        UPDATE dbo.Inventories SET ReorderPoint = @ReorderPoint, UpdatedAt = SYSUTCDATETIME() WHERE VariantId = @Id;
    END;
    COMMIT TRANSACTION;
    SELECT @Id AS Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminGallery @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, ProductId, ImageUrl, AltText, DisplayOrder, IsActive
    FROM dbo.ProductGalleryImages WHERE ProductId = @ProductId ORDER BY DisplayOrder;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveGallery
    @Id INT, @ProductId INT, @ImageUrl NVARCHAR(500), @AltText NVARCHAR(200), @DisplayOrder INT, @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@ImageUrl)), N'') IS NULL OR @DisplayOrder < 1
        THROW 52115, N'Image and positive display order are required.', 1;
    IF @Id = 0
    BEGIN
        INSERT dbo.ProductGalleryImages (ProductId, ImageUrl, AltText, DisplayOrder, IsActive)
        VALUES (@ProductId, @ImageUrl, @AltText, @DisplayOrder, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.ProductGalleryImages SET ImageUrl = @ImageUrl, AltText = @AltText,
            DisplayOrder = @DisplayOrder, IsActive = @IsActive, UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND ProductId = @ProductId;
        IF @@ROWCOUNT = 0 THROW 52116, N'Gallery image not found.', 1;
    END;
    SELECT @Id AS Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSpecifications @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.SpecificationKey, d.DisplayName, cs.DisplayOrder, cs.IsRequired,
           v.SpecificationValue
    FROM dbo.Products p JOIN dbo.CategorySpecifications cs ON cs.CategoryId = p.CategoryId
    JOIN dbo.SpecificationDefinitions d ON d.Id = cs.SpecificationId AND d.IsActive = 1
    LEFT JOIN dbo.ProductSpecificationValues v ON v.ProductId = p.Id AND v.SpecificationId = d.Id
    WHERE p.Id = @ProductId ORDER BY cs.DisplayOrder, d.DisplayName;
END;
GO
