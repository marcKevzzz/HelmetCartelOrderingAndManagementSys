-- ============================================================================
-- Migration 31: Stock reservation lifecycle and storefront availability fix
--
-- Reservations are held when an online order is created. They are converted
-- into a sale exactly once when HitPay confirms payment or when a cash/COD
-- order is fulfilled. Available stock is always CurrentStock - ReservedStock.
-- ============================================================================
USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Customer cancellation records a cancelled pending payment.
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Payments_Status')
    ALTER TABLE dbo.Payments DROP CONSTRAINT CK_Payments_Status;
GO

ALTER TABLE dbo.Payments ADD CONSTRAINT CK_Payments_Status
    CHECK (Status IN (N'Pending', N'Completed', N'Failed', N'Refunded', N'Cancelled'));
GO

-- HitPay confirmation converts the existing reservation into a completed sale.
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

        IF @OldStock IS NULL OR @OldStock - @OldReservedStock < @Quantity
            THROW 52207, N'Paid order has insufficient stock; manual resolution required.', 1;

        INSERT @Lines (VariantId, Quantity, OldStock, OldReservedStock)
        VALUES (@VariantId, @Quantity, @OldStock, @OldReservedStock);

        SET @OldStock = NULL;
        SET @OldReservedStock = NULL;
        FETCH NEXT FROM line_cursor INTO @VariantId, @Quantity;
    END;

    CLOSE line_cursor;
    DEALLOCATE line_cursor;

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

    INSERT dbo.RestockAlerts (InventoryId, Severity)
    SELECT i.Id,
           CASE WHEN i.CurrentStock - i.ReservedStock = 0
                THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
    FROM dbo.Inventories i
    INNER JOIN @Lines l ON l.VariantId = i.VariantId
    WHERE i.IsLowStock = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.RestockAlerts a
          WHERE a.InventoryId = i.Id AND a.IsDismissed = 0
      );

    COMMIT TRANSACTION;
    SELECT @OrderId AS Id, CONVERT(BIT, 1) AS Processed;
END;
GO

-- Fulfilment converts a reservation only when the order has not already been
-- committed by HitPay. The audit check also prevents old double-deducted orders
-- from being deducted a second time after this migration is applied.
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

    DECLARE @OldStatus NVARCHAR(50),
            @Source NVARCHAR(30),
            @HasCommittedSale BIT;

    SELECT @OldStatus = Status, @Source = OrderSource
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
    WHERE Id = @OrderId;

    IF @OldStatus IS NULL
        THROW 52001, N'Order not found.', 1;

    IF NOT
    (
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

    IF (@NewStatus IN (N'ReadyForPickup', N'Shipped'))
       AND @Source = N'ONLINE'
       AND EXISTS
       (
           SELECT 1 FROM dbo.Payments
           WHERE OrderId = @OrderId AND PaymentGateway = N'HitPay'
       )
       AND NOT EXISTS
       (
           SELECT 1 FROM dbo.Payments
           WHERE OrderId = @OrderId AND Status = N'Completed'
       )
        THROW 52003, N'Online HitPay payment is not complete.', 1;

    SELECT @HasCommittedSale = CASE WHEN EXISTS
        (
            SELECT 1 FROM dbo.StockAuditLogs l
            INNER JOIN dbo.Orders o ON o.OrderNumber = l.ReferenceNumber
            WHERE o.Id = @OrderId
              AND l.ChangeType = N'ONLINE_SALE'
              AND EXISTS
              (
                  SELECT 1 FROM dbo.Payments p
                  WHERE p.OrderId = @OrderId AND p.Status = N'Completed'
              )
        ) THEN 1 ELSE 0 END;

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
        SET Status = N'Completed', PaidAt = SYSUTCDATETIME()
        WHERE OrderId = @OrderId
          AND PaymentGateway IN (N'Cash', N'CashOnDelivery')
          AND Status = N'Pending';
    END;

    IF (@OldStatus = N'Processing' AND @NewStatus = N'Shipped')
       OR (@OldStatus = N'ReadyForPickup' AND @NewStatus = N'Completed')
    BEGIN
        UPDATE inv
        SET inv.CurrentStock = CASE
                WHEN @HasCommittedSale = 1 THEN inv.CurrentStock
                WHEN inv.ReservedStock >= oi.Quantity
                    THEN inv.CurrentStock - oi.Quantity
                ELSE inv.CurrentStock
            END,
            inv.ReservedStock = CASE
                WHEN inv.ReservedStock >= oi.Quantity
                    THEN inv.ReservedStock - oi.Quantity
                ELSE inv.ReservedStock
            END,
            inv.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Inventories inv
        INNER JOIN dbo.OrderItems oi ON inv.VariantId = oi.VariantId
        WHERE oi.OrderId = @OrderId;
    END;

    IF @NewStatus = N'Cancelled'
    BEGIN
        UPDATE inv
        SET inv.CurrentStock = CASE
                WHEN @HasCommittedSale = 1 THEN inv.CurrentStock + oi.Quantity
                ELSE inv.CurrentStock
            END,
            inv.ReservedStock = CASE
                WHEN inv.ReservedStock >= oi.Quantity
                    THEN inv.ReservedStock - oi.Quantity
                ELSE 0
            END,
            inv.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Inventories inv
        INNER JOIN dbo.OrderItems oi ON inv.VariantId = oi.VariantId
        WHERE oi.OrderId = @OrderId;
    END;

    COMMIT TRANSACTION;
    SELECT @OrderId AS Id, @NewStatus AS Status,
           @Courier AS Courier, @TrackingNumber AS TrackingNumber;
END;
GO

-- Customer cancellation uses the same reservation/sale distinction as the
-- admin status transition so cash pickup orders do not get over-restocked.
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

        DECLARE @CurrentStatus NVARCHAR(50),
                @OrderUserId INT,
                @OrderEmail NVARCHAR(256),
                @OrderNumber NVARCHAR(50),
                @HasCommittedSale BIT;

        SELECT @CurrentStatus = Status,
               @OrderUserId = UserId,
               @OrderEmail = CustomerEmail,
               @OrderNumber = OrderNumber
        FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @OrderId;

        IF @CurrentStatus IS NULL
            THROW 52301, N'Order not found.', 1;

        IF @UserId IS NOT NULL AND @OrderUserId IS NOT NULL AND @OrderUserId <> @UserId
            THROW 52302, N'You are not authorized to cancel this order.', 1;

        IF @CurrentStatus NOT IN (N'PendingPayment', N'Processing')
            THROW 52303, N'This order can no longer be cancelled.', 1;

        SELECT @HasCommittedSale = CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.StockAuditLogs l
            WHERE l.ReferenceNumber = @OrderNumber
              AND l.ChangeType = N'ONLINE_SALE'
              AND EXISTS
              (
                  SELECT 1 FROM dbo.Payments p
                  WHERE p.OrderId = @OrderId AND p.Status = N'Completed'
              )
        ) THEN 1 ELSE 0 END;

        UPDATE dbo.Orders
        SET Status = N'Cancelled',
            Notes = CONCAT(ISNULL(Notes + N' | ', N''), N'Cancelled by customer: ', @Reason),
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @OrderId;

        UPDATE dbo.Payments
        SET Status = CASE WHEN Status = N'Completed' THEN N'Refunded' ELSE N'Cancelled' END
        WHERE OrderId = @OrderId;

        UPDATE inv
        SET inv.CurrentStock = CASE
                WHEN @HasCommittedSale = 1 THEN inv.CurrentStock + oi.Quantity
                ELSE inv.CurrentStock
            END,
            inv.ReservedStock = CASE
                WHEN inv.ReservedStock >= oi.Quantity
                    THEN inv.ReservedStock - oi.Quantity
                ELSE 0
            END,
            inv.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Inventories inv
        INNER JOIN dbo.OrderItems oi ON inv.VariantId = oi.VariantId
        WHERE oi.OrderId = @OrderId;

        COMMIT TRANSACTION;
        SET @Success = 1;
        SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO

-- Repair the known legacy state where cash/COD order creation both reserved
-- and deducted stock. Keep the reservation, restore on-hand stock, and let
-- the corrected fulfillment procedure consume it once later.
UPDATE inv
SET inv.CurrentStock = inv.CurrentStock + oi.Quantity,
    inv.UpdatedAt = SYSUTCDATETIME()
FROM dbo.Inventories inv
INNER JOIN dbo.OrderItems oi ON inv.VariantId = oi.VariantId
INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
WHERE o.Status = N'Processing'
  AND EXISTS
  (
      SELECT 1 FROM dbo.Payments p
      WHERE p.OrderId = o.Id
        AND p.PaymentGateway IN (N'Cash', N'CashOnDelivery')
        AND p.Status = N'Pending'
  )
  AND inv.ReservedStock >= oi.Quantity
  AND EXISTS
  (
      SELECT 1 FROM dbo.StockAuditLogs l
      WHERE l.ReferenceNumber = o.OrderNumber
        AND l.VariantId = oi.VariantId
        AND l.ChangeType = N'ONLINE_SALE'
  );
GO

-- Return both on-hand and sellable quantities to the product detail API.
CREATE OR ALTER PROCEDURE dbo.sp_GetProductById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

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
            THEN 1 ELSE 0
        END AS IsDiscountActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage,
            p.DiscountType, p.DiscountAmount, p.DiscountStartDate,
            p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        orders.OrderCount,
        p.MainImageUrl,
        p.Description,
        p.IsFeatured
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    OUTER APPLY
    (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    OUTER APPLY
    (
        SELECT COUNT(DISTINCT oi.OrderId) AS OrderCount
        FROM dbo.v_VisibleProductColors pc
        INNER JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
        INNER JOIN dbo.OrderItems oi ON oi.VariantId = pv.Id
        INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
        WHERE pc.ProductId = p.Id AND o.Status <> N'Cancelled'
    ) orders
    WHERE p.Id = @Id AND p.IsActive = 1;

    SELECT
        pv.Id,
        pc.ProductId,
        pv.SKU,
        pv.Size,
        pc.Color,
        pc.ColorHex,
        pv.PriceAdjustment,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, pv.PriceAdjustment,
            p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
            p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        ISNULL(i.CurrentStock, 0) AS CurrentStock,
        ISNULL(i.ReservedStock, 0) AS ReservedStock,
        ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) AS AvailableStock,
        ISNULL(i.IsLowStock, 0) AS IsLowStock
    FROM dbo.v_VisibleProductVariants pv
    INNER JOIN dbo.v_VisibleProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.v_VisibleProducts p ON pc.ProductId = p.Id
    LEFT JOIN dbo.v_VisibleInventories i ON pv.Id = i.VariantId
    WHERE pc.ProductId = @Id AND pv.IsActive = 1
    ORDER BY pv.Id ASC;

    SELECT ImageUrl,
           COALESCE(AltText, N'Product view') AS AltText,
           CONVERT(INT, DisplayOrder) AS DisplayOrder
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @Id AND IsActive = 1
    ORDER BY DisplayOrder ASC, Id ASC;
END;
GO
