/*
    Run after database/schema/04_product_specifications.sql.
    Includes read/write procedures and an idempotent seed for the supplied Shoei RF-1400 specs.
*/
IF OBJECT_ID(N'dbo.sp_GetProductSpecifications', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetProductSpecifications AS BEGIN RETURN 0; END');
GO
ALTER PROCEDURE dbo.sp_GetProductSpecifications
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT d.SpecificationKey,
           d.DisplayName,
           v.SpecificationValue,
           cs.DisplayOrder
    FROM dbo.Products p
    INNER JOIN dbo.CategorySpecifications cs ON cs.CategoryId = p.CategoryId
    INNER JOIN dbo.SpecificationDefinitions d ON d.Id = cs.SpecificationId AND d.IsActive = 1
    INNER JOIN dbo.ProductSpecificationValues v ON v.ProductId = p.Id AND v.SpecificationId = d.Id
    WHERE p.Id = @ProductId AND p.IsActive = 1
    ORDER BY cs.DisplayOrder, d.DisplayName;
END;
GO

IF OBJECT_ID(N'dbo.sp_UpsertSpecificationDefinition', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_UpsertSpecificationDefinition AS BEGIN RETURN 0; END');
GO
ALTER PROCEDURE dbo.sp_UpsertSpecificationDefinition
    @SpecificationKey NVARCHAR(80),
    @DisplayName NVARCHAR(120)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @NormalizedKey NVARCHAR(80) = LOWER(LTRIM(RTRIM(@SpecificationKey)));

    IF NULLIF(LTRIM(RTRIM(@SpecificationKey)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@DisplayName)), N'') IS NULL
        THROW 50010, 'Specification key and display name are required.', 1;

    BEGIN TRANSACTION;
    UPDATE dbo.SpecificationDefinitions WITH (UPDLOCK, SERIALIZABLE)
       SET DisplayName = LTRIM(RTRIM(@DisplayName)),
           IsActive = 1,
           UpdatedAt = SYSUTCDATETIME()
     WHERE SpecificationKey = @NormalizedKey;

    IF @@ROWCOUNT = 0
        INSERT dbo.SpecificationDefinitions (SpecificationKey, DisplayName)
        VALUES (@NormalizedKey, LTRIM(RTRIM(@DisplayName)));
    COMMIT TRANSACTION;
END;
GO

IF OBJECT_ID(N'dbo.sp_UpsertCategorySpecification', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_UpsertCategorySpecification AS BEGIN RETURN 0; END');
GO
ALTER PROCEDURE dbo.sp_UpsertCategorySpecification
    @CategoryId INT,
    @SpecificationKey NVARCHAR(80),
    @DisplayOrder INT,
    @IsRequired BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SpecificationId INT;
    SELECT @SpecificationId = Id
    FROM dbo.SpecificationDefinitions
    WHERE SpecificationKey = @SpecificationKey AND IsActive = 1;

    IF @SpecificationId IS NULL
        THROW 50011, 'Specification definition was not found or is inactive.', 1;

    BEGIN TRANSACTION;
    UPDATE dbo.CategorySpecifications WITH (UPDLOCK, SERIALIZABLE)
       SET DisplayOrder = @DisplayOrder,
           IsRequired = @IsRequired
     WHERE CategoryId = @CategoryId AND SpecificationId = @SpecificationId;

    IF @@ROWCOUNT = 0
        INSERT dbo.CategorySpecifications (CategoryId, SpecificationId, DisplayOrder, IsRequired)
        VALUES (@CategoryId, @SpecificationId, @DisplayOrder, @IsRequired);
    COMMIT TRANSACTION;
END;
GO

IF OBJECT_ID(N'dbo.sp_UpsertProductSpecificationValue', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_UpsertProductSpecificationValue AS BEGIN RETURN 0; END');
GO
ALTER PROCEDURE dbo.sp_UpsertProductSpecificationValue
    @ProductId INT,
    @SpecificationKey NVARCHAR(80),
    @SpecificationValue NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SpecificationId INT;
    SELECT @SpecificationId = d.Id
    FROM dbo.SpecificationDefinitions d
    INNER JOIN dbo.Products p ON p.Id = @ProductId AND p.IsActive = 1
    INNER JOIN dbo.CategorySpecifications cs ON cs.CategoryId = p.CategoryId AND cs.SpecificationId = d.Id
    WHERE d.SpecificationKey = @SpecificationKey AND d.IsActive = 1;

    IF @SpecificationId IS NULL
        THROW 50012, 'Specification is not configured for this product category.', 1;
    IF NULLIF(LTRIM(RTRIM(@SpecificationValue)), N'') IS NULL
        THROW 50013, 'Specification value is required.', 1;

    BEGIN TRANSACTION;
    UPDATE dbo.ProductSpecificationValues WITH (UPDLOCK, SERIALIZABLE)
       SET SpecificationValue = LTRIM(RTRIM(@SpecificationValue)),
           UpdatedAt = SYSUTCDATETIME()
     WHERE ProductId = @ProductId AND SpecificationId = @SpecificationId;

    IF @@ROWCOUNT = 0
        INSERT dbo.ProductSpecificationValues (ProductId, SpecificationId, SpecificationValue)
        VALUES (@ProductId, @SpecificationId, LTRIM(RTRIM(@SpecificationValue)));
    COMMIT TRANSACTION;
END;
GO

IF OBJECT_ID(N'dbo.sp_SeedShoeiRf1400Specifications', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_SeedShoeiRf1400Specifications AS BEGIN RETURN 0; END');
GO
ALTER PROCEDURE dbo.sp_SeedShoeiRf1400Specifications
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ProductId INT, @CategoryId INT;
    SELECT @ProductId = Id, @CategoryId = CategoryId
    FROM dbo.Products
    WHERE Slug = N'shoei-rf-1400-dedicated' AND IsActive = 1;

    IF @ProductId IS NULL
        THROW 50014, 'Active product with slug shoei-rf-1400-dedicated was not found.', 1;

    DECLARE @Definitions TABLE
    (
        SpecificationKey NVARCHAR(80) NOT NULL PRIMARY KEY,
        DisplayName NVARCHAR(120) NOT NULL,
        DisplayOrder INT NOT NULL,
        SpecificationValue NVARCHAR(1000) NOT NULL
    );
    INSERT @Definitions (SpecificationKey, DisplayName, DisplayOrder, SpecificationValue) VALUES
        (N'shell_architecture', N'Shell Architecture', 1, N'Proprietary 6-Ply AIM+ (Advanced Integrated Matrix Plus Multi-Fiber)'),
        (N'safety_certifications', N'Safety Certifications', 2, N'SNELL M2020D & DOT FMVSS 218 Approved (Exceeds ECE 22.06 criteria)'),
        (N'origin', N'Origin', 3, N'Handcrafted with precision in Ibaraki and Iwate, Japan'),
        (N'shell_sizing', N'Shell Sizing', 4, N'4 Shell Sizes across 6 Head Sizes (XS to 2XL) for compact, proportional fit'),
        (N'approximate_weight', N'Approximate Weight', 5, N'1,510g ± 50g (3.32 lbs) based on Size Large shell'),
        (N'retention_system', N'Retention System', 6, N'Heavy-Duty Stainless Steel Double D-Ring with end snap'),
        (N'shield_mechanism', N'Shield Mechanism', 7, N'CWR-F2 Center-Lock Quick-Release with 10-stage detent fine adjustment'),
        (N'anti_fog_system', N'Anti-Fog System', 8, N'Genuine Shoei Pinlock EVO Lens Included in Box (100% Max Vision)'),
        (N'interior_lining', N'Interior Lining', 9, N'3D Max-Dry System (Antimicrobial, moisture-wicking, fully removable & washable)'),
        (N'intercom_compatibility', N'Intercom Compatibility', 10, N'Pre-molded 40mm ear speaker recesses & microphone wiring channels');

    BEGIN TRANSACTION;
    UPDATE d
       SET DisplayName = src.DisplayName,
           UpdatedAt = SYSUTCDATETIME()
    FROM dbo.SpecificationDefinitions d
    INNER JOIN @Definitions src ON src.SpecificationKey = d.SpecificationKey;

    INSERT dbo.SpecificationDefinitions (SpecificationKey, DisplayName)
    SELECT src.SpecificationKey, src.DisplayName
    FROM @Definitions src
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.SpecificationDefinitions d WITH (UPDLOCK, HOLDLOCK)
        WHERE d.SpecificationKey = src.SpecificationKey
    );

    UPDATE cs
       SET DisplayOrder = src.DisplayOrder,
           IsRequired = 0
    FROM dbo.CategorySpecifications cs
    INNER JOIN dbo.SpecificationDefinitions d ON d.Id = cs.SpecificationId
    INNER JOIN @Definitions src ON src.SpecificationKey = d.SpecificationKey
    WHERE cs.CategoryId = @CategoryId;

    INSERT dbo.CategorySpecifications (CategoryId, SpecificationId, DisplayOrder, IsRequired)
    SELECT @CategoryId, d.Id, src.DisplayOrder, 0
    FROM @Definitions src
    INNER JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = src.SpecificationKey
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.CategorySpecifications cs WITH (UPDLOCK, HOLDLOCK)
        WHERE cs.CategoryId = @CategoryId AND cs.SpecificationId = d.Id
    );

    UPDATE v
       SET SpecificationValue = src.SpecificationValue,
           UpdatedAt = SYSUTCDATETIME()
    FROM dbo.ProductSpecificationValues v
    INNER JOIN dbo.SpecificationDefinitions d ON d.Id = v.SpecificationId
    INNER JOIN @Definitions src ON src.SpecificationKey = d.SpecificationKey
    WHERE v.ProductId = @ProductId;

    INSERT dbo.ProductSpecificationValues (ProductId, SpecificationId, SpecificationValue)
    SELECT @ProductId, d.Id, src.SpecificationValue
    FROM @Definitions src
    INNER JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = src.SpecificationKey
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.ProductSpecificationValues v WITH (UPDLOCK, HOLDLOCK)
        WHERE v.ProductId = @ProductId AND v.SpecificationId = d.Id
    );
    COMMIT TRANSACTION;
END;
GO
