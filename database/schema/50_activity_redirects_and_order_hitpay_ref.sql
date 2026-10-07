-- =====================================================================================
-- Migration 50: Activity Feed Redirects & HitPay Reference Resolution
-- Updates:
--  1. sp_GetOrderDetails: Resolves order by Id, OrderNumber, or Payment GatewayReference
--  2. sp_AdminOrders: Adds searching by Payment GatewayReference (HitPay Reference)
--  3. sp_AdminRecentActivity: Formats Review references as REV-<Id> for direct redirection
-- =====================================================================================

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

PRINT N'Applying Migration 50: Activity Feed Redirects & HitPay Reference Resolution...';
GO

-- 1. STORED PROCEDURE: sp_GetOrderDetails
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetOrderDetails
    @OrderNumber NVARCHAR(100) = NULL,
    @OrderId INT = NULL,
    @PaymentReference NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ResolvedId INT;

    IF @OrderId IS NOT NULL
        SET @ResolvedId = @OrderId;
    ELSE IF @OrderNumber IS NOT NULL
    BEGIN
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE OrderNumber = @OrderNumber;
        -- Fallback: check if @OrderNumber is a HitPay / Payment GatewayReference
        IF @ResolvedId IS NULL
        BEGIN
            SELECT TOP 1 @ResolvedId = p.OrderId 
            FROM dbo.Payments p 
            WHERE p.GatewayReference = @OrderNumber
            ORDER BY p.Id DESC;
        END
    END
    ELSE IF @PaymentReference IS NOT NULL
    BEGIN
        SELECT TOP 1 @ResolvedId = p.OrderId 
        FROM dbo.Payments p 
        WHERE p.GatewayReference = @PaymentReference
        ORDER BY p.Id DESC;
    END

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
        o.VoucherCode,
        o.CashTendered,
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
        o.UpdatedAt,
        (SELECT COUNT(*) FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id) AS RmaCount,
        (SELECT TOP 1 rr.RequestType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaType,
        (SELECT TOP 1 rr.Status FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaStatus,
        (SELECT TOP 1 rr.ResolutionType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaResolution
    FROM dbo.Orders o
    WHERE o.Id = @ResolvedId;

    -- Result Set 2: Order Items
    SELECT
        oi.Id,
        oi.OrderId,
        oi.VariantId,
        c.ProductId AS ProductId,
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
    WHERE py.OrderId = @ResolvedId 
    ORDER BY py.Id DESC;
END;
GO

-- 2. STORED PROCEDURE: sp_AdminOrders
-- Enhanced with Payment GatewayReference searching
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
           OR o.ShippingCity LIKE N'%' + @Search + N'%'
           OR EXISTS (SELECT 1 FROM dbo.Payments py WHERE py.OrderId = o.Id AND py.GatewayReference LIKE N'%' + @Search + N'%'))
    ORDER BY o.CreatedAt DESC, o.Id DESC;
END;
GO

-- 3. STORED PROCEDURE: sp_AdminRecentActivity
-- Updates Review reference format to REV-<ReviewId> for targeted modal redirection
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_AdminRecentActivity 
    @Limit INT = 8,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ActivityType, Reference, Detail, Actor, ActorRole, CreatedAt
    FROM (
        -- 1. Orders Placed & Status Updates
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
                    WHEN pay.Status = N'Completed' THEN CONCAT(N'Paid via ', CASE WHEN UPPER(ISNULL(pay.PaymentGateway, N'')) = N'HITPAY' THEN N'QRPh' ELSE ISNULL(pay.PaymentGateway, N'Online Payment') END, N' (PHP ', FORMAT(o.TotalAmount, N'N2'), N')')
                    WHEN pay.PaymentGateway = N'CashOnDelivery' THEN CONCAT(N'Cash on Delivery (Pending, PHP ', FORMAT(o.TotalAmount, N'N2'), N')')
                    ELSE CONCAT(CASE WHEN UPPER(ISNULL(pay.PaymentGateway, N'')) = N'HITPAY' THEN N'QRPh' ELSE ISNULL(pay.PaymentGateway, N'Payment') END, N' (PHP ', FORMAT(o.TotalAmount, N'N2'), N')')
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

        -- 2. Stock Movements (Restocks, manual adjustments, damaged stock write-offs)
        SELECT 
            N'Stock' AS ActivityType,
            COALESCE(l.ReferenceNumber, v.SKU) AS Reference,
            CONCAT(
                CASE 
                    WHEN l.ChangeType = N'RESTOCK' THEN N'Restocked '
                    WHEN l.ChangeType = N'ADJUSTMENT' AND l.QuantityChanged >= 0 THEN N'Stock increased (+ '
                    WHEN l.ChangeType = N'ADJUSTMENT' AND l.QuantityChanged < 0 THEN N'Stock adjusted (- '
                    WHEN l.ChangeType = N'DAMAGED' THEN N'Stock written off (- '
                    WHEN l.ChangeType = N'RETURN' THEN N'Returned stock incremented (+ '
                    ELSE CONCAT(l.ChangeType, N' ')
                END,
                p.Name, N' (', pc.Color, N', ', v.Size, N')',
                N' &bull; Change: ',
                CASE WHEN l.QuantityChanged > 0 THEN CONCAT(N'+', l.QuantityChanged) ELSE CAST(l.QuantityChanged AS NVARCHAR(10)) END,
                N' &bull; Current Level: ',
                l.PreviousStock + l.QuantityChanged, N' units'
            ) AS Detail,
            COALESCE(NULLIF(CONCAT(u.FirstName, N' ', u.LastName), N' '), N'Staff') AS Actor,
            CASE 
                WHEN r.Name = N'Admin' THEN N'Admin'
                WHEN r.Name = N'Customer' THEN N'Customer'
                ELSE N'Staff'
            END AS ActorRole,
            l.CreatedAt
        FROM dbo.StockAuditLogs l
        JOIN dbo.ProductVariants v ON v.Id = l.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        LEFT JOIN dbo.Users u ON u.Id = l.UserId
        LEFT JOIN dbo.Roles r ON r.Id = u.RoleId
        WHERE l.ChangeType IN (N'RESTOCK', N'ADJUSTMENT', N'DAMAGED', N'RETURN')

        UNION ALL

        -- 3. Return & Exchange RMAs (Submitted by Customer)
        SELECT 
            N'RMA' AS ActivityType,
            rma.RmaNumber AS Reference,
            CONCAT(
                N'Submitted ', 
                CASE WHEN rma.RequestType = N'RETURN' THEN N'Return request for refund' ELSE N'Exchange request' END,
                N' on Order #', o.OrderNumber,
                N' &bull; Item: ', p.Name, N' (', pc.Color, N', ', pv.Size, N')',
                N' &bull; Reason: ', rma.Reason,
                CASE WHEN rma.CustomerNotes IS NOT NULL AND LEN(rma.CustomerNotes) > 0 THEN CONCAT(N' &bull; Note: "', LEFT(rma.CustomerNotes, 50), N'..."') ELSE N'' END
            ) AS Detail,
            COALESCE(NULLIF(o.CustomerName, N''), NULLIF(CONCAT(u.FirstName, N' ', u.LastName), N' '), N'Customer') AS Actor,
            N'Customer' AS ActorRole,
            rma.CreatedAt
        FROM dbo.ReturnRequests rma
        JOIN dbo.Orders o ON o.Id = rma.OrderId
        JOIN dbo.OrderItems oi ON oi.Id = rma.OrderItemId
        JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        LEFT JOIN dbo.Users u ON u.Id = rma.UserId

        UNION ALL

        -- 4. Return & Exchange RMAs (Resolved by Staff/Admin)
        SELECT 
            N'RMA' AS ActivityType,
            rma.RmaNumber AS Reference,
            CONCAT(
                N'Processed RMA: ', rma.Status,
                CASE 
                    WHEN rma.ResolutionType IS NOT NULL THEN CONCAT(N' (Resolution: ', rma.ResolutionType, N')') 
                    ELSE N'' 
                END,
                CASE 
                    WHEN rma.RefundAmount IS NOT NULL AND rma.RefundAmount > 0 THEN CONCAT(N' &bull; Refund: PHP ', FORMAT(rma.RefundAmount, N'N2')) 
                    ELSE N'' 
                END,
                N' on Order #', o.OrderNumber,
                CASE WHEN rma.Restocked = 1 THEN N' &bull; Item Restocked' ELSE N'' END
            ) AS Detail,
            COALESCE(NULLIF(CONCAT(pb.FirstName, N' ', pb.LastName), N' '), N'Staff Member') AS Actor,
            CASE WHEN pbr.Name = N'Admin' THEN N'Admin' ELSE N'Staff' END AS ActorRole,
            rma.UpdatedAt AS CreatedAt
        FROM dbo.ReturnRequests rma
        JOIN dbo.Orders o ON o.Id = rma.OrderId
        LEFT JOIN dbo.Users pb ON pb.Id = rma.ProcessedBy
        LEFT JOIN dbo.Roles pbr ON pbr.Id = pb.RoleId
        WHERE rma.Status IN (N'Approved', N'Rejected', N'Completed', N'Received')
          AND rma.ProcessedBy IS NOT NULL

        UNION ALL

        -- 5. Customer Product Reviews (Reference explicitly formatted as REV-<Id>)
        SELECT 
            N'Review' AS ActivityType,
            CONCAT(N'REV-', pr.Id) AS Reference,
            CONCAT(
                N'Reviewed ', p.Name,
                N' (', pr.Rating, N'/5 stars)',
                CASE WHEN pr.Title IS NOT NULL AND LEN(pr.Title) > 0 THEN CONCAT(N' &bull; "', pr.Title, N'"') ELSE N'' END,
                CASE WHEN pr.IsVerifiedPurchase = 1 THEN N' &bull; Verified Purchase' ELSE N'' END
            ) AS Detail,
            COALESCE(NULLIF(pr.ReviewerName, N''), N'Customer') AS Actor,
            N'Customer' AS ActorRole,
            pr.CreatedAt
        FROM dbo.ProductReviews pr
        JOIN dbo.Products p ON p.Id = pr.ProductId

        UNION ALL

        -- 6. Moderation Review Reports (Reference explicitly includes review id)
        SELECT 
            N'Review' AS ActivityType,
            CONCAT(N'Report #', rep.Id, N' (REV-', pr.Id, N')') AS Reference,
            CONCAT(
                N'Flagged review on ', p.Name,
                N' &bull; Reason: ', rep.Reason,
                CASE WHEN rep.Notes IS NOT NULL AND LEN(rep.Notes) > 0 THEN CONCAT(N' &bull; "', LEFT(rep.Notes, 40), N'..."') ELSE N'' END
            ) AS Detail,
            COALESCE(NULLIF(CONCAT(u.FirstName, N' ', u.LastName), N' '), N'Community Member') AS Actor,
            N'Customer' AS ActorRole,
            rep.CreatedAt
        FROM dbo.ReviewReports rep
        JOIN dbo.ProductReviews pr ON pr.Id = rep.ReviewId
        JOIN dbo.Products p ON p.Id = pr.ProductId
        LEFT JOIN dbo.Users u ON u.Id = rep.UserId

        UNION ALL

        -- 7. Payment Transactions (Completed payments and refunds) - labeled QRPh instead of HitPay
        SELECT 
            N'Payment' AS ActivityType,
            COALESCE(py.GatewayReference, o.OrderNumber) AS Reference,
            CONCAT(
                CASE 
                    WHEN py.Status = N'Completed' THEN N'Payment received via '
                    WHEN py.Status = N'Refunded' THEN N'Refund issued via '
                    WHEN py.Status = N'Failed' THEN N'Payment attempt failed on '
                    ELSE N'Payment updated on '
                END,
                CASE WHEN UPPER(ISNULL(py.PaymentGateway, N'')) = N'HITPAY' THEN N'QRPh' ELSE ISNULL(py.PaymentGateway, N'Payment Gateway') END,
                N' for Order #', o.OrderNumber,
                N' &bull; PHP ', FORMAT(py.Amount, N'N2'),
                N' &bull; Status: ', py.Status
            ) AS Detail,
            ISNULL(NULLIF(o.CustomerName, N''), N'Store Customer') AS Actor,
            CASE 
                WHEN o.OrderSource IN (N'INSTORE_POS', N'IN_STORE') THEN N'Staff'
                WHEN r.Name = N'Admin' THEN N'Admin'
                WHEN r.Name = N'Staff' THEN N'Staff'
                ELSE N'Customer'
            END AS ActorRole,
            COALESCE(py.PaidAt, py.CreatedAt) AS CreatedAt
        FROM dbo.Payments py
        JOIN dbo.Orders o ON o.Id = py.OrderId
        LEFT JOIN dbo.Users u ON u.Id = o.UserId
        LEFT JOIN dbo.Roles r ON r.Id = u.RoleId
    ) act
    ORDER BY act.CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @Limit ROWS ONLY;
END;
GO

PRINT N'Migration 50 successfully applied.';
GO
