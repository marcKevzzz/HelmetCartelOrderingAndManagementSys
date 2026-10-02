-- ==============================================================================
-- Helmet Cartel Ordering & Management System
-- Migration 28: Descriptive Activity Feed & Stock History Clean Isolation
-- ==============================================================================
USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

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
                N' • ',
                CASE WHEN o.ShippingMethod = N'Pickup' THEN N'Store Pickup' ELSE N'Door-to-Door Delivery' END,
                N' • ',
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
                    WHEN l.ChangeType = N'Restock' THEN N'Restocked '
                    WHEN l.ChangeType = N'Adjustment' THEN N'Adjusted stock for '
                    WHEN l.ChangeType = N'Count' THEN N'Inventory count for '
                    ELSE CONCAT(l.ChangeType, N' for ')
                END,
                p.Name, N' (', pc.Color, N', ', v.Size, N'): ',
                CASE WHEN l.QuantityChanged > 0 THEN CONCAT(N'+', CAST(l.QuantityChanged AS NVARCHAR), N' units')
                     ELSE CONCAT(CAST(l.QuantityChanged AS NVARCHAR), N' units')
                END,
                CASE WHEN l.Notes IS NOT NULL AND LEN(l.Notes) > 0 THEN CONCAT(N' — ', l.Notes) ELSE N'' END
            ) AS Detail,
            COALESCE(NULLIF(CONCAT(u.FirstName, N' ', u.LastName), N' '), N'Staff') AS Actor,
            l.CreatedAt
        FROM dbo.v_VisibleStockAuditLogs l
        JOIN dbo.v_VisibleProductVariants v ON v.Id = l.VariantId
        JOIN dbo.v_VisibleProductColors pc ON pc.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        LEFT JOIN dbo.Users u ON u.Id = l.UserId
        WHERE l.ChangeType NOT IN (N'ONLINE_SALE', N'INSTORE_SALE')
    ) activity
    ORDER BY CreatedAt DESC;
END;
GO
