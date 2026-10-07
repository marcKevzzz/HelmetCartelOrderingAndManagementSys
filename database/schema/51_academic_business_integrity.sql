-- Academic business-process corrections. Payment gateway and simulation handlers are unchanged.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RefreshOrderStockAlerts @OrderId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    UPDATE a SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
    FROM dbo.RestockAlerts a JOIN dbo.Inventories i ON i.Id = a.InventoryId
    WHERE a.IsDismissed = 0 AND i.IsLowStock = 0
      AND EXISTS (SELECT 1 FROM dbo.OrderItems oi WHERE oi.OrderId = @OrderId AND oi.VariantId = i.VariantId);
    INSERT dbo.RestockAlerts(InventoryId, Severity)
    SELECT i.Id, CASE WHEN i.CurrentStock - i.ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
    FROM dbo.Inventories i WITH (UPDLOCK, ROWLOCK)
    WHERE i.IsLowStock = 1
      AND EXISTS (SELECT 1 FROM dbo.OrderItems oi WHERE oi.OrderId = @OrderId AND oi.VariantId = i.VariantId)
      AND NOT EXISTS (SELECT 1 FROM dbo.RestockAlerts a WITH (UPDLOCK, HOLDLOCK) WHERE a.InventoryId = i.Id AND a.IsDismissed = 0);
    COMMIT TRANSACTION;
END;
GO

-- Call only while the owning order is locked inside a transaction.
CREATE OR ALTER PROCEDURE dbo.sp_ChangeOrderInventory
    @OrderId INT, @Action NVARCHAR(20), @ActorId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT = 0 THROW 55001, N'Order inventory changes require a transaction.', 1;
    IF @Action NOT IN (N'COMMIT', N'RELEASE', N'RESTORE') THROW 55002, N'Invalid inventory action.', 1;
    DECLARE @OrderNumber NVARCHAR(50) = (SELECT OrderNumber FROM dbo.Orders WHERE Id = @OrderId);
    DECLARE @VariantId INT, @Quantity INT, @OldStock INT, @Reserved INT;
    DECLARE lines CURSOR LOCAL FAST_FORWARD FOR
        SELECT VariantId, SUM(Quantity) FROM dbo.OrderItems WHERE OrderId = @OrderId GROUP BY VariantId ORDER BY VariantId;
    OPEN lines;
    FETCH NEXT FROM lines INTO @VariantId, @Quantity;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @OldStock = NULL;
        SELECT @OldStock = CurrentStock, @Reserved = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) WHERE VariantId = @VariantId;
        IF @OldStock IS NULL THROW 55003, N'Order inventory is missing.', 1;
        IF @Action IN (N'COMMIT', N'RELEASE') AND @Reserved < @Quantity
            THROW 55004, N'Order reservation is inconsistent; reconcile before processing.', 1;
        IF @Action = N'COMMIT'
        BEGIN
            UPDATE dbo.Inventories WITH (UPDLOCK, ROWLOCK)
            SET CurrentStock = CurrentStock - @Quantity, ReservedStock = ReservedStock - @Quantity, UpdatedAt = SYSUTCDATETIME()
            WHERE VariantId = @VariantId AND CurrentStock >= @Quantity AND ReservedStock >= @Quantity;
            IF @@ROWCOUNT <> 1 THROW 55005, N'Insufficient stock for fulfillment.', 1;
            INSERT dbo.StockAuditLogs(VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
            VALUES(@VariantId, @ActorId, N'ONLINE_SALE', @OldStock, -@Quantity, @OrderNumber, N'Cash/COD reservation converted to physical sale.');
        END;
        IF @Action = N'RELEASE'
            UPDATE dbo.Inventories WITH (UPDLOCK, ROWLOCK)
            SET ReservedStock = ReservedStock - @Quantity, UpdatedAt = SYSUTCDATETIME() WHERE VariantId = @VariantId;
        IF @Action = N'RESTORE'
        BEGIN
            -- A paid order has already consumed its reservation. Never release another order's units.
            UPDATE dbo.Inventories WITH (UPDLOCK, ROWLOCK)
            SET CurrentStock = CurrentStock + @Quantity, UpdatedAt = SYSUTCDATETIME() WHERE VariantId = @VariantId;
            INSERT dbo.StockAuditLogs(VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
            VALUES(@VariantId, @ActorId, N'RETURN', @OldStock, @Quantity, @OrderNumber, N'Cancelled order returned to stock; refund requires separate confirmation.');
        END;
        FETCH NEXT FROM lines INTO @VariantId, @Quantity;
    END;
    CLOSE lines;
    DEALLOCATE lines;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminUpdateOrderStatus
    @OrderId INT, @NewStatus NVARCHAR(50), @Notes NVARCHAR(500) = NULL,
    @Courier NVARCHAR(100) = NULL, @TrackingNumber NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @OldStatus NVARCHAR(50), @Method NVARCHAR(50), @Number NVARCHAR(50), @UserId INT, @Committed BIT;
        SELECT @OldStatus = Status, @Method = ShippingMethod, @Number = OrderNumber, @UserId = UserId
        FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE Id = @OrderId;
        IF @OldStatus IS NULL THROW 52001, N'Order not found.', 1;
        IF NOT (
            (@OldStatus = N'Processing' AND @NewStatus = N'ReadyForPickup' AND @Method = N'Pickup') OR
            (@OldStatus = N'Processing' AND @NewStatus = N'Shipped' AND @Method = N'Delivery') OR
            (@OldStatus = N'ReadyForPickup' AND @NewStatus = N'Completed' AND @Method = N'Pickup') OR
            (@OldStatus = N'Shipped' AND @NewStatus IN (N'Delivered', N'Completed') AND @Method = N'Delivery') OR
            (@OldStatus = N'Delivered' AND @NewStatus = N'Completed' AND @Method = N'Delivery') OR
            (@OldStatus IN (N'PendingPayment', N'Processing') AND @NewStatus = N'Cancelled'))
            THROW 52002, N'Invalid transition for this fulfillment method.', 1;
        IF @NewStatus = N'Shipped' AND (NULLIF(LTRIM(RTRIM(@Courier)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@TrackingNumber)), N'') IS NULL)
            THROW 55006, N'Courier and tracking number are required.', 1;
        IF @NewStatus <> N'Cancelled' AND NOT EXISTS (
            SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND
            (Status = N'Completed' OR (Status = N'Pending' AND PaymentGateway IN (N'Cash', N'CashOnDelivery'))))
            THROW 52003, N'Order requires a valid payment record.', 1;
        SET @Committed = CASE WHEN EXISTS (SELECT 1 FROM dbo.StockAuditLogs WHERE ReferenceNumber = @Number AND ChangeType = N'ONLINE_SALE' AND QuantityChanged < 0) THEN 1 ELSE 0 END;
        IF @NewStatus IN (N'Shipped', N'Completed') AND @Committed = 0
            EXEC dbo.sp_ChangeOrderInventory @OrderId, N'COMMIT', @UserId;
        IF @NewStatus = N'Cancelled'
        BEGIN
            IF @Committed = 1 EXEC dbo.sp_ChangeOrderInventory @OrderId, N'RESTORE', @UserId;
            ELSE EXEC dbo.sp_ChangeOrderInventory @OrderId, N'RELEASE', @UserId;
            UPDATE dbo.Payments SET Status = N'Cancelled' WHERE OrderId = @OrderId AND Status IN (N'Pending', N'Failed');
            IF EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND Status = N'Completed')
                SET @Notes = LEFT(CONCAT(@Notes, N' | Refund pending manual confirmation.'), 500);
        END;
        IF @NewStatus IN (N'Completed', N'Delivered')
            UPDATE dbo.Payments SET Status = N'Completed', PaidAt = SYSUTCDATETIME()
            WHERE OrderId = @OrderId AND Status = N'Pending' AND PaymentGateway IN (N'Cash', N'CashOnDelivery');
        UPDATE dbo.Orders SET Status = @NewStatus, Notes = COALESCE(@Notes, Notes),
            Courier = COALESCE(@Courier, Courier), TrackingNumber = COALESCE(@TrackingNumber, TrackingNumber), UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @OrderId;
        EXEC dbo.sp_RefreshOrderStockAlerts @OrderId;
        COMMIT TRANSACTION;
        SELECT @OrderId AS Id, @NewStatus AS Status, @Courier AS Courier, @TrackingNumber AS TrackingNumber;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CustomerCancelOrder
    @OrderId INT, @UserId INT = NULL, @UserEmail NVARCHAR(256) = NULL,
    @Reason NVARCHAR(255) = N'Customer requested cancellation', @Success BIT OUTPUT, @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @OwnerId INT, @Status NVARCHAR(50), @Number NVARCHAR(50), @Committed BIT;
        SELECT @OwnerId = UserId, @Status = Status, @Number = OrderNumber
        FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE Id = @OrderId;
        IF @UserId IS NULL OR @OwnerId IS NULL OR @OwnerId <> @UserId
            THROW 52302, N'You are not authorized to cancel this order.', 1;
        IF @Status NOT IN (N'PendingPayment', N'Processing') THROW 52303, N'This order can no longer be cancelled.', 1;
        SET @Committed = CASE WHEN EXISTS (SELECT 1 FROM dbo.StockAuditLogs WHERE ReferenceNumber = @Number AND ChangeType = N'ONLINE_SALE' AND QuantityChanged < 0) THEN 1 ELSE 0 END;
        IF @Committed = 1 EXEC dbo.sp_ChangeOrderInventory @OrderId, N'RESTORE', @UserId;
        ELSE EXEC dbo.sp_ChangeOrderInventory @OrderId, N'RELEASE', @UserId;
        UPDATE dbo.Orders SET Status = N'Cancelled',
            Notes = LEFT(CONCAT(Notes, N' | Cancelled by customer: ', @Reason,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND Status = N'Completed') THEN N' | Refund pending manual confirmation.' ELSE N'' END), 500),
            UpdatedAt = SYSUTCDATETIME() WHERE Id = @OrderId;
        -- Keep completed payment history intact. Cancellation alone does not prove a refund.
        UPDATE dbo.Payments SET Status = N'Cancelled' WHERE OrderId = @OrderId AND Status IN (N'Pending', N'Failed');
        EXEC dbo.sp_RefreshOrderStockAlerts @OrderId;
        COMMIT TRANSACTION;
        SET @Success = 1; SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0; SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO
