-- =====================================================================================
-- MIGRATION 46: OPTIMIZE USER ORDERS WITH PRELOADED ITEMS JSON
-- Author: Helmet Cartel Engineering Team
-- Date: 2026-10-04
-- Purpose: Pre-load order items in dbo.sp_GetUserOrders as ItemsJson to allow instantaneous
--          rendering of the Return / Exchange item checklist and expanded order drawer.
-- =====================================================================================

USE [HelmetCartelDB];
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
