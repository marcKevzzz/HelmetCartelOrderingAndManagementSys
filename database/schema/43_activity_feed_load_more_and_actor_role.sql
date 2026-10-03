-- =====================================================================================
-- Migration 43: Recent Activity Feed Load More Pagination & Actor Role Identification
-- =====================================================================================

PRINT N'Applying Migration 43: Update dbo.sp_AdminRecentActivity with @Offset and ActorRole...';
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminRecentActivity 
    @Limit INT = 8,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ActivityType, Reference, Detail, Actor, ActorRole, CreatedAt
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
            CASE 
                WHEN o.OrderSource IN (N'INSTORE_POS', N'IN_STORE') THEN N'Staff'
                WHEN r.Name = N'Admin' THEN N'Admin'
                WHEN r.Name = N'Staff' THEN N'Staff'
                ELSE N'Customer'
            END AS ActorRole,
            COALESCE(o.UpdatedAt, o.CreatedAt) AS CreatedAt
        FROM dbo.Orders o
        LEFT JOIN dbo.Users u ON u.Id = o.UserId
        LEFT JOIN dbo.Roles r ON r.Id = u.RoleId
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
            CASE 
                WHEN r.Name = N'Admin' THEN N'Admin'
                WHEN r.Name = N'Customer' THEN N'Customer'
                ELSE N'Admin'
            END AS ActorRole,
            l.CreatedAt
        FROM dbo.StockAuditLogs l
        JOIN dbo.ProductVariants v ON v.Id = l.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        LEFT JOIN dbo.Users u ON u.Id = l.UserId
        LEFT JOIN dbo.Roles r ON r.Id = u.RoleId
        WHERE l.ChangeType IN (N'RESTOCK', N'ADJUSTMENT', N'DAMAGED')
    ) activity
    ORDER BY CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @Limit ROWS ONLY;
END;
GO

PRINT N'Migration 43 Applied Successfully.';
GO
