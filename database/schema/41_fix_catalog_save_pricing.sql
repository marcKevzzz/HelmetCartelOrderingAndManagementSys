-- Migration 41: Repair catalog saving before specification persistence.
-- Uses the installed effective-price function and current product columns.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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
        p.Id, p.CategoryId, p.BrandId, p.Name, p.Slug, p.Description, p.BasePrice,
        p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive,
        p.MainImageUrl, p.IsActive, p.PublicationStatus,
        c.Name AS CategoryName, b.Name AS BrandName,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice
    FROM dbo.Products p
    LEFT JOIN dbo.Categories c ON c.Id = p.CategoryId
    LEFT JOIN dbo.Brands b ON b.Id = p.BrandId
    WHERE p.Id = @Id;
END;

GO
