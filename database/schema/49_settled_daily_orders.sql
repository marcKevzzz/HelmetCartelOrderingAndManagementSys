-- =========================================================================
-- Migration 49: Procedure for Daily Settled Orders Drilldown
-- Aligns with sp_AdminSalesDaily to return the exact settled transactions
-- =========================================================================

CREATE OR ALTER PROCEDURE dbo.sp_AdminDailySettledOrders
    @TargetDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH OrderSales AS (
        SELECT 
            o.Id,
            o.OrderNumber,
            o.CustomerName,
            o.CustomerEmail,
            o.CustomerPhone,
            o.OrderSource,
            o.Status,
            (o.Subtotal - o.DiscountAmount) - ISNULL(
                (SELECT SUM(COALESCE(rr.RefundAmount, oi.TotalPrice, 0.00))
                 FROM dbo.ReturnRequests rr
                 JOIN dbo.OrderItems oi ON rr.OrderItemId = oi.Id
                 WHERE rr.OrderId = o.Id AND rr.Status IN (N'Approved', N'Completed')), 0.00
            ) AS NetMerchandiseRevenue,
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
            p.Status AS PaymentStatus,
            p.PaymentGateway AS PaymentMethod,
            p.PaidAt
        FROM dbo.Payments p
        JOIN dbo.Orders o ON o.Id = p.OrderId
        WHERE p.Status = N'Completed'
          AND o.Status IN (N'Completed', N'Delivered')
          AND CONVERT(DATE, p.PaidAt) = @TargetDate
    )
    SELECT 
        Id,
        OrderNumber,
        CustomerName,
        CustomerEmail,
        CustomerPhone,
        OrderSource,
        Status,
        NetMerchandiseRevenue AS TotalAmount,
        CreatedAt,
        ShippingMethod,
        ShippingFee,
        ShippingRegion,
        ShippingAddress,
        ShippingBarangay,
        ShippingCity,
        ShippingProvince,
        ShippingPostalCode,
        Courier,
        TrackingNumber,
        DeliveryNotes,
        ItemCount,
        PaymentStatus,
        PaymentMethod
    FROM OrderSales
    ORDER BY PaidAt DESC, Id DESC;
END;
GO
