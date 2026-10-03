-- ============================================================================
-- Migration 39: Robust Product Specifications Management
-- Ensures full support for saving, updating, deleting, and displaying
-- both standard and custom technical specifications.
-- ============================================================================

PRINT N'Updating dbo.sp_AdminSaveProductSpecifications...';
GO

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

    -- If null, empty string, or empty array, remove all specifications for this product
    IF @SpecsJson IS NULL OR LTRIM(RTRIM(@SpecsJson)) = N'' OR @SpecsJson = N'[]'
    BEGIN
        DELETE FROM dbo.ProductSpecificationValues WHERE ProductId = @ProductId;
        RETURN;
    END;

    BEGIN TRANSACTION;

    DECLARE @ParsedSpecs TABLE (
        SpecKey NVARCHAR(80),
        DisplayName NVARCHAR(120),
        SpecValue NVARCHAR(1000),
        DisplayOrder INT IDENTITY(1,1)
    );

    INSERT INTO @ParsedSpecs (SpecKey, DisplayName, SpecValue)
    SELECT 
        LOWER(LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.key'), JSON_VALUE(s.value, '$.SpecificationKey'), JSON_VALUE(s.value, '$.specificationKey'))))),
        LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.name'), JSON_VALUE(s.value, '$.DisplayName'), JSON_VALUE(s.value, '$.displayName'), JSON_VALUE(s.value, '$.key'), JSON_VALUE(s.value, '$.SpecificationKey')))),
        LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.value'), JSON_VALUE(s.value, '$.SpecificationValue'), JSON_VALUE(s.value, '$.specificationValue'))))
    FROM OPENJSON(@SpecsJson) AS s
    WHERE NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.key'), JSON_VALUE(s.value, '$.SpecificationKey'), JSON_VALUE(s.value, '$.specificationKey')))), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.value'), JSON_VALUE(s.value, '$.SpecificationValue'), JSON_VALUE(s.value, '$.specificationValue')))), N'') IS NOT NULL;

    -- Ensure definition entries exist (deduplicated by SpecKey)
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt)
    SELECT p.SpecKey, MAX(ISNULL(NULLIF(p.DisplayName, N''), p.SpecKey)), 1, SYSUTCDATETIME()
    FROM @ParsedSpecs p
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.SpecificationDefinitions d
        WHERE d.SpecificationKey = p.SpecKey
    )
    GROUP BY p.SpecKey;

    -- Ensure category mapping exists
    IF @CategoryId IS NOT NULL
    BEGIN
        INSERT INTO dbo.CategorySpecifications (CategoryId, SpecificationId, DisplayOrder, IsRequired)
        SELECT @CategoryId, d.Id, MIN(p.DisplayOrder), 0
        FROM @ParsedSpecs p
        INNER JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = p.SpecKey
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.CategorySpecifications cs
            WHERE cs.CategoryId = @CategoryId AND cs.SpecificationId = d.Id
        )
        GROUP BY d.Id;
    END;

    -- Upsert ProductSpecificationValues and purge removed specifications
    MERGE dbo.ProductSpecificationValues AS target
    USING (
        SELECT d.Id AS SpecificationId, MAX(p.SpecValue) AS SpecValue
        FROM @ParsedSpecs p
        INNER JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = p.SpecKey
        GROUP BY d.Id
    ) AS source
    ON (target.ProductId = @ProductId AND target.SpecificationId = source.SpecificationId)
    WHEN MATCHED THEN
        UPDATE SET target.SpecificationValue = source.SpecValue,
                   target.UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ProductId, SpecificationId, SpecificationValue, CreatedAt)
        VALUES (@ProductId, source.SpecificationId, source.SpecValue, SYSUTCDATETIME())
    WHEN NOT MATCHED BY SOURCE AND target.ProductId = @ProductId THEN
        DELETE;

    COMMIT TRANSACTION;
END;
GO

PRINT N'Updating dbo.sp_GetProductSpecifications...';
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetProductSpecifications
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT d.SpecificationKey,
           d.DisplayName,
           v.SpecificationValue,
           ISNULL(cs.DisplayOrder, 99) AS DisplayOrder
    FROM dbo.Products p
    INNER JOIN dbo.ProductSpecificationValues v ON v.ProductId = p.Id
    INNER JOIN dbo.SpecificationDefinitions d ON d.Id = v.SpecificationId AND d.IsActive = 1
    LEFT JOIN dbo.CategorySpecifications cs ON cs.CategoryId = p.CategoryId AND cs.SpecificationId = d.Id
    WHERE p.Id = @ProductId
    ORDER BY ISNULL(cs.DisplayOrder, 99), d.DisplayName;
END;
GO

PRINT N'Updating dbo.sp_AdminGetProductComplete...';
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminGetProductComplete
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result 1: Product Header Info
    SELECT p.Id, p.CategoryId, p.BrandId, p.Name, p.Slug, p.Description,
           p.BasePrice, p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
           p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive,
           p.MainImageUrl, p.IsActive, p.PublicationStatus,
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
    ORDER BY ISNULL(cs.DisplayOrder, 99) ASC, d.DisplayName ASC;

    -- Result 3: Product Colors
    SELECT Id, Color, ColorHex, ColorType, GradientAngle
    FROM dbo.ProductColors
    WHERE ProductId = @ProductId
    ORDER BY Id ASC;

    -- Result 4: Product Variants
    SELECT pv.Id, pv.Id AS VariantId, pv.ProductColorId, pc.Color, pc.ColorHex, pv.SKU, pv.Size, pv.PriceAdjustment,
           ISNULL(i.CurrentStock, 0) AS CurrentStock,
           ISNULL(i.ReorderPoint, 5) AS ReorderPoint,
           pv.IsActive
    FROM dbo.ProductVariants pv
    JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    LEFT JOIN dbo.Inventories i ON i.VariantId = pv.Id
    WHERE pc.ProductId = @ProductId
    ORDER BY pv.Id ASC;

    -- Result 5: Gallery Images
    SELECT Id, ImageUrl, AltText, DisplayOrder, IsActive
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @ProductId
    ORDER BY DisplayOrder ASC, Id ASC;
END;
GO
