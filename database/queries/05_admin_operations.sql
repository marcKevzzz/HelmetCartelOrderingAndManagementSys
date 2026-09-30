USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF TYPE_ID(N'dbo.SaleLineInput') IS NULL
    EXEC(N'CREATE TYPE dbo.SaleLineInput AS TABLE (VariantId INT NOT NULL PRIMARY KEY, Quantity INT NOT NULL)');
GO

CREATE OR ALTER PROCEDURE dbo.sp_CreatePhysicalSale
    @OrderNumber NVARCHAR(50), @ActorUserId INT = NULL,
    @CustomerName NVARCHAR(100), @CustomerEmail NVARCHAR(256), @CustomerPhone NVARCHAR(30),
    @OrderSource NVARCHAR(30), @OrderStatus NVARCHAR(50), @PaymentMethod NVARCHAR(50),
    @PaymentStatus NVARCHAR(50), @Notes NVARCHAR(500), @Items dbo.SaleLineInput READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM @Items) OR EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0)
        THROW 52201, N'Sale needs positive item quantities.', 1;
    IF @PaymentMethod NOT IN (N'Cash', N'Card_POS') OR
       (@OrderSource = N'INSTORE_POS' AND (@OrderStatus <> N'Completed' OR @PaymentStatus <> N'Completed')) OR
       (@OrderSource = N'ONLINE' AND (@OrderStatus <> N'Processing' OR @PaymentStatus <> N'Pending')) OR
       @OrderSource NOT IN (N'INSTORE_POS', N'ONLINE')
        THROW 52202, N'Invalid physical sale options.', 1;

    DECLARE @Lines TABLE (VariantId INT PRIMARY KEY, Quantity INT, UnitPrice DECIMAL(18,2), OldStock INT);
    DECLARE @VariantId INT, @Quantity INT, @UnitPrice DECIMAL(18,2), @OldStock INT, @Reserved INT;
    DECLARE sale_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT VariantId, Quantity FROM @Items ORDER BY VariantId;
    BEGIN TRANSACTION;
    OPEN sale_cursor;
    FETCH NEXT FROM sale_cursor INTO @VariantId, @Quantity;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @UnitPrice = CONVERT(DECIMAL(18,2), (p.BasePrice + v.PriceAdjustment) * (1 - p.DiscountPercentage / 100.0))
        FROM dbo.ProductVariants v JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = c.ProductId
        WHERE v.Id = @VariantId AND v.IsActive = 1 AND p.IsActive = 1;
        SELECT @OldStock = CurrentStock, @Reserved = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) WHERE VariantId = @VariantId;
        IF @UnitPrice IS NULL OR @OldStock IS NULL OR @OldStock - @Reserved < @Quantity
            THROW 52203, N'Item unavailable or insufficient stock.', 1;
        INSERT @Lines VALUES (@VariantId, @Quantity, @UnitPrice, @OldStock);
        SET @UnitPrice = NULL;
        SET @OldStock = NULL;
        FETCH NEXT FROM sale_cursor INTO @VariantId, @Quantity;
    END;
    CLOSE sale_cursor;
    DEALLOCATE sale_cursor;

    DECLARE @Subtotal DECIMAL(18,2) = (SELECT SUM(Quantity * UnitPrice) FROM @Lines);
    INSERT dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone,
        OrderSource, Status, Subtotal, DiscountAmount, Notes)
    VALUES (@OrderNumber, CASE WHEN @OrderSource = N'ONLINE' THEN @ActorUserId ELSE NULL END,
        @CustomerName, @CustomerEmail, @CustomerPhone,
        @OrderSource, @OrderStatus, @Subtotal, 0, @Notes);
    DECLARE @OrderId INT = CONVERT(INT, SCOPE_IDENTITY());
    INSERT dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    SELECT @OrderId, VariantId, Quantity, UnitPrice FROM @Lines;
    UPDATE i SET CurrentStock = i.CurrentStock - l.Quantity, UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId;
    INSERT dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber)
    SELECT VariantId, @ActorUserId, CASE WHEN @OrderSource = N'INSTORE_POS' THEN N'INSTORE_SALE' ELSE N'ONLINE_SALE' END,
           OldStock, -Quantity, @OrderNumber FROM @Lines;
    INSERT dbo.Payments (OrderId, PaymentGateway, Amount, Status, PaidAt)
    VALUES (@OrderId, @PaymentMethod, @Subtotal, @PaymentStatus,
        CASE WHEN @PaymentStatus = N'Completed' THEN SYSUTCDATETIME() ELSE NULL END);
    INSERT dbo.RestockAlerts (InventoryId, Severity)
    SELECT i.Id, CASE WHEN i.CurrentStock - i.ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId
    WHERE i.IsLowStock = 1 AND NOT EXISTS
        (SELECT 1 FROM dbo.RestockAlerts a WHERE a.InventoryId = i.Id AND a.IsDismissed = 0);
    COMMIT TRANSACTION;
    SELECT @OrderId AS Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ConfirmHitPayOrder
    @OrderNumber NVARCHAR(50), @GatewayReference NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@GatewayReference)), N'') IS NULL
        THROW 52204, N'Payment reference is required.', 1;
    BEGIN TRANSACTION;
    DECLARE @OrderId INT, @Status NVARCHAR(50), @Total DECIMAL(18,2), @CustomerUserId INT;
    SELECT @OrderId = Id, @Status = Status, @Total = TotalAmount, @CustomerUserId = UserId
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE OrderNumber = @OrderNumber AND OrderSource = N'ONLINE';
    IF @OrderId IS NULL THROW 52205, N'Online order not found.', 1;
    IF @Status = N'Processing' AND EXISTS
        (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND PaymentGateway = N'HitPay'
         AND GatewayReference = @GatewayReference AND Status = N'Completed')
    BEGIN
        COMMIT TRANSACTION;
        SELECT @OrderId AS Id, CONVERT(BIT, 0) AS Processed;
        RETURN;
    END;
    IF @Status <> N'PendingPayment' THROW 52206, N'Order cannot accept this payment.', 1;

    DECLARE @Lines TABLE (VariantId INT PRIMARY KEY, Quantity INT, OldStock INT);
    DECLARE @VariantId INT, @Quantity INT, @OldStock INT, @Reserved INT;
    DECLARE line_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT VariantId, SUM(Quantity) FROM dbo.OrderItems WHERE OrderId = @OrderId GROUP BY VariantId ORDER BY VariantId;
    OPEN line_cursor;
    FETCH NEXT FROM line_cursor INTO @VariantId, @Quantity;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @OldStock = CurrentStock, @Reserved = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) WHERE VariantId = @VariantId;
        IF @OldStock IS NULL OR @OldStock - @Reserved < @Quantity
            THROW 52207, N'Paid order has insufficient stock; manual resolution required.', 1;
        INSERT @Lines VALUES (@VariantId, @Quantity, @OldStock);
        SET @OldStock = NULL;
        FETCH NEXT FROM line_cursor INTO @VariantId, @Quantity;
    END;
    CLOSE line_cursor;
    DEALLOCATE line_cursor;

    UPDATE i SET CurrentStock = i.CurrentStock - l.Quantity, UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId;
    INSERT dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber)
    SELECT VariantId, @CustomerUserId, N'ONLINE_SALE', OldStock, -Quantity, @OrderNumber FROM @Lines;
    INSERT dbo.Payments (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt)
    VALUES (@OrderId, N'HitPay', @GatewayReference, @Total, N'Completed', SYSUTCDATETIME());
    UPDATE dbo.Orders SET Status = N'Processing', UpdatedAt = SYSUTCDATETIME() WHERE Id = @OrderId;
    INSERT dbo.RestockAlerts (InventoryId, Severity)
    SELECT i.Id, CASE WHEN i.CurrentStock - i.ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId
    WHERE i.IsLowStock = 1 AND NOT EXISTS
        (SELECT 1 FROM dbo.RestockAlerts a WHERE a.InventoryId = i.Id AND a.IsDismissed = 0);
    COMMIT TRANSACTION;
    SELECT @OrderId AS Id, CONVERT(BIT, 1) AS Processed;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminDashboard @IncludeRevenue BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT ISNULL(SUM(CurrentStock), 0) FROM dbo.Inventories) AS OnHandStock,
        (SELECT ISNULL(SUM(CurrentStock - ReservedStock), 0) FROM dbo.Inventories) AS AvailableStock,
        (SELECT COUNT(*) FROM dbo.Inventories WHERE IsLowStock = 1) AS LowStockCount,
        (SELECT COUNT(*) FROM dbo.Inventories WHERE CurrentStock - ReservedStock = 0) AS OutOfStockCount,
        (SELECT COUNT(*) FROM dbo.Orders WHERE Status IN (N'PendingPayment', N'Processing', N'ReadyForPickup')) AS ActiveOrders,
        CASE WHEN @IncludeRevenue = 1 THEN
            (SELECT ISNULL(SUM(Amount), 0) FROM dbo.Payments WHERE Status = N'Completed' AND PaidAt >= CONVERT(DATE, SYSUTCDATETIME()))
        ELSE NULL END AS TodayRevenue;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminRecentActivity @Limit INT = 8
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) ActivityType, Reference, Detail, Actor, CreatedAt
    FROM (
        SELECT N'Order' AS ActivityType, o.OrderNumber AS Reference,
               o.Status AS Detail, o.CustomerName AS Actor,
               COALESCE(o.UpdatedAt, o.CreatedAt) AS CreatedAt
        FROM dbo.Orders o
        UNION ALL
        SELECT N'Stock', COALESCE(l.ReferenceNumber, v.SKU),
               CONCAT(v.SKU, N' - ', l.ChangeType, N' ',
                   CASE WHEN l.QuantityChanged > 0 THEN N'+' ELSE N'' END, l.QuantityChanged),
               COALESCE(NULLIF(CONCAT(u.FirstName, N' ', u.LastName), N' '), N'System'), l.CreatedAt
        FROM dbo.StockAuditLogs l
        JOIN dbo.ProductVariants v ON v.Id = l.VariantId
        LEFT JOIN dbo.Users u ON u.Id = l.UserId
    ) activity
    ORDER BY CreatedAt DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSellableVariants @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.Id AS VariantId, v.SKU, p.Name AS ProductName, b.Name AS Brand,
           c.Color, v.Size, i.CurrentStock - i.ReservedStock AS AvailableStock,
           CONVERT(DECIMAL(18,2), (p.BasePrice + v.PriceAdjustment) * (1 - p.DiscountPercentage / 100.0)) AS UnitPrice
    FROM dbo.ProductVariants v JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE p.IsActive = 1 AND v.IsActive = 1
      AND (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%' OR v.SKU LIKE N'%' + @Search + N'%')
    ORDER BY p.Name, c.Color, v.Size;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminOrders
    @Search NVARCHAR(100) = NULL,
    @Status NVARCHAR(50) = NULL,
    @Source NVARCHAR(30) = NULL,
    @Limit INT = 100,
    @OrderDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) o.Id, o.OrderNumber, o.CustomerName, o.CustomerEmail, o.CustomerPhone,
           o.OrderSource, o.Status, o.TotalAmount, o.CreatedAt,
           (SELECT COUNT(*) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id) AS ItemCount,
           (SELECT TOP 1 p.Status FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS PaymentStatus
    FROM dbo.Orders o
    WHERE (@Status IS NULL OR o.Status = @Status)
      AND (@Source IS NULL OR o.OrderSource = @Source)
      AND (@OrderDate IS NULL OR (o.CreatedAt >= @OrderDate AND o.CreatedAt < DATEADD(DAY, 1, @OrderDate)))
      AND (@Search IS NULL OR o.OrderNumber LIKE N'%' + @Search + N'%'
           OR o.CustomerName LIKE N'%' + @Search + N'%' OR o.CustomerEmail LIKE N'%' + @Search + N'%')
    ORDER BY o.CreatedAt DESC, o.Id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminUpdateOrderStatus
    @OrderId INT,
    @NewStatus NVARCHAR(50),
    @Notes NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    DECLARE @OldStatus NVARCHAR(50), @Source NVARCHAR(30);
    SELECT @OldStatus = Status, @Source = OrderSource FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE Id = @OrderId;
    IF @OldStatus IS NULL THROW 52001, N'Order not found.', 1;
    IF NOT ((@OldStatus = N'Processing' AND @NewStatus = N'ReadyForPickup')
         OR (@OldStatus = N'ReadyForPickup' AND @NewStatus = N'Completed')
         OR (@OldStatus = N'PendingPayment' AND @NewStatus = N'Cancelled'))
        THROW 52002, N'Invalid order status transition.', 1;
    IF @NewStatus = N'ReadyForPickup' AND @Source = N'ONLINE'
       AND EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND PaymentGateway = N'HitPay')
       AND NOT EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND Status = N'Completed')
        THROW 52003, N'Online payment is not complete.', 1;
    UPDATE dbo.Orders SET Status = @NewStatus, Notes = COALESCE(@Notes, Notes), UpdatedAt = SYSUTCDATETIME() WHERE Id = @OrderId;
    IF @NewStatus = N'Completed'
        UPDATE dbo.Payments SET Status = N'Completed', PaidAt = SYSUTCDATETIME()
        WHERE OrderId = @OrderId AND PaymentGateway = N'Cash' AND Status = N'Pending';
    COMMIT TRANSACTION;
    SELECT @OrderId AS Id, @NewStatus AS Status;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminStockHistory @VariantId INT, @Limit INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) l.Id, l.VariantId, l.ChangeType, l.PreviousStock, l.QuantityChanged,
           l.NewStock, l.ReferenceNumber, l.Notes, l.CreatedAt,
           CONCAT(u.FirstName, N' ', u.LastName) AS PerformedBy
    FROM dbo.StockAuditLogs l LEFT JOIN dbo.Users u ON u.Id = l.UserId
    WHERE l.VariantId = @VariantId ORDER BY l.CreatedAt DESC, l.Id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminAdjustStock
    @VariantId INT, @QuantityChanged INT, @UserId INT,
    @ReferenceNumber NVARCHAR(100), @Notes NVARCHAR(500), @NewStock INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @QuantityChanged = 0 OR NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
        THROW 52004, N'Nonzero quantity and reason are required.', 1;
    BEGIN TRANSACTION;
    DECLARE @OldStock INT, @Reserved INT, @Reorder INT, @InventoryId INT;
    SELECT @OldStock = CurrentStock, @Reserved = ReservedStock, @Reorder = ReorderPoint, @InventoryId = Id
    FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) WHERE VariantId = @VariantId;
    IF @OldStock IS NULL THROW 52005, N'Inventory not found.', 1;
    SET @NewStock = @OldStock + @QuantityChanged;
    IF @NewStock < @Reserved THROW 52006, N'Adjustment would reduce stock below reserved quantity.', 1;
    UPDATE dbo.Inventories SET CurrentStock = @NewStock, UpdatedAt = SYSUTCDATETIME() WHERE Id = @InventoryId;
    INSERT dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
    VALUES (@VariantId, @UserId, N'ADJUSTMENT', @OldStock, @QuantityChanged, @ReferenceNumber, @Notes);
    IF @NewStock - @Reserved <= @Reorder
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.RestockAlerts WHERE InventoryId = @InventoryId AND IsDismissed = 0)
            UPDATE dbo.RestockAlerts SET Severity = CASE WHEN @NewStock - @Reserved = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
            WHERE InventoryId = @InventoryId AND IsDismissed = 0;
        ELSE
            INSERT dbo.RestockAlerts (InventoryId, Severity)
            VALUES (@InventoryId, CASE WHEN @NewStock - @Reserved = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END);
    END
    ELSE
        UPDATE dbo.RestockAlerts SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
        WHERE InventoryId = @InventoryId AND IsDismissed = 0;
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesReport @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS PaymentCount, ISNULL(SUM(p.Amount), 0) AS Revenue,
           ISNULL(SUM(CASE WHEN o.OrderSource = N'ONLINE' THEN p.Amount ELSE 0 END), 0) AS OnlineRevenue,
           ISNULL(SUM(CASE WHEN o.OrderSource = N'INSTORE_POS' THEN p.Amount ELSE 0 END), 0) AS InStoreRevenue
    FROM dbo.Payments p JOIN dbo.Orders o ON o.Id = p.OrderId
    WHERE p.Status = N'Completed' AND p.PaidAt >= @StartDate AND p.PaidAt < @EndDate;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesDaily @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(DATE, p.PaidAt) AS SalesDate, COUNT(*) AS PaymentCount, SUM(p.Amount) AS Revenue
    FROM dbo.Payments p WHERE p.Status = N'Completed' AND p.PaidAt >= @StartDate AND p.PaidAt < @EndDate
    GROUP BY CONVERT(DATE, p.PaidAt) ORDER BY SalesDate;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryReport
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.Name AS Brand, COUNT(*) AS VariantCount, SUM(i.CurrentStock) AS OnHandStock,
           SUM(i.CurrentStock - i.ReservedStock) AS AvailableStock,
           SUM(CASE WHEN i.IsLowStock = 1 THEN 1 ELSE 0 END) AS LowStockCount
    FROM dbo.Inventories i JOIN dbo.ProductVariants v ON v.Id = i.VariantId
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId JOIN dbo.Brands b ON b.Id = p.BrandId
    GROUP BY b.Name ORDER BY b.Name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminPayments @Limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) p.Id, o.OrderNumber, p.PaymentGateway, p.GatewayReference,
           p.Amount, p.Status, p.PaidAt, p.CreatedAt
    FROM dbo.Payments p JOIN dbo.Orders o ON o.Id = p.OrderId
    ORDER BY p.CreatedAt DESC, p.Id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminWebhookEvents @Limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) Id, HitPayPaymentId, ReferenceNumber, IsSignatureValid,
           ProcessingStatus, ErrorMessage, CreatedAt
    FROM dbo.HitPayWebhookLogs ORDER BY CreatedAt DESC, Id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_LogHitPayWebhook
    @HitPayPaymentId NVARCHAR(100), @ReferenceNumber NVARCHAR(100), @RawPayload NVARCHAR(MAX),
    @SignatureReceived NVARCHAR(256), @IsSignatureValid BIT,
    @ProcessingStatus NVARCHAR(50), @ErrorMessage NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.HitPayWebhookLogs (HitPayPaymentId, ReferenceNumber, RawPayload, SignatureReceived,
        IsSignatureValid, ProcessingStatus, ErrorMessage)
    VALUES (@HitPayPaymentId, @ReferenceNumber, @RawPayload, @SignatureReceived,
        @IsSignatureValid, @ProcessingStatus, @ErrorMessage);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminReviews @Limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) r.Id, p.Name AS ProductName, r.ProductId, r.ReviewerName, r.Rating,
           r.Title, r.Comment, r.IsVerifiedPurchase, r.IsHidden, r.CreatedAt,
           (SELECT COUNT(*) FROM dbo.ReviewReports rr WHERE rr.ReviewId = r.Id) AS ReportCount
    FROM dbo.ProductReviews r JOIN dbo.Products p ON p.Id = r.ProductId
    ORDER BY (SELECT COUNT(*) FROM dbo.ReviewReports rr WHERE rr.ReviewId = r.Id) DESC, r.CreatedAt DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminModerateReview @ReviewId INT, @IsHidden BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ProductReviews SET IsHidden = @IsHidden WHERE Id = @ReviewId;
    IF @@ROWCOUNT = 0 THROW 52007, N'Review not found.', 1;
    SELECT @ReviewId AS Id, @IsHidden AS IsHidden;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminUsers @Limit INT = 200
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) u.Id, u.FirstName, u.LastName, u.Email, u.PhoneNumber,
           r.Name AS Role, u.IsActive, u.CreatedAt
    FROM dbo.Users u JOIN dbo.Roles r ON r.Id = u.RoleId
    ORDER BY u.CreatedAt DESC, u.Id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminUpdateUser
    @UserId INT, @FirstName NVARCHAR(100), @LastName NVARCHAR(100),
    @PhoneNumber NVARCHAR(30), @RoleName NVARCHAR(50), @IsActive BIT, @ActorUserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@FirstName)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@LastName)), N'') IS NULL
        THROW 52008, N'First and last name are required.', 1;
    BEGIN TRANSACTION;
    DECLARE @RoleId INT, @OldRole NVARCHAR(50), @OldActive BIT;
    SELECT @RoleId = Id FROM dbo.Roles WHERE Name = @RoleName;
    SELECT @OldRole = r.Name, @OldActive = u.IsActive
    FROM dbo.Users u WITH (UPDLOCK, ROWLOCK) JOIN dbo.Roles r ON r.Id = u.RoleId WHERE u.Id = @UserId;
    IF @RoleId IS NULL OR @OldRole IS NULL THROW 52009, N'User or role not found.', 1;
    IF @UserId = @ActorUserId AND (@RoleName <> N'Admin' OR @IsActive = 0)
        THROW 52010, N'You cannot remove your own admin access.', 1;
    IF @OldRole = N'Admin' AND @OldActive = 1 AND (@RoleName <> N'Admin' OR @IsActive = 0)
       AND (SELECT COUNT(*) FROM dbo.Users u JOIN dbo.Roles r ON r.Id = u.RoleId WHERE r.Name = N'Admin' AND u.IsActive = 1) <= 1
        THROW 52011, N'At least one active admin is required.', 1;
    UPDATE dbo.Users SET FirstName = LTRIM(RTRIM(@FirstName)), LastName = LTRIM(RTRIM(@LastName)),
        FullName = CONCAT(LTRIM(RTRIM(@FirstName)), N' ', LTRIM(RTRIM(@LastName))),
        PhoneNumber = @PhoneNumber, RoleId = @RoleId, IsActive = @IsActive, UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @UserId;
    COMMIT TRANSACTION;
    SELECT @UserId AS Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryProducts
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL,
    @StockStatus NVARCHAR(50) = 'all'
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    IF @Brand = 'all' SET @Brand = NULL;
    IF @Category = 'all' SET @Category = NULL;
    IF @StockStatus IS NULL OR LTRIM(RTRIM(@StockStatus)) = '' SET @StockStatus = 'all';

    SELECT 
        p.Id AS ProductId,
        p.Name AS ProductName,
        p.Slug,
        b.Id AS BrandId,
        b.Name AS BrandName,
        c.Id AS CategoryId,
        c.Name AS CategoryName,
        p.RidingStyle,
        p.BasePrice,
        p.DiscountPercentage,
        CAST(p.BasePrice * (1.0 - (p.DiscountPercentage / 100.0)) AS DECIMAL(18,2)) AS EffectivePrice,
        p.MainImageUrl,
        p.IsActive,
        ISNULL(SUM(i.CurrentStock), 0) AS TotalStock,
        ISNULL(SUM(i.ReservedStock), 0) AS ReservedStock,
        ISNULL(SUM(i.CurrentStock), 0) - ISNULL(SUM(i.ReservedStock), 0) AS AvailableStock,
        COUNT(DISTINCT pv.Id) AS VariantCount,
        ISNULL(MIN(pv.SKU), N'HC-DEFAULT') AS SampleSKU,
        CASE 
            WHEN ISNULL(SUM(i.CurrentStock), 0) <= 0 THEN 'out_of_stock'
            WHEN ISNULL(SUM(i.CurrentStock), 0) <= 15 THEN 'low_stock'
            ELSE 'in_stock'
        END AS StockStatus
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    LEFT JOIN dbo.ProductColors pc ON pc.ProductId = p.Id
    LEFT JOIN dbo.ProductVariants pv ON pv.ProductColorId = pc.Id AND pv.IsActive = 1
    LEFT JOIN dbo.Inventories i ON i.VariantId = pv.Id
    WHERE (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%' OR b.Name LIKE N'%' + @Search + N'%' OR pv.SKU LIKE N'%' + @Search + N'%')
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR c.Name = @Category OR c.Slug = @Category)
    GROUP BY p.Id, p.Name, p.Slug, b.Id, b.Name, c.Id, c.Name, p.RidingStyle, p.BasePrice, p.DiscountPercentage, p.MainImageUrl, p.IsActive
    HAVING (@StockStatus = 'all')
        OR (@StockStatus = 'in_stock' AND ISNULL(SUM(i.CurrentStock), 0) > 15)
        OR (@StockStatus = 'low_stock' AND ISNULL(SUM(i.CurrentStock), 0) > 0 AND ISNULL(SUM(i.CurrentStock), 0) <= 15)
        OR (@StockStatus = 'out_of_stock' AND ISNULL(SUM(i.CurrentStock), 0) <= 0)
    ORDER BY p.Id ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryVariants
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL,
    @StockStatus NVARCHAR(50) = 'all'
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    IF @Brand = 'all' SET @Brand = NULL;
    IF @Category = 'all' SET @Category = NULL;
    IF @StockStatus IS NULL OR LTRIM(RTRIM(@StockStatus)) = '' SET @StockStatus = 'all';

    SELECT 
        v.Id AS VariantId,
        p.Id AS ProductId,
        b.Name AS BrandName,
        p.Name AS ProductName,
        cat.Name AS CategoryName,
        c.Color,
        c.ColorHex,
        v.Size,
        ISNULL(i.CurrentStock, 0) AS CurrentStock,
        ISNULL(i.ReservedStock, 0) AS ReservedStock,
        ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) AS AvailableStock,
        ISNULL(i.ReorderPoint, 3) AS ReorderPoint,
        CONVERT(DECIMAL(18,2), (p.BasePrice + v.PriceAdjustment) * (1 - p.DiscountPercentage / 100.0)) AS EffectivePrice,
        v.SKU,
        p.MainImageUrl,
        CASE 
            WHEN ISNULL(i.CurrentStock, 0) <= 0 THEN 'out_of_stock'
            WHEN ISNULL(i.CurrentStock, 0) <= ISNULL(i.ReorderPoint, 3) THEN 'low_stock'
            ELSE 'in_stock'
        END AS StockStatus
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE v.IsActive = 1 AND p.IsActive = 1
      AND (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%' OR b.Name LIKE N'%' + @Search + N'%' OR v.SKU LIKE N'%' + @Search + N'%' OR c.Color LIKE N'%' + @Search + N'%')
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR cat.Name = @Category OR cat.Slug = @Category)
      AND (
          (@StockStatus = 'all')
          OR (@StockStatus = 'in_stock' AND ISNULL(i.CurrentStock, 0) > ISNULL(i.ReorderPoint, 3))
          OR (@StockStatus = 'low_stock' AND ISNULL(i.CurrentStock, 0) > 0 AND ISNULL(i.CurrentStock, 0) <= ISNULL(i.ReorderPoint, 3))
          OR (@StockStatus = 'out_of_stock' AND ISNULL(i.CurrentStock, 0) <= 0)
      )
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminGlobalSearch
    @Query NVARCHAR(100),
    @Limit INT = 8
AS
BEGIN
    SET NOCOUNT ON;
    SET @Query = LTRIM(RTRIM(@Query));
    IF @Query IS NULL OR LEN(@Query) < 1
    BEGIN
        SELECT TOP 0 '' AS Category, '' AS Title, '' AS Subtitle, '' AS Url, '' AS Badge;
        RETURN;
    END;

    -- 1. Helmets / Variants
    SELECT TOP (@Limit)
        'Inventory' AS Category,
        CONCAT(b.Name, ' ', p.Name) AS Title,
        CONCAT(c.Color, ' • Size ', v.Size, ' • Stock: ', RIGHT('000' + CAST(ISNULL(i.CurrentStock,0) AS VARCHAR(10)), 3), ' • SKU: ', v.SKU) AS Subtitle,
        CONCAT('/Admin/Inventory.aspx?q=', v.SKU) AS Url,
        CASE WHEN ISNULL(i.CurrentStock,0) <= 0 THEN 'Out of Stock' WHEN ISNULL(i.CurrentStock,0) <= ISNULL(i.ReorderPoint,3) THEN 'Low Stock' ELSE 'In Stock' END AS Badge
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE p.Name LIKE '%' + @Query + '%'
       OR b.Name LIKE '%' + @Query + '%'
       OR v.SKU LIKE '%' + @Query + '%'
       OR c.Color LIKE '%' + @Query + '%'

    UNION ALL

    -- 2. Orders
    SELECT TOP (@Limit)
        'Orders' AS Category,
        CONCAT(o.OrderNumber, ' — ', o.CustomerName) AS Title,
        CONCAT('₱', FORMAT(o.TotalAmount, 'N2'), ' • ', o.Status, ' • ', o.OrderSource) AS Subtitle,
        CONCAT('/Admin/Orders.aspx?q=', o.OrderNumber) AS Url,
        o.Status AS Badge
    FROM dbo.Orders o
    WHERE o.OrderNumber LIKE '%' + @Query + '%'
       OR o.CustomerName LIKE '%' + @Query + '%'
       OR o.CustomerEmail LIKE '%' + @Query + '%'
       OR o.CustomerPhone LIKE '%' + @Query + '%'

    UNION ALL

    -- 3. Users / People
    SELECT TOP (@Limit)
        'Users' AS Category,
        u.FullName AS Title,
        CONCAT(u.Email, ' • ', u.PhoneNumber, ' • Role: ', r.Name) AS Subtitle,
        CONCAT('/Admin/Users.aspx?q=', u.Email) AS Url,
        r.Name AS Badge
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id = u.RoleId
    WHERE u.FullName LIKE '%' + @Query + '%'
       OR u.Email LIKE '%' + @Query + '%'
       OR u.PhoneNumber LIKE '%' + @Query + '%';
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminCreateProductWithVariants
    @CategoryId INT,
    @BrandId INT,
    @Name NVARCHAR(200),
    @Slug NVARCHAR(220),
    @Description NVARCHAR(MAX),
    @RidingStyle NVARCHAR(50),
    @BasePrice DECIMAL(18,2),
    @DiscountPercentage INT,
    @MainImageUrl NVARCHAR(500),
    @VariantsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
       OR @BasePrice < 0 OR @DiscountPercentage NOT BETWEEN 0 AND 100
        THROW 52301, N'Invalid product basic details.', 1;

    BEGIN TRANSACTION;

    INSERT INTO dbo.Products (CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice,
        DiscountPercentage, MainImageUrl, IsFeatured, IsActive)
    VALUES (@CategoryId, @BrandId, @Name, @Slug, @Description, @RidingStyle, @BasePrice,
        @DiscountPercentage, @MainImageUrl, 0, 1);

    DECLARE @ProductId INT = SCOPE_IDENTITY();

    DECLARE @ParsedVariants TABLE (
        Color NVARCHAR(100),
        ColorHex NVARCHAR(255),
        Size NVARCHAR(20),
        SKU NVARCHAR(100),
        PriceAdjustment DECIMAL(18,2),
        Stock INT,
        ReorderPoint INT
    );

    INSERT INTO @ParsedVariants (Color, ColorHex, Size, SKU, PriceAdjustment, Stock, ReorderPoint)
    SELECT 
        JSON_VALUE(value, '$.color'),
        ISNULL(JSON_VALUE(value, '$.colorHex'), '#18181B'),
        JSON_VALUE(value, '$.size'),
        JSON_VALUE(value, '$.sku'),
        ISNULL(TRY_CONVERT(DECIMAL(18,2), JSON_VALUE(value, '$.priceAdj')), 0.00),
        ISNULL(TRY_CONVERT(INT, JSON_VALUE(value, '$.stock')), 10),
        ISNULL(TRY_CONVERT(INT, JSON_VALUE(value, '$.reorder')), 3)
    FROM OPENJSON(@VariantsJson);

    DECLARE @ColorMap TABLE (Color NVARCHAR(100), ColorId INT);
    DECLARE @ColorName NVARCHAR(100), @ColorHex NVARCHAR(255);
    DECLARE cur_colors CURSOR LOCAL FAST_FORWARD FOR 
        SELECT DISTINCT Color, ColorHex FROM @ParsedVariants;
    OPEN cur_colors;
    FETCH NEXT FROM cur_colors INTO @ColorName, @ColorHex;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @ColorId INT;
        INSERT INTO dbo.ProductColors (ProductId, Color, ColorHex, ColorType)
        VALUES (@ProductId, @ColorName, @ColorHex, CASE WHEN @ColorHex LIKE 'linear-gradient%' THEN 'LINEAR_GRADIENT' ELSE 'SOLID' END);
        SET @ColorId = SCOPE_IDENTITY();
        INSERT INTO @ColorMap (Color, ColorId) VALUES (@ColorName, @ColorId);
        FETCH NEXT FROM cur_colors INTO @ColorName, @ColorHex;
    END;
    CLOSE cur_colors;
    DEALLOCATE cur_colors;

    DECLARE @VariantId INT, @Size NVARCHAR(20), @SKU NVARCHAR(100), @Adj DECIMAL(18,2), @Stock INT, @Reorder INT, @MappedColorId INT;
    DECLARE cur_vars CURSOR LOCAL FAST_FORWARD FOR 
        SELECT m.ColorId, v.Size, v.SKU, v.PriceAdjustment, v.Stock, v.ReorderPoint
        FROM @ParsedVariants v
        JOIN @ColorMap m ON m.Color = v.Color;
    OPEN cur_vars;
    FETCH NEXT FROM cur_vars INTO @MappedColorId, @Size, @SKU, @Adj, @Stock, @Reorder;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO dbo.ProductVariants (ProductColorId, SKU, Size, PriceAdjustment, IsActive)
        VALUES (@MappedColorId, @SKU, @Size, @Adj, 1);
        SET @VariantId = SCOPE_IDENTITY();

        INSERT INTO dbo.Inventories (VariantId, CurrentStock, ReservedStock, ReorderPoint, LastRestockedAt)
        VALUES (@VariantId, @Stock, 0, @Reorder, SYSUTCDATETIME());

        IF @Stock > 0
        BEGIN
            INSERT INTO dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
            VALUES (@VariantId, 1, 'RESTOCK', 0, @Stock, 'INIT-CATALOG', 'Initial stock on product creation');
        END;

        FETCH NEXT FROM cur_vars INTO @MappedColorId, @Size, @SKU, @Adj, @Stock, @Reorder;
    END;
    CLOSE cur_vars;
    DEALLOCATE cur_vars;

    COMMIT TRANSACTION;

    SELECT @ProductId AS Id;
END;
GO


