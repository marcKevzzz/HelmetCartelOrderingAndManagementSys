USE HelmetCartelDB;
GO
IF OBJECT_ID(N'dbo.CartItems', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CartItems (
        Id INT IDENTITY PRIMARY KEY,
        UserId INT NOT NULL REFERENCES dbo.Users(Id),
        VariantId INT NOT NULL REFERENCES dbo.ProductVariants(Id),
        Quantity INT NOT NULL CHECK (Quantity BETWEEN 1 AND 9999),
        IsSelected BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NULL,
        CONSTRAINT UQ_CartItems_UserVariant UNIQUE (UserId, VariantId)
    );
END;
IF OBJECT_ID(N'dbo.Favorites', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Favorites (
        Id INT IDENTITY PRIMARY KEY,
        UserId INT NOT NULL REFERENCES dbo.Users(Id),
        ProductId INT NOT NULL REFERENCES dbo.Products(Id),
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NULL,
        CONSTRAINT UQ_Favorites_UserProduct UNIQUE (UserId, ProductId)
    );
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_GetShoppingState @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- One round trip returns current prices, visibility, stock, and reviews for both collections.
    SELECT (
        SELECT JSON_QUERY((
            SELECT ci.VariantId AS variantId, pc.ProductId AS productId,
                ci.Quantity AS quantity, ci.IsSelected AS isSelected,
                p.Name AS name, b.Name AS brand, v.Size AS size, pc.Color AS color,
                p.MainImageUrl AS imageUrl,
                dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage,
                    p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS price,
                CASE WHEN vp.Id IS NULL OR vv.Id IS NULL THEN 0
                     ELSE ISNULL(i.CurrentStock - i.ReservedStock, 0) END AS availableStock
            FROM dbo.CartItems ci
            JOIN dbo.ProductVariants v ON v.Id = ci.VariantId
            JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
            JOIN dbo.Products p ON p.Id = pc.ProductId
            JOIN dbo.Brands b ON b.Id = p.BrandId
            LEFT JOIN dbo.v_VisibleProducts vp ON vp.Id = p.Id
            LEFT JOIN dbo.v_VisibleProductVariants vv ON vv.Id = v.Id
            LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
            WHERE ci.UserId = @UserId
            ORDER BY ci.Id
            FOR JSON PATH
        )) AS cart,
        JSON_QUERY((
            SELECT f.ProductId AS productId, p.Name AS name, b.Name AS brand, c.Name AS category,
                p.MainImageUrl AS imageUrl, p.BasePrice AS originalPrice,
                dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage,
                    p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS price,
                p.DiscountPercentage AS discountPercentage,
                review.Rating AS rating, review.ReviewCount AS reviewCount,
                CAST(CASE WHEN NOT EXISTS (
                    SELECT 1 FROM dbo.v_VisibleProductVariants v
                    JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
                    JOIN dbo.Inventories i ON i.VariantId = v.Id
                    WHERE pc.ProductId = p.Id AND i.CurrentStock > i.ReservedStock
                ) THEN 1 ELSE 0 END AS BIT) AS isOutOfStock
            FROM dbo.Favorites f
            JOIN dbo.v_VisibleProducts p ON p.Id = f.ProductId
            JOIN dbo.Brands b ON b.Id = p.BrandId
            JOIN dbo.Categories c ON c.Id = p.CategoryId
            OUTER APPLY (
                SELECT CAST(ISNULL(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
                    COUNT(*) AS ReviewCount
                FROM dbo.ProductReviews r WHERE r.ProductId = p.Id AND r.IsHidden = 0
            ) review
            WHERE f.UserId = @UserId
            ORDER BY f.Id
            FOR JSON PATH
        )) AS favorites
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS ShoppingState;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_ChangeShoppingState
    @UserId INT, @Operation NVARCHAR(30), @Id INT = NULL,
    @Quantity INT = NULL, @IsSelected BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Serialize changes per account, including inserts into initially empty collections.
        DECLARE @Owner INT;
        SELECT @Owner = Id FROM dbo.Users WITH (UPDLOCK, ROWLOCK) WHERE Id = @UserId AND IsActive = 1;
        IF @Owner IS NULL THROW 53048, 'Account is unavailable.', 1;

        IF @Operation IN (N'AddCart', N'SetCart')
        BEGIN
            IF @Quantity IS NOT NULL AND (@Quantity < 0 OR @Quantity > 9999)
                THROW 53048, 'Quantity must be between 0 and 9999.', 1;
            IF @Operation = N'AddCart' AND (@Quantity IS NULL OR @Quantity = 0)
                THROW 53048, 'Quantity must be positive.', 1;
            DECLARE @Existing INT, @Next INT, @Stock INT;
            SELECT @Existing = Quantity FROM dbo.CartItems WITH (UPDLOCK, ROWLOCK)
                WHERE UserId = @UserId AND VariantId = @Id;
            SET @Next = CASE WHEN @Operation = N'AddCart' THEN ISNULL(@Existing, 0) + @Quantity
                             ELSE COALESCE(@Quantity, @Existing) END;
            IF @Next IS NULL THROW 53048, 'Cart item no longer exists.', 1;
            IF @Quantity IS NOT NULL AND @Next > 0
            BEGIN
                SELECT @Stock = i.CurrentStock - i.ReservedStock
                FROM dbo.v_VisibleProductVariants v
                JOIN dbo.Inventories i ON i.VariantId = v.Id
                WHERE v.Id = @Id;
                IF @Stock IS NULL OR @Next > @Stock OR @Next > 9999
                    THROW 53048, 'Requested quantity is unavailable.', 1;
            END;
            IF @Next = 0 DELETE dbo.CartItems WHERE UserId = @UserId AND VariantId = @Id;
            ELSE IF @Existing IS NULL
                INSERT dbo.CartItems(UserId, VariantId, Quantity, IsSelected)
                VALUES (@UserId, @Id, @Next, ISNULL(@IsSelected, 1));
            ELSE UPDATE dbo.CartItems SET Quantity = @Next, IsSelected = COALESCE(@IsSelected, IsSelected),
                UpdatedAt = SYSUTCDATETIME() WHERE UserId = @UserId AND VariantId = @Id;
        END
        ELSE IF @Operation = N'RemoveCart'
            DELETE dbo.CartItems WHERE UserId = @UserId AND VariantId = @Id;
        ELSE IF @Operation = N'ClearCart'
            DELETE dbo.CartItems WHERE UserId = @UserId;
        ELSE IF @Operation = N'SelectCart'
            UPDATE dbo.CartItems SET IsSelected = ISNULL(@IsSelected, 0), UpdatedAt = SYSUTCDATETIME() WHERE UserId = @UserId;
        ELSE IF @Operation = N'SaveFavorite'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.v_VisibleProducts WHERE Id = @Id)
                THROW 53048, 'Product is unavailable.', 1;
            IF NOT EXISTS (SELECT 1 FROM dbo.Favorites WHERE UserId = @UserId AND ProductId = @Id)
                INSERT dbo.Favorites(UserId, ProductId) VALUES (@UserId, @Id);
        END
        ELSE IF @Operation = N'RemoveFavorite'
            DELETE dbo.Favorites WHERE UserId = @UserId AND ProductId = @Id;
        ELSE IF @Operation = N'ClearFavorites'
            DELETE dbo.Favorites WHERE UserId = @UserId;
        ELSE THROW 53048, 'Unsupported shopping operation.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
    -- Cart changes never reserve or decrement inventory; checkout owns allocation.
    EXEC dbo.sp_GetShoppingState @UserId;
END;
GO

-- Existing SQL rows win; import retries cannot add quantity twice.
CREATE OR ALTER PROCEDURE dbo.sp_ImportShoppingState
    @UserId INT, @Cart NVARCHAR(MAX), @Favorites NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Owner INT;
        SELECT @Owner = Id FROM dbo.Users WITH (UPDLOCK, ROWLOCK) WHERE Id = @UserId AND IsActive = 1;
        IF @Owner IS NULL THROW 53048, 'Account is unavailable.', 1;
        INSERT dbo.CartItems(UserId, VariantId, Quantity, IsSelected)
        SELECT @UserId, saved.VariantId,
            CASE WHEN saved.Quantity > i.CurrentStock - i.ReservedStock THEN i.CurrentStock - i.ReservedStock ELSE saved.Quantity END,
            saved.IsSelected
        FROM (
            SELECT VariantId, MAX(Quantity) AS Quantity, CONVERT(BIT, MAX(CONVERT(INT, ISNULL(IsSelected, 1)))) AS IsSelected
            FROM OPENJSON(@Cart) WITH (VariantId INT, Quantity INT, IsSelected BIT)
            WHERE VariantId > 0 AND Quantity BETWEEN 1 AND 9999 GROUP BY VariantId
        ) saved
        JOIN dbo.v_VisibleProductVariants v ON v.Id = saved.VariantId
        JOIN dbo.Inventories i ON i.VariantId = v.Id AND i.CurrentStock > i.ReservedStock
        WHERE NOT EXISTS (SELECT 1 FROM dbo.CartItems WHERE UserId = @UserId AND VariantId = saved.VariantId);
        INSERT dbo.Favorites(UserId, ProductId)
        SELECT @UserId, p.Id FROM dbo.v_VisibleProducts p
        WHERE p.Id IN (SELECT TRY_CONVERT(INT, value) FROM OPENJSON(@Favorites))
            AND NOT EXISTS (SELECT 1 FROM dbo.Favorites WHERE UserId = @UserId AND ProductId = p.Id);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
    EXEC dbo.sp_GetShoppingState @UserId;
END;
GO
