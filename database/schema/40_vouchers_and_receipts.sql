-- Online vouchers and persistent receipt data. Requires migrations through 39.
-- Run in the intended database; safe to rerun without replacing existing data.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'dbo.Vouchers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Vouchers (
        Id INT IDENTITY PRIMARY KEY,
        Code NVARCHAR(30) NOT NULL UNIQUE,
        DiscountType NVARCHAR(20) NOT NULL,
        DiscountValue DECIMAL(18,2) NOT NULL,
        MinimumSpend DECIMAL(18,2) NOT NULL DEFAULT 0,
        ExpiresAt DATETIME2 NULL,
        UsageLimit INT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NULL,
        CONSTRAINT CK_Vouchers_Discount CHECK (DiscountValue > 0 AND
            (DiscountType = N'FIXED_AMOUNT' OR (DiscountType = N'PERCENTAGE' AND DiscountValue <= 100))),
        CONSTRAINT CK_Vouchers_Limits CHECK (MinimumSpend >= 0 AND (UsageLimit IS NULL OR UsageLimit > 0)),
        CONSTRAINT CK_Vouchers_Code CHECK (LEN(Code) BETWEEN 3 AND 30 AND
            Code COLLATE Latin1_General_100_BIN2 NOT LIKE N'%[^A-Z0-9-]%')
    );
END;
IF COL_LENGTH(N'dbo.Orders', N'VoucherCode') IS NULL
    ALTER TABLE dbo.Orders ADD VoucherCode NVARCHAR(30) NULL;
IF COL_LENGTH(N'dbo.Orders', N'CashTendered') IS NULL
    ALTER TABLE dbo.Orders ADD CashTendered DECIMAL(18,2) NULL;
IF OBJECT_ID(N'dbo.VoucherRedemptions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VoucherRedemptions (
        Id INT IDENTITY PRIMARY KEY,
        VoucherId INT NOT NULL REFERENCES dbo.Vouchers(Id),
        OrderId INT NOT NULL UNIQUE REFERENCES dbo.Orders(Id),
        DiscountAmount DECIMAL(18,2) NOT NULL CHECK (DiscountAmount >= 0),
        ReleasedAt DATETIME2 NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NULL
    );
    CREATE INDEX IX_VoucherRedemptions_Usage ON dbo.VoucherRedemptions(VoucherId, ReleasedAt);
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AdminVouchers
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.*, (SELECT COUNT(*) FROM dbo.VoucherRedemptions r
        WHERE r.VoucherId = v.Id AND r.ReleasedAt IS NULL) AS UsageCount,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM dbo.VoucherRedemptions r WHERE r.VoucherId = v.Id)
            THEN 1 ELSE 0 END AS BIT) AS HasRedemptions
    FROM dbo.Vouchers v ORDER BY v.CreatedAt DESC, v.Id DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveVoucher
    @Id INT = 0, @Code NVARCHAR(30), @DiscountType NVARCHAR(20),
    @DiscountValue DECIMAL(18,2), @MinimumSpend DECIMAL(18,2) = 0,
    @ExpiresAt DATETIME2 = NULL, @UsageLimit INT = NULL, @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Code = UPPER(LTRIM(RTRIM(@Code)));
    IF @Code IS NULL OR LEN(@Code) NOT BETWEEN 3 AND 30 OR
       @Code COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Z0-9-]%'
        THROW 54001, N'Use 3-30 letters, numbers or hyphens for the voucher code.', 1;
    IF @DiscountType IS NULL OR @DiscountType NOT IN (N'PERCENTAGE', N'FIXED_AMOUNT') OR
       @DiscountValue IS NULL OR @DiscountValue <= 0 OR
       (@DiscountType = N'PERCENTAGE' AND @DiscountValue > 100) OR
       @MinimumSpend IS NULL OR @MinimumSpend < 0 OR @UsageLimit <= 0
        THROW 54002, N'Check the discount, minimum spend and usage limit.', 1;
    -- Past dates are allowed only when retaining an existing expiry (e.g. disabling an expired code).
    IF @ExpiresAt <= SYSUTCDATETIME() AND NOT EXISTS
        (SELECT 1 FROM dbo.Vouchers WHERE Id = @Id AND ExpiresAt = @ExpiresAt)
        THROW 54003, N'Choose a future expiry date.', 1;
    BEGIN TRANSACTION;
    IF @Id <> 0 AND NOT EXISTS (SELECT 1 FROM dbo.Vouchers WITH (UPDLOCK, ROWLOCK) WHERE Id = @Id)
        THROW 54004, N'Voucher not found.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Vouchers WHERE Code = @Code AND Id <> @Id)
        THROW 54005, N'This voucher code already exists.', 1;
    IF EXISTS (SELECT 1 FROM dbo.VoucherRedemptions WHERE VoucherId = @Id) AND
       EXISTS (SELECT 1 FROM dbo.Vouchers WHERE Id = @Id AND Code <> @Code)
        THROW 54006, N'A redeemed voucher code cannot be renamed.', 1;
    IF @UsageLimit < (SELECT COUNT(*) FROM dbo.VoucherRedemptions WHERE VoucherId = @Id AND ReleasedAt IS NULL)
        THROW 54007, N'Usage limit cannot be lower than current usage.', 1;
    IF @Id = 0
    BEGIN
        INSERT dbo.Vouchers(Code, DiscountType, DiscountValue, MinimumSpend, ExpiresAt, UsageLimit, IsActive)
        VALUES (@Code, @DiscountType, @DiscountValue, @MinimumSpend, @ExpiresAt, @UsageLimit, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
        UPDATE dbo.Vouchers SET Code = @Code, DiscountType = @DiscountType, DiscountValue = @DiscountValue,
            MinimumSpend = @MinimumSpend, ExpiresAt = @ExpiresAt, UsageLimit = @UsageLimit,
            IsActive = @IsActive, UpdatedAt = SYSUTCDATETIME() WHERE Id = @Id;
    COMMIT;
    SELECT @Id AS Id;
END;
GO
-- Internal shared eligibility calculation. Redemption holds the voucher lock until the caller commits.
CREATE OR ALTER PROCEDURE dbo.sp_CalculateVoucher
    @Code NVARCHAR(30), @Subtotal DECIMAL(18,2), @ForRedemption BIT = 0,
    @VoucherId INT OUTPUT, @DiscountAmount DECIMAL(18,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @ForRedemption = 1 AND @@TRANCOUNT = 0
        THROW 54008, N'Voucher redemption requires an order transaction.', 1;
    SET @VoucherId = NULL;
    SET @Code = UPPER(LTRIM(RTRIM(@Code)));
    DECLARE @Type NVARCHAR(20), @Value DECIMAL(18,2), @Minimum DECIMAL(18,2),
        @Expiry DATETIME2, @Limit INT, @Active BIT;
    IF @ForRedemption = 1
        SELECT @VoucherId = Id, @Type = DiscountType, @Value = DiscountValue,
            @Minimum = MinimumSpend, @Expiry = ExpiresAt, @Limit = UsageLimit, @Active = IsActive
        FROM dbo.Vouchers WITH (UPDLOCK, ROWLOCK) WHERE Code = @Code;
    ELSE
        SELECT @VoucherId = Id, @Type = DiscountType, @Value = DiscountValue,
            @Minimum = MinimumSpend, @Expiry = ExpiresAt, @Limit = UsageLimit, @Active = IsActive
        FROM dbo.Vouchers WHERE Code = @Code;
    IF @VoucherId IS NULL THROW 54009, N'Voucher code not found.', 1;
    IF @Active = 0 THROW 54010, N'This voucher is inactive.', 1;
    IF @Expiry <= SYSUTCDATETIME() THROW 54011, N'This voucher has expired.', 1;
    IF @Subtotal IS NULL OR @Subtotal <= 0 OR @Subtotal < @Minimum
        THROW 54012, N'Your merchandise subtotal does not meet the voucher minimum spend.', 1;
    IF @Limit IS NOT NULL AND @Limit <=
        (SELECT COUNT(*) FROM dbo.VoucherRedemptions WHERE VoucherId = @VoucherId AND ReleasedAt IS NULL)
        THROW 54013, N'This voucher has reached its usage limit.', 1;
    SET @DiscountAmount = ROUND(CASE WHEN @Type = N'PERCENTAGE' THEN @Subtotal * @Value / 100 ELSE @Value END, 2);
    IF @DiscountAmount > @Subtotal SET @DiscountAmount = @Subtotal;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_PreviewVoucher
    @Code NVARCHAR(30), @Items dbo.SaleLineInput READONLY
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM @Items) OR EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0) OR
       EXISTS (SELECT VariantId FROM @Items GROUP BY VariantId HAVING COUNT(*) > 1)
        THROW 54014, N'Choose valid, distinct merchandise items.', 1;
    DECLARE @Subtotal DECIMAL(18,2), @Count INT;
    SELECT @Subtotal = SUM(CONVERT(DECIMAL(18,2), dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
        p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive)) * l.Quantity),
        @Count = COUNT(*)
    FROM @Items l JOIN dbo.v_VisibleProductVariants v ON v.Id = l.VariantId
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId;
    IF @Count <> (SELECT COUNT(*) FROM @Items) THROW 54014, N'An item is no longer available.', 1;
    DECLARE @Id INT, @Discount DECIMAL(18,2);
    EXEC dbo.sp_CalculateVoucher @Code, @Subtotal, 0, @Id OUTPUT, @Discount OUTPUT;
    SELECT UPPER(LTRIM(RTRIM(@Code))) AS Code, @Subtotal AS Subtotal,
        @Discount AS DiscountAmount, @Subtotal - @Discount AS DiscountedSubtotal;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_ApplyOrderVoucher
    @OrderId INT, @Code NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT = 0 THROW 54008, N'Voucher redemption requires an order transaction.', 1;
    DECLARE @Subtotal DECIMAL(18,2), @Id INT, @Discount DECIMAL(18,2);
    IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @OrderId AND OrderSource = N'ONLINE' AND Status IN (N'PendingPayment', N'Processing'))
        THROW 54015, N'This order cannot accept a voucher.', 1;
    IF EXISTS (SELECT 1 FROM dbo.VoucherRedemptions WHERE OrderId = @OrderId)
        THROW 54016, N'This order already has a voucher.', 1;
    SELECT @Subtotal = SUM(TotalPrice) FROM dbo.OrderItems WHERE OrderId = @OrderId;
    EXEC dbo.sp_CalculateVoucher @Code, @Subtotal, 1, @Id OUTPUT, @Discount OUTPUT;
    INSERT dbo.VoucherRedemptions(VoucherId, OrderId, DiscountAmount) VALUES (@Id, @OrderId, @Discount);
    UPDATE dbo.Orders SET VoucherCode = UPPER(LTRIM(RTRIM(@Code))), DiscountAmount = @Discount,
        UpdatedAt = SYSUTCDATETIME() WHERE Id = @OrderId;
    SELECT VoucherCode AS Code, Subtotal, DiscountAmount, Subtotal - DiscountAmount AS DiscountedSubtotal
    FROM dbo.Orders WHERE Id = @OrderId;
END;
GO
-- Releases usage in the same transaction for every cancellation path, exactly once.
CREATE OR ALTER TRIGGER dbo.tr_Orders_ReleaseVoucher ON dbo.Orders AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE r SET ReleasedAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME()
    FROM dbo.VoucherRedemptions r JOIN inserted i ON i.Id = r.OrderId
    JOIN deleted d ON d.Id = i.Id
    WHERE i.Status = N'Cancelled' AND d.Status <> N'Cancelled' AND r.ReleasedAt IS NULL;
END;
GO

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
        o.VoucherCode,
        o.CashTendered,
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
    WHERE py.OrderId = @ResolvedId ORDER BY py.Id DESC;
END;
GO

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
        o.VoucherCode,
        o.CashTendered,
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
    WHERE py.OrderId = @ResolvedId ORDER BY py.Id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetUserOrders
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserEmail NVARCHAR(256);
    SELECT @UserEmail = Email FROM dbo.Users WHERE Id = @UserId;

    SELECT
        o.Id,
        o.OrderNumber,
        o.CustomerName,
        o.CustomerEmail,
        o.CustomerPhone,
        o.Subtotal,
        o.DiscountAmount,
        o.VoucherCode,
        o.ShippingFee,
        o.TotalAmount,
        o.Status AS OrderStatus,
        o.OrderSource,
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
        ISNULL((SELECT TOP 1 p.PaymentGateway FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'HitPay') AS PaymentGateway,
        ISNULL((SELECT TOP 1 p.Status FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'Pending') AS PaymentStatus,
        (SELECT TOP 1 p.GatewayReference FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS GatewayReference,
        (SELECT COUNT(*) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id) AS ItemCount,
        (SELECT STRING_AGG(p.MainImageUrl, ';')
         FROM (
             SELECT TOP 3 p.MainImageUrl
             FROM dbo.OrderItems oi
             JOIN dbo.ProductVariants pv ON oi.VariantId = pv.Id
             JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
             JOIN dbo.Products p ON pc.ProductId = p.Id
             WHERE oi.OrderId = o.Id
             ORDER BY oi.Id ASC
         ) p) AS PreviewImages
    FROM dbo.Orders o
    WHERE o.UserId = @UserId OR (o.UserId IS NULL AND o.CustomerEmail = @UserEmail)
    ORDER BY o.CreatedAt DESC;
END;
GO

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
    UPDATE dbo.Orders SET CashTendered = @CashTendered WHERE Id = @OrderId;

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

CREATE OR ALTER PROCEDURE dbo.sp_GetVariantPriceInfo
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
        CONVERT(DECIMAL(18,2), dbo.fn_CalculateEffectivePrice(p.BasePrice, pv.PriceAdjustment, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive)) AS UnitPrice
    FROM dbo.v_VisibleProductVariants pv
    INNER JOIN dbo.v_VisibleProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.v_VisibleProducts p ON pc.ProductId = p.Id
    WHERE pv.Id = @VariantId AND pv.IsActive = 1 AND p.IsActive = 1;
END;
GO
