-- =====================================================================================
-- 53_order_items_quantity_count_fix.sql
-- Fixes ItemCount in order queries to sum total quantities (SUM(oi.Quantity))
-- rather than counting distinct line item rows (COUNT(*)), ensuring that orders with
-- quantity > 1 accurately display the true total item count across admin tables,
-- settled reports, and user order history.
-- =====================================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. STORED PROCEDURE: sp_AdminOrders
-- Updated: ItemCount uses SUM(oi.Quantity)
-- =====================================================================================
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
        ISNULL((SELECT SUM(oi.Quantity) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id), 0) AS ItemCount,
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
           OR o.ShippingCity LIKE N'%' + @Search + N'%'
           OR EXISTS (SELECT 1 FROM dbo.Payments py WHERE py.OrderId = o.Id AND py.GatewayReference LIKE N'%' + @Search + N'%'))
    ORDER BY o.CreatedAt DESC, o.Id DESC;
END;
GO

-- 2. STORED PROCEDURE: sp_AdminDailySettledOrders
-- Updated: ItemCount uses SUM(oi.Quantity)
-- =====================================================================================
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
                (SELECT SUM(ISNULL(rr.RefundAmount, 0.00))
                 FROM dbo.ReturnRequests rr
                 JOIN dbo.OrderItems oi ON rr.OrderItemId = oi.Id
                 WHERE rr.OrderId = o.Id AND rr.RequestType = N'RETURN' AND rr.ResolutionType = N'REFUND' AND rr.Status = N'Completed'), 0.00
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
            ISNULL((SELECT SUM(oi.Quantity) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id), 0) AS ItemCount,
            p.Status AS PaymentStatus,
            p.PaymentGateway AS PaymentMethod,
            p.PaidAt
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY OrderId ORDER BY PaidAt DESC, Id DESC) AS PaymentRank
            FROM dbo.Payments WHERE Status = N'Completed') p
        JOIN dbo.Orders o ON o.Id = p.OrderId
        WHERE p.PaymentRank = 1
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

-- 3. STORED PROCEDURE: sp_GetUserOrders
-- Updated: ItemCount uses SUM(oi.Quantity)
-- =====================================================================================
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
        ISNULL((SELECT SUM(oi.Quantity) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id), 0) AS ItemCount,
        (SELECT COUNT(*) FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id) AS RmaCount,
        (SELECT TOP 1 rr.RequestType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaType,
        (SELECT TOP 1 rr.Status FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaStatus,
        (SELECT TOP 1 rr.ResolutionType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaResolution,
        (SELECT STRING_AGG(p.MainImageUrl, ';')
         FROM (
             SELECT TOP 3 p.MainImageUrl
             FROM dbo.OrderItems oi
             JOIN dbo.ProductVariants pv ON oi.VariantId = pv.Id
             JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
             JOIN dbo.Products p ON pc.ProductId = p.Id
             WHERE oi.OrderId = o.Id
             ORDER BY oi.Id ASC
         ) p) AS PreviewImages,
        (SELECT 
            oi.Id AS Id,
            oi.Id AS OrderItemId,
            oi.OrderId,
            oi.VariantId,
            c.ProductId,
            oi.Quantity,
            oi.UnitPrice,
            oi.TotalPrice,
            ISNULL(NULLIF(oi.ProductName, N''), p.Name) AS ProductName,
            p.Slug AS ProductSlug,
            p.MainImageUrl,
            ISNULL(NULLIF(oi.ColorName, N''), c.Color) AS Color,
            ISNULL(NULLIF(oi.Size, N''), v.Size) AS Size,
            ISNULL(NULLIF(oi.SKU, N''), v.SKU) AS SKU,
            (SELECT TOP 1 rr.Id FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaId,
            (SELECT TOP 1 rr.RmaNumber FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaNumber,
            (SELECT TOP 1 rr.RequestType FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaType,
            (SELECT TOP 1 rr.Status FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaStatus,
            (SELECT TOP 1 rr.ResolutionType FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaResolution,
            (SELECT TOP 1 pr.Id FROM dbo.ProductReviews pr WHERE pr.OrderId = oi.OrderId AND pr.ProductId = c.ProductId) AS ReviewId
         FROM dbo.OrderItems oi
         LEFT JOIN dbo.ProductVariants v ON oi.VariantId = v.Id
         LEFT JOIN dbo.ProductColors c ON v.ProductColorId = c.Id
         LEFT JOIN dbo.Products p ON c.ProductId = p.Id
         WHERE oi.OrderId = o.Id
         FOR JSON PATH) AS ItemsJson
    FROM dbo.Orders o
    WHERE o.UserId = @UserId OR (o.UserId IS NULL AND o.CustomerEmail = @UserEmail)
    ORDER BY o.CreatedAt DESC;
END;
GO
