SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW dbo.v_SettledOrderRevenue AS
SELECT o.Id AS OrderId, o.OrderSource, paid.PaidAt,
    CONVERT(DECIMAL(18,2), CASE WHEN o.Subtotal - o.DiscountAmount > ISNULL(refunds.Amount, 0)
        THEN o.Subtotal - o.DiscountAmount - ISNULL(refunds.Amount, 0) ELSE 0 END) AS Revenue
FROM dbo.Orders o
JOIN (SELECT OrderId, MAX(PaidAt) AS PaidAt FROM dbo.Payments WHERE Status = N'Completed' GROUP BY OrderId) paid ON paid.OrderId = o.Id
OUTER APPLY (SELECT SUM(rr.RefundAmount) AS Amount FROM dbo.ReturnRequests rr
    WHERE rr.OrderId = o.Id AND rr.RequestType = N'RETURN' AND rr.ResolutionType = N'REFUND' AND rr.Status = N'Completed') refunds
WHERE o.Status IN (N'Completed', N'Delivered');
GO

CREATE OR ALTER VIEW dbo.v_SettledSalesLines AS
SELECT oi.OrderId, pv.Id AS VariantId, p.Id AS ProductId, p.Name AS ProductName,
    b.Id AS BrandId, b.Name AS BrandName, c.Id AS CategoryId, c.Name AS CategoryName, settled.PaidAt,
    CASE WHEN refunds.HasReturn = 1 THEN 0 ELSE oi.Quantity END AS UnitsSold,
    CONVERT(DECIMAL(28,8), CASE WHEN allocation.Amount > ISNULL(refunds.Amount, 0)
        THEN allocation.Amount - ISNULL(refunds.Amount, 0) ELSE 0 END) AS Revenue
FROM dbo.OrderItems oi JOIN dbo.Orders o ON o.Id = oi.OrderId
JOIN dbo.v_SettledOrderRevenue settled ON settled.OrderId = o.Id
JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
JOIN dbo.Products p ON p.Id = pc.ProductId
JOIN dbo.Brands b ON b.Id = p.BrandId JOIN dbo.Categories c ON c.Id = p.CategoryId
CROSS APPLY (SELECT CONVERT(DECIMAL(28,8), oi.TotalPrice) * (o.Subtotal - o.DiscountAmount) / NULLIF(o.Subtotal, 0) AS Amount) allocation
OUTER APPLY (SELECT SUM(rr.RefundAmount) AS Amount, MAX(1) AS HasReturn FROM dbo.ReturnRequests rr
    WHERE rr.OrderItemId = oi.Id AND rr.RequestType = N'RETURN' AND rr.ResolutionType = N'REFUND' AND rr.Status = N'Completed') refunds;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesReport @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS PaymentCount, ISNULL(SUM(Revenue), 0) AS Revenue,
        ISNULL(SUM(CASE WHEN OrderSource = N'ONLINE' THEN Revenue ELSE 0 END), 0) AS OnlineRevenue,
        ISNULL(SUM(CASE WHEN OrderSource = N'INSTORE_POS' THEN Revenue ELSE 0 END), 0) AS InStoreRevenue
    FROM dbo.v_SettledOrderRevenue WHERE PaidAt >= @StartDate AND PaidAt < @EndDate;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesDaily @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(DATE, PaidAt) AS SalesDate, COUNT(*) AS PaymentCount, SUM(Revenue) AS Revenue
    FROM dbo.v_SettledOrderRevenue WHERE PaidAt >= @StartDate AND PaidAt < @EndDate
    GROUP BY CONVERT(DATE, PaidAt) ORDER BY SalesDate;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesHourly @TargetDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DATEPART(HOUR, PaidAt) AS SaleHour, COUNT(*) AS OrderCount, SUM(Revenue) AS Revenue
    FROM dbo.v_SettledOrderRevenue WHERE PaidAt >= @TargetDate AND PaidAt < DATEADD(DAY, 1, @TargetDate)
    GROUP BY DATEPART(HOUR, PaidAt) ORDER BY SaleHour;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesPerformance @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProductId, ProductName, BrandId, BrandName, CategoryId, CategoryName,
        SUM(UnitsSold) AS UnitsSold, COUNT(DISTINCT OrderId) AS OrderCount,
        CONVERT(DECIMAL(18,2), SUM(Revenue)) AS Revenue,
        CONVERT(DECIMAL(18,2), SUM(Revenue) / NULLIF(SUM(UnitsSold), 0)) AS AverageSellingPrice
    FROM dbo.v_SettledSalesLines WHERE PaidAt >= @StartDate AND PaidAt < @EndDate
    GROUP BY ProductId, ProductName, BrandId, BrandName, CategoryId, CategoryName
    ORDER BY UnitsSold DESC, Revenue DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesByBrandAndCategory @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT BrandName AS DimensionName, SUM(UnitsSold) AS UnitsSold, COUNT(DISTINCT OrderId) AS OrderCount,
        CONVERT(DECIMAL(18,2), SUM(Revenue)) AS Revenue,
        ISNULL(CONVERT(DECIMAL(18,2), SUM(Revenue) / NULLIF(SUM(UnitsSold), 0)), 0) AS AverageUnitPrice
    FROM dbo.v_SettledSalesLines WHERE PaidAt >= @StartDate AND PaidAt < @EndDate
    GROUP BY BrandName ORDER BY UnitsSold DESC, Revenue DESC;
    SELECT CategoryName AS DimensionName, SUM(UnitsSold) AS UnitsSold, COUNT(DISTINCT OrderId) AS OrderCount,
        CONVERT(DECIMAL(18,2), SUM(Revenue)) AS Revenue,
        ISNULL(CONVERT(DECIMAL(18,2), SUM(Revenue) / NULLIF(SUM(UnitsSold), 0)), 0) AS AverageUnitPrice
    FROM dbo.v_SettledSalesLines WHERE PaidAt >= @StartDate AND PaidAt < @EndDate
    GROUP BY CategoryName ORDER BY UnitsSold DESC, Revenue DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminProcessReturnRequest
    @RmaId INT, @NewStatus NVARCHAR(30), @ResolutionType NVARCHAR(30) = NULL,
    @RefundAmount DECIMAL(18,2) = NULL, @RestockItem BIT = 0, @AdminNotes NVARCHAR(1000) = NULL,
    @ProcessedBy INT = NULL, @Success BIT OUTPUT, @ErrorMessage NVARCHAR(255) OUTPUT,
    @ExchangeVariantId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Users u JOIN dbo.Roles r ON r.Id = u.RoleId
            WHERE u.Id = @ProcessedBy AND u.IsActive = 1 AND r.Name IN (N'Admin', N'Staff'))
            THROW 55010, N'Staff authorization is required.', 1;
        DECLARE @OldStatus NVARCHAR(30), @Type NVARCHAR(20), @ItemId INT, @OrderId INT, @Restocked BIT,
            @Number NVARCHAR(30), @VariantId INT, @ReplacementId INT, @Quantity INT, @OldStock INT, @NetItem DECIMAL(18,2);
        SELECT @OldStatus = Status, @Type = RequestType, @ItemId = OrderItemId, @OrderId = OrderId,
            @Restocked = Restocked, @Number = RmaNumber, @ReplacementId = ExchangeVariantId
        FROM dbo.ReturnRequests WITH (UPDLOCK, ROWLOCK) WHERE Id = @RmaId;
        IF @OldStatus IS NULL THROW 55011, N'Return request not found.', 1;
        SET @ReplacementId = COALESCE(@ExchangeVariantId, @ReplacementId);
        IF NOT ((@OldStatus = N'Pending' AND @NewStatus IN (N'Approved', N'Rejected', N'Cancelled')) OR
            (@OldStatus = N'Approved' AND @NewStatus IN (N'Received', N'Rejected', N'Cancelled')) OR
            (@OldStatus = N'Received' AND @NewStatus IN (N'Completed', N'Rejected', N'Cancelled')))
            THROW 55012, N'Approve and receive the item before completing its resolution.', 1;
        SELECT @VariantId = oi.VariantId, @Quantity = oi.Quantity,
            @NetItem = ROUND(oi.TotalPrice * (o.Subtotal - o.DiscountAmount) / NULLIF(o.Subtotal, 0), 2)
        FROM dbo.OrderItems oi JOIN dbo.Orders o ON o.Id = oi.OrderId WHERE oi.Id = @ItemId;
        SET @ResolutionType = COALESCE(@ResolutionType, CASE WHEN @Type = N'EXCHANGE' THEN N'REPLACEMENT' ELSE N'REFUND' END);
        IF (@Type = N'EXCHANGE' AND @ResolutionType <> N'REPLACEMENT') OR (@Type = N'RETURN' AND @ResolutionType <> N'REFUND')
            THROW 55013, N'Use replacement for exchanges and refund for returns.', 1;
        SET @RefundAmount = CASE WHEN @Type = N'EXCHANGE' THEN 0 ELSE COALESCE(@RefundAmount, @NetItem, 0) END;
        IF @RefundAmount < 0 OR @RefundAmount > ISNULL(@NetItem, 0)
            THROW 55014, N'Refund cannot exceed the discounted item amount.', 1;
        IF @RestockItem = 1 AND @NewStatus <> N'Completed'
            THROW 55015, N'Restock only after inspection when completing the resolution.', 1;
        IF @NewStatus = N'Completed' AND NULLIF(LTRIM(RTRIM(@AdminNotes)), N'') IS NULL
            THROW 55016, N'Record manual refund or replacement handover confirmation in notes.', 1;
        IF @NewStatus = N'Completed'
        BEGIN
            -- Lock both variants in a stable order for concurrent exchanges.
            SELECT @OldStock = CurrentStock FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
            WHERE VariantId = CASE WHEN @ReplacementId < @VariantId THEN @ReplacementId ELSE @VariantId END;
            IF @ReplacementId IS NOT NULL
                SELECT @OldStock = CurrentStock FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
                WHERE VariantId = CASE WHEN @ReplacementId < @VariantId THEN @VariantId ELSE @ReplacementId END;
            IF @RestockItem = 1 AND @Restocked = 0
            BEGIN
                SELECT @OldStock = CurrentStock FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) WHERE VariantId = @VariantId;
                IF @OldStock IS NULL THROW 55017, N'Return inventory is missing.', 1;
                UPDATE dbo.Inventories WITH (UPDLOCK, ROWLOCK) SET CurrentStock = CurrentStock + @Quantity, UpdatedAt = SYSUTCDATETIME() WHERE VariantId = @VariantId;
                INSERT dbo.StockAuditLogs(VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
                VALUES(@VariantId, @ProcessedBy, N'RETURN', @OldStock, @Quantity, @Number, N'Inspected merchandise returned to sellable inventory.');
                SET @Restocked = 1;
            END;
            IF @Type = N'EXCHANGE'
            BEGIN
                IF @ReplacementId IS NULL THROW 55018, N'Choose a replacement variant before completing the exchange.', 1;
                IF NOT EXISTS (SELECT 1 FROM dbo.v_VisibleProductVariants v JOIN dbo.v_VisibleProductColors pc ON pc.Id = v.ProductColorId
                    JOIN dbo.v_VisibleProducts p ON p.Id = pc.ProductId JOIN dbo.OrderItems oi ON oi.Id = @ItemId
                    WHERE v.Id = @ReplacementId AND dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage,
                        p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) = oi.UnitPrice
                    AND p.Id = (SELECT originalColor.ProductId FROM dbo.ProductVariants original
                        JOIN dbo.ProductColors originalColor ON originalColor.Id = original.ProductColorId WHERE original.Id = @VariantId))
                    THROW 55019, N'This academic workflow supports equal-price replacements only.', 1;
                SELECT @OldStock = CurrentStock FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) WHERE VariantId = @ReplacementId;
                UPDATE dbo.Inventories WITH (UPDLOCK, ROWLOCK) SET CurrentStock = CurrentStock - @Quantity, UpdatedAt = SYSUTCDATETIME()
                WHERE VariantId = @ReplacementId AND CurrentStock - ReservedStock >= @Quantity;
                IF @@ROWCOUNT <> 1 THROW 55020, N'Replacement has insufficient available stock.', 1;
                INSERT dbo.StockAuditLogs(VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
                VALUES(@ReplacementId, @ProcessedBy, N'ADJUSTMENT', @OldStock, -@Quantity, @Number, N'Equal-price exchange replacement handed over.');
            END;
        END;
        UPDATE dbo.ReturnRequests SET Status = @NewStatus, ResolutionType = @ResolutionType, RefundAmount = @RefundAmount,
            ExchangeVariantId = CASE WHEN @Type = N'EXCHANGE' THEN @ReplacementId ELSE NULL END,
            Restocked = @Restocked, AdminNotes = @AdminNotes, ProcessedBy = @ProcessedBy, UpdatedAt = SYSUTCDATETIME() WHERE Id = @RmaId;
        IF @NewStatus = N'Completed' AND @ReplacementId IS NOT NULL
        BEGIN
            UPDATE a SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
            FROM dbo.RestockAlerts a JOIN dbo.Inventories i ON i.Id = a.InventoryId
            WHERE i.VariantId = @ReplacementId AND a.IsDismissed = 0 AND i.IsLowStock = 0;
            INSERT dbo.RestockAlerts(InventoryId, Severity)
            SELECT i.Id, CASE WHEN i.CurrentStock - i.ReservedStock <= 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
            FROM dbo.Inventories i WITH (UPDLOCK, ROWLOCK) WHERE i.VariantId = @ReplacementId AND i.IsLowStock = 1
                AND NOT EXISTS (SELECT 1 FROM dbo.RestockAlerts a WITH (UPDLOCK, HOLDLOCK) WHERE a.InventoryId = i.Id AND a.IsDismissed = 0);
        END;
        EXEC dbo.sp_RefreshOrderStockAlerts @OrderId;
        COMMIT TRANSACTION;
        SET @Success = 1; SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0; SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminReturnReplacements @RmaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.Id AS variantId, v.SKU AS sku, pc.Color AS color, v.Size AS size,
        i.CurrentStock - i.ReservedStock AS availableStock
    FROM dbo.ReturnRequests rr JOIN dbo.OrderItems oi ON oi.Id = rr.OrderItemId
    JOIN dbo.ProductVariants original ON original.Id = oi.VariantId
    JOIN dbo.ProductColors originalColor ON originalColor.Id = original.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = originalColor.ProductId
    JOIN dbo.v_VisibleProductColors pc ON pc.ProductId = p.Id
    JOIN dbo.v_VisibleProductVariants v ON v.ProductColorId = pc.Id
    JOIN dbo.v_VisibleInventories i ON i.VariantId = v.Id
    WHERE rr.Id = @RmaId AND rr.RequestType = N'EXCHANGE'
        AND dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage,
            p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) = oi.UnitPrice
    ORDER BY pc.Color, v.Size;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminDashboard
    @IncludeRevenue BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayStart DATETIME2 = CONVERT(DATETIME2, CONVERT(DATE, SYSUTCDATETIME()));
    DECLARE @TomorrowStart DATETIME2 = DATEADD(DAY, 1, @TodayStart);
    DECLARE @YesterdayStart DATETIME2 = DATEADD(DAY, -1, @TodayStart);

    ;WITH StockAtTodayStart AS
    (
        SELECT
            i.Id,
            i.ReservedStock,
            i.ReorderPoint,
            CASE
                WHEN v.CreatedAt >= @TodayStart THEN 0
                ELSE i.CurrentStock - ISNULL(SUM(CASE WHEN l.CreatedAt >= @TodayStart THEN l.QuantityChanged ELSE 0 END), 0)
            END AS PreviousStock
        FROM dbo.v_VisibleInventories i
        JOIN dbo.v_VisibleProductVariants v ON v.Id = i.VariantId
        LEFT JOIN dbo.v_VisibleStockAuditLogs l ON l.VariantId = i.VariantId
        GROUP BY i.Id, i.CurrentStock, i.ReservedStock, i.ReorderPoint, v.CreatedAt
    ),
    OrderSales AS (
        SELECT 
            p.PaidAt,
            -- Merchandise sales exclude shipping and completed manual refunds.
            (o.Subtotal - o.DiscountAmount) - ISNULL(
                (SELECT SUM(ISNULL(rr.RefundAmount, 0.00))
                 FROM dbo.ReturnRequests rr
                 JOIN dbo.OrderItems oi ON rr.OrderItemId = oi.Id
                 WHERE rr.OrderId = o.Id AND rr.RequestType = N'RETURN' AND rr.ResolutionType = N'REFUND' AND rr.Status = N'Completed'), 0.00
            ) AS NetRevenue
        FROM (SELECT OrderId, MAX(PaidAt) AS PaidAt FROM dbo.Payments WHERE Status = N'Completed' GROUP BY OrderId) p
        JOIN dbo.Orders o ON o.Id = p.OrderId
        WHERE 1 = 1
          AND o.Status IN (N'Completed', N'Delivered')
    )
    SELECT
        (SELECT ISNULL(SUM(CurrentStock), 0) FROM dbo.v_VisibleInventories) AS OnHandStock,
        (SELECT ISNULL(SUM(CurrentStock - ReservedStock), 0) FROM dbo.v_VisibleInventories) AS AvailableStock,
        (SELECT COUNT(*) FROM dbo.v_VisibleInventories WHERE IsLowStock = 1) AS LowStockCount,
        (SELECT COUNT(*) FROM dbo.v_VisibleInventories WHERE CurrentStock - ReservedStock = 0) AS OutOfStockCount,
        (SELECT COUNT(*) FROM dbo.Orders WHERE Status IN (N'PendingPayment', N'Processing', N'ReadyForPickup')) AS ActiveOrders,
        (SELECT ISNULL(SUM(PreviousStock), 0) FROM StockAtTodayStart) AS YesterdayOnHandStock,
        (SELECT ISNULL(SUM(CASE WHEN PreviousStock > ReservedStock THEN PreviousStock - ReservedStock ELSE 0 END), 0)
         FROM StockAtTodayStart) AS YesterdayAvailableStock,
        (SELECT COUNT(*) FROM StockAtTodayStart WHERE PreviousStock > 0 AND PreviousStock - ReservedStock <= ReorderPoint) AS YesterdayLowStockCount,
        (SELECT COUNT(*) FROM dbo.Orders WHERE CreatedAt >= @YesterdayStart AND CreatedAt < @TodayStart) AS YesterdayOrdersCount,
        CASE WHEN @IncludeRevenue = 1 THEN
            ISNULL((SELECT SUM(CASE WHEN NetRevenue > 0 THEN NetRevenue ELSE 0.00 END) 
                    FROM OrderSales 
                    WHERE PaidAt >= @TodayStart AND PaidAt < @TomorrowStart), 0.00)
        ELSE NULL END AS TodayRevenue,
        CASE WHEN @IncludeRevenue = 1 THEN
            ISNULL((SELECT SUM(CASE WHEN NetRevenue > 0 THEN NetRevenue ELSE 0.00 END) 
                    FROM OrderSales 
                    WHERE PaidAt >= @YesterdayStart AND PaidAt < @TodayStart), 0.00)
        ELSE NULL END AS YesterdayRevenue;
END;
GO

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
            (SELECT COUNT(*) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id) AS ItemCount,
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

