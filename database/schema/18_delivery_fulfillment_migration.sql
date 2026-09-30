-- =====================================================================================
-- 18_delivery_fulfillment_migration.sql
-- Helmet Cartel Ordering and Management System
-- End-to-End Delivery Fulfillment, Courier Dispatch & COD Reconciliation Migration
-- =====================================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Safely add Delivery and Fulfillment Columns to dbo.Orders
IF COL_LENGTH(N'dbo.Orders', N'ShippingMethod') IS NULL
    ALTER TABLE dbo.Orders ADD ShippingMethod NVARCHAR(50) NOT NULL CONSTRAINT DF_Orders_ShippingMethod DEFAULT 'Pickup';
GO

IF COL_LENGTH(N'dbo.Orders', N'ShippingFee') IS NULL
    ALTER TABLE dbo.Orders ADD ShippingFee DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_ShippingFee DEFAULT 0.00;
GO

IF COL_LENGTH(N'dbo.Orders', N'ShippingRegion') IS NULL
    ALTER TABLE dbo.Orders ADD ShippingRegion NVARCHAR(100) NULL;
GO

IF COL_LENGTH(N'dbo.Orders', N'ShippingAddress') IS NULL
    ALTER TABLE dbo.Orders ADD ShippingAddress NVARCHAR(300) NULL;
GO

IF COL_LENGTH(N'dbo.Orders', N'ShippingBarangay') IS NULL
    ALTER TABLE dbo.Orders ADD ShippingBarangay NVARCHAR(100) NULL;
GO

IF COL_LENGTH(N'dbo.Orders', N'ShippingCity') IS NULL
    ALTER TABLE dbo.Orders ADD ShippingCity NVARCHAR(100) NULL;
GO

IF COL_LENGTH(N'dbo.Orders', N'ShippingProvince') IS NULL
    ALTER TABLE dbo.Orders ADD ShippingProvince NVARCHAR(100) NULL;
GO

IF COL_LENGTH(N'dbo.Orders', N'ShippingPostalCode') IS NULL
    ALTER TABLE dbo.Orders ADD ShippingPostalCode NVARCHAR(20) NULL;
GO

IF COL_LENGTH(N'dbo.Orders', N'Courier') IS NULL
    ALTER TABLE dbo.Orders ADD Courier NVARCHAR(50) NULL;
GO

IF COL_LENGTH(N'dbo.Orders', N'TrackingNumber') IS NULL
    ALTER TABLE dbo.Orders ADD TrackingNumber NVARCHAR(100) NULL;
GO

IF COL_LENGTH(N'dbo.Orders', N'DeliveryNotes') IS NULL
    ALTER TABLE dbo.Orders ADD DeliveryNotes NVARCHAR(500) NULL;
GO

-- 2. Update TotalAmount Computed Column to incorporate ShippingFee
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'TotalAmount')
BEGIN
    ALTER TABLE dbo.Orders DROP COLUMN TotalAmount;
END
GO
ALTER TABLE dbo.Orders ADD TotalAmount AS CONVERT(DECIMAL(18,2), Subtotal - DiscountAmount + ShippingFee) PERSISTED;
GO

-- 3. Update Status Constraint on dbo.Orders
DECLARE @DropStatusSql NVARCHAR(MAX) = N'';
SELECT @DropStatusSql = @DropStatusSql + N'ALTER TABLE dbo.Orders DROP CONSTRAINT ' + QUOTENAME(name) + N';'
FROM sys.check_constraints 
WHERE parent_object_id = OBJECT_ID(N'dbo.Orders') AND (definition LIKE N'%Status%' OR name = N'CK_Orders_Status');
IF @DropStatusSql <> N'' EXEC sp_executesql @DropStatusSql;
GO

ALTER TABLE dbo.Orders WITH CHECK ADD CONSTRAINT CK_Orders_Status 
    CHECK (Status IN (N'PendingPayment', N'Processing', N'ReadyForPickup', N'Shipped', N'Delivered', N'Completed', N'Cancelled'));
GO

-- 4. Update Payment Gateway Constraint on dbo.Payments to support CashOnDelivery
DECLARE @DropGatewaySql NVARCHAR(MAX) = N'';
SELECT @DropGatewaySql = @DropGatewaySql + N'ALTER TABLE dbo.Payments DROP CONSTRAINT ' + QUOTENAME(name) + N';'
FROM sys.check_constraints 
WHERE parent_object_id = OBJECT_ID(N'dbo.Payments') AND (definition LIKE N'%PaymentGateway%' OR name = N'CK_Payments_Gateway');
IF @DropGatewaySql <> N'' EXEC sp_executesql @DropGatewaySql;
GO

ALTER TABLE dbo.Payments WITH CHECK ADD CONSTRAINT CK_Payments_Gateway 
    CHECK (PaymentGateway IN (N'HitPay', N'Cash', N'Card_POS', N'CashOnDelivery'));
GO

-- 5. Stored Procedure: sp_CreateOrder (Updated for Delivery, Fees, and Address)
CREATE OR ALTER PROCEDURE dbo.sp_CreateOrder
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
    @ShippingMethod NVARCHAR(50) = 'Pickup',
    @ShippingFee DECIMAL(18,2) = 0.00,
    @ShippingRegion NVARCHAR(100) = NULL,
    @ShippingAddress NVARCHAR(300) = NULL,
    @ShippingBarangay NVARCHAR(100) = NULL,
    @ShippingCity NVARCHAR(100) = NULL,
    @ShippingProvince NVARCHAR(100) = NULL,
    @ShippingPostalCode NVARCHAR(20) = NULL,
    @DeliveryNotes NVARCHAR(500) = NULL,
    @NewOrderId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @ShippingFee IS NULL SET @ShippingFee = 0.00;
    IF @ShippingMethod IS NULL SET @ShippingMethod = 'Pickup';

    IF @Subtotal IS NULL OR @DiscountAmount IS NULL OR @TotalAmount IS NULL
       OR @Subtotal < 0 OR @DiscountAmount < 0 OR @DiscountAmount > @Subtotal
       OR @ShippingFee < 0
       OR @TotalAmount <> CONVERT(DECIMAL(18,2), @Subtotal - @DiscountAmount + @ShippingFee)
        THROW 51012, N'Order amounts are inconsistent.', 1;

    INSERT INTO dbo.Orders (
        OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone,
        OrderSource, Status, Subtotal, DiscountAmount, Notes,
        ShippingMethod, ShippingFee, ShippingRegion, ShippingAddress,
        ShippingBarangay, ShippingCity, ShippingProvince, ShippingPostalCode,
        DeliveryNotes, CreatedAt
    ) VALUES (
        @OrderNumber, @UserId, @CustomerName, @CustomerEmail, @CustomerPhone,
        @OrderSource, @Status, @Subtotal, @DiscountAmount, @Notes,
        @ShippingMethod, @ShippingFee, @ShippingRegion, @ShippingAddress,
        @ShippingBarangay, @ShippingCity, @ShippingProvince, @ShippingPostalCode,
        @DeliveryNotes, SYSUTCDATETIME()
    );

    SET @NewOrderId = SCOPE_IDENTITY();
END;
GO

-- 6. Stored Procedure: sp_GetOrderDetails (Updated for Delivery, Fees, and Tracking)
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

    -- Result Set 2: Order Items
    SELECT
        oi.Id,
        oi.OrderId,
        oi.VariantId,
        oi.Quantity,
        oi.UnitPrice,
        oi.TotalPrice,
        p.Name AS ProductName,
        p.Slug AS ProductSlug,
        p.MainImageUrl,
        c.Color,
        v.Size,
        v.SKU
    FROM dbo.OrderItems oi
    INNER JOIN dbo.ProductVariants v ON oi.VariantId = v.Id
    INNER JOIN dbo.ProductColors c ON v.ProductColorId = c.Id
    INNER JOIN dbo.Products p ON c.ProductId = p.Id
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

-- 7. Stored Procedure: sp_AdminOrders (Updated with Shipping and Courier Details)
CREATE OR ALTER PROCEDURE dbo.sp_AdminOrders
    @Search NVARCHAR(100) = NULL,
    @Status NVARCHAR(50) = NULL,
    @Source NVARCHAR(30) = NULL,
    @Limit INT = 100,
    @OrderDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Limit)
        o.Id,
        o.OrderNumber,
        o.CustomerName,
        o.CustomerEmail,
        o.CustomerPhone,
        o.OrderSource,
        o.Status,
        o.TotalAmount,
        o.CreatedAt,
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
        (SELECT COUNT(*) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id) AS ItemCount,
        (SELECT TOP 1 p.Status FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS PaymentStatus,
        (SELECT TOP 1 p.PaymentGateway FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS PaymentMethod
    FROM dbo.Orders o
    WHERE (@Status IS NULL OR o.Status = @Status)
      AND (@Source IS NULL OR o.OrderSource = @Source)
      AND (@OrderDate IS NULL OR (o.CreatedAt >= @OrderDate AND o.CreatedAt < DATEADD(DAY, 1, @OrderDate)))
      AND (@Search IS NULL OR o.OrderNumber LIKE N'%' + @Search + N'%'
           OR o.CustomerName LIKE N'%' + @Search + N'%'
           OR o.CustomerEmail LIKE N'%' + @Search + N'%'
           OR o.TrackingNumber LIKE N'%' + @Search + N'%'
           OR o.ShippingCity LIKE N'%' + @Search + N'%')
    ORDER BY o.CreatedAt DESC, o.Id DESC;
END;
GO

-- 8. Stored Procedure: sp_AdminUpdateOrderStatus (Dispatch, Tracking & COD Reconciliation)
CREATE OR ALTER PROCEDURE dbo.sp_AdminUpdateOrderStatus
    @OrderId INT,
    @NewStatus NVARCHAR(50),
    @Notes NVARCHAR(500) = NULL,
    @Courier NVARCHAR(50) = NULL,
    @TrackingNumber NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DECLARE @OldStatus NVARCHAR(50), @Source NVARCHAR(30), @ShippingMethod NVARCHAR(50);
    SELECT @OldStatus = Status, @Source = OrderSource, @ShippingMethod = ShippingMethod
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
    WHERE Id = @OrderId;

    IF @OldStatus IS NULL THROW 52001, N'Order not found.', 1;

    -- Valid status transitions
    IF NOT (
        (@OldStatus = N'Processing' AND @NewStatus = N'ReadyForPickup') -- Pickup path
        OR (@OldStatus = N'Processing' AND @NewStatus = N'Shipped')      -- Delivery dispatch path
        OR (@OldStatus = N'ReadyForPickup' AND @NewStatus = N'Completed') -- Pickup collected
        OR (@OldStatus = N'Shipped' AND @NewStatus = N'Delivered')       -- Delivery completed by courier
        OR (@OldStatus = N'Delivered' AND @NewStatus = N'Completed')     -- Finalized
        OR (@OldStatus = N'Shipped' AND @NewStatus = N'Completed')       -- Direct completion
        OR (@OldStatus = N'PendingPayment' AND @NewStatus = N'Cancelled')
        OR (@OldStatus = N'Processing' AND @NewStatus = N'Cancelled')
    )
        THROW 52002, N'Invalid order status transition.', 1;

    -- Ensure online HitPay payments are completed before readying for pickup or dispatching
    IF (@NewStatus IN (N'ReadyForPickup', N'Shipped')) AND @Source = N'ONLINE'
       AND EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND PaymentGateway = N'HitPay')
       AND NOT EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND Status = N'Completed')
        THROW 52003, N'Online HitPay payment is not complete.', 1;

    -- Update Order Header
    UPDATE dbo.Orders
    SET Status = @NewStatus,
        Notes = COALESCE(@Notes, Notes),
        Courier = COALESCE(@Courier, Courier),
        TrackingNumber = COALESCE(@TrackingNumber, TrackingNumber),
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @OrderId;

    -- Reconcile Cash or COD payments when marked Delivered or Completed
    IF @NewStatus IN (N'Completed', N'Delivered')
    BEGIN
        UPDATE dbo.Payments
        SET Status = N'Completed',
            PaidAt = SYSUTCDATETIME()
        WHERE OrderId = @OrderId
          AND PaymentGateway IN (N'Cash', N'CashOnDelivery')
          AND Status = N'Pending';
    END

    -- If cancelled from Processing, restore inventory
    IF @NewStatus = N'Cancelled' AND @OldStatus = N'Processing'
    BEGIN
        UPDATE inv
        SET inv.CurrentStock = inv.CurrentStock + oi.Quantity,
            inv.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Inventories inv
        INNER JOIN dbo.OrderItems oi ON inv.VariantId = oi.VariantId
        WHERE oi.OrderId = @OrderId;
    END

    COMMIT TRANSACTION;

    SELECT @OrderId AS Id, @NewStatus AS Status, @Courier AS Courier, @TrackingNumber AS TrackingNumber;
END;
GO
