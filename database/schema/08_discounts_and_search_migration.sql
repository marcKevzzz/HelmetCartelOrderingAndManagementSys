USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. ADD DISCOUNT COLUMNS TO dbo.Products IF NOT PRESENT
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Products') AND name = N'DiscountType')
BEGIN
    ALTER TABLE dbo.Products ADD DiscountType NVARCHAR(20) NOT NULL CONSTRAINT DF_Products_DiscountType DEFAULT N'PERCENTAGE';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Products') AND name = N'DiscountAmount')
BEGIN
    ALTER TABLE dbo.Products ADD DiscountAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_Products_DiscountAmount DEFAULT 0.00;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Products') AND name = N'DiscountStartDate')
BEGIN
    ALTER TABLE dbo.Products ADD DiscountStartDate DATETIME2 NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Products') AND name = N'DiscountEndDate')
BEGIN
    ALTER TABLE dbo.Products ADD DiscountEndDate DATETIME2 NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Products') AND name = N'DiscountIsActive')
BEGIN
    ALTER TABLE dbo.Products ADD DiscountIsActive BIT NOT NULL CONSTRAINT DF_Products_DiscountIsActive DEFAULT 1;
END;
GO

-- 2. CREATE TABLE dbo.ProductDiscounts FOR SCHEDULED PRODUCT/VARIANT DISCOUNTS
IF OBJECT_ID(N'dbo.ProductDiscounts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ProductDiscounts (
        Id INT IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED,
        ProductId INT NOT NULL REFERENCES dbo.Products(Id) ON DELETE CASCADE,
        VariantId INT NULL REFERENCES dbo.ProductVariants(Id),
        DiscountType NVARCHAR(20) NOT NULL CONSTRAINT DF_ProductDiscounts_Type DEFAULT N'PERCENTAGE',
        DiscountValue DECIMAL(18,2) NOT NULL,
        StartDate DATETIME2 NULL,
        EndDate DATETIME2 NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_ProductDiscounts_IsActive DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_ProductDiscounts_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_ProductDiscounts_Type CHECK (DiscountType IN (N'PERCENTAGE', N'FIXED_AMOUNT')),
        CONSTRAINT CK_ProductDiscounts_Value CHECK (DiscountValue >= 0)
    );

    CREATE NONCLUSTERED INDEX IX_ProductDiscounts_Product ON dbo.ProductDiscounts (ProductId, IsActive, StartDate, EndDate);
    CREATE NONCLUSTERED INDEX IX_ProductDiscounts_Variant ON dbo.ProductDiscounts (VariantId, IsActive, StartDate, EndDate);
END;
GO

-- 3. FUNCTION TO SECURELY CALCULATE EFFECTIVE DISCOUNTED PRICE
CREATE OR ALTER FUNCTION dbo.fn_CalculateEffectivePrice
(
    @BasePrice DECIMAL(18,2),
    @PriceAdjustment DECIMAL(18,2),
    @DiscountPercentage INT,
    @DiscountType NVARCHAR(20),
    @DiscountAmount DECIMAL(18,2),
    @StartDate DATETIME2,
    @EndDate DATETIME2,
    @IsActive BIT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @GrossPrice DECIMAL(18,2) = @BasePrice + ISNULL(@PriceAdjustment, 0.00);
    IF @GrossPrice <= 0 RETURN 0.00;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();
    DECLARE @IsDiscountValid BIT = 0;

    IF ISNULL(@IsActive, 1) = 1
       AND (@StartDate IS NULL OR @StartDate <= @Now)
       AND (@EndDate IS NULL OR @EndDate >= @Now)
    BEGIN
        SET @IsDiscountValid = 1;
    END;

    IF @IsDiscountValid = 0
    BEGIN
        -- Check if legacy DiscountPercentage is set without dates
        IF @DiscountPercentage > 0 AND @DiscountPercentage <= 100 AND @StartDate IS NULL AND @EndDate IS NULL
        BEGIN
            RETURN CONVERT(DECIMAL(18,2), @GrossPrice * (1.0 - (@DiscountPercentage / 100.0)));
        END;
        RETURN @GrossPrice;
    END;

    DECLARE @Effective DECIMAL(18,2) = @GrossPrice;

    IF @DiscountType = N'FIXED_AMOUNT' AND @DiscountAmount > 0
    BEGIN
        SET @Effective = @GrossPrice - @DiscountAmount;
    END
    ELSE IF @DiscountPercentage > 0
    BEGIN
        SET @Effective = @GrossPrice * (1.0 - (@DiscountPercentage / 100.0));
    END;

    IF @Effective < 0 SET @Effective = 0.00;
    RETURN CONVERT(DECIMAL(18,2), @Effective);
END;
GO

-- 4. UPDATE STORED PROCEDURE: sp_GetProductsPaged
-- Supports search across brand, helmet model name, category, product name, and SKU!
CREATE OR ALTER PROCEDURE dbo.sp_GetProductsPaged
    @CategoryId INT = NULL,
    @BrandId INT = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL,
    @RidingStyle NVARCHAR(50) = NULL,
    @Search NVARCHAR(200) = NULL,
    @OnSale BIT = 0,
    @MinPrice DECIMAL(18,2) = NULL,
    @MaxPrice DECIMAL(18,2) = NULL,
    @Colors NVARCHAR(200) = NULL,
    @Sizes NVARCHAR(100) = NULL,
    @SortBy NVARCHAR(50) = 'popular',
    @PageNumber INT = 1,
    @PageSize INT = 9,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Colors = NULLIF(LTRIM(RTRIM(@Colors)), N'');
    SET @Sizes = NULLIF(LTRIM(RTRIM(@Sizes)), N'');
    IF @PageNumber IS NULL OR @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 9;
    IF @PageSize > 100 SET @PageSize = 100;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    -- Calculate total count
    SELECT @TotalCount = COUNT(*)
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    WHERE p.IsActive = 1
      AND (
          ISNULL(@OnSale, 0) = 0 
          OR (
              (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
              AND ISNULL(p.DiscountIsActive, 1) = 1
              AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
              AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
          )
      )
      AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
      AND (@BrandId IS NULL OR p.BrandId = @BrandId)
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand)
      AND (@Category IS NULL OR @Category = 'all' OR c.Slug = @Category OR c.Name LIKE '%' + @Category + '%')
      AND (@RidingStyle IS NULL OR @RidingStyle = 'all' OR p.RidingStyle = @RidingStyle)
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%'
          OR b.Name LIKE N'%' + @Search + N'%'
          OR c.Name LIKE N'%' + @Search + N'%'
          OR p.RidingStyle LIKE N'%' + @Search + N'%'
          OR p.Description LIKE N'%' + @Search + N'%'
          OR EXISTS (
              SELECT 1 
              FROM dbo.ProductColors pc_s
              JOIN dbo.ProductVariants pv_s ON pv_s.ProductColorId = pc_s.Id
              WHERE pc_s.ProductId = p.Id AND pv_s.SKU LIKE N'%' + @Search + N'%'
          )
      )
      AND (@MinPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) >= @MinPrice)
      AND (@MaxPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) <= @MaxPrice)
      AND EXISTS
      (
          SELECT 1
          FROM dbo.ProductColors pc
          JOIN dbo.ProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
            AND (@Colors IS NULL OR CHARINDEX(N',' + UPPER(dbo.fn_BaseColorFromHex(pc.ColorHex)) + N',', N',' + UPPER(@Colors) + N',') > 0)
            AND (@Sizes IS NULL OR CHARINDEX(N',' + UPPER(pv.Size) + N',', N',' + UPPER(@Sizes) + N',') > 0)
      );

    -- Paged rows
    SELECT 
        p.Id,
        p.Name,
        p.Slug,
        b.Name AS Brand,
        c.Name AS Category,
        p.RidingStyle,
        p.BasePrice,
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        CASE 
            WHEN ISNULL(p.DiscountIsActive, 1) = 1 
                 AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
                 AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
                 AND (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
            THEN 1 
            ELSE 0 
        END AS IsDiscountActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        p.MainImageUrl,
        p.Description,
        p.IsFeatured
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    OUTER APPLY (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    WHERE p.IsActive = 1
      AND (
          ISNULL(@OnSale, 0) = 0 
          OR (
              (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
              AND ISNULL(p.DiscountIsActive, 1) = 1
              AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
              AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
          )
      )
      AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
      AND (@BrandId IS NULL OR p.BrandId = @BrandId)
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand)
      AND (@Category IS NULL OR @Category = 'all' OR c.Slug = @Category OR c.Name LIKE '%' + @Category + '%')
      AND (@RidingStyle IS NULL OR @RidingStyle = 'all' OR p.RidingStyle = @RidingStyle)
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%'
          OR b.Name LIKE N'%' + @Search + N'%'
          OR c.Name LIKE N'%' + @Search + N'%'
          OR p.RidingStyle LIKE N'%' + @Search + N'%'
          OR p.Description LIKE N'%' + @Search + N'%'
          OR EXISTS (
              SELECT 1 
              FROM dbo.ProductColors pc_s
              JOIN dbo.ProductVariants pv_s ON pv_s.ProductColorId = pc_s.Id
              WHERE pc_s.ProductId = p.Id AND pv_s.SKU LIKE N'%' + @Search + N'%'
          )
      )
      AND (@MinPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) >= @MinPrice)
      AND (@MaxPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) <= @MaxPrice)
      AND EXISTS
      (
          SELECT 1
          FROM dbo.ProductColors pc
          JOIN dbo.ProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
            AND (@Colors IS NULL OR CHARINDEX(N',' + UPPER(dbo.fn_BaseColorFromHex(pc.ColorHex)) + N',', N',' + UPPER(@Colors) + N',') > 0)
            AND (@Sizes IS NULL OR CHARINDEX(N',' + UPPER(pv.Size) + N',', N',' + UPPER(@Sizes) + N',') > 0)
      )
    ORDER BY 
        CASE WHEN @SortBy = 'price_asc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END ASC,
        CASE WHEN @SortBy = 'price_desc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END DESC,
        CASE WHEN @SortBy = 'newest' THEN p.CreatedAt END DESC,
        CASE WHEN @SortBy = 'rating' THEN review.Rating END DESC,
        CASE WHEN @SortBy = 'popular' OR @SortBy IS NULL THEN review.ReviewCount END DESC,
        p.Id ASC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- 5. UPDATE STORED PROCEDURE: sp_GetProductById
CREATE OR ALTER PROCEDURE dbo.sp_GetProductById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    -- Result Set 1: Product Header
    SELECT 
        p.Id,
        p.Name,
        p.Slug,
        b.Name AS Brand,
        c.Name AS Category,
        p.RidingStyle,
        p.BasePrice,
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        CASE 
            WHEN ISNULL(p.DiscountIsActive, 1) = 1 
                 AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
                 AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
                 AND (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
            THEN 1 
            ELSE 0 
        END AS IsDiscountActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        orders.OrderCount,
        p.MainImageUrl,
        p.Description,
        p.IsFeatured
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    OUTER APPLY (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    OUTER APPLY (
        SELECT COUNT(DISTINCT oi.OrderId) AS OrderCount
        FROM dbo.ProductColors pc
        INNER JOIN dbo.ProductVariants pv ON pv.ProductColorId = pc.Id
        INNER JOIN dbo.OrderItems oi ON oi.VariantId = pv.Id
        INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
        WHERE pc.ProductId = p.Id AND o.Status <> N'Cancelled'
    ) orders
    WHERE p.Id = @Id AND p.IsActive = 1;

    -- Result Set 2: Variants & Stock
    SELECT 
        pv.Id,
        pc.ProductId,
        pv.SKU,
        pv.Size,
        pc.Color,
        pc.ColorHex,
        pv.PriceAdjustment,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, pv.PriceAdjustment, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        ISNULL(i.CurrentStock, 0) AS CurrentStock,
        ISNULL(i.IsLowStock, 0) AS IsLowStock
    FROM dbo.ProductVariants pv
    INNER JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.Products p ON pc.ProductId = p.Id
    LEFT JOIN dbo.Inventories i ON pv.Id = i.VariantId
    WHERE pc.ProductId = @Id AND pv.IsActive = 1
    ORDER BY pv.Id ASC;

    -- Result Set 3: Additional product gallery images
    SELECT
        ImageUrl,
        COALESCE(AltText, N'Product view') AS AltText,
        CAST(DisplayOrder AS INT) AS DisplayOrder
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @Id AND IsActive = 1
    ORDER BY DisplayOrder ASC, Id ASC;
END;
GO

-- 6. UPDATE STORED PROCEDURE: sp_AdminInventoryVariants
-- Supports consistent search across brand, helmet model name, category, product name, and SKU!
CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryVariants
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL,
    @StockStatus NVARCHAR(50) = 'all'
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    IF @Brand = 'all' SET @Brand = NULL;
    IF @Category = 'all' SET @Category = NULL;
    IF @StockStatus IS NULL OR LTRIM(RTRIM(@StockStatus)) = '' SET @StockStatus = 'all';

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
        dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        v.SKU,
        p.MainImageUrl,
        CASE 
            WHEN ISNULL(i.CurrentStock, 0) <= 0 THEN 'out_of_stock'
            WHEN ISNULL(i.CurrentStock, 0) <= ISNULL(i.ReorderPoint, 3) THEN 'low_stock'
            ELSE 'in_stock'
        END AS StockStatus
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE v.IsActive = 1 AND p.IsActive = 1
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%' 
          OR b.Name LIKE N'%' + @Search + N'%' 
          OR cat.Name LIKE N'%' + @Search + N'%'
          OR v.SKU LIKE N'%' + @Search + N'%' 
          OR c.Color LIKE N'%' + @Search + N'%'
      )
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR cat.Name = @Category OR cat.Slug = @Category)
      AND (
          (@StockStatus = 'all')
          OR (@StockStatus = 'in_stock' AND ISNULL(i.CurrentStock, 0) > ISNULL(i.ReorderPoint, 3))
          OR (@StockStatus = 'low_stock' AND ISNULL(i.CurrentStock, 0) > 0 AND ISNULL(i.CurrentStock, 0) <= ISNULL(i.ReorderPoint, 3))
          OR (@StockStatus = 'out_of_stock' AND ISNULL(i.CurrentStock, 0) <= 0)
      )
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;
GO

-- 7. UPDATE STORED PROCEDURE: sp_AdminCatalogProducts
-- Supports consistent search across brand, helmet model name, category, product name, and SKU!
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
        (SELECT COUNT(*) FROM dbo.ProductVariants v JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId WHERE pc.ProductId = p.Id) AS VariantCount
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
    ORDER BY p.CreatedAt DESC, p.Id DESC;
END;
GO

-- 8. UPDATE STORED PROCEDURE: sp_AdminAdjustStock (Stock In Only Enforcement)
-- Stock can only be increased; does not allow stock removal!
CREATE OR ALTER PROCEDURE dbo.sp_AdminAdjustStock
    @VariantId INT, 
    @QuantityChanged INT, 
    @UserId INT,
    @ReferenceNumber NVARCHAR(100), 
    @Notes NVARCHAR(500), 
    @NewStock INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Strict Rule: Stock can only be increased (Stock In only)
    IF @QuantityChanged <= 0
        THROW 52004, N'Stock In quantity must be a positive integer greater than zero.', 1;
    IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
        THROW 52005, N'A reference note or reason is required for stock addition.', 1;

    BEGIN TRANSACTION;
    DECLARE @OldStock INT, @Reserved INT, @Reorder INT, @InventoryId INT;
    SELECT @OldStock = CurrentStock, @Reserved = ReservedStock, @Reorder = ReorderPoint, @InventoryId = Id
    FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) 
    WHERE VariantId = @VariantId;

    IF @OldStock IS NULL 
        THROW 52006, N'Inventory record not found for variant.', 1;

    SET @NewStock = @OldStock + @QuantityChanged;

    UPDATE dbo.Inventories 
    SET CurrentStock = @NewStock, 
        LastRestockedAt = SYSUTCDATETIME(),
        UpdatedAt = SYSUTCDATETIME() 
    WHERE Id = @InventoryId;

    INSERT INTO dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
    VALUES (@VariantId, @UserId, N'STOCK_IN', @OldStock, @QuantityChanged, @ReferenceNumber, @Notes);

    -- Dismiss restock alerts if stock is now above threshold
    IF @NewStock - @Reserved > @Reorder
    BEGIN
        UPDATE dbo.RestockAlerts 
        SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
        WHERE InventoryId = @InventoryId AND IsDismissed = 0;
    END;

    COMMIT TRANSACTION;
END;
GO

-- 9. UPDATE STORED PROCEDURE: sp_AdminCreateProductWithVariants
CREATE OR ALTER PROCEDURE dbo.sp_AdminCreateProductWithVariants
    @CategoryId INT,
    @BrandId INT,
    @Name NVARCHAR(200),
    @Slug NVARCHAR(220),
    @Description NVARCHAR(MAX),
    @RidingStyle NVARCHAR(50),
    @BasePrice DECIMAL(18,2),
    @DiscountPercentage INT = 0,
    @DiscountType NVARCHAR(20) = N'PERCENTAGE',
    @DiscountAmount DECIMAL(18,2) = 0.00,
    @DiscountStartDate DATETIME2 = NULL,
    @DiscountEndDate DATETIME2 = NULL,
    @MainImageUrl NVARCHAR(500),
    @VariantsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
       OR @BasePrice < 0
        THROW 52301, N'Invalid product basic details.', 1;

    BEGIN TRANSACTION;

    INSERT INTO dbo.Products (
        CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice,
        DiscountPercentage, DiscountType, DiscountAmount, DiscountStartDate, DiscountEndDate, DiscountIsActive,
        MainImageUrl, IsFeatured, IsActive
    )
    VALUES (
        @CategoryId, @BrandId, @Name, @Slug, @Description, @RidingStyle, @BasePrice,
        ISNULL(@DiscountPercentage, 0), ISNULL(@DiscountType, N'PERCENTAGE'), ISNULL(@DiscountAmount, 0.00),
        @DiscountStartDate, @DiscountEndDate, 1,
        @MainImageUrl, 0, 1
    );

    DECLARE @ProductId INT = SCOPE_IDENTITY();

    DECLARE @ParsedVariants TABLE (
        Color NVARCHAR(100),
        ColorHex NVARCHAR(255),
        Size NVARCHAR(20),
        SKU NVARCHAR(100),
        PriceAdjustment DECIMAL(18,2),
        Stock INT,
        ReorderPoint INT
    );

    INSERT INTO @ParsedVariants (Color, ColorHex, Size, SKU, PriceAdjustment, Stock, ReorderPoint)
    SELECT 
        JSON_VALUE(value, '$.color'),
        ISNULL(JSON_VALUE(value, '$.colorHex'), '#18181B'),
        JSON_VALUE(value, '$.size'),
        JSON_VALUE(value, '$.sku'),
        ISNULL(TRY_CONVERT(DECIMAL(18,2), JSON_VALUE(value, '$.priceAdj')), 0.00),
        ISNULL(TRY_CONVERT(INT, JSON_VALUE(value, '$.stock')), 10),
        ISNULL(TRY_CONVERT(INT, JSON_VALUE(value, '$.reorder')), 3)
    FROM OPENJSON(@VariantsJson);

    DECLARE @ColorMap TABLE (Color NVARCHAR(100), ColorId INT);
    DECLARE @ColorName NVARCHAR(100), @ColorHex NVARCHAR(255);
    DECLARE cur_colors CURSOR LOCAL FAST_FORWARD FOR 
        SELECT DISTINCT Color, ColorHex FROM @ParsedVariants;
    OPEN cur_colors;
    FETCH NEXT FROM cur_colors INTO @ColorName, @ColorHex;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @ColorId INT;
        INSERT INTO dbo.ProductColors (ProductId, Color, ColorHex, ColorType)
        VALUES (@ProductId, @ColorName, @ColorHex, CASE WHEN @ColorHex LIKE 'linear-gradient%' THEN 'LINEAR_GRADIENT' ELSE 'SOLID' END);
        SET @ColorId = SCOPE_IDENTITY();
        INSERT INTO @ColorMap (Color, ColorId) VALUES (@ColorName, @ColorId);
        FETCH NEXT FROM cur_colors INTO @ColorName, @ColorHex;
    END;
    CLOSE cur_colors;
    DEALLOCATE cur_colors;

    DECLARE @VariantId INT, @Size NVARCHAR(20), @SKU NVARCHAR(100), @Adj DECIMAL(18,2), @Stock INT, @Reorder INT, @MappedColorId INT;
    DECLARE cur_vars CURSOR LOCAL FAST_FORWARD FOR 
        SELECT m.ColorId, v.Size, v.SKU, v.PriceAdjustment, v.Stock, v.ReorderPoint
        FROM @ParsedVariants v
        JOIN @ColorMap m ON m.Color = v.Color;
    OPEN cur_vars;
    FETCH NEXT FROM cur_vars INTO @MappedColorId, @Size, @SKU, @Adj, @Stock, @Reorder;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO dbo.ProductVariants (ProductColorId, SKU, Size, PriceAdjustment, IsActive)
        VALUES (@MappedColorId, @SKU, @Size, @Adj, 1);
        SET @VariantId = SCOPE_IDENTITY();

        INSERT INTO dbo.Inventories (VariantId, CurrentStock, ReservedStock, ReorderPoint, LastRestockedAt)
        VALUES (@VariantId, @Stock, 0, @Reorder, SYSUTCDATETIME());

        IF @Stock > 0
        BEGIN
            INSERT INTO dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
            VALUES (@VariantId, 1, 'STOCK_IN', 0, @Stock, 'INIT-CATALOG', 'Initial stock on product creation');
        END;

        FETCH NEXT FROM cur_vars INTO @MappedColorId, @Size, @SKU, @Adj, @Stock, @Reorder;
    END;
    CLOSE cur_vars;
    DEALLOCATE cur_vars;

    COMMIT TRANSACTION;

    SELECT @ProductId AS Id;
END;
GO
