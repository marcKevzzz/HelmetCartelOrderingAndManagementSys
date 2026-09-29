-- Dynamic admin dashboard and analytics metrics.
-- Run against the intended Helmet Cartel database after migration 12.

CREATE OR ALTER PROCEDURE dbo.sp_AdminDashboard
    @IncludeRevenue BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayStart DATETIME2 = CONVERT(DATETIME2, CONVERT(DATE, SYSUTCDATETIME()));
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
        FROM dbo.Inventories i
        JOIN dbo.ProductVariants v ON v.Id = i.VariantId
        LEFT JOIN dbo.StockAuditLogs l ON l.VariantId = i.VariantId
        GROUP BY i.Id, i.CurrentStock, i.ReservedStock, i.ReorderPoint, v.CreatedAt
    )
    SELECT
        (SELECT ISNULL(SUM(CurrentStock), 0) FROM dbo.Inventories) AS OnHandStock,
        (SELECT ISNULL(SUM(CurrentStock - ReservedStock), 0) FROM dbo.Inventories) AS AvailableStock,
        (SELECT COUNT(*) FROM dbo.Inventories WHERE IsLowStock = 1) AS LowStockCount,
        (SELECT COUNT(*) FROM dbo.Inventories WHERE CurrentStock - ReservedStock = 0) AS OutOfStockCount,
        (SELECT COUNT(*) FROM dbo.Orders WHERE Status IN (N'PendingPayment', N'Processing', N'ReadyForPickup')) AS ActiveOrders,
        (SELECT ISNULL(SUM(PreviousStock), 0) FROM StockAtTodayStart) AS YesterdayOnHandStock,
        (SELECT ISNULL(SUM(CASE WHEN PreviousStock > ReservedStock THEN PreviousStock - ReservedStock ELSE 0 END), 0)
         FROM StockAtTodayStart) AS YesterdayAvailableStock,
        (SELECT COUNT(*) FROM StockAtTodayStart WHERE PreviousStock > 0 AND PreviousStock - ReservedStock <= ReorderPoint) AS YesterdayLowStockCount,
        (SELECT COUNT(*) FROM dbo.Orders WHERE CreatedAt >= @YesterdayStart AND CreatedAt < @TodayStart) AS YesterdayOrdersCount,
        CASE WHEN @IncludeRevenue = 1 THEN
            (SELECT ISNULL(SUM(Amount), 0) FROM dbo.Payments
             WHERE Status = N'Completed' AND PaidAt >= @TodayStart)
        ELSE NULL END AS TodayRevenue,
        CASE WHEN @IncludeRevenue = 1 THEN
            (SELECT ISNULL(SUM(Amount), 0) FROM dbo.Payments
             WHERE Status = N'Completed' AND PaidAt >= @YesterdayStart AND PaidAt < @TodayStart)
        ELSE NULL END AS YesterdayRevenue;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryTrend
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartCutoff DATETIME2 = CONVERT(DATETIME2, CONVERT(DATE, @StartDate));
    DECLARE @EndExclusive DATETIME2 = DATEADD(DAY, 1, CONVERT(DATETIME2, CONVERT(DATE, @EndDate)));

    IF @StartCutoff >= @EndExclusive
        THROW 52130, N'The inventory trend start date must be on or before the end date.', 1;

    ;WITH InventorySnapshots AS
    (
        SELECT
            i.VariantId,
            v.CreatedAt,
            p.IsActive AS ProductIsActive,
            v.IsActive AS VariantIsActive,
            CASE WHEN v.CreatedAt >= @StartCutoff THEN 0
                 ELSE i.CurrentStock - ISNULL(SUM(CASE WHEN l.CreatedAt >= @StartCutoff THEN l.QuantityChanged ELSE 0 END), 0)
            END AS StartStock,
            CASE WHEN v.CreatedAt >= @EndExclusive THEN 0
                 ELSE i.CurrentStock - ISNULL(SUM(CASE WHEN l.CreatedAt >= @EndExclusive THEN l.QuantityChanged ELSE 0 END), 0)
            END AS EndStock
        FROM dbo.Inventories i
        JOIN dbo.ProductVariants v ON v.Id = i.VariantId
        JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = c.ProductId
        LEFT JOIN dbo.StockAuditLogs l ON l.VariantId = i.VariantId
        GROUP BY i.VariantId, i.CurrentStock, v.CreatedAt, p.IsActive, v.IsActive
    )
    SELECT
        CONVERT(INT, ISNULL(SUM(StartStock), 0)) AS StartTotalUnits,
        CONVERT(INT, ISNULL(SUM(EndStock), 0)) AS EndTotalUnits,
        CONVERT(INT, ISNULL(SUM(CASE WHEN CreatedAt < @StartCutoff AND ProductIsActive = 1 AND VariantIsActive = 1 THEN 1 ELSE 0 END), 0)) AS StartActiveSkus,
        CONVERT(INT, ISNULL(SUM(CASE WHEN CreatedAt < @EndExclusive AND ProductIsActive = 1 AND VariantIsActive = 1 THEN 1 ELSE 0 END), 0)) AS EndActiveSkus
    FROM InventorySnapshots;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminAdjustStock
    @VariantId INT,
    @QuantityChanged INT,
    @UserId INT = NULL,
    @ReferenceNumber NVARCHAR(100),
    @Notes NVARCHAR(500),
    @NewStock INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @QuantityChanged <= 0
        THROW 52004, N'Stock In quantity must be a positive integer greater than zero.', 1;
    IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
        THROW 52005, N'A reference note or reason is required for stock addition.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OldStock INT, @Reserved INT, @Reorder INT, @InventoryId INT;
        SELECT
            @OldStock = CurrentStock,
            @Reserved = ReservedStock,
            @Reorder = ReorderPoint,
            @InventoryId = Id
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
        WHERE VariantId = @VariantId;

        IF @OldStock IS NULL
            THROW 52006, N'Inventory record not found for variant.', 1;

        SET @NewStock = @OldStock + @QuantityChanged;

        UPDATE dbo.Inventories
        SET CurrentStock = @NewStock,
            LastRestockedAt = SYSUTCDATETIME(),
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @InventoryId;

        INSERT dbo.StockAuditLogs
            (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
        VALUES
            (@VariantId, @UserId, N'RESTOCK', @OldStock, @QuantityChanged, @ReferenceNumber, @Notes);

        IF @NewStock - @Reserved > @Reorder
        BEGIN
            UPDATE dbo.RestockAlerts
            SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
            WHERE InventoryId = @InventoryId AND IsDismissed = 0;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

PRINT 'Migration 13 completed successfully.';
