-- ============================================================================
-- Migration 57: Add Catalog Item Duplicate Validation
-- Adds procedures for duplicate checking and enforces uniqueness in sp_AdminSaveProduct
-- ============================================================================

PRINT N'Creating dbo.sp_AdminGetCatalogItemLookups...';
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminGetCatalogItemLookups
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, BrandId, CategoryId, Name
    FROM dbo.Products
    ORDER BY Name ASC;
END;
GO

PRINT N'Creating dbo.sp_AdminCheckProductDuplicate...';
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminCheckProductDuplicate
    @ProductId INT = 0,
    @BrandId INT,
    @CategoryId INT,
    @Name NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 
        FROM dbo.Products
        WHERE BrandId = @BrandId
          AND CategoryId = @CategoryId
          AND LOWER(LTRIM(RTRIM(Name))) = LOWER(LTRIM(RTRIM(@Name)))
          AND Id <> ISNULL(@ProductId, 0)
    )
    BEGIN
        SELECT CAST(1 AS BIT) AS IsDuplicate;
    END
    ELSE
    BEGIN
        SELECT CAST(0 AS BIT) AS IsDuplicate;
    END
END;
GO

PRINT N'Updating dbo.sp_AdminSaveProduct with duplicate constraint...';
GO

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
    @IsActive BIT = 1,
    @PublicationStatus NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
       OR @BasePrice < 0 OR @DiscountPercentage NOT BETWEEN 0 AND 100
        THROW 52101, N'Invalid product details.', 1;

    -- Enforce duplicate validation: same brand, category, and name cannot be duplicated
    IF EXISTS (
        SELECT 1 
        FROM dbo.Products
        WHERE BrandId = @BrandId
          AND CategoryId = @CategoryId
          AND LOWER(LTRIM(RTRIM(Name))) = LOWER(LTRIM(RTRIM(@Name)))
          AND Id <> @Id
    )
    BEGIN
        THROW 52102, N'A helmet model with this brand, category, and name already exists in the catalog.', 1;
    END;

    -- Resolve PublicationStatus: if omitted, derive from IsActive
    IF @PublicationStatus IS NULL OR @PublicationStatus NOT IN (N'Draft', N'Published', N'Archived')
    BEGIN
        SET @PublicationStatus = CASE WHEN @IsActive = 1 THEN N'Published' ELSE N'Draft' END;
    END;

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
            CategoryId, BrandId, Name, Slug, Description, BasePrice,
            DiscountPercentage, DiscountType, DiscountAmount, DiscountStartDate, DiscountEndDate, DiscountIsActive,
            MainImageUrl, IsActive, PublicationStatus, CreatedAt, UpdatedAt
        )
        VALUES (
            @CategoryId, @BrandId, @Name, @Slug, @Description, @BasePrice,
            @DiscountPercentage, @DiscountType, @DiscountAmount, @DiscountStartDate, @DiscountEndDate,
            CASE WHEN (@DiscountPercentage > 0 OR @DiscountAmount > 0) THEN 1 ELSE 0 END,
            NULLIF(LTRIM(RTRIM(@MainImageUrl)), N''), @IsActive, @PublicationStatus,
            SYSUTCDATETIME(), SYSUTCDATETIME()
        );

        SET @Id = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.Products
        SET CategoryId = @CategoryId,
            BrandId = @BrandId,
            Name = @Name,
            Slug = @Slug,
            Description = @Description,
            BasePrice = @BasePrice,
            DiscountPercentage = @DiscountPercentage,
            DiscountType = @DiscountType,
            DiscountAmount = @DiscountAmount,
            DiscountStartDate = @DiscountStartDate,
            DiscountEndDate = @DiscountEndDate,
            DiscountIsActive = CASE WHEN (@DiscountPercentage > 0 OR @DiscountAmount > 0) THEN 1 ELSE 0 END,
            MainImageUrl = NULLIF(LTRIM(RTRIM(@MainImageUrl)), N''),
            IsActive = @IsActive,
            PublicationStatus = @PublicationStatus,
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;
    END;

    SELECT 
        p.Id,
        p.CategoryId,
        p.BrandId,
        p.Name,
        p.Slug,
        p.Description,
        p.BasePrice,
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        p.DiscountIsActive,
        p.MainImageUrl,
        p.IsActive,
        p.PublicationStatus,
        p.CreatedAt,
        p.UpdatedAt,
        b.Name AS BrandName,
        c.Name AS CategoryName
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    WHERE p.Id = @Id;
END;
GO
