-- =====================================================================================
-- Migration 45: Free Shipping Vouchers and Activity Feed QRPh Labeling
-- =====================================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'Applying Migration 45: Free shipping voucher support & QRPh payment activity logging...';
GO

-- 1. Update constraint on dbo.Vouchers to permit FREE_SHIPPING
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Vouchers_Discount' AND parent_object_id = OBJECT_ID(N'dbo.Vouchers'))
BEGIN
    ALTER TABLE dbo.Vouchers DROP CONSTRAINT CK_Vouchers_Discount;
END;
GO

ALTER TABLE dbo.Vouchers ADD CONSTRAINT CK_Vouchers_Discount 
CHECK (
    ([DiscountType] = N'FREE_SHIPPING' AND [DiscountValue] >= 0) 
    OR 
    ([DiscountValue] > 0 AND (
        [DiscountType] = N'FIXED_AMOUNT' 
        OR ([DiscountType] = N'PERCENTAGE' AND [DiscountValue] <= 100)
    ))
);
GO

-- 2. Procedure: dbo.sp_AdminSaveVoucher
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveVoucher
    @Id INT = 0, 
    @Code NVARCHAR(30), 
    @DiscountType NVARCHAR(20),
    @DiscountValue DECIMAL(18,2), 
    @MinimumSpend DECIMAL(18,2) = 0,
    @ExpiresAt DATETIME2 = NULL, 
    @UsageLimit INT = NULL, 
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Code = UPPER(LTRIM(RTRIM(@Code)));

    IF @Code IS NULL OR LEN(@Code) NOT BETWEEN 3 AND 30 OR
       @Code COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Z0-9-]%'
        THROW 54001, N'Use 3-30 letters, numbers or hyphens for the voucher code.', 1;

    IF @DiscountType IS NULL OR @DiscountType NOT IN (N'PERCENTAGE', N'FIXED_AMOUNT', N'FREE_SHIPPING') OR
       @DiscountValue IS NULL OR
       (@DiscountType <> N'FREE_SHIPPING' AND @DiscountValue <= 0) OR
       (@DiscountType = N'FREE_SHIPPING' AND @DiscountValue < 0) OR
       (@DiscountType = N'PERCENTAGE' AND @DiscountValue > 100) OR
       @MinimumSpend IS NULL OR @MinimumSpend < 0 OR @UsageLimit <= 0
        THROW 54002, N'Check the discount, minimum spend and usage limit.', 1;

    -- Past dates are allowed only when retaining an existing expiry
    IF @ExpiresAt <= SYSUTCDATETIME() AND NOT EXISTS
        (SELECT 1 FROM dbo.Vouchers WHERE Id = @Id AND ExpiresAt = @ExpiresAt)
        THROW 54003, N'Choose a future expiry date.', 1;

    BEGIN TRANSACTION;
    IF @Id <> 0 AND NOT EXISTS (SELECT 1 FROM dbo.Vouchers WITH (UPDLOCK, ROWLOCK) WHERE Id = @Id)
        THROW 54004, N'Voucher not found.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Vouchers WHERE Code = @Code AND Id <> @Id)
        THROW 54005, N'This voucher code already exists.', 1;

    IF EXISTS (SELECT 1 FROM dbo.VoucherRedemptions WHERE VoucherId = @Id) AND
       EXISTS (SELECT 1 FROM dbo.Vouchers WHERE Id = @Id AND Code <> @Code)
        THROW 54006, N'A redeemed voucher code cannot be renamed.', 1;

    IF @UsageLimit < (SELECT COUNT(*) FROM dbo.VoucherRedemptions WHERE VoucherId = @Id AND ReleasedAt IS NULL)
        THROW 54007, N'Usage limit cannot be lower than current usage.', 1;

    IF @Id = 0
    BEGIN
        INSERT dbo.Vouchers(Code, DiscountType, DiscountValue, MinimumSpend, ExpiresAt, UsageLimit, IsActive)
        VALUES (@Code, @DiscountType, @DiscountValue, @MinimumSpend, @ExpiresAt, @UsageLimit, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Vouchers 
        SET Code = @Code, 
            DiscountType = @DiscountType, 
            DiscountValue = @DiscountValue,
            MinimumSpend = @MinimumSpend, 
            ExpiresAt = @ExpiresAt, 
            UsageLimit = @UsageLimit,
            IsActive = @IsActive, 
            UpdatedAt = SYSUTCDATETIME() 
        WHERE Id = @Id;
    END

    COMMIT TRANSACTION;
    SELECT @Id AS Id;
END;
GO

-- 3. Procedure: dbo.sp_CalculateVoucher
CREATE OR ALTER PROCEDURE dbo.sp_CalculateVoucher
    @Code NVARCHAR(30), 
    @Subtotal DECIMAL(18,2), 
    @ForRedemption BIT = 0,
    @VoucherId INT OUTPUT, 
    @DiscountAmount DECIMAL(18,2) OUTPUT,
    @DiscountType NVARCHAR(20) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @ForRedemption = 1 AND @@TRANCOUNT = 0
        THROW 54008, N'Voucher redemption requires an order transaction.', 1;

    SET @VoucherId = NULL;
    SET @Code = UPPER(LTRIM(RTRIM(@Code)));
    DECLARE @Type NVARCHAR(20), @Value DECIMAL(18,2), @Minimum DECIMAL(18,2),
        @Expiry DATETIME2, @Limit INT, @Active BIT;

    IF @ForRedemption = 1
        SELECT @VoucherId = Id, @Type = DiscountType, @Value = DiscountValue,
            @Minimum = MinimumSpend, @Expiry = ExpiresAt, @Limit = UsageLimit, @Active = IsActive
        FROM dbo.Vouchers WITH (UPDLOCK, ROWLOCK) WHERE Code = @Code;
    ELSE
        SELECT @VoucherId = Id, @Type = DiscountType, @Value = DiscountValue,
            @Minimum = MinimumSpend, @Expiry = ExpiresAt, @Limit = UsageLimit, @Active = IsActive
        FROM dbo.Vouchers WHERE Code = @Code;

    IF @VoucherId IS NULL THROW 54009, N'Voucher code not found.', 1;
    IF @Active = 0 THROW 54010, N'This voucher is inactive.', 1;
    IF @Expiry <= SYSUTCDATETIME() THROW 54011, N'This voucher has expired.', 1;
    IF @Subtotal IS NULL OR @Subtotal <= 0 OR @Subtotal < @Minimum
        THROW 54012, N'Your merchandise subtotal does not meet the voucher minimum spend.', 1;
    IF @Limit IS NOT NULL AND @Limit <=
        (SELECT COUNT(*) FROM dbo.VoucherRedemptions WHERE VoucherId = @VoucherId AND ReleasedAt IS NULL)
        THROW 54013, N'This voucher has reached its usage limit.', 1;

    SET @DiscountType = @Type;

    IF @Type = N'FREE_SHIPPING'
    BEGIN
        SET @DiscountAmount = 0.00;
    END
    ELSE IF @Type = N'PERCENTAGE'
    BEGIN
        SET @DiscountAmount = ROUND(@Subtotal * @Value / 100.0, 2);
    END
    ELSE
    BEGIN
        SET @DiscountAmount = @Value;
    END

    IF @DiscountAmount > @Subtotal SET @DiscountAmount = @Subtotal;
END;
GO

-- 4. Procedure: dbo.sp_PreviewVoucher
CREATE OR ALTER PROCEDURE dbo.sp_PreviewVoucher
    @Code NVARCHAR(30), 
    @Items dbo.SaleLineInput READONLY
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM @Items) OR EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0) OR
       EXISTS (SELECT VariantId FROM @Items GROUP BY VariantId HAVING COUNT(*) > 1)
        THROW 54014, N'Choose valid, distinct merchandise items.', 1;

    DECLARE @Subtotal DECIMAL(18,2), @Count INT;
    SELECT @Subtotal = SUM(CONVERT(DECIMAL(18,2), dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
        p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive)) * l.Quantity),
        @Count = COUNT(*)
    FROM @Items l JOIN dbo.v_VisibleProductVariants v ON v.Id = l.VariantId
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId;

    IF @Count <> (SELECT COUNT(*) FROM @Items) THROW 54014, N'An item is no longer available.', 1;

    DECLARE @Id INT, @Discount DECIMAL(18,2), @Type NVARCHAR(20);
    EXEC dbo.sp_CalculateVoucher @Code, @Subtotal, 0, @Id OUTPUT, @Discount OUTPUT, @Type OUTPUT;

    SELECT 
        UPPER(LTRIM(RTRIM(@Code))) AS Code, 
        @Subtotal AS Subtotal,
        @Discount AS DiscountAmount, 
        @Subtotal - @Discount AS DiscountedSubtotal,
        @Type AS DiscountType;
END;
GO

-- 5. Procedure: dbo.sp_ApplyOrderVoucher
CREATE OR ALTER PROCEDURE dbo.sp_ApplyOrderVoucher
    @OrderId INT, 
    @Code NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT = 0 THROW 54008, N'Voucher redemption requires an order transaction.', 1;

    DECLARE @Subtotal DECIMAL(18,2), @Id INT, @Discount DECIMAL(18,2), @Type NVARCHAR(20);
    IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @OrderId AND OrderSource = N'ONLINE' AND Status IN (N'PendingPayment', N'Processing'))
        THROW 54015, N'This order cannot accept a voucher.', 1;

    IF EXISTS (SELECT 1 FROM dbo.VoucherRedemptions WHERE OrderId = @OrderId)
        THROW 54016, N'This order already has a voucher.', 1;

    SELECT @Subtotal = SUM(TotalPrice) FROM dbo.OrderItems WHERE OrderId = @OrderId;

    EXEC dbo.sp_CalculateVoucher @Code, @Subtotal, 1, @Id OUTPUT, @Discount OUTPUT, @Type OUTPUT;

    IF @Type = N'FREE_SHIPPING'
    BEGIN
        DECLARE @SavedShippingFee DECIMAL(18,2) = 0.00;
        SELECT @SavedShippingFee = ISNULL(ShippingFee, 0.00) FROM dbo.Orders WHERE Id = @OrderId;

        -- Record the redemption with the value of the waived delivery fee
        INSERT dbo.VoucherRedemptions(VoucherId, OrderId, DiscountAmount) 
        VALUES (@Id, @OrderId, @SavedShippingFee);

        -- Set ShippingFee to 0.00 (TotalAmount is automatically recomputed)
        UPDATE dbo.Orders 
        SET VoucherCode = UPPER(LTRIM(RTRIM(@Code))), 
            DiscountAmount = 0.00,
            ShippingFee = 0.00,
            UpdatedAt = SYSUTCDATETIME() 
        WHERE Id = @OrderId;
    END
    ELSE
    BEGIN
        INSERT dbo.VoucherRedemptions(VoucherId, OrderId, DiscountAmount) 
        VALUES (@Id, @OrderId, @Discount);

        UPDATE dbo.Orders 
        SET VoucherCode = UPPER(LTRIM(RTRIM(@Code))), 
            DiscountAmount = @Discount,
            UpdatedAt = SYSUTCDATETIME() 
        WHERE Id = @OrderId;
    END

    SELECT 
        VoucherCode AS Code, 
        Subtotal, 
        DiscountAmount, 
        Subtotal - DiscountAmount AS DiscountedSubtotal,
        @Type AS DiscountType
    FROM dbo.Orders 
    WHERE Id = @OrderId;
END;
GO

-- 6. STORED PROCEDURE: sp_AdminRecentActivity
-- Change "Payment received via HitPay" to "via QRPh"
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

        -- 7. Payment Transactions (Completed payments and refunds) - labeled QRPh instead of HitPay
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
                CASE 
                    WHEN UPPER(ISNULL(py.PaymentGateway, N'')) = N'HITPAY' THEN N'QRPh'
                    ELSE ISNULL(py.PaymentGateway, N'Payment Gateway')
                END,
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

PRINT N'Migration 45 applied successfully.';
GO
