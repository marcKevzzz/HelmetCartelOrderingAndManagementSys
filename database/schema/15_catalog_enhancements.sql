-- ============================================================================
-- 15_catalog_enhancements.sql
-- Helmet Cartel Ordering & Management System
-- Product Specifications Batch Save, Complete Product Retrieval,
-- and RidingStyle deprecation in admin catalog procedures.
-- ============================================================================

USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Ensure dbo.sp_AdminSaveProduct handles RidingStyle optionally
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveProduct
    @Id INT,
    @CategoryId INT,
    @BrandId INT,
    @Name NVARCHAR(200),
    @Slug NVARCHAR(220),
    @Description NVARCHAR(MAX) = NULL,
    @RidingStyle NVARCHAR(50) = NULL,
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

    -- If RidingStyle not supplied, fall back to Category name or Standard
    IF NULLIF(LTRIM(RTRIM(@RidingStyle)), N'') IS NULL
    BEGIN
        SELECT @RidingStyle = Name FROM dbo.Categories WHERE Id = @CategoryId;
        IF @RidingStyle IS NULL SET @RidingStyle = N'Standard';
    END;

    -- Ensure unique slug if collision occurs with another product
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
            CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice,
            DiscountPercentage, DiscountType, DiscountAmount, DiscountStartDate, DiscountEndDate, DiscountIsActive,
            MainImageUrl, IsFeatured, IsActive, CreatedAt, UpdatedAt
        )
        VALUES (
            @CategoryId, @BrandId, @Name, @Slug, @Description, @RidingStyle, @BasePrice,
            ISNULL(@DiscountPercentage, 0), ISNULL(@DiscountType, N'PERCENTAGE'), ISNULL(@DiscountAmount, 0.00),
            @DiscountStartDate, @DiscountEndDate, 1,
            NULLIF(LTRIM(RTRIM(@MainImageUrl)), N''), @IsFeatured, @IsActive,
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
            MainImageUrl = NULLIF(LTRIM(RTRIM(@MainImageUrl)), N''),
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

-- 2. Stored Procedure to batch upsert specifications for a product from JSON
-- JSON format: [{"key":"shell_architecture","name":"Shell Architecture","value":"Multi-Fiber Composite"}, ...]
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveProductSpecifications
    @ProductId INT,
    @SpecsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Id = @ProductId)
        THROW 52120, N'Product not found.', 1;

    DECLARE @CategoryId INT;
    SELECT @CategoryId = CategoryId FROM dbo.Products WHERE Id = @ProductId;

    IF @SpecsJson IS NULL OR LTRIM(RTRIM(@SpecsJson)) = N'' OR @SpecsJson = N'[]'
        RETURN;

    BEGIN TRANSACTION;

    -- Parse JSON into table variable
    DECLARE @ParsedSpecs TABLE (
        SpecKey NVARCHAR(80),
        DisplayName NVARCHAR(120),
        SpecValue NVARCHAR(1000),
        DisplayOrder INT IDENTITY(1,1)
    );

    INSERT INTO @ParsedSpecs (SpecKey, DisplayName, SpecValue)
    SELECT 
        LOWER(LTRIM(RTRIM(JSON_VALUE(s.value, '$.key')))),
        LTRIM(RTRIM(JSON_VALUE(s.value, '$.name'))),
        LTRIM(RTRIM(JSON_VALUE(s.value, '$.value')))
    FROM OPENJSON(@SpecsJson) AS s
    WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(s.value, '$.key'))), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(JSON_VALUE(s.value, '$.value'))), N'') IS NOT NULL;

    -- Ensure SpecificationDefinitions exist
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName)
    SELECT DISTINCT p.SpecKey, ISNULL(NULLIF(p.DisplayName, N''), p.SpecKey)
    FROM @ParsedSpecs p
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.SpecificationDefinitions d
        WHERE d.SpecificationKey = p.SpecKey
    );

    -- Ensure CategorySpecifications exist for this category
    INSERT INTO dbo.CategorySpecifications (CategoryId, SpecificationId, DisplayOrder, IsRequired)
    SELECT @CategoryId, d.Id, p.DisplayOrder, 0
    FROM @ParsedSpecs p
    INNER JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = p.SpecKey
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.CategorySpecifications cs
        WHERE cs.CategoryId = @CategoryId AND cs.SpecificationId = d.Id
    );

    -- Upsert ProductSpecificationValues
    MERGE dbo.ProductSpecificationValues AS target
    USING (
        SELECT d.Id AS SpecificationId, p.SpecValue
        FROM @ParsedSpecs p
        INNER JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = p.SpecKey
    ) AS source
    ON (target.ProductId = @ProductId AND target.SpecificationId = source.SpecificationId)
    WHEN MATCHED THEN
        UPDATE SET target.SpecificationValue = source.SpecValue,
                   target.UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ProductId, SpecificationId, SpecificationValue, CreatedAt)
        VALUES (@ProductId, source.SpecificationId, source.SpecValue, SYSUTCDATETIME());

    COMMIT TRANSACTION;
END;
GO

-- 3. Stored Procedure to retrieve full product details for the admin editor
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

-- 4. Clear Product Gallery Images
CREATE OR ALTER PROCEDURE dbo.sp_AdminClearProductGallery
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.ProductGalleryImages WHERE ProductId = @ProductId;
END;
GO

-- 5. Upsert-safe Save Color Procedure
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

    -- Auto-resolve existing color by ProductId and Color if @Id = 0
    IF @Id = 0
    BEGIN
        SELECT @Id = Id FROM dbo.ProductColors WHERE ProductId = @ProductId AND Color = @Color;
        IF @Id IS NULL SET @Id = 0;
    END;

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

-- 6. Upsert-safe Save Variant Procedure
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveVariant
    @Id INT, @ProductColorId INT, @SKU NVARCHAR(100), @Size NVARCHAR(20),
    @PriceAdjustment DECIMAL(18,2), @ReorderPoint INT, @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@SKU)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Size)), N'') IS NULL
       OR @ReorderPoint < 0 THROW 52113, N'Invalid variant details.', 1;

    -- Auto-resolve existing variant by (ProductColorId, Size) or SKU if @Id = 0
    IF @Id = 0
    BEGIN
        SELECT @Id = Id FROM dbo.ProductVariants WHERE ProductColorId = @ProductColorId AND Size = @Size;
        IF @Id IS NULL OR @Id = 0
            SELECT @Id = Id FROM dbo.ProductVariants WHERE SKU = @SKU;
        IF @Id IS NULL SET @Id = 0;
    END;

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

