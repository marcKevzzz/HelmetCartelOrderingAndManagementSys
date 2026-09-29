-- =====================================================================================
-- DATABASE: Helmet Cartel Ordering and Management System
-- SCRIPT: 03_procedures_and_queries.sql - Stored Procedures & Atomic Transactions
-- Run after 01_schema.sql and 03_product_gallery.sql on a new database, or after
-- 02_3nf_integrity_migration.sql and 03_product_gallery.sql on an existing database.
-- =====================================================================================

USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================================
-- 1. STORED PROCEDURE: sp_DeductStockAtomic
-- Ensures pessimistic row-level locking (UPDLOCK, ROWLOCK) to eliminate race conditions.
-- Guarantees atomic decrements across online and POS checkouts.
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_DeductStockAtomic', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_DeductStockAtomic AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_DeductStockAtomic
    @VariantId INT,
    @Quantity INT,
    @UserId INT = NULL,
    @ChangeType NVARCHAR(50), -- 'ONLINE_SALE' or 'INSTORE_SALE'
    @OrderNumber NVARCHAR(100),
    @RemainingStock INT OUTPUT,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Success = 0;
    SET @RemainingStock = NULL;
    SET @ErrorMessage = NULL;
    IF @Quantity IS NULL OR @Quantity <= 0
    BEGIN
        SET @ErrorMessage = N'Quantity must be greater than zero.';
        RETURN;
    END;
    IF @ChangeType NOT IN (N'ONLINE_SALE', N'INSTORE_SALE') OR @ChangeType IS NULL
    BEGIN
        SET @ErrorMessage = N'Invalid sale change type.';
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStock INT, @ReservedStock INT;

        -- Pessimistic locking of the inventory row
        SELECT @CurrentStock = CurrentStock, @ReservedStock = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
        WHERE VariantId = @VariantId;

        IF @CurrentStock IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = 'Variant inventory record not found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @CurrentStock - @ReservedStock < @Quantity
        BEGIN
            SET @Success = 0;
            SET @RemainingStock = @CurrentStock;
            SET @ErrorMessage = CONCAT('Insufficient stock. Available: ', @CurrentStock - @ReservedStock, ', Requested: ', @Quantity);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Perform atomic deduction
        UPDATE dbo.Inventories
        SET CurrentStock = CurrentStock - @Quantity,
            UpdatedAt = SYSUTCDATETIME()
        WHERE VariantId = @VariantId AND CurrentStock - ReservedStock >= @Quantity;

        IF @@ROWCOUNT <> 1
            THROW 51010, N'Inventory changed during deduction.', 1;

        SET @RemainingStock = @CurrentStock - @Quantity;

        -- Record in audit log
        INSERT INTO dbo.StockAuditLogs (
            VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes
        ) VALUES (
            @VariantId, @UserId, @ChangeType, @CurrentStock, -@Quantity, @OrderNumber, 
            CONCAT('Stock deducted via ', @ChangeType)
        );

        -- If remaining stock reaches or falls below reorder point, trigger alert
        DECLARE @ReorderPoint INT, @InvId INT;
        SELECT @InvId = Id, @ReorderPoint = ReorderPoint FROM dbo.Inventories WHERE VariantId = @VariantId;

        IF @RemainingStock - @ReservedStock <= @ReorderPoint
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.RestockAlerts WHERE InventoryId = @InvId AND IsDismissed = 0)
                UPDATE dbo.RestockAlerts
                SET Severity = CASE WHEN @RemainingStock - @ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
                WHERE InventoryId = @InvId AND IsDismissed = 0;
            ELSE
                INSERT INTO dbo.RestockAlerts (InventoryId, Severity)
                VALUES (@InvId, CASE WHEN @RemainingStock - @ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END);
        END

        COMMIT TRANSACTION;

        SET @Success = 1;
        SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END;
GO

-- =====================================================================================
-- 2. STORED PROCEDURE: sp_RestockInventory
-- Safely increases inventory and logs the supplier PO/invoice.
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_RestockInventory', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_RestockInventory AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_RestockInventory
    @VariantId INT,
    @RestockQuantity INT,
    @UserId INT,
    @SupplierInvoice NVARCHAR(100),
    @Notes NVARCHAR(500),
    @NewStock INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RestockQuantity IS NULL OR @RestockQuantity <= 0
        THROW 51011, N'Restock quantity must be greater than zero.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OldStock INT, @ReservedStock INT;

        SELECT @OldStock = CurrentStock, @ReservedStock = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
        WHERE VariantId = @VariantId;

        IF @OldStock IS NULL
        BEGIN
            RAISERROR('Variant inventory not found.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE dbo.Inventories
        SET CurrentStock = CurrentStock + @RestockQuantity,
            LastRestockedAt = SYSUTCDATETIME(),
            UpdatedAt = SYSUTCDATETIME()
        WHERE VariantId = @VariantId;

        SET @NewStock = @OldStock + @RestockQuantity;

        INSERT INTO dbo.StockAuditLogs (
            VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes
        ) VALUES (
            @VariantId, @UserId, N'RESTOCK', @OldStock, @RestockQuantity, @SupplierInvoice, @Notes
        );

        -- Dismiss open alerts for this inventory if stock is now healthy
        DECLARE @InvId INT, @ReorderPoint INT;
        SELECT @InvId = Id, @ReorderPoint = ReorderPoint FROM dbo.Inventories WHERE VariantId = @VariantId;

        IF @NewStock - @ReservedStock > @ReorderPoint
        BEGIN
            UPDATE dbo.RestockAlerts
            SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
            WHERE InventoryId = @InvId AND IsDismissed = 0;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- 3. STORED PROCEDURE: sp_GetSalesSummaryReport
-- Aggregates sales figures across online and in-store channels.
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_GetSalesSummaryReport', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetSalesSummaryReport AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetSalesSummaryReport
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate IS NULL SET @StartDate = DATEADD(DAY, -30, SYSUTCDATETIME());
    IF @EndDate IS NULL SET @EndDate = SYSUTCDATETIME();

    SELECT 
        COUNT(o.Id) AS TotalOrders,
        SUM(CASE WHEN o.Status = 'Completed' THEN 1 ELSE 0 END) AS CompletedOrders,
        SUM(CASE WHEN o.Status = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledOrders,
        SUM(CASE WHEN o.Status = 'Completed' THEN o.TotalAmount ELSE 0.00 END) AS TotalGrossRevenue,
        SUM(CASE WHEN o.OrderSource = 'ONLINE' AND o.Status = 'Completed' THEN o.TotalAmount ELSE 0.00 END) AS OnlineRevenue,
        SUM(CASE WHEN o.OrderSource = 'INSTORE_POS' AND o.Status = 'Completed' THEN o.TotalAmount ELSE 0.00 END) AS InStoreRevenue,
        AVG(CASE WHEN o.Status = 'Completed' THEN o.TotalAmount ELSE NULL END) AS AverageOrderValue
    FROM dbo.Orders o
    WHERE o.CreatedAt BETWEEN @StartDate AND @EndDate;

    -- Breakdown by payment method
    SELECT 
        p.PaymentGateway,
        COUNT(p.Id) AS TransactionCount,
        SUM(p.Amount) AS TotalCollected
    FROM dbo.Payments p
    INNER JOIN dbo.Orders o ON p.OrderId = o.Id
    WHERE p.Status = 'Completed' AND p.CreatedAt BETWEEN @StartDate AND @EndDate
    GROUP BY p.PaymentGateway;
END;
GO

-- =====================================================================================
-- 4. STORED PROCEDURE: sp_GetUserByEmail
-- Retrieves user record with role name for authentication.
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_GetUserByEmail', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetUserByEmail AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserByEmail
    @Email NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.Id,
        u.RoleId,
        r.Name AS RoleName,
        u.FirstName,
        u.LastName,
        u.FullName,
        u.Email,
        u.PasswordHash,
        u.Salt,
        u.PhoneNumber,
        u.IsActive,
        u.CreatedAt
    FROM dbo.Users u
    INNER JOIN dbo.Roles r ON u.RoleId = r.Id
    WHERE u.Email = @Email AND u.IsActive = 1;
END;
GO

-- =====================================================================================
-- 5. STORED PROCEDURE: sp_RegisterUser
-- Registers a new customer or staff user with role verification.
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_RegisterUser', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_RegisterUser AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_RegisterUser
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @Email NVARCHAR(256),
    @PasswordHash NVARCHAR(512),
    @Salt NVARCHAR(128),
    @PhoneNumber NVARCHAR(30) = NULL,
    @RoleName NVARCHAR(50) = 'Customer',
    @NewUserId INT OUTPUT,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = 'An account with this email address already exists.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        DECLARE @RoleId INT;
        SELECT @RoleId = Id FROM dbo.Roles WHERE Name = @RoleName;

        IF @RoleId IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = CONCAT('Specified role "', @RoleName, '" was not found.');
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        INSERT INTO dbo.Users (
            RoleId, FirstName, LastName, FullName, Email, PasswordHash, Salt, PhoneNumber, IsActive, CreatedAt
        ) VALUES (
            @RoleId, @FirstName, @LastName, CONCAT(@FirstName, N' ', @LastName), @Email, @PasswordHash, @Salt, @PhoneNumber, 1, SYSUTCDATETIME()
        );

        SET @NewUserId = SCOPE_IDENTITY();
        SET @Success = 1;
        SET @ErrorMessage = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END;
GO

-- =====================================================================================
-- 6. STORED PROCEDURE: sp_GetUserProfile
-- Retrieves safe user profile details.
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_GetUserProfile', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetUserProfile AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserProfile
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.Id,
        u.RoleId,
        r.Name AS RoleName,
        u.FirstName,
        u.LastName,
        u.FullName,
        u.Email,
        u.PhoneNumber,
        u.CreatedAt
    FROM dbo.Users u
    INNER JOIN dbo.Roles r ON u.RoleId = r.Id
    WHERE u.Id = @UserId AND u.IsActive = 1;
END;
GO

-- =====================================================================================
-- 7. STORED PROCEDURE: sp_GetUserOrders
-- Retrieves complete order history for a customer.
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_GetUserOrders', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetUserOrders AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserOrders
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        o.Id,
        o.OrderNumber,
        o.Subtotal,
        o.DiscountAmount,
        o.TotalAmount,
        o.Status AS OrderStatus,
        o.OrderSource,
        o.CreatedAt,
        ISNULL((
            SELECT TOP 1 p.PaymentGateway 
            FROM dbo.Payments p 
            WHERE p.OrderId = o.Id 
            ORDER BY p.CreatedAt DESC
        ), 'HitPay') AS PaymentGateway,
        (
            SELECT COUNT(*) 
            FROM dbo.OrderItems oi 
            WHERE oi.OrderId = o.Id
        ) AS ItemCount
    FROM dbo.Orders o
    WHERE o.UserId = @UserId
    ORDER BY o.CreatedAt DESC;
END;
GO

-- =====================================================================================
-- 8. COLOR FAMILY HELPER & STORED PROCEDURE: sp_GetProductsPaged
-- =====================================================================================
IF OBJECT_ID(N'dbo.fn_BaseColorFromHex', N'FN') IS NULL
    EXEC(N'CREATE FUNCTION dbo.fn_BaseColorFromHex(@ColorHex NVARCHAR(10)) RETURNS NVARCHAR(10) AS BEGIN RETURN NULL; END');
GO

ALTER FUNCTION dbo.fn_BaseColorFromHex(@ColorHex NVARCHAR(255))
RETURNS NVARCHAR(20)
AS
BEGIN
    IF @ColorHex IS NULL OR LEN(LTRIM(RTRIM(@ColorHex))) = 0
        RETURN NULL;

    DECLARE @CleanHex NVARCHAR(255) = LTRIM(RTRIM(@ColorHex));

    DECLARE @HashIdx INT = CHARINDEX(N'#', @CleanHex);
    IF @HashIdx > 0 AND LEN(@CleanHex) >= @HashIdx + 6
    BEGIN
        SET @CleanHex = SUBSTRING(@CleanHex, @HashIdx, 7);
    END
    ELSE
    BEGIN
        RETURN N'Multi';
    END

    IF LEN(@CleanHex) <> 7 OR LEFT(@CleanHex, 1) <> N'#'
        RETURN N'Multi';

    DECLARE @Hex NVARCHAR(16) = N'0123456789ABCDEF';
    DECLARE @R INT = (CHARINDEX(UPPER(SUBSTRING(@CleanHex, 2, 1)), @Hex) - 1) * 16
                   + CHARINDEX(UPPER(SUBSTRING(@CleanHex, 3, 1)), @Hex) - 1;
    DECLARE @G INT = (CHARINDEX(UPPER(SUBSTRING(@CleanHex, 4, 1)), @Hex) - 1) * 16
                   + CHARINDEX(UPPER(SUBSTRING(@CleanHex, 5, 1)), @Hex) - 1;
    DECLARE @B INT = (CHARINDEX(UPPER(SUBSTRING(@CleanHex, 6, 1)), @Hex) - 1) * 16
                   + CHARINDEX(UPPER(SUBSTRING(@CleanHex, 7, 1)), @Hex) - 1;

    IF @R < 0 OR @G < 0 OR @B < 0 RETURN N'Multi';

    DECLARE @MaxChannel INT = CASE
        WHEN @R >= @G AND @R >= @B THEN @R
        WHEN @G >= @B THEN @G
        ELSE @B
    END;
    DECLARE @MinChannel INT = CASE
        WHEN @R <= @G AND @R <= @B THEN @R
        WHEN @G <= @B THEN @G
        ELSE @B
    END;
    DECLARE @Delta DECIMAL(10,4) = @MaxChannel - @MinChannel;
    DECLARE @Hue DECIMAL(10,4);

    IF @MaxChannel <= 64 RETURN N'Black';
    IF @MinChannel >= 200 RETURN N'White';
    IF @Delta <= 32 RETURN N'Grey';

    SET @Hue = CASE
        WHEN @MaxChannel = @R THEN 60.0 * (@G - @B) / @Delta
        WHEN @MaxChannel = @G THEN 60.0 * ((@B - @R) / @Delta + 2)
        ELSE 60.0 * ((@R - @G) / @Delta + 4)
    END;
    IF @Hue < 0 SET @Hue = @Hue + 360;

    IF @Hue < 15 OR @Hue >= 345 RETURN N'Red';
    IF @Hue < 45 RETURN N'Orange';
    IF @Hue < 165 RETURN N'Green';
    IF @Hue < 195 RETURN N'Cyan';
    IF @Hue < 255 RETURN N'Blue';
    IF @Hue < 315 RETURN N'Purple';
    RETURN N'Pink';
END;
GO

-- =====================================================================================
-- 6b. STORED PROCEDURE: sp_AddProductColor
-- Supports solid hex (#RRGGBB), comma-separated hexes, and CSS linear-gradient syntax.
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_AddProductColor', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_AddProductColor AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_AddProductColor
    @ProductId INT,
    @Color NVARCHAR(50),
    @ColorHex NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.ProductColors WHERE ProductId = @ProductId AND Color = @Color)
    BEGIN
        UPDATE dbo.ProductColors
        SET ColorHex = @ColorHex
        WHERE ProductId = @ProductId AND Color = @Color;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.ProductColors (ProductId, Color, ColorHex)
        VALUES (@ProductId, @Color, @ColorHex);
    END

    SELECT Id, ProductId, Color, ColorHex, CreatedAt
    FROM dbo.ProductColors
    WHERE ProductId = @ProductId AND Color = @Color;
END;
GO

IF OBJECT_ID(N'dbo.sp_GetProductsPaged', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetProductsPaged AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetProductsPaged
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
    @PageSize INT = 10,
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

    -- Calculate total count
    SELECT @TotalCount = COUNT(*)
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    WHERE p.IsActive = 1
      AND (ISNULL(@OnSale, 0) = 0 OR p.DiscountPercentage > 0)
      AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
      AND (@BrandId IS NULL OR p.BrandId = @BrandId)
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand)
      AND (@Category IS NULL OR @Category = 'all' OR c.Slug = @Category OR c.Name LIKE '%' + @Category + '%')
      AND (@RidingStyle IS NULL OR @RidingStyle = 'all' OR p.RidingStyle = @RidingStyle)
      AND (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%'
           OR b.Name LIKE N'%' + @Search + N'%'
           OR c.Name LIKE N'%' + @Search + N'%'
           OR p.RidingStyle LIKE N'%' + @Search + N'%'
           OR p.Description LIKE N'%' + @Search + N'%')
      AND (@MinPrice IS NULL OR p.BasePrice * (1.0 - p.DiscountPercentage / 100.0) >= @MinPrice)
      AND (@MaxPrice IS NULL OR p.BasePrice * (1.0 - p.DiscountPercentage / 100.0) <= @MaxPrice)
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
        CAST(p.BasePrice * (1.0 - (p.DiscountPercentage / 100.0)) AS DECIMAL(18,2)) AS EffectivePrice,
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
      AND (ISNULL(@OnSale, 0) = 0 OR p.DiscountPercentage > 0)
      AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
      AND (@BrandId IS NULL OR p.BrandId = @BrandId)
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand)
      AND (@Category IS NULL OR @Category = 'all' OR c.Slug = @Category OR c.Name LIKE '%' + @Category + '%')
      AND (@RidingStyle IS NULL OR @RidingStyle = 'all' OR p.RidingStyle = @RidingStyle)
      AND (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%'
           OR b.Name LIKE N'%' + @Search + N'%'
           OR c.Name LIKE N'%' + @Search + N'%'
           OR p.RidingStyle LIKE N'%' + @Search + N'%'
           OR p.Description LIKE N'%' + @Search + N'%')
      AND (@MinPrice IS NULL OR p.BasePrice * (1.0 - p.DiscountPercentage / 100.0) >= @MinPrice)
      AND (@MaxPrice IS NULL OR p.BasePrice * (1.0 - p.DiscountPercentage / 100.0) <= @MaxPrice)
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
        CASE WHEN @SortBy = 'price_asc' THEN p.BasePrice * (1.0 - p.DiscountPercentage / 100.0) END ASC,
        CASE WHEN @SortBy = 'price_desc' THEN p.BasePrice * (1.0 - p.DiscountPercentage / 100.0) END DESC,
        CASE WHEN @SortBy = 'newest' THEN p.CreatedAt END DESC,
        CASE WHEN @SortBy = 'rating' THEN review.Rating END DESC,
        CASE WHEN @SortBy = 'popular' OR @SortBy IS NULL THEN review.ReviewCount END DESC,
        p.Id ASC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- =====================================================================================
-- 9. STORED PROCEDURE: sp_GetProductById
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetProductById', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetProductById AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetProductById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

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
        CAST(p.BasePrice * (1.0 - (p.DiscountPercentage / 100.0)) AS DECIMAL(18,2)) AS EffectivePrice,
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
        ISNULL(i.CurrentStock, 0) AS CurrentStock,
        ISNULL(i.IsLowStock, 0) AS IsLowStock
    FROM dbo.ProductVariants pv
    INNER JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
    LEFT JOIN dbo.Inventories i ON pv.Id = i.VariantId
    WHERE pc.ProductId = @Id AND pv.IsActive = 1
    ORDER BY pv.Id ASC;

    -- Result Set 3: Additional product gallery images.
    SELECT
        ImageUrl,
        COALESCE(AltText, N'Product view') AS AltText,
        CAST(DisplayOrder AS INT) AS DisplayOrder
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @Id AND IsActive = 1
    ORDER BY DisplayOrder ASC, Id ASC;
END;
GO

-- Add an optional gallery image for a product.
IF OBJECT_ID(N'dbo.sp_AddProductGalleryImage', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_AddProductGalleryImage AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_AddProductGalleryImage
    @ProductId INT,
    @ImageUrl NVARCHAR(500),
    @AltText NVARCHAR(200) = NULL,
    @DisplayOrder INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @DisplayOrder < 1
        THROW 50001, 'Gallery image display order must be at least 1.', 1;
    IF NULLIF(LTRIM(RTRIM(@ImageUrl)), N'') IS NULL
        THROW 50002, 'Gallery image URL is required.', 1;

    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM dbo.Products WITH (UPDLOCK, HOLDLOCK) WHERE Id = @ProductId)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50003, 'Product does not exist.', 1;
    END;
    IF EXISTS (SELECT 1 FROM dbo.ProductGalleryImages WITH (UPDLOCK, HOLDLOCK) WHERE ProductId = @ProductId AND DisplayOrder = @DisplayOrder)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50004, 'That gallery image position is already used for this product.', 1;
    END;

    INSERT dbo.ProductGalleryImages (ProductId, ImageUrl, AltText, DisplayOrder)
    VALUES (@ProductId, LTRIM(RTRIM(@ImageUrl)), NULLIF(LTRIM(RTRIM(@AltText)), N''), @DisplayOrder);
    COMMIT TRANSACTION;
END;
GO

-- =====================================================================================
-- Related products: same category, then riding style, then highest rated catalog items.
-- The selected product is excluded and only active products with active variants are returned.
IF OBJECT_ID(N'dbo.sp_GetRelatedProducts', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetRelatedProducts AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetRelatedProducts
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (4)
        p.Id,
        p.Name,
        p.Slug,
        b.Name AS Brand,
        c.Name AS Category,
        p.RidingStyle,
        p.BasePrice,
        p.DiscountPercentage,
        CAST(p.BasePrice * (1.0 - p.DiscountPercentage / 100.0) AS DECIMAL(18,2)) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        p.MainImageUrl,
        p.Description,
        p.IsFeatured
    FROM dbo.Products sourceProduct
    INNER JOIN dbo.Products p ON p.Id <> sourceProduct.Id AND p.IsActive = 1
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    OUTER APPLY (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    WHERE sourceProduct.Id = @ProductId AND sourceProduct.IsActive = 1
      AND EXISTS (
          SELECT 1 FROM dbo.ProductColors pc
          INNER JOIN dbo.ProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
      )
    ORDER BY CASE
                 WHEN p.CategoryId = sourceProduct.CategoryId THEN 0
                 WHEN p.RidingStyle = sourceProduct.RidingStyle THEN 1
                 ELSE 2
             END,
             review.Rating DESC,
             review.ReviewCount DESC,
             p.CreatedAt DESC,
             p.Id ASC;
END;
GO

-- 10. STORED PROCEDURE: sp_GetCategories
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetCategories', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetCategories AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetCategories
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        c.Id,
        c.Name,
        c.Slug,
        c.Description,
        c.DisplayOrder,
        COUNT(p.Id) AS ProductCount
    FROM dbo.Categories c
    LEFT JOIN dbo.Products p ON c.Id = p.CategoryId AND p.IsActive = 1
        AND EXISTS (
            SELECT 1 FROM dbo.ProductColors pc
            JOIN dbo.ProductVariants pv ON pv.ProductColorId = pc.Id
            WHERE pc.ProductId = p.Id AND pv.IsActive = 1
        )
    GROUP BY c.Id, c.Name, c.Slug, c.Description, c.DisplayOrder
    ORDER BY c.DisplayOrder ASC;
END;
GO

-- =====================================================================================
-- 11. STORED PROCEDURE: sp_GetBrands
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetBrands', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetBrands AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetBrands
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        b.Id,
        b.Name,
        b.LogoUrl,
        b.Website,
        COUNT(p.Id) AS ProductCount
    FROM dbo.Brands b
    LEFT JOIN dbo.Products p ON b.Id = p.BrandId AND p.IsActive = 1
        AND EXISTS (
            SELECT 1 FROM dbo.ProductColors pc
            JOIN dbo.ProductVariants pv ON pv.ProductColorId = pc.Id
            WHERE pc.ProductId = p.Id AND pv.IsActive = 1
        )
    WHERE b.IsActive = 1
    GROUP BY b.Id, b.Name, b.LogoUrl, b.Website
    HAVING COUNT(p.Id) > 0
    ORDER BY b.Name ASC;
END;
GO

-- =====================================================================================
-- 12. STORED PROCEDURE: sp_CreateOrder
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_CreateOrder', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_CreateOrder AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_CreateOrder
    @OrderNumber NVARCHAR(50),
    @UserId INT = NULL,
    @CustomerName NVARCHAR(100),
    @CustomerEmail NVARCHAR(256),
    @CustomerPhone NVARCHAR(30),
    @OrderSource NVARCHAR(30) = 'ONLINE',
    @Status NVARCHAR(50) = 'Processing',
    @Subtotal DECIMAL(18,2),
    @DiscountAmount DECIMAL(18,2) = 0.00,
    @TotalAmount DECIMAL(18,2),
    @Notes NVARCHAR(500) = NULL,
    @NewOrderId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Subtotal IS NULL OR @DiscountAmount IS NULL OR @TotalAmount IS NULL
       OR @Subtotal < 0 OR @DiscountAmount < 0 OR @DiscountAmount > @Subtotal
       OR @TotalAmount <> @Subtotal - @DiscountAmount
        THROW 51012, N'Order amounts are inconsistent.', 1;

    INSERT INTO dbo.Orders (
        OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone,
        OrderSource, Status, Subtotal, DiscountAmount, Notes, CreatedAt
    ) VALUES (
        @OrderNumber, @UserId, @CustomerName, @CustomerEmail, @CustomerPhone,
        @OrderSource, @Status, @Subtotal, @DiscountAmount, @Notes, SYSUTCDATETIME()
    );

    SET @NewOrderId = SCOPE_IDENTITY();
END;
GO

-- =====================================================================================
-- 13. STORED PROCEDURE: sp_AddOrderItem
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_AddOrderItem', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_AddOrderItem AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_AddOrderItem
    @OrderId INT,
    @VariantId INT,
    @Quantity INT,
    @UnitPrice DECIMAL(18,2),
    @TotalPrice DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Quantity IS NULL OR @Quantity <= 0 OR @UnitPrice IS NULL OR @UnitPrice < 0
       OR @TotalPrice IS NULL OR @TotalPrice <> CONVERT(DECIMAL(18,2), @Quantity * @UnitPrice)
        THROW 51013, N'Order item amount is inconsistent.', 1;

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    VALUES (@OrderId, @VariantId, @Quantity, @UnitPrice);
END;
GO

-- =====================================================================================
-- Validate complete order inside the caller's order creation transaction.
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_ValidateOrderTotals', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_ValidateOrderTotals AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_ValidateOrderTotals
    @OrderId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Subtotal DECIMAL(18,2), @LineTotal DECIMAL(18,2), @LineCount INT;
    SELECT @Subtotal = Subtotal FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE Id = @OrderId;
    SELECT @LineTotal = SUM(TotalPrice), @LineCount = COUNT(*)
    FROM dbo.OrderItems WHERE OrderId = @OrderId;

    IF @Subtotal IS NULL OR @LineCount = 0 OR @LineTotal <> @Subtotal
        THROW 51017, N'Order subtotal does not match its items.', 1;
END;
GO

-- =====================================================================================
-- 14. STORED PROCEDURE: sp_GetOrderDetails
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetOrderDetails', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetOrderDetails AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetOrderDetails
    @OrderNumber NVARCHAR(50) = NULL,
    @OrderId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Result Set 1: Order Header
    SELECT 
        o.Id,
        o.OrderNumber,
        o.UserId,
        o.CustomerName,
        o.CustomerEmail,
        o.CustomerPhone,
        o.OrderSource,
        o.Status,
        o.Subtotal,
        o.DiscountAmount,
        o.TotalAmount,
        o.Notes,
        o.CreatedAt,
        ISNULL((
            SELECT TOP 1 p.PaymentGateway 
            FROM dbo.Payments p 
            WHERE p.OrderId = o.Id 
            ORDER BY p.CreatedAt DESC
        ), 'Cash') AS PaymentGateway,
        ISNULL((
            SELECT TOP 1 p.Status 
            FROM dbo.Payments p 
            WHERE p.OrderId = o.Id 
            ORDER BY p.CreatedAt DESC
        ), 'Pending') AS PaymentStatus
    FROM dbo.Orders o
    WHERE (@OrderId IS NOT NULL AND o.Id = @OrderId)
       OR (@OrderNumber IS NOT NULL AND o.OrderNumber = @OrderNumber);

    -- Result Set 2: Order Items
    SELECT 
        oi.Id,
        oi.OrderId,
        oi.VariantId,
        p.Name AS ProductName,
        pv.SKU,
        pv.Size,
        pc.Color,
        oi.Quantity,
        oi.UnitPrice,
        oi.TotalPrice
    FROM dbo.OrderItems oi
    INNER JOIN dbo.ProductVariants pv ON oi.VariantId = pv.Id
    INNER JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.Products p ON pc.ProductId = p.Id
    INNER JOIN dbo.Orders o ON oi.OrderId = o.Id
    WHERE (@OrderId IS NOT NULL AND o.Id = @OrderId)
       OR (@OrderNumber IS NOT NULL AND o.OrderNumber = @OrderNumber);
END;
GO

-- =====================================================================================
-- 15. STORED PROCEDURE: sp_UpdateOrderStatus
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_UpdateOrderStatus', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_UpdateOrderStatus AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_UpdateOrderStatus
    @OrderId INT,
    @NewStatus NVARCHAR(50)
AS
BEGIN
    -- OrderRepository uses ExecuteNonQuery row count to detect missing orders.
    SET NOCOUNT OFF;

    UPDATE dbo.Orders
    SET Status = @NewStatus,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @OrderId;
END;
GO

-- =====================================================================================
-- 16. STORED PROCEDURE: sp_RecordPayment
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_RecordPayment', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_RecordPayment AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_RecordPayment
    @OrderId INT,
    @PaymentGateway NVARCHAR(50),
    @GatewayReference NVARCHAR(100) = NULL,
    @Amount DECIMAL(18,2),
    @Status NVARCHAR(50) = 'Pending',
    @PaidAt DATETIME2 = NULL,
    @PaymentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;
        SET @PaymentId = NULL;

        IF @GatewayReference IS NOT NULL
        BEGIN
            SELECT @PaymentId = Id
            FROM dbo.Payments WITH (UPDLOCK, HOLDLOCK)
            WHERE PaymentGateway = @PaymentGateway AND GatewayReference = @GatewayReference;

            IF @PaymentId IS NOT NULL
            BEGIN
                IF EXISTS (SELECT 1 FROM dbo.Payments WHERE Id = @PaymentId AND (OrderId <> @OrderId OR Amount <> @Amount))
                    THROW 51016, N'Gateway reference belongs to another payment.', 1;
                COMMIT TRANSACTION;
                RETURN;
            END;
        END;

        INSERT INTO dbo.Payments (
            OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt
        ) VALUES (
            @OrderId, @PaymentGateway, @GatewayReference, @Amount, @Status, @PaidAt, SYSUTCDATETIME()
        );

        SET @PaymentId = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- 17. STORED PROCEDURE: sp_GetInventoryByVariantId
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetInventoryByVariantId', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetInventoryByVariantId AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetInventoryByVariantId
    @VariantId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        i.Id,
        i.VariantId,
        i.CurrentStock,
        i.ReservedStock,
        i.ReorderPoint,
        i.IsLowStock,
        i.LastRestockedAt,
        i.UpdatedAt
    FROM dbo.Inventories i
    WHERE i.VariantId = @VariantId;
END;
GO

-- =====================================================================================
-- 18. STORED PROCEDURE: sp_GetRecentOrders
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetRecentOrders', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetRecentOrders AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetRecentOrders
    @Limit INT = 20,
    @Status NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Limit)
        Id, OrderNumber, CustomerName, CustomerEmail, CustomerPhone,
        OrderSource, Status, Subtotal, DiscountAmount, TotalAmount, CreatedAt
    FROM dbo.Orders
    WHERE (@Status IS NULL OR Status = @Status)
    ORDER BY CreatedAt DESC;
END;
GO

-- =====================================================================================
-- 19. STORED PROCEDURE: sp_GetVariantPriceInfo
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetVariantPriceInfo', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetVariantPriceInfo AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetVariantPriceInfo
    @VariantId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        pv.Id AS VariantId,
        pc.ProductId,
        p.Name AS ProductName,
        pv.SKU,
        pv.Size,
        pc.Color,
        CAST((p.BasePrice + pv.PriceAdjustment) * (1.0 - (p.DiscountPercentage / 100.0)) AS DECIMAL(18,2)) AS UnitPrice
    FROM dbo.ProductVariants pv
    INNER JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.Products p ON pc.ProductId = p.Id
    WHERE pv.Id = @VariantId AND pv.IsActive = 1 AND p.IsActive = 1;
END;
GO

-- =====================================================================================
-- 20. STORED PROCEDURE: sp_GetInventoryList
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetInventoryList', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetInventoryList AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetInventoryList
    @LowStockOnly BIT = 0,
    @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        i.Id AS InventoryId,
        pv.Id AS VariantId,
        p.Name AS ProductName,
        b.Name AS Brand,
        pv.SKU,
        pv.Size,
        pc.Color,
        i.CurrentStock,
        i.ReservedStock,
        i.ReorderPoint,
        i.IsLowStock,
        i.LastRestockedAt
    FROM dbo.Inventories i
    INNER JOIN dbo.ProductVariants pv ON i.VariantId = pv.Id
    INNER JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.Products p ON pc.ProductId = p.Id
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    WHERE (@LowStockOnly = 0 OR i.IsLowStock = 1)
      AND (@Search IS NULL OR p.Name LIKE '%' + @Search + '%' OR pv.SKU LIKE '%' + @Search + '%')
    ORDER BY i.IsLowStock DESC, i.CurrentStock ASC;
END;
GO

-- =====================================================================================
-- 21. STORED PROCEDURE: sp_GetInventoryStatusByVariantId
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetInventoryStatusByVariantId', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetInventoryStatusByVariantId AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetInventoryStatusByVariantId
    @VariantId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        i.Id AS InventoryId,
        pv.Id AS VariantId,
        p.Name AS ProductName,
        b.Name AS Brand,
        pv.SKU,
        pv.Size,
        pc.Color,
        i.CurrentStock,
        i.ReservedStock,
        i.ReorderPoint,
        i.IsLowStock,
        i.LastRestockedAt
    FROM dbo.Inventories i
    INNER JOIN dbo.ProductVariants pv ON i.VariantId = pv.Id
    INNER JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.Products p ON pc.ProductId = p.Id
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    WHERE pv.Id = @VariantId;
END;
GO

-- =====================================================================================
-- 22. STORED PROCEDURE: sp_GetProductReviews
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetProductReviews', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetProductReviews AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetProductReviews
    @ProductId INT,
    @IncludeHidden BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        Id,
        ProductId,
        UserId,
        OrderId,
        ReviewerName,
        Rating,
        Title,
        Comment,
        IsVerifiedPurchase,
        (SELECT COUNT(*) FROM dbo.ReviewReports reports WHERE reports.ReviewId = reviews.Id) AS FlagCount,
        IsHidden,
        CreatedAt
    FROM dbo.ProductReviews reviews
    WHERE ProductId = @ProductId
      AND (@IncludeHidden = 1 OR IsHidden = 0)
    ORDER BY CreatedAt DESC;
END;
GO

-- =====================================================================================
-- 23. STORED PROCEDURE: sp_AddProductReview
-- Verifies linked purchase; catalog queries derive visible review aggregates.
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_AddProductReview', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_AddProductReview AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_AddProductReview
    @ProductId INT,
    @UserId INT = NULL,
    @OrderId INT = NULL,
    @ReviewerName NVARCHAR(100),
    @Rating INT,
    @Title NVARCHAR(150) = NULL,
    @Comment NVARCHAR(MAX),
    @IsVerifiedPurchase BIT = 0,
    @NewReviewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Verified BIT = 0;
        IF @UserId IS NOT NULL AND @OrderId IS NOT NULL AND EXISTS
        (
            SELECT 1
            FROM dbo.Orders o
            JOIN dbo.OrderItems oi ON oi.OrderId = o.Id
            JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
            JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
            WHERE o.Id = @OrderId AND o.UserId = @UserId
              AND o.Status = N'Completed' AND pc.ProductId = @ProductId
        )
            SET @Verified = 1;

        IF (@OrderId IS NOT NULL OR @IsVerifiedPurchase = 1) AND @Verified = 0
            THROW 51014, N'Linked completed purchase not found.', 1;

        INSERT INTO dbo.ProductReviews (
            ProductId, UserId, OrderId, ReviewerName, Rating, Title, Comment, IsVerifiedPurchase, IsHidden
        )
        VALUES (
            @ProductId, @UserId, @OrderId, @ReviewerName, @Rating, @Title, @Comment, @Verified, 0
        );

        SET @NewReviewId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- 24. STORED PROCEDURE: sp_ReportReview
-- Community reports with duplicate checks and automatic hide after three reports.
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_ReportReview', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_ReportReview AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_ReportReview
    @ReviewId INT,
    @UserId INT = NULL,
    @IpAddress NVARCHAR(45) = NULL,
    @Reason NVARCHAR(50), -- 'SPAM', 'OFFENSIVE', 'IRRELEVANT', 'FAKE'
    @Notes NVARCHAR(255) = NULL,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.ProductReviews WITH (UPDLOCK, ROWLOCK) WHERE Id = @ReviewId)
            THROW 51015, N'Review not found.', 1;

        -- The review row lock serializes reports for the same review.
        IF @UserId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.ReviewReports WHERE ReviewId = @ReviewId AND UserId = @UserId)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'You have already reported this review.';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        ELSE IF @UserId IS NULL AND @IpAddress IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.ReviewReports WHERE ReviewId = @ReviewId AND IpAddress = @IpAddress)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'You have already reported this review.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO dbo.ReviewReports (ReviewId, UserId, IpAddress, Reason, Notes)
        VALUES (@ReviewId, @UserId, @IpAddress, @Reason, @Notes);

        -- Auto-hide after three stored reports.
        UPDATE dbo.ProductReviews
        SET 
            IsHidden = CASE WHEN (SELECT COUNT(*) FROM dbo.ReviewReports WHERE ReviewId = @ReviewId) >= 3 THEN 1 ELSE IsHidden END
        WHERE Id = @ReviewId;

        COMMIT TRANSACTION;

        SET @Success = 1;
        SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END;
GO

-- =====================================================================================
-- 25. STORED PROCEDURE: sp_GetFaqs
-- Retrieves global FAQs (ProductId IS NULL) and optionally product-specific Q&As
-- =====================================================================================
IF OBJECT_ID(N'dbo.sp_GetFaqs', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetFaqs AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetFaqs
    @ProductId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        Id,
        ProductId,
        Question,
        Answer,
        DisplayOrder,
        IsActive,
        CreatedAt
    FROM dbo.Faqs
    WHERE IsActive = 1
      AND (@ProductId IS NULL AND ProductId IS NULL 
           OR @ProductId IS NOT NULL AND (ProductId IS NULL OR ProductId = @ProductId))
    ORDER BY 
        CASE WHEN ProductId IS NULL THEN 0 ELSE 1 END ASC,
        DisplayOrder ASC,
        Id ASC;
END;
GO
