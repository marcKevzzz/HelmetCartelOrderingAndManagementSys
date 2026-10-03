-- ============================================================================
-- Migration 36: Schema Enhancements, Order Snapshots, and Integrity Fixes
-- Description:
--   1. Adds PublicationStatus ('Draft', 'Published', 'Archived') to dbo.Products
--      Backfills existing active products as 'Published' and inactive as 'Draft'.
--   2. Adds order-time snapshot columns (ProductName, SKU, ColorName, Size) to dbo.OrderItems
--      and backfills existing items from the catalog.
--   3. Adds filtered unique index on dbo.UserAddresses (UserId) WHERE IsDefault = 1
--      after deduplicating any legacy defaults.
--   4. Adds foreign key index on dbo.Orders (UserId).
--   5. Adds sequence dbo.Seq_RmaNumber and filtered unique index on active RMA per OrderItemId.
--   6. Updates dbo.sp_AddOrderItem and dbo.sp_CreatePhysicalSale to snapshot catalog values in SQL.
--   7. Updates dbo.sp_ConfirmHitPayOrder to fix reservation-aware stock verification.
--   8. Updates dbo.sp_CreateReturnRequest with sequence generation and concurrency locking.
--   9. Updates dbo.v_VisibleProducts to enforce PublicationStatus = 'Published' AND IsActive = 1.
--  10. Updates dbo.sp_GetProductsPaged to support explicit 'top_selling' sales volume sorting.
--  11. Updates dbo.sp_GetOrderDetails and dbo.sp_GetUserOrderDetails to read order-time snapshots.
--  12. Updates admin catalog procedures to support PublicationStatus.
-- ============================================================================

USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- 1. dbo.Products: PublicationStatus
-- ----------------------------------------------------------------------------
IF COL_LENGTH(N'dbo.Products', N'PublicationStatus') IS NULL
BEGIN
    ALTER TABLE dbo.Products 
    ADD PublicationStatus NVARCHAR(20) NOT NULL 
    CONSTRAINT DF_Products_PublicationStatus DEFAULT N'Draft';

    -- Backfill existing products based on current active status
    EXEC(N'
        UPDATE dbo.Products SET PublicationStatus = N''Published'' WHERE IsActive = 1;
        UPDATE dbo.Products SET PublicationStatus = N''Draft'' WHERE IsActive = 0;
    ');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Products_PublicationStatus')
BEGIN
    ALTER TABLE dbo.Products
    ADD CONSTRAINT CK_Products_PublicationStatus 
    CHECK (PublicationStatus IN (N'Draft', N'Published', N'Archived'));
END;
GO

-- ----------------------------------------------------------------------------
-- 2. dbo.OrderItems: Order-time Snapshots
-- ----------------------------------------------------------------------------
IF COL_LENGTH(N'dbo.OrderItems', N'ProductName') IS NULL
BEGIN
    ALTER TABLE dbo.OrderItems ADD ProductName NVARCHAR(200) NULL;
    ALTER TABLE dbo.OrderItems ADD SKU NVARCHAR(100) NULL;
    ALTER TABLE dbo.OrderItems ADD ColorName NVARCHAR(100) NULL;
    ALTER TABLE dbo.OrderItems ADD Size NVARCHAR(20) NULL;

    -- Backfill existing order items from catalog relations
    EXEC(N'
        UPDATE oi
        SET oi.ProductName = ISNULL(p.Name, N''Motorcycle Helmet''),
            oi.SKU = ISNULL(v.SKU, N''N/A''),
            oi.ColorName = ISNULL(c.Color, N''Standard''),
            oi.Size = ISNULL(v.Size, N''Standard'')
        FROM dbo.OrderItems oi
        LEFT JOIN dbo.ProductVariants v ON v.Id = oi.VariantId
        LEFT JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
        LEFT JOIN dbo.Products p ON p.Id = c.ProductId;
    ');
END;
GO

-- ----------------------------------------------------------------------------
-- 3. dbo.UserAddresses: Deduplicate Defaults and Add Unique Filtered Index
-- ----------------------------------------------------------------------------
;WITH DuplicateDefaults AS (
    SELECT Id, ROW_NUMBER() OVER (PARTITION BY UserId ORDER BY UpdatedAt DESC, Id DESC) AS rn
    FROM dbo.UserAddresses
    WHERE IsDefault = 1
)
UPDATE a
SET a.IsDefault = 0
FROM dbo.UserAddresses a
INNER JOIN DuplicateDefaults d ON d.Id = a.Id
WHERE d.rn > 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_UserAddresses_UserDefault' AND object_id = OBJECT_ID(N'dbo.UserAddresses'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_UserAddresses_UserDefault
    ON dbo.UserAddresses (UserId)
    WHERE IsDefault = 1;
END;
GO

-- ----------------------------------------------------------------------------
-- 4. dbo.Orders: Foreign Key Index on UserId
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Orders_UserId' AND object_id = OBJECT_ID(N'dbo.Orders'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Orders_UserId ON dbo.Orders (UserId);
END;
GO

-- ----------------------------------------------------------------------------
-- 5. dbo.ReturnRequests: Sequence and Active Item Deduplication/Index
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.Seq_RmaNumber', N'SO') IS NULL
BEGIN
    DECLARE @MaxRmaVal INT = 1000;
    SELECT @MaxRmaVal = ISNULL(MAX(CAST(RIGHT(RmaNumber, 4) AS INT)), 1000)
    FROM dbo.ReturnRequests;
    IF @MaxRmaVal < 1000 SET @MaxRmaVal = 1000;
    SET @MaxRmaVal = @MaxRmaVal + 1;

    DECLARE @SqlSeq NVARCHAR(MAX) = N'CREATE SEQUENCE dbo.Seq_RmaNumber START WITH ' + CAST(@MaxRmaVal AS NVARCHAR(20)) + N' INCREMENT BY 1 MINVALUE 1;';
    EXEC sp_executesql @SqlSeq;
END;
GO

;WITH DuplicateRMA AS (
    SELECT Id, ROW_NUMBER() OVER (PARTITION BY OrderItemId ORDER BY CreatedAt DESC, Id DESC) AS rn
    FROM dbo.ReturnRequests
    WHERE Status NOT IN (N'Rejected', N'Cancelled')
)
UPDATE r
SET r.Status = N'Cancelled'
FROM dbo.ReturnRequests r
INNER JOIN DuplicateRMA d ON d.Id = r.Id
WHERE d.rn > 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_ReturnRequests_ActiveItem' AND object_id = OBJECT_ID(N'dbo.ReturnRequests'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_ReturnRequests_ActiveItem
    ON dbo.ReturnRequests (OrderItemId)
    WHERE Status <> N'Rejected' AND Status <> N'Cancelled';
END;
GO

-- ----------------------------------------------------------------------------
-- 6. Procedure: dbo.sp_SaveUserAddress (Transactional)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_SaveUserAddress
    @Id INT = NULL,
    @UserId INT,
    @AddressLabel NVARCHAR(50) = NULL,
    @RecipientName NVARCHAR(100) = NULL,
    @PhoneNumber NVARCHAR(30) = NULL,
    @StreetAddress NVARCHAR(255),
    @Barangay NVARCHAR(100) = NULL,
    @City NVARCHAR(100),
    @Province NVARCHAR(100),
    @PostalCode NVARCHAR(20) = NULL,
    @DeliveryLandmark NVARCHAR(255) = NULL,
    @IsDefault BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @UserId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId)
        THROW 53011, N'User not found.', 1;

    IF @RecipientName IS NULL OR LEN(LTRIM(RTRIM(@RecipientName))) = 0
    BEGIN
        SELECT @RecipientName = LTRIM(RTRIM(CONCAT(FirstName, N' ', LastName)))
        FROM dbo.Users
        WHERE Id = @UserId;
    END

    IF @PhoneNumber IS NULL OR LEN(LTRIM(RTRIM(@PhoneNumber))) = 0
    BEGIN
        SELECT @PhoneNumber = PhoneNumber
        FROM dbo.Users
        WHERE Id = @UserId;
    END

    IF @StreetAddress IS NULL OR LEN(LTRIM(RTRIM(@StreetAddress))) = 0
        THROW 53013, N'Street address is required.', 1;

    IF @City IS NULL OR LEN(LTRIM(RTRIM(@City))) = 0
        THROW 53015, N'City / Municipality is required.', 1;

    IF @Province IS NULL OR LEN(LTRIM(RTRIM(@Province))) = 0
        THROW 53016, N'Province is required.', 1;

    SET @AddressLabel = ISNULL(NULLIF(LTRIM(RTRIM(@AddressLabel)), N''), N'Home');
    SET @RecipientName = ISNULL(NULLIF(LTRIM(RTRIM(@RecipientName)), N''), N'Account Holder');
    SET @PhoneNumber = ISNULL(NULLIF(LTRIM(RTRIM(@PhoneNumber)), N''), N'');
    SET @Barangay = ISNULL(NULLIF(LTRIM(RTRIM(@Barangay)), N''), N'');
    SET @PostalCode = ISNULL(NULLIF(LTRIM(RTRIM(@PostalCode)), N''), N'');

    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.UserAddresses WHERE UserId = @UserId)
    BEGIN
        SET @IsDefault = 1;
    END

    IF @IsDefault = 1
    BEGIN
        UPDATE dbo.UserAddresses
        SET IsDefault = 0,
            UpdatedAt = SYSUTCDATETIME()
        WHERE UserId = @UserId;
    END

    DECLARE @TargetId INT = @Id;

    IF @TargetId IS NOT NULL AND @TargetId > 0 AND EXISTS (SELECT 1 FROM dbo.UserAddresses WHERE Id = @TargetId AND UserId = @UserId)
    BEGIN
        UPDATE dbo.UserAddresses
        SET AddressLabel = @AddressLabel,
            RecipientName = @RecipientName,
            PhoneNumber = @PhoneNumber,
            StreetAddress = LTRIM(RTRIM(@StreetAddress)),
            Barangay = @Barangay,
            City = LTRIM(RTRIM(@City)),
            Province = LTRIM(RTRIM(@Province)),
            PostalCode = @PostalCode,
            DeliveryLandmark = NULLIF(LTRIM(RTRIM(@DeliveryLandmark)), N''),
            IsDefault = @IsDefault,
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @TargetId AND UserId = @UserId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.UserAddresses (
            UserId, AddressLabel, RecipientName, PhoneNumber,
            StreetAddress, Barangay, City, Province, PostalCode,
            DeliveryLandmark, IsDefault, CreatedAt, UpdatedAt
        )
        VALUES (
            @UserId, @AddressLabel, @RecipientName, @PhoneNumber,
            LTRIM(RTRIM(@StreetAddress)), @Barangay,
            LTRIM(RTRIM(@City)), LTRIM(RTRIM(@Province)), @PostalCode,
            NULLIF(LTRIM(RTRIM(@DeliveryLandmark)), N''), @IsDefault,
            SYSUTCDATETIME(), SYSUTCDATETIME()
        );

        SET @TargetId = CONVERT(INT, SCOPE_IDENTITY());
    END

    COMMIT TRANSACTION;

    SELECT 
        a.Id,
        a.UserId,
        a.AddressLabel,
        a.RecipientName,
        a.PhoneNumber,
        a.StreetAddress,
        a.Barangay,
        a.City,
        a.Province,
        a.PostalCode,
        a.DeliveryLandmark,
        a.IsDefault,
        a.CreatedAt,
        a.UpdatedAt
    FROM dbo.UserAddresses a
    WHERE a.Id = @TargetId;
END;
GO

-- ----------------------------------------------------------------------------
-- 7. Procedure: dbo.sp_AddOrderItem (Captures Catalog Snapshots in SQL)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AddOrderItem
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

    DECLARE @ProductName NVARCHAR(200),
            @SKU NVARCHAR(100),
            @ColorName NVARCHAR(100),
            @Size NVARCHAR(20);

    SELECT 
        @ProductName = p.Name,
        @SKU = v.SKU,
        @ColorName = c.Color,
        @Size = v.Size
    FROM dbo.ProductVariants v
    INNER JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = c.ProductId
    WHERE v.Id = @VariantId;

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice, ProductName, SKU, ColorName, Size)
    VALUES (@OrderId, @VariantId, @Quantity, @UnitPrice, @ProductName, @SKU, @ColorName, @Size);
END;
GO

-- ----------------------------------------------------------------------------
-- 8. Procedure: dbo.sp_CreatePhysicalSale (POS Snapshot Capture)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CreatePhysicalSale
    @OrderNumber NVARCHAR(50), 
    @ActorUserId INT = NULL,
    @CustomerName NVARCHAR(100), 
    @CustomerEmail NVARCHAR(256), 
    @CustomerPhone NVARCHAR(30),
    @OrderSource NVARCHAR(30), 
    @OrderStatus NVARCHAR(50), 
    @PaymentMethod NVARCHAR(50),
    @PaymentStatus NVARCHAR(50), 
    @Notes NVARCHAR(500), 
    @Items dbo.SaleLineInput READONLY,
    @CashTendered DECIMAL(18,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM @Items) OR EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0)
        THROW 52201, N'Sale needs positive item quantities.', 1;

    IF @PaymentMethod NOT IN (N'Cash', N'Card_POS') OR
       (@OrderSource = N'INSTORE_POS' AND (@OrderStatus <> N'Completed' OR @PaymentStatus <> N'Completed')) OR
       (@OrderSource = N'ONLINE' AND (@OrderStatus <> N'Processing' OR @PaymentStatus <> N'Pending')) OR
       @OrderSource NOT IN (N'INSTORE_POS', N'ONLINE')
        THROW 52202, N'Invalid physical sale options.', 1;

    BEGIN TRANSACTION;

    DECLARE @Lines TABLE (VariantId INT PRIMARY KEY, Quantity INT, UnitPrice DECIMAL(18,2), OldStock INT);
    DECLARE @VariantId INT, @Quantity INT, @UnitPrice DECIMAL(18,2), @OldStock INT;
    DECLARE sale_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT VariantId, SUM(Quantity) FROM @Items GROUP BY VariantId;
    OPEN sale_cursor;
    FETCH NEXT FROM sale_cursor INTO @VariantId, @Quantity;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @OldStock = CurrentStock - ReservedStock,
               @UnitPrice = dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
                    p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
                    p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive)
        FROM dbo.Inventories i WITH (UPDLOCK, ROWLOCK)
        JOIN dbo.ProductVariants v ON v.Id = i.VariantId
        JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = c.ProductId
        WHERE i.VariantId = @VariantId AND p.IsActive = 1 AND v.IsActive = 1;

        IF @OldStock IS NULL OR @OldStock < @Quantity
            THROW 52203, N'Insufficient stock available for physical sale.', 1;

        INSERT @Lines VALUES (@VariantId, @Quantity, @UnitPrice, @OldStock);
        SET @UnitPrice = NULL;
        SET @OldStock = NULL;
        FETCH NEXT FROM sale_cursor INTO @VariantId, @Quantity;
    END;
    CLOSE sale_cursor;
    DEALLOCATE sale_cursor;

    DECLARE @Subtotal DECIMAL(18,2) = (SELECT SUM(Quantity * UnitPrice) FROM @Lines);
    IF @OrderSource = N'INSTORE_POS' AND @PaymentMethod = N'Cash' AND
       (@CashTendered IS NULL OR @CashTendered < @Subtotal)
        THROW 52208, N'Cash tendered is less than the current sale total.', 1;

    INSERT dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone,
        OrderSource, Status, Subtotal, DiscountAmount, Notes)
    VALUES (@OrderNumber, CASE WHEN @OrderSource = N'ONLINE' THEN @ActorUserId ELSE NULL END,
        @CustomerName, @CustomerEmail, @CustomerPhone,
        @OrderSource, @OrderStatus, @Subtotal, 0, @Notes);

    DECLARE @OrderId INT = CONVERT(INT, SCOPE_IDENTITY());

    -- Capture snapshots inside SQL
    INSERT dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice, ProductName, SKU, ColorName, Size)
    SELECT 
        @OrderId, 
        l.VariantId, 
        l.Quantity, 
        l.UnitPrice,
        p.Name,
        v.SKU,
        c.Color,
        v.Size
    FROM @Lines l
    INNER JOIN dbo.ProductVariants v ON v.Id = l.VariantId
    INNER JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = c.ProductId;

    UPDATE i SET CurrentStock = i.CurrentStock - l.Quantity, UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId;

    INSERT dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber)
    SELECT VariantId, @ActorUserId, CASE WHEN @OrderSource = N'INSTORE_POS' THEN N'INSTORE_SALE' ELSE N'ONLINE_SALE' END,
           OldStock, -Quantity, @OrderNumber FROM @Lines;

    INSERT dbo.Payments (OrderId, PaymentGateway, Amount, Status, PaidAt)
    VALUES (@OrderId, @PaymentMethod, @Subtotal, @PaymentStatus,
        CASE WHEN @PaymentStatus = N'Completed' THEN SYSUTCDATETIME() ELSE NULL END);

    INSERT dbo.RestockAlerts (InventoryId, Severity)
    SELECT i.Id, CASE WHEN i.CurrentStock - i.ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId
    WHERE i.IsLowStock = 1 AND NOT EXISTS
        (SELECT 1 FROM dbo.RestockAlerts a WHERE a.InventoryId = i.Id AND a.IsDismissed = 0);

    COMMIT TRANSACTION;
    SELECT @OrderId AS Id;
END;
GO

-- ----------------------------------------------------------------------------
-- 9. Procedure: dbo.sp_ConfirmHitPayOrder (Reservation-Aware Stock Verification)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ConfirmHitPayOrder
    @OrderNumber NVARCHAR(50),
    @GatewayReference NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@GatewayReference)), N'') IS NULL
        THROW 52204, N'Payment reference is required.', 1;

    BEGIN TRANSACTION;

    DECLARE @OrderId INT,
            @Status NVARCHAR(50),
            @Total DECIMAL(18,2),
            @CustomerUserId INT;

    SELECT @OrderId = Id,
           @Status = Status,
           @Total = TotalAmount,
           @CustomerUserId = UserId
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
    WHERE OrderNumber = @OrderNumber AND OrderSource = N'ONLINE';

    IF @OrderId IS NULL
        THROW 52205, N'Online order not found.', 1;

    IF @Status = N'Processing' AND EXISTS
    (
        SELECT 1
        FROM dbo.Payments
        WHERE OrderId = @OrderId
          AND PaymentGateway = N'HitPay'
          AND GatewayReference = @GatewayReference
          AND Status = N'Completed'
    )
    BEGIN
        COMMIT TRANSACTION;
        SELECT @OrderId AS Id, CONVERT(BIT, 0) AS Processed;
        RETURN;
    END;

    IF @Status <> N'PendingPayment'
        THROW 52206, N'Order cannot accept this payment.', 1;

    DECLARE @Lines TABLE
    (
        VariantId INT PRIMARY KEY,
        Quantity INT NOT NULL,
        OldStock INT NOT NULL,
        OldReservedStock INT NOT NULL
    );

    DECLARE @VariantId INT,
            @Quantity INT,
            @OldStock INT,
            @OldReservedStock INT;

    DECLARE line_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT VariantId, SUM(Quantity)
        FROM dbo.OrderItems
        WHERE OrderId = @OrderId
        GROUP BY VariantId
        ORDER BY VariantId;

    OPEN line_cursor;
    FETCH NEXT FROM line_cursor INTO @VariantId, @Quantity;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @OldStock = CurrentStock,
               @OldReservedStock = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
        WHERE VariantId = @VariantId;

        -- Stock was already reserved for this order during checkout (via sp_ReserveStockAtomic).
        -- Physical stock must be sufficient to fulfill the quantity.
        IF @OldStock IS NULL OR @OldStock < @Quantity
            THROW 52207, N'Paid order has insufficient physical stock; manual resolution required.', 1;

        INSERT @Lines (VariantId, Quantity, OldStock, OldReservedStock)
        VALUES (@VariantId, @Quantity, @OldStock, @OldReservedStock);

        SET @OldStock = NULL;
        SET @OldReservedStock = NULL;
        FETCH NEXT FROM line_cursor INTO @VariantId, @Quantity;
    END;

    CLOSE line_cursor;
    DEALLOCATE line_cursor;

    -- Deduct physical stock and consume the reservation
    UPDATE i
    SET CurrentStock = i.CurrentStock - l.Quantity,
        ReservedStock = CASE
            WHEN i.ReservedStock >= l.Quantity THEN i.ReservedStock - l.Quantity
            ELSE 0
        END,
        UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Inventories i
    INNER JOIN @Lines l ON l.VariantId = i.VariantId;

    INSERT dbo.StockAuditLogs
        (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
    SELECT VariantId, @CustomerUserId, N'ONLINE_SALE', OldStock, -Quantity,
           @OrderNumber, N'HitPay payment confirmed; reservation converted to sale.'
    FROM @Lines;

    INSERT dbo.Payments
        (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt)
    VALUES
        (@OrderId, N'HitPay', @GatewayReference, @Total, N'Completed', SYSUTCDATETIME());

    UPDATE dbo.Orders
    SET Status = N'Processing', UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @OrderId;

    COMMIT TRANSACTION;
    SELECT @OrderId AS Id, CONVERT(BIT, 1) AS Processed;
END;
GO

-- ----------------------------------------------------------------------------
-- 10. Procedure: dbo.sp_CreateReturnRequest (Safe Concurrency & Sequence)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CreateReturnRequest
    @OrderId INT,
    @OrderItemId INT,
    @UserId INT = NULL,
    @RequestType NVARCHAR(20),
    @Reason NVARCHAR(50),
    @ExchangeVariantId INT = NULL,
    @CustomerNotes NVARCHAR(1000) = NULL,
    @NewRmaId INT OUTPUT,
    @NewRmaNumber NVARCHAR(30) OUTPUT,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OrderStatus NVARCHAR(50);
        SELECT @OrderStatus = Status FROM dbo.Orders WHERE Id = @OrderId;

        IF @OrderStatus IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Order does not exist.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @OrderStatus NOT IN (N'Completed', N'Delivered')
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Only delivered or completed orders are eligible for return or exchange.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.OrderItems WHERE Id = @OrderItemId AND OrderId = @OrderId)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Order item does not belong to this order.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Concurrency locking on item active returns
        IF EXISTS (SELECT 1 FROM dbo.ReturnRequests WITH (UPDLOCK, HOLDLOCK) WHERE OrderItemId = @OrderItemId AND Status NOT IN (N'Rejected', N'Cancelled'))
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'An active return or exchange request already exists for this item.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Safe atomic sequence generation
        DECLARE @DatePrefix NVARCHAR(12) = N'RMA-' + FORMAT(SYSUTCDATETIME(), N'yyyyMMdd') + N'-';
        DECLARE @NextSeq BIGINT = NEXT VALUE FOR dbo.Seq_RmaNumber;
        SET @NewRmaNumber = @DatePrefix + RIGHT(N'0000' + CAST((@NextSeq % 10000) AS NVARCHAR(10)), 4);

        INSERT INTO dbo.ReturnRequests (
            RmaNumber,
            OrderId,
            OrderItemId,
            UserId,
            RequestType,
            Reason,
            ExchangeVariantId,
            CustomerNotes,
            Status,
            Restocked
        )
        VALUES (
            @NewRmaNumber,
            @OrderId,
            @OrderItemId,
            @UserId,
            @RequestType,
            @Reason,
            @ExchangeVariantId,
            @CustomerNotes,
            N'Pending',
            0
        );

        SET @NewRmaId = CONVERT(INT, SCOPE_IDENTITY());
        SET @Success = 1;
        SET @ErrorMessage = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO

-- ----------------------------------------------------------------------------
-- 11. Views: dbo.v_VisibleProducts Enforcing PublicationStatus = 'Published'
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_VisibleProducts AS
SELECT p.* 
FROM dbo.Products p 
WHERE p.IsActive = 1 
  AND p.PublicationStatus = N'Published';
GO

-- ----------------------------------------------------------------------------
-- 12. Procedure: dbo.sp_GetProductsPaged (Supporting Explicit 'top_selling')
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetProductsPaged
    @CategoryId INT = NULL,
    @BrandId INT = NULL,
    @Brand NVARCHAR(200) = NULL,
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
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Colors = NULLIF(LTRIM(RTRIM(@Colors)), N'');
    SET @Sizes = NULLIF(LTRIM(RTRIM(@Sizes)), N'');
    IF @PageNumber IS NULL OR @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 9;
    IF @PageSize > 100 SET @PageSize = 100;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    -- Calculate total count
    SELECT @TotalCount = COUNT(*)
    FROM dbo.v_VisibleProducts p
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
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand OR CHARINDEX(N',' + UPPER(b.Name) + N',', N',' + UPPER(@Brand) + N',') > 0)
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
              FROM dbo.v_VisibleProductColors pc_s
              JOIN dbo.v_VisibleProductVariants pv_s ON pv_s.ProductColorId = pc_s.Id
              WHERE pc_s.ProductId = p.Id AND pv_s.SKU LIKE N'%' + @Search + N'%'
          )
      )
      AND (@MinPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) >= @MinPrice)
      AND (@MaxPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) <= @MaxPrice)
      AND EXISTS
      (
          SELECT 1
          FROM dbo.v_VisibleProductColors pc
          JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
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
        p.IsFeatured,
        p.PublicationStatus,
        sales.UnitsSold
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    OUTER APPLY (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    OUTER APPLY (
        SELECT ISNULL(SUM(oi.Quantity), 0) AS UnitsSold
        FROM dbo.OrderItems oi
        INNER JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
        INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
        WHERE pc.ProductId = p.Id
          AND o.Status NOT IN (N'Cancelled', N'Refunded', N'PendingPayment')
    ) sales
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
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand OR CHARINDEX(N',' + UPPER(b.Name) + N',', N',' + UPPER(@Brand) + N',') > 0)
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
              FROM dbo.v_VisibleProductColors pc_s
              JOIN dbo.v_VisibleProductVariants pv_s ON pv_s.ProductColorId = pc_s.Id
              WHERE pc_s.ProductId = p.Id AND pv_s.SKU LIKE N'%' + @Search + N'%'
          )
      )
      AND (@MinPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) >= @MinPrice)
      AND (@MaxPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) <= @MaxPrice)
      AND EXISTS
      (
          SELECT 1
          FROM dbo.v_VisibleProductColors pc
          JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
            AND (@Colors IS NULL OR CHARINDEX(N',' + UPPER(dbo.fn_BaseColorFromHex(pc.ColorHex)) + N',', N',' + UPPER(@Colors) + N',') > 0)
            AND (@Sizes IS NULL OR CHARINDEX(N',' + UPPER(pv.Size) + N',', N',' + UPPER(@Sizes) + N',') > 0)
      )
    ORDER BY 
        CASE WHEN @SortBy = 'top_selling' THEN sales.UnitsSold END DESC,
        CASE WHEN @SortBy = 'price_asc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END ASC,
        CASE WHEN @SortBy = 'price_desc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END DESC,
        CASE WHEN @SortBy = 'newest' THEN p.CreatedAt END DESC,
        CASE WHEN @SortBy = 'rating' THEN review.Rating END DESC,
        CASE WHEN @SortBy = 'popular' OR @SortBy IS NULL THEN review.ReviewCount END DESC,
        p.CreatedAt DESC,
        p.Id ASC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ----------------------------------------------------------------------------
-- 13. Procedure: dbo.sp_GetOrderDetails (Reading Snapshots)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetOrderDetails
    @OrderNumber NVARCHAR(50) = NULL,
    @OrderId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ResolvedId INT;

    IF @OrderId IS NOT NULL
        SET @ResolvedId = @OrderId;
    ELSE IF @OrderNumber IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE OrderNumber = @OrderNumber;

    IF @ResolvedId IS NULL
        THROW 51018, N'Order not found.', 1;

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
        o.ShippingMethod,
        o.ShippingFee,
        o.ShippingRegion,
        o.ShippingAddress,
        o.ShippingBarangay,
        o.ShippingCity,
        o.ShippingProvince,
        o.ShippingPostalCode,
        o.Courier,
        o.TrackingNumber,
        o.DeliveryNotes,
        o.Notes,
        o.CreatedAt,
        o.UpdatedAt
    FROM dbo.Orders o
    WHERE o.Id = @ResolvedId;

    -- Result Set 2: Order Items (Snapshot preference with catalog fallback)
    SELECT
        oi.Id,
        oi.OrderId,
        oi.VariantId,
        oi.Quantity,
        oi.UnitPrice,
        oi.TotalPrice,
        ISNULL(NULLIF(oi.ProductName, N''), p.Name) AS ProductName,
        p.Slug AS ProductSlug,
        p.MainImageUrl,
        ISNULL(NULLIF(oi.ColorName, N''), c.Color) AS Color,
        ISNULL(NULLIF(oi.Size, N''), v.Size) AS Size,
        ISNULL(NULLIF(oi.SKU, N''), v.SKU) AS SKU
    FROM dbo.OrderItems oi
    LEFT JOIN dbo.ProductVariants v ON oi.VariantId = v.Id
    LEFT JOIN dbo.ProductColors c ON v.ProductColorId = c.Id
    LEFT JOIN dbo.Products p ON c.ProductId = p.Id
    WHERE oi.OrderId = @ResolvedId;

    -- Result Set 3: Payments
    SELECT
        py.Id,
        py.OrderId,
        py.PaymentGateway,
        py.GatewayReference,
        py.Amount,
        py.Status,
        py.PaidAt,
        py.CreatedAt
    FROM dbo.Payments py
    WHERE py.OrderId = @ResolvedId;
END;
GO

-- ----------------------------------------------------------------------------
-- 14. Procedure: dbo.sp_GetUserOrderDetails (Reading Snapshots)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetUserOrderDetails
    @UserId INT,
    @OrderId INT = NULL,
    @OrderNumber NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @UserId IS NULL
        THROW 52001, N'User identifier is required.', 1;

    DECLARE @ResolvedId INT;

    IF @OrderId IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE Id = @OrderId AND UserId = @UserId;
    ELSE IF @OrderNumber IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE OrderNumber = @OrderNumber AND UserId = @UserId;

    IF @ResolvedId IS NULL
        THROW 52002, N'Order not found or access denied.', 1;

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
        o.ShippingFee,
        o.TotalAmount,
        o.ShippingMethod,
        o.ShippingRegion,
        o.ShippingAddress,
        o.ShippingBarangay,
        o.ShippingCity,
        o.ShippingProvince,
        o.ShippingPostalCode,
        o.Courier,
        o.TrackingNumber,
        o.DeliveryNotes,
        o.Notes,
        o.CreatedAt,
        o.UpdatedAt,
        ISNULL((SELECT TOP 1 p.PaymentGateway FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'HitPay') AS PaymentMethod,
        ISNULL((SELECT TOP 1 p.Status FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'Pending') AS PaymentStatus,
        (SELECT TOP 1 p.GatewayReference FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS GatewayReference,
        (SELECT TOP 1 p.PaidAt FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS PaidAt
    FROM dbo.Orders o
    WHERE o.Id = @ResolvedId;

    -- Result Set 2: Order Items (Snapshot preference with catalog fallback)
    SELECT
        oi.Id,
        oi.OrderId,
        oi.VariantId,
        oi.Quantity,
        oi.UnitPrice,
        oi.TotalPrice,
        ISNULL(NULLIF(oi.ProductName, N''), p.Name) AS ProductName,
        p.Slug AS ProductSlug,
        p.MainImageUrl,
        ISNULL(NULLIF(oi.ColorName, N''), c.Color) AS Color,
        ISNULL(NULLIF(oi.Size, N''), v.Size) AS Size,
        ISNULL(NULLIF(oi.SKU, N''), v.SKU) AS SKU
    FROM dbo.OrderItems oi
    LEFT JOIN dbo.ProductVariants v ON oi.VariantId = v.Id
    LEFT JOIN dbo.ProductColors c ON v.ProductColorId = c.Id
    LEFT JOIN dbo.Products p ON c.ProductId = p.Id
    WHERE oi.OrderId = @ResolvedId;

    -- Result Set 3: Payments
    SELECT
        py.Id,
        py.OrderId,
        py.PaymentGateway,
        py.GatewayReference,
        py.Amount,
        py.Status,
        py.PaidAt,
        py.CreatedAt
    FROM dbo.Payments py
    WHERE py.OrderId = @ResolvedId;
END;
GO

-- ----------------------------------------------------------------------------
-- 15. Procedure: dbo.sp_AdminSaveProduct (Supporting PublicationStatus)
-- ----------------------------------------------------------------------------
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

    IF NULLIF(LTRIM(RTRIM(@RidingStyle)), N'') IS NULL
    BEGIN
        SELECT @RidingStyle = Name FROM dbo.Categories WHERE Id = @CategoryId;
        IF @RidingStyle IS NULL SET @RidingStyle = N'Standard';
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
            CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice,
            DiscountPercentage, DiscountType, DiscountAmount, DiscountStartDate, DiscountEndDate, DiscountIsActive,
            MainImageUrl, IsFeatured, IsActive, PublicationStatus, CreatedAt, UpdatedAt
        )
        VALUES (
            @CategoryId, @BrandId, @Name, @Slug, @Description, @RidingStyle, @BasePrice,
            ISNULL(@DiscountPercentage, 0), ISNULL(@DiscountType, N'PERCENTAGE'), ISNULL(@DiscountAmount, 0.00),
            @DiscountStartDate, @DiscountEndDate, 1,
            NULLIF(LTRIM(RTRIM(@MainImageUrl)), N''), @IsFeatured, @IsActive, @PublicationStatus,
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
            PublicationStatus = @PublicationStatus,
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;
    END;

    SELECT 
        p.Id, p.CategoryId, p.BrandId, p.Name, p.Slug, p.Description, p.RidingStyle,
        p.BasePrice, p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
        p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive,
        p.MainImageUrl, p.IsFeatured, p.IsActive, p.PublicationStatus,
        b.Name AS BrandName, c.Name AS CategoryName
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    WHERE p.Id = @Id;
END;
GO

-- ----------------------------------------------------------------------------
-- 16. Procedure: dbo.sp_AdminGetProductComplete (Returning PublicationStatus)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminGetProductComplete
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result 1: Product Header Info
    SELECT p.Id, p.CategoryId, p.BrandId, p.Name, p.Slug, p.Description, p.RidingStyle,
           p.BasePrice, p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
           p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive,
           p.MainImageUrl, p.IsFeatured, p.IsActive, p.PublicationStatus,
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

-- ----------------------------------------------------------------------------
-- 17. Procedure: dbo.sp_AdminCatalogProducts (Returning PublicationStatus)
-- ----------------------------------------------------------------------------
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
        p.PublicationStatus,
        p.CreatedAt,
        (
            SELECT COUNT(*) 
            FROM dbo.ProductVariants v 
            JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId 
            WHERE pc.ProductId = p.Id AND v.IsActive = 1
        ) AS VariantCount
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
    ORDER BY p.Id DESC;
END;
GO
