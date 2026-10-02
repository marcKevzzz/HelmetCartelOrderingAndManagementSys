-- ==============================================================================
-- Helmet Cartel Ordering & Management System
-- Migration 29: Order Cancellation Check Fix, Stock Restoration, & Analytics Accuracy
-- ==============================================================================
USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Fix CK_Payments_Status check constraint to include 'Cancelled'
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Payments_Status')
BEGIN
    ALTER TABLE dbo.Payments DROP CONSTRAINT CK_Payments_Status;
END
GO

ALTER TABLE dbo.Payments ADD CONSTRAINT CK_Payments_Status 
    CHECK (Status IN (N'Pending', N'Completed', N'Failed', N'Refunded', N'Cancelled'));
GO

-- 2. Update dbo.sp_CustomerCancelOrder with accurate payment status and inventory restoration
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

        -- Update order status to Cancelled
        UPDATE dbo.Orders
        SET Status = N'Cancelled',
            Notes = CONCAT(ISNULL(Notes + N' | ', N''), N'Cancelled by customer: ', @Reason),
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @OrderId;

        -- Update payment record
        UPDATE dbo.Payments
        SET Status = CASE WHEN Status = N'Completed' THEN N'Refunded' ELSE N'Cancelled' END
        WHERE OrderId = @OrderId;

        IF @CurrentStatus = N'Processing'
        BEGIN
            -- Was paid, so CurrentStock was already deducted via ONLINE_SALE
            UPDATE inv
            SET inv.CurrentStock = inv.CurrentStock + oi.Quantity,
                inv.UpdatedAt = SYSUTCDATETIME()
            FROM dbo.Inventories inv
            INNER JOIN dbo.OrderItems oi ON inv.VariantId = oi.VariantId
            WHERE oi.OrderId = @OrderId;

            INSERT INTO dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
            SELECT oi.VariantId,
                   @UserId,
                   N'RESTOCK',
                   inv.CurrentStock - oi.Quantity,
                   oi.Quantity,
                   @OrderNumber,
                   CONCAT(N'Restocked on customer cancellation: ', @Reason)
            FROM dbo.OrderItems oi
            INNER JOIN dbo.Inventories inv ON inv.VariantId = oi.VariantId
            WHERE oi.OrderId = @OrderId;
        END
        ELSE
        BEGIN
            -- PendingPayment: only ReservedStock was held
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
            INNER JOIN dbo.Inventories inv ON inv.VariantId = oi.VariantId
            WHERE oi.OrderId = @OrderId;
        END

        COMMIT TRANSACTION;
        SET @Success = 1;
        SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO

-- 3. Sales Analytics Procedures: Strictly include only Completed or Delivered orders
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesReport @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(DISTINCT o.Id) AS PaymentCount, ISNULL(SUM(p.Amount), 0) AS Revenue,
           ISNULL(SUM(CASE WHEN o.OrderSource = N'ONLINE' THEN p.Amount ELSE 0 END), 0) AS OnlineRevenue,
           ISNULL(SUM(CASE WHEN o.OrderSource = N'INSTORE_POS' THEN p.Amount ELSE 0 END), 0) AS InStoreRevenue
    FROM dbo.Payments p JOIN dbo.Orders o ON o.Id = p.OrderId
    WHERE p.Status = N'Completed'
      AND o.Status IN (N'Completed', N'Delivered')
      AND p.PaidAt >= @StartDate AND p.PaidAt < @EndDate;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesDaily @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(DATE, p.PaidAt) AS SalesDate, COUNT(DISTINCT o.Id) AS PaymentCount, SUM(p.Amount) AS Revenue
    FROM dbo.Payments p
    JOIN dbo.Orders o ON o.Id = p.OrderId
    WHERE p.Status = N'Completed'
      AND o.Status IN (N'Completed', N'Delivered')
      AND p.PaidAt >= @StartDate AND p.PaidAt < @EndDate
    GROUP BY CONVERT(DATE, p.PaidAt) ORDER BY SalesDate;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesByBrandAndCategory
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesLines TABLE
    (
        OrderId INT NOT NULL,
        Quantity INT NOT NULL,
        UnitPrice DECIMAL(18, 2) NOT NULL,
        BrandName NVARCHAR(100) NOT NULL,
        CategoryName NVARCHAR(100) NOT NULL
    );

    INSERT @SalesLines (OrderId, Quantity, UnitPrice, BrandName, CategoryName)
    SELECT oi.OrderId,
           oi.Quantity,
           oi.UnitPrice,
           b.Name,
           c.Name
    FROM dbo.OrderItems oi
    INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
    INNER JOIN dbo.ProductVariants v ON v.Id = oi.VariantId
    INNER JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = pc.ProductId
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    INNER JOIN
    (
        SELECT OrderId, MAX(PaidAt) AS PaidAt
        FROM dbo.Payments
        WHERE Status = N'Completed'
          AND PaidAt IS NOT NULL
        GROUP BY OrderId
    ) completed ON completed.OrderId = oi.OrderId
    WHERE o.Status IN (N'Completed', N'Delivered')
      AND completed.PaidAt >= @StartDate
      AND completed.PaidAt < @EndDate;

    SELECT BrandName AS DimensionName,
           SUM(Quantity) AS UnitsSold,
           COUNT(DISTINCT OrderId) AS OrderCount,
           CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice)) AS Revenue,
           CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice) / NULLIF(SUM(Quantity), 0)) AS AverageUnitPrice
    FROM @SalesLines
    GROUP BY BrandName
    ORDER BY UnitsSold DESC, Revenue DESC, BrandName;

    SELECT CategoryName AS DimensionName,
           SUM(Quantity) AS UnitsSold,
           COUNT(DISTINCT OrderId) AS OrderCount,
           CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice)) AS Revenue,
           CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice) / NULLIF(SUM(Quantity), 0)) AS AverageUnitPrice
    FROM @SalesLines
    GROUP BY CategoryName
    ORDER BY UnitsSold DESC, Revenue DESC, CategoryName;
END;
GO

-- 4. Activity Feed: Clean HTML bullet separators
CREATE OR ALTER PROCEDURE dbo.sp_AdminRecentActivity 
    @Limit INT = 8
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Limit) ActivityType, Reference, Detail, Actor, CreatedAt
    FROM (
        -- 1. Descriptive Order Activity (Single consolidated entry per customer order)
        SELECT 
            N'Order' AS ActivityType,
            o.OrderNumber AS Reference,
            CONCAT(
                CASE 
                    WHEN o.Status = N'PendingPayment' THEN N'Awaiting payment for '
                    WHEN o.Status = N'Processing' THEN N'Placed order for '
                    WHEN o.Status = N'ReadyForPickup' THEN N'Ready for pickup: '
                    WHEN o.Status = N'Shipped' THEN N'Dispatched for delivery: '
                    WHEN o.Status = N'Delivered' THEN N'Delivered to customer: '
                    WHEN o.Status = N'Completed' THEN N'Completed order: '
                    WHEN o.Status = N'Cancelled' THEN N'Cancelled order: '
                    ELSE CONCAT(o.Status, N': ')
                END,
                ISNULL((
                    SELECT STRING_AGG(CONCAT(p.Name, N' (', pc.Color, N', ', pv.Size, N') x', oi.Quantity), N', ')
                    FROM dbo.OrderItems oi
                    JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
                    JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
                    JOIN dbo.Products p ON p.Id = pc.ProductId
                    WHERE oi.OrderId = o.Id
                ), N'Items'),
                N' &bull; ',
                CASE WHEN o.ShippingMethod = N'Pickup' THEN N'Store Pickup' ELSE N'Door-to-Door Delivery' END,
                N' &bull; ',
                CASE 
                    WHEN pay.Status = N'Completed' THEN CONCAT(N'Paid via ', ISNULL(pay.PaymentGateway, N'Online Payment'), N' (PHP ', FORMAT(o.TotalAmount, N'N2'), N')')
                    WHEN pay.PaymentGateway = N'CashOnDelivery' THEN CONCAT(N'Cash on Delivery (Pending, PHP ', FORMAT(o.TotalAmount, N'N2'), N')')
                    ELSE CONCAT(ISNULL(pay.PaymentGateway, N'Payment'), N' (PHP ', FORMAT(o.TotalAmount, N'N2'), N')')
                END
            ) AS Detail,
            ISNULL(NULLIF(o.CustomerName, N''), N'Store Customer') AS Actor,
            COALESCE(o.UpdatedAt, o.CreatedAt) AS CreatedAt
        FROM dbo.Orders o
        LEFT JOIN (
            SELECT OrderId, PaymentGateway, Status,
                   ROW_NUMBER() OVER(PARTITION BY OrderId ORDER BY Id DESC) as rn
            FROM dbo.Payments
        ) pay ON pay.OrderId = o.Id AND pay.rn = 1

        UNION ALL

        -- 2. Staff Stock Movements (Restocks, manual adjustments, damaged stock write-offs only; excludes sales)
        SELECT 
            N'Stock' AS ActivityType,
            COALESCE(l.ReferenceNumber, v.SKU) AS Reference,
            CONCAT(
                CASE 
                    WHEN l.ChangeType = N'RESTOCK' THEN N'Restocked '
                    WHEN l.ChangeType = N'ADJUSTMENT' AND l.QuantityChanged >= 0 THEN N'Stock increased (+ '
                    WHEN l.ChangeType = N'ADJUSTMENT' AND l.QuantityChanged < 0 THEN N'Stock adjusted (- '
                    WHEN l.ChangeType = N'DAMAGED' THEN N'Stock written off (- '
                    ELSE CONCAT(l.ChangeType, N' ')
                END,
                p.Name, N' (', pc.Color, N', ', v.Size, N')',
                N' &bull; Change: ',
                CASE WHEN l.QuantityChanged > 0 THEN CONCAT(N'+', l.QuantityChanged) ELSE CAST(l.QuantityChanged AS NVARCHAR(10)) END,
                N' &bull; Level: ',
                l.PreviousStock + l.QuantityChanged, N' units'
            ) AS Detail,
            COALESCE(NULLIF(CONCAT(u.FirstName, N' ', u.LastName), N' '), N'Staff') AS Actor,
            l.CreatedAt
        FROM dbo.StockAuditLogs l
        JOIN dbo.ProductVariants v ON v.Id = l.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        LEFT JOIN dbo.Users u ON u.Id = l.UserId
        WHERE l.ChangeType IN (N'RESTOCK', N'ADJUSTMENT', N'DAMAGED')
    ) activity
    ORDER BY CreatedAt DESC;
END;
GO
