-- =====================================================================================
-- Migration 44: Orders, RMAs, Reviews Visibility & Full Activity Feed Scope
-- =====================================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'Applying Migration 44: Enhancing Reviews, Orders, RMAs, and Recent Activity Feed...';
GO

-- 1. STORED PROCEDURE: sp_GetProductReviews
-- Allows logged-in users to view their own reviews even if hidden (@CurrentUserId)
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetProductReviews
    @ProductId INT,
    @IncludeHidden BIT = 0,
    @CurrentUserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        reviews.Id,
        reviews.ProductId,
        reviews.UserId,
        reviews.OrderId,
        reviews.ReviewerName,
        reviews.Rating,
        reviews.Title,
        reviews.Comment,
        reviews.IsVerifiedPurchase,
        (SELECT COUNT(*) FROM dbo.ReviewReports reports WHERE reports.ReviewId = reviews.Id) AS FlagCount,
        reviews.IsHidden,
        reviews.CreatedAt
    FROM dbo.ProductReviews reviews
    WHERE reviews.ProductId = @ProductId
      AND (
          @IncludeHidden = 1 
          OR reviews.IsHidden = 0 
          OR (reviews.UserId IS NOT NULL AND @CurrentUserId IS NOT NULL AND reviews.UserId = @CurrentUserId)
      )
    ORDER BY 
        -- If current user review is hidden, float it to top so user sees their own review status
        CASE WHEN reviews.UserId = @CurrentUserId AND reviews.IsHidden = 1 THEN 0 ELSE 1 END,
        reviews.CreatedAt DESC;
END;
GO

-- 2. STORED PROCEDURE: sp_ReportReview
-- Prevents users from reporting their own reviews
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_ReportReview
    @ReviewId INT,
    @UserId INT = NULL,
    @IpAddress NVARCHAR(45) = NULL,
    @Reason NVARCHAR(50), -- 'SPAM', 'OFFENSIVE', 'IRRELEVANT', 'FAKE'
    @Notes NVARCHAR(255) = NULL,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ReviewAuthorId INT;

        SELECT @ReviewAuthorId = UserId
        FROM dbo.ProductReviews WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @ReviewId;

        IF @ReviewAuthorId IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.ProductReviews WHERE Id = @ReviewId)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Review not found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Disallow reporting own reviews
        IF @UserId IS NOT NULL AND @ReviewAuthorId IS NOT NULL AND @UserId = @ReviewAuthorId
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'You cannot report your own review.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Check duplicate report by user
        IF @UserId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.ReviewReports WHERE ReviewId = @ReviewId AND UserId = @UserId)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'You have already reported this review.';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        -- Check duplicate report by IP if guest
        ELSE IF @UserId IS NULL AND @IpAddress IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.ReviewReports WHERE ReviewId = @ReviewId AND IpAddress = @IpAddress)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'You have already reported this review.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO dbo.ReviewReports (ReviewId, UserId, IpAddress, Reason, Notes)
        VALUES (@ReviewId, @UserId, @IpAddress, @Reason, @Notes);

        -- Auto-hide after three stored reports.
        UPDATE dbo.ProductReviews
        SET 
            IsHidden = CASE WHEN (SELECT COUNT(*) FROM dbo.ReviewReports WHERE ReviewId = @ReviewId) >= 3 THEN 1 ELSE IsHidden END
        WHERE Id = @ReviewId;

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

-- 3. STORED PROCEDURE: sp_GetUserOrders
-- Returns order history with RMA summary columns (RmaCount, LatestRmaType, LatestRmaStatus, LatestRmaResolution)
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
         ) p) AS PreviewImages
    FROM dbo.Orders o
    WHERE o.UserId = @UserId OR (o.UserId IS NULL AND o.CustomerEmail = @UserEmail)
    ORDER BY o.CreatedAt DESC;
END;
GO

-- 4. STORED PROCEDURE: sp_GetOrderDetails
-- Enhanced with ProductId and RMA status per item
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetOrderDetails
    @OrderNumber NVARCHAR(50) = NULL,
    @OrderId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ResolvedId INT;

    IF @OrderId IS NOT NULL
        SET @ResolvedId = @OrderId;
    ELSE IF @OrderNumber IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE OrderNumber = @OrderNumber;

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

    -- Result Set 2: Order Items (With ProductId, RMA status, and Review indicator)
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
    WHERE py.OrderId = @ResolvedId ORDER BY py.Id DESC;
END;
GO

-- 5. STORED PROCEDURE: sp_GetUserOrderDetails
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetUserOrderDetails
    @UserId INT,
    @OrderId INT = NULL,
    @OrderNumber NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @UserId IS NULL
        THROW 52001, N'User identifier is required.', 1;

    DECLARE @ResolvedId INT;

    IF @OrderId IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE Id = @OrderId AND UserId = @UserId;
    ELSE IF @OrderNumber IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE OrderNumber = @OrderNumber AND UserId = @UserId;

    IF @ResolvedId IS NULL
        THROW 52002, N'Order not found or access denied.', 1;

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
        o.ShippingFee,
        o.TotalAmount,
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
        ISNULL((SELECT TOP 1 p.PaymentGateway FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'HitPay') AS PaymentMethod,
        ISNULL((SELECT TOP 1 p.Status FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'Pending') AS PaymentStatus,
        (SELECT TOP 1 p.GatewayReference FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS GatewayReference,
        (SELECT TOP 1 p.PaidAt FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS PaidAt,
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
    WHERE py.OrderId = @ResolvedId ORDER BY py.Id DESC;
END;
GO

-- 6. STORED PROCEDURE: sp_AdminRecentActivity (Scope All Activities)
-- Comprehensive operations feed covering Orders, Stock, RMAs, Reviews/Reports, and Payments
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

        -- 5. Customer Product Reviews
        SELECT 
            N'Review' AS ActivityType,
            CONCAT(pr.Rating, N'-Star Rating') AS Reference,
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

        -- 6. Moderation Review Reports
        SELECT 
            N'Review' AS ActivityType,
            CONCAT(N'Report #', rep.Id) AS Reference,
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

        -- 7. Payment Transactions (Completed payments and refunds)
        SELECT 
            N'Payment' AS ActivityType,
            COALESCE(py.GatewayReference, o.OrderNumber) AS Reference,
            CONCAT(
                CASE 
                    WHEN py.Status = N'Completed' THEN N'Payment received via '
                    WHEN py.Status = N'Refunded' THEN N'Refund issued via '
                    WHEN py.Status = N'Failed' THEN N'Payment attempt failed on '
                    ELSE CONCAT(py.Status, N' payment via ')
                END,
                ISNULL(py.PaymentGateway, N'Payment Gateway'),
                N' &bull; Amount: PHP ', FORMAT(py.Amount, N'N2'),
                N' &bull; Order #', o.OrderNumber
            ) AS Detail,
            COALESCE(NULLIF(o.CustomerName, N''), N'Customer') AS Actor,
            N'Customer' AS ActorRole,
            COALESCE(py.PaidAt, py.CreatedAt) AS CreatedAt
        FROM dbo.Payments py
        JOIN dbo.Orders o ON o.Id = py.OrderId
        WHERE py.Status IN (N'Completed', N'Refunded')
    ) activity
    ORDER BY CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @Limit ROWS ONLY;
END;
GO

PRINT N'Migration 44 applied successfully.';
GO
