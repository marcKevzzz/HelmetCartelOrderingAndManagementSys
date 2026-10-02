-- ============================================================================
-- Migration 26: Recompile Stored Procedures with SET QUOTED_IDENTIFIER ON
-- Fixes runtime error: "UPDATE failed because the following SET options have incorrect settings: 'QUOTED_IDENTIFIER'"
-- ============================================================================

USE [HelmetCartelDB];
GO

-- 1. dbo.sp_ReserveStockAtomic
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ReserveStockAtomic
    @VariantId INT,
    @Quantity INT,
    @OrderNumber NVARCHAR(50),
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentStock INT, @ReservedStock INT;

    SELECT @CurrentStock = CurrentStock, @ReservedStock = ReservedStock
    FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
    WHERE VariantId = @VariantId;

    IF @CurrentStock IS NULL
    BEGIN
        SET @Success = 0;
        SET @ErrorMessage = N'Inventory record not found for variant.';
        RETURN;
    END;

    IF @CurrentStock - @ReservedStock < @Quantity
    BEGIN
        SET @Success = 0;
        SET @ErrorMessage = CONCAT(N'Insufficient available stock. Available: ', @CurrentStock - @ReservedStock, N', Requested: ', @Quantity);
        RETURN;
    END;

    UPDATE dbo.Inventories
    SET ReservedStock = ReservedStock + @Quantity,
        UpdatedAt = SYSUTCDATETIME()
    WHERE VariantId = @VariantId;

    SET @Success = 1;
    SET @ErrorMessage = NULL;
END;
GO

-- 2. dbo.sp_CustomerCancelOrder
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CustomerCancelOrder
    @OrderId INT,
    @UserId INT = NULL,
    @UserEmail NVARCHAR(256) = NULL,
    @Reason NVARCHAR(255) = N'Customer requested cancellation',
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStatus NVARCHAR(50), @OrderUserId INT, @OrderEmail NVARCHAR(256), @OrderNumber NVARCHAR(50);

        SELECT @CurrentStatus = Status,
               @OrderUserId = UserId,
               @OrderEmail = CustomerEmail,
               @OrderNumber = OrderNumber
        FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @OrderId;

        IF @CurrentStatus IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Order not found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @UserId IS NOT NULL AND @OrderUserId IS NOT NULL AND @OrderUserId <> @UserId
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'You are not authorized to cancel this order.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @CurrentStatus NOT IN (N'PendingPayment', N'Processing')
        BEGIN
            SET @Success = 0;
            IF @CurrentStatus IN (N'Shipped', N'ReadyForPickup')
                SET @ErrorMessage = N'Order is already in transit or ready for pickup. Please contact support or request a return upon delivery.';
            ELSE IF @CurrentStatus IN (N'Delivered', N'Completed')
                SET @ErrorMessage = N'Order has already been delivered/collected. Please use the Return Item feature.';
            ELSE IF @CurrentStatus = N'Cancelled'
                SET @ErrorMessage = N'Order is already cancelled.';
            ELSE
                SET @ErrorMessage = CONCAT(N'Orders with status ', @CurrentStatus, N' cannot be cancelled.');
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        UPDATE dbo.Orders
        SET Status = N'Cancelled',
            Notes = CONCAT(ISNULL(Notes + N' | ', N''), N'Cancelled by customer: ', @Reason),
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @OrderId;

        UPDATE dbo.Payments
        SET Status = N'Cancelled'
        WHERE OrderId = @OrderId AND Status = N'Pending';

        UPDATE inv
        SET inv.ReservedStock = CASE WHEN inv.ReservedStock >= oi.Quantity THEN inv.ReservedStock - oi.Quantity ELSE 0 END,
            inv.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Inventories inv
        INNER JOIN dbo.OrderItems oi ON inv.VariantId = oi.VariantId
        WHERE oi.OrderId = @OrderId;

        INSERT INTO dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
        SELECT oi.VariantId,
               @UserId,
               N'ORDER_CANCELLED',
               inv.CurrentStock,
               oi.Quantity,
               @OrderNumber,
               CONCAT(N'Reservation released on cancellation: ', @Reason)
        FROM dbo.OrderItems oi
        INNER JOIN dbo.Inventories inv ON oi.VariantId = inv.VariantId
        WHERE oi.OrderId = @OrderId;

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

-- 3. dbo.sp_AdminUpdateOrderStatus
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminUpdateOrderStatus
    @OrderId INT,
    @NewStatus NVARCHAR(50),
    @Notes NVARCHAR(500) = NULL,
    @Courier NVARCHAR(100) = NULL,
    @TrackingNumber NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DECLARE @OldStatus NVARCHAR(50), @Source NVARCHAR(30), @ShippingMethod NVARCHAR(50);

    SELECT @OldStatus = Status,
           @Source = OrderSource,
           @ShippingMethod = ShippingMethod
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
    WHERE Id = @OrderId;

    IF @OldStatus IS NULL
        THROW 52001, N'Order not found.', 1;

    IF NOT (
        (@OldStatus = N'Processing' AND @NewStatus = N'ReadyForPickup') OR
        (@OldStatus = N'Processing' AND @NewStatus = N'Shipped') OR
        (@OldStatus = N'ReadyForPickup' AND @NewStatus = N'Completed') OR
        (@OldStatus = N'Shipped' AND @NewStatus = N'Delivered') OR
        (@OldStatus = N'Delivered' AND @NewStatus = N'Completed') OR
        (@OldStatus = N'Shipped' AND @NewStatus = N'Completed') OR
        (@OldStatus = N'PendingPayment' AND @NewStatus = N'Cancelled') OR
        (@OldStatus = N'Processing' AND @NewStatus = N'Cancelled')
    )
        THROW 52002, N'Invalid order status transition.', 1;

    IF (@NewStatus IN (N'ReadyForPickup', N'Shipped')) AND @Source = N'ONLINE'
       AND EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND PaymentGateway = N'HitPay')
       AND NOT EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND Status = N'Completed')
        THROW 52003, N'Online HitPay payment is not complete.', 1;

    UPDATE dbo.Orders
    SET Status = @NewStatus,
        Notes = COALESCE(@Notes, Notes),
        Courier = COALESCE(@Courier, Courier),
        TrackingNumber = COALESCE(@TrackingNumber, TrackingNumber),
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @OrderId;

    IF @NewStatus IN (N'Completed', N'Delivered')
    BEGIN
        UPDATE dbo.Payments
        SET Status = N'Completed',
            PaidAt = SYSUTCDATETIME()
        WHERE OrderId = @OrderId
          AND PaymentGateway IN (N'Cash', N'CashOnDelivery')
          AND Status = N'Pending';
    END;

    IF (@OldStatus = N'Processing' AND @NewStatus = N'Shipped') OR (@OldStatus = N'ReadyForPickup' AND @NewStatus = N'Completed')
    BEGIN
        UPDATE inv
        SET inv.CurrentStock = CASE WHEN inv.CurrentStock >= oi.Quantity THEN inv.CurrentStock - oi.Quantity ELSE 0 END,
            inv.ReservedStock = CASE WHEN inv.ReservedStock >= oi.Quantity THEN inv.ReservedStock - oi.Quantity ELSE 0 END,
            inv.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Inventories inv
        INNER JOIN dbo.OrderItems oi ON inv.VariantId = oi.VariantId
        WHERE oi.OrderId = @OrderId;
    END;

    IF @NewStatus = N'Cancelled'
    BEGIN
        UPDATE inv
        SET inv.ReservedStock = CASE WHEN inv.ReservedStock >= oi.Quantity THEN inv.ReservedStock - oi.Quantity ELSE 0 END,
            inv.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Inventories inv
        INNER JOIN dbo.OrderItems oi ON inv.VariantId = oi.VariantId
        WHERE oi.OrderId = @OrderId;
    END;

    COMMIT TRANSACTION;

    SELECT @OrderId AS Id, @NewStatus AS Status, @Courier AS Courier, @TrackingNumber AS TrackingNumber;
END;
GO

-- 4. dbo.sp_CreateReturnRequest
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

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

        IF EXISTS (SELECT 1 FROM dbo.ReturnRequests WHERE OrderItemId = @OrderItemId AND Status NOT IN (N'Rejected', N'Cancelled'))
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'An active return or exchange request already exists for this item.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        DECLARE @DatePrefix NVARCHAR(12) = N'RMA-' + FORMAT(SYSUTCDATETIME(), N'yyyyMMdd') + N'-';
        DECLARE @NextSeq INT = 1;

        SELECT @NextSeq = ISNULL(MAX(CAST(RIGHT(RmaNumber, 4) AS INT)), 0) + 1
        FROM dbo.ReturnRequests
        WHERE RmaNumber LIKE @DatePrefix + N'%';

        SET @NewRmaNumber = @DatePrefix + RIGHT(N'0000' + CAST(@NextSeq AS NVARCHAR(10)), 4);

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

        SET @NewRmaId = SCOPE_IDENTITY();
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

-- 5. dbo.sp_GetUserOrders
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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
