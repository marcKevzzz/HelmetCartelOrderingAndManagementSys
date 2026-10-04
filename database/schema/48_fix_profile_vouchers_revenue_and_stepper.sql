-- =====================================================================================
-- 48_fix_profile_vouchers_revenue_and_stepper.sql
-- Fixes:
-- 1. dbo.sp_UpdateUserProfile: Make PhoneNumber optional/preserve existing, validate uniqueness only if changed
-- 2. dbo.sp_PreviewVoucher & dbo.sp_ApplyOrderVoucher: Enforce single-use per customer (email/user)
-- 3. dbo.sp_AdminProcessReturnRequest: Default RefundAmount to item total if null on approval
-- 4. dbo.sp_AdminDashboard: Exclude ShippingFee from revenue, deduct approved return refunds
-- 5. dbo.sp_AdminSalesDaily: Exclude ShippingFee, deduct approved return refunds
-- 6. dbo.sp_AdminSalesHourly: Exclude ShippingFee, deduct approved return refunds
-- 7. dbo.sp_AdminSalesPerformance: Deduct approved return items from units sold and revenue
-- 8. dbo.sp_AdminSalesByBrandAndCategory: Deduct approved return items from units sold and revenue
-- =====================================================================================

USE [HelmetCartelDB];
GO

-- 1. UPDATE STORED PROCEDURE: sp_UpdateUserProfile
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'dbo.sp_UpdateUserProfile', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_UpdateUserProfile AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_UpdateUserProfile
    @UserId INT,
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @PhoneNumber NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1)
        THROW 53001, N'User account not found or inactive.', 1;

    IF @FirstName IS NULL OR LEN(LTRIM(RTRIM(@FirstName))) = 0
        THROW 53002, N'First name is required.', 1;

    IF @LastName IS NULL OR LEN(LTRIM(RTRIM(@LastName))) = 0
        THROW 53003, N'Last name is required.', 1;

    IF @PhoneNumber IS NOT NULL AND LEN(LTRIM(RTRIM(@PhoneNumber))) > 0
    BEGIN
        SET @PhoneNumber = LTRIM(RTRIM(@PhoneNumber));
        IF EXISTS (SELECT 1 FROM dbo.Users WHERE PhoneNumber = @PhoneNumber AND Id <> @UserId)
            THROW 53005, N'This mobile phone number is already registered to another account.', 1;
    END
    ELSE
    BEGIN
        -- Preserve existing phone number if empty/null passed
        SELECT @PhoneNumber = PhoneNumber FROM dbo.Users WHERE Id = @UserId;
    END

    UPDATE dbo.Users
    SET FirstName = LTRIM(RTRIM(@FirstName)),
        LastName = LTRIM(RTRIM(@LastName)),
        PhoneNumber = @PhoneNumber,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @UserId;

    SELECT 
        u.Id,
        r.Name AS RoleName,
        u.FirstName,
        u.LastName,
        CONCAT(u.FirstName, N' ', u.LastName) AS FullName,
        u.Email,
        u.PhoneNumber,
        u.CreatedAt
    FROM dbo.Users u
    INNER JOIN dbo.Roles r ON u.RoleId = r.Id
    WHERE u.Id = @UserId;
END;
GO

-- 2. UPDATE STORED PROCEDURE: sp_PreviewVoucher (Enforce One-Time Use Per Customer)
CREATE OR ALTER PROCEDURE dbo.sp_PreviewVoucher
    @Code NVARCHAR(30), 
    @Items dbo.SaleLineInput READONLY,
    @CustomerEmail NVARCHAR(255) = NULL,
    @CustomerId INT = NULL
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

    -- Check if this customer has already used this voucher
    IF (@CustomerId IS NOT NULL OR (@CustomerEmail IS NOT NULL AND LEN(LTRIM(RTRIM(@CustomerEmail))) > 0))
    BEGIN
        IF EXISTS (
            SELECT 1 
            FROM dbo.VoucherRedemptions vr
            JOIN dbo.Orders o ON vr.OrderId = o.Id
            WHERE vr.VoucherId = @Id 
              AND vr.ReleasedAt IS NULL
              AND o.Status <> N'Cancelled'
              AND (
                  (@CustomerId IS NOT NULL AND o.UserId = @CustomerId)
                  OR (@CustomerEmail IS NOT NULL AND LEN(LTRIM(RTRIM(@CustomerEmail))) > 0 
                      AND LOWER(LTRIM(RTRIM(o.CustomerEmail))) = LOWER(LTRIM(RTRIM(@CustomerEmail))))
              )
        )
        BEGIN
            THROW 54017, N'You have already used this voucher code. Vouchers are limited to one use per customer.', 1;
        END
    END

    SELECT 
        UPPER(LTRIM(RTRIM(@Code))) AS Code, 
        @Subtotal AS Subtotal,
        @Discount AS DiscountAmount, 
        @Subtotal - @Discount AS DiscountedSubtotal,
        @Type AS DiscountType;
END;
GO

-- 3. UPDATE STORED PROCEDURE: sp_ApplyOrderVoucher (Enforce One-Time Use Per Customer)
CREATE OR ALTER PROCEDURE dbo.sp_ApplyOrderVoucher
    @OrderId INT, 
    @Code NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT = 0 THROW 54008, N'Voucher redemption requires an order transaction.', 1;

    DECLARE @Subtotal DECIMAL(18,2), @Id INT, @Discount DECIMAL(18,2), @Type NVARCHAR(20);
    DECLARE @CustomerId INT, @CustomerEmail NVARCHAR(255);

    SELECT 
        @CustomerId = UserId, 
        @CustomerEmail = LTRIM(RTRIM(CustomerEmail))
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
    WHERE Id = @OrderId AND OrderSource = N'ONLINE' AND Status IN (N'PendingPayment', N'Processing');

    IF @@ROWCOUNT = 0
        THROW 54015, N'This order cannot accept a voucher.', 1;

    IF EXISTS (SELECT 1 FROM dbo.VoucherRedemptions WHERE OrderId = @OrderId)
        THROW 54016, N'This order already has a voucher.', 1;

    SELECT @Subtotal = SUM(TotalPrice) FROM dbo.OrderItems WHERE OrderId = @OrderId;

    EXEC dbo.sp_CalculateVoucher @Code, @Subtotal, 1, @Id OUTPUT, @Discount OUTPUT, @Type OUTPUT;

    -- Strict One-Time Use Per Customer Check
    IF EXISTS (
        SELECT 1 
        FROM dbo.VoucherRedemptions vr
        JOIN dbo.Orders o ON vr.OrderId = o.Id
        WHERE vr.VoucherId = @Id 
          AND vr.OrderId <> @OrderId
          AND vr.ReleasedAt IS NULL
          AND o.Status <> N'Cancelled'
          AND (
              (@CustomerId IS NOT NULL AND o.UserId = @CustomerId)
              OR (@CustomerEmail IS NOT NULL AND LEN(@CustomerEmail) > 0 
                  AND LOWER(LTRIM(RTRIM(o.CustomerEmail))) = LOWER(@CustomerEmail))
          )
    )
    BEGIN
        THROW 54017, N'You have already used this voucher code. Vouchers are limited to one use per customer.', 1;
    END

    IF @Type = N'FREE_SHIPPING'
    BEGIN
        DECLARE @SavedShippingFee DECIMAL(18,2) = 0.00;
        SELECT @SavedShippingFee = ISNULL(ShippingFee, 0.00) FROM dbo.Orders WHERE Id = @OrderId;

        INSERT dbo.VoucherRedemptions(VoucherId, OrderId, DiscountAmount) 
        VALUES (@Id, @OrderId, @SavedShippingFee);

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

-- 4. UPDATE STORED PROCEDURE: sp_AdminProcessReturnRequest (Default RefundAmount if null)
CREATE OR ALTER PROCEDURE dbo.sp_AdminProcessReturnRequest
    @RmaId INT,
    @NewStatus NVARCHAR(30),
    @ResolutionType NVARCHAR(30) = NULL,
    @RefundAmount DECIMAL(18,2) = NULL,
    @RestockItem BIT = 0,
    @AdminNotes NVARCHAR(1000) = NULL,
    @ProcessedBy INT = NULL,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStatus NVARCHAR(30);
        DECLARE @CurrentRestocked BIT;
        DECLARE @OrderItemId INT;
        DECLARE @RmaNumber NVARCHAR(30);
        DECLARE @ItemTotalPrice DECIMAL(18,2);

        SELECT 
            @CurrentStatus = Status,
            @CurrentRestocked = Restocked,
            @OrderItemId = OrderItemId,
            @RmaNumber = RmaNumber
        FROM dbo.ReturnRequests WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @RmaId;

        IF @CurrentStatus IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'RMA Request not found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        SELECT @ItemTotalPrice = TotalPrice FROM dbo.OrderItems WHERE Id = @OrderItemId;

        -- If approving or completing without explicit refund amount, default to item price
        IF (@NewStatus IN (N'Approved', N'Completed')) AND @RefundAmount IS NULL
        BEGIN
            SET @RefundAmount = @ItemTotalPrice;
        END

        -- If restock is requested and not already restocked
        IF @RestockItem = 1 AND @CurrentRestocked = 0
        BEGIN
            DECLARE @VariantId INT;
            DECLARE @Quantity INT;

            SELECT @VariantId = VariantId, @Quantity = Quantity
            FROM dbo.OrderItems
            WHERE Id = @OrderItemId;

            IF @VariantId IS NOT NULL AND @Quantity > 0
            BEGIN
                DECLARE @PrevStock INT;
                SELECT @PrevStock = CurrentStock
                FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
                WHERE VariantId = @VariantId;

                IF @PrevStock IS NOT NULL
                BEGIN
                    -- Increment inventory stock atomically
                    UPDATE dbo.Inventories WITH (UPDLOCK, ROWLOCK)
                    SET CurrentStock = CurrentStock + @Quantity,
                        UpdatedAt = SYSUTCDATETIME()
                    WHERE VariantId = @VariantId;

                    -- Record in StockAuditLogs
                    INSERT INTO dbo.StockAuditLogs (
                        VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes
                    )
                    VALUES (
                        @VariantId, @ProcessedBy, N'RETURN', @PrevStock, @Quantity, @RmaNumber,
                        CONCAT(N'Restocked from RMA: ', @RmaNumber)
                    );

                    SET @CurrentRestocked = 1;
                END
            END
        END

        -- Update ReturnRequest record
        UPDATE dbo.ReturnRequests WITH (UPDLOCK, ROWLOCK)
        SET Status = @NewStatus,
            ResolutionType = ISNULL(@ResolutionType, ResolutionType),
            RefundAmount = ISNULL(@RefundAmount, RefundAmount),
            Restocked = @CurrentRestocked,
            AdminNotes = ISNULL(@AdminNotes, AdminNotes),
            ProcessedBy = ISNULL(@ProcessedBy, ProcessedBy),
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @RmaId;

        SET @Success = 1;
        SET @ErrorMessage = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END;
GO

-- 5. UPDATE STORED PROCEDURE: sp_AdminDashboard (Exclude Delivery Fee, Deduct Approved Returns)
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
            -- Merchandise Sales = (Subtotal - DiscountAmount) - Approved Return Refunds
            (o.Subtotal - o.DiscountAmount) - ISNULL(
                (SELECT SUM(COALESCE(rr.RefundAmount, oi.TotalPrice, 0.00))
                 FROM dbo.ReturnRequests rr
                 JOIN dbo.OrderItems oi ON rr.OrderItemId = oi.Id
                 WHERE rr.OrderId = o.Id AND rr.Status IN (N'Approved', N'Completed')), 0.00
            ) AS NetRevenue
        FROM dbo.Payments p
        JOIN dbo.Orders o ON o.Id = p.OrderId
        WHERE p.Status = N'Completed'
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

-- 6. UPDATE STORED PROCEDURE: sp_AdminSalesDaily (Exclude Delivery Fee, Deduct Approved Returns)
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesDaily 
    @StartDate DATETIME2, 
    @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH OrderSales AS (
        SELECT 
            CONVERT(DATE, p.PaidAt) AS SalesDate,
            o.Id AS OrderId,
            (o.Subtotal - o.DiscountAmount) - ISNULL(
                (SELECT SUM(COALESCE(rr.RefundAmount, oi.TotalPrice, 0.00))
                 FROM dbo.ReturnRequests rr
                 JOIN dbo.OrderItems oi ON rr.OrderItemId = oi.Id
                 WHERE rr.OrderId = o.Id AND rr.Status IN (N'Approved', N'Completed')), 0.00
            ) AS NetMerchandiseRevenue
        FROM dbo.Payments p
        JOIN dbo.Orders o ON o.Id = p.OrderId
        WHERE p.Status = N'Completed'
          AND o.Status IN (N'Completed', N'Delivered')
          AND p.PaidAt >= @StartDate AND p.PaidAt < @EndDate
    )
    SELECT 
        SalesDate, 
        COUNT(DISTINCT OrderId) AS PaymentCount, 
        SUM(CASE WHEN NetMerchandiseRevenue > 0 THEN NetMerchandiseRevenue ELSE 0.00 END) AS Revenue
    FROM OrderSales
    GROUP BY SalesDate 
    ORDER BY SalesDate;
END;
GO

-- 7. UPDATE STORED PROCEDURE: sp_AdminSalesHourly (Exclude Delivery Fee, Deduct Approved Returns)
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesHourly
    @TargetDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DayStart DATETIME2 = CONVERT(DATETIME2, @TargetDate);
    DECLARE @DayEnd DATETIME2 = DATEADD(DAY, 1, @DayStart);

    ;WITH OrderSales AS (
        SELECT 
            DATEPART(HOUR, p.PaidAt) AS SaleHour,
            o.Id AS OrderId,
            (o.Subtotal - o.DiscountAmount) - ISNULL(
                (SELECT SUM(COALESCE(rr.RefundAmount, oi.TotalPrice, 0.00))
                 FROM dbo.ReturnRequests rr
                 JOIN dbo.OrderItems oi ON rr.OrderItemId = oi.Id
                 WHERE rr.OrderId = o.Id AND rr.Status IN (N'Approved', N'Completed')), 0.00
            ) AS NetMerchandiseRevenue
        FROM dbo.Payments p
        JOIN dbo.Orders o ON o.Id = p.OrderId
        WHERE p.Status = N'Completed'
          AND o.Status IN (N'Completed', N'Delivered')
          AND p.PaidAt >= @DayStart AND p.PaidAt < @DayEnd
    )
    SELECT 
        SaleHour,
        COUNT(DISTINCT OrderId) AS OrderCount,
        SUM(CASE WHEN NetMerchandiseRevenue > 0 THEN NetMerchandiseRevenue ELSE 0.00 END) AS Revenue
    FROM OrderSales
    GROUP BY SaleHour
    ORDER BY SaleHour;
END;
GO

-- 8. UPDATE STORED PROCEDURE: sp_AdminSalesPerformance (Deduct Approved Return Items)
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesPerformance
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH LineSales AS (
        SELECT 
            oi.Id AS OrderItemId,
            p.Id AS ProductId,
            p.Name AS ProductName,
            b.Id AS BrandId,
            b.Name AS BrandName,
            c.Id AS CategoryId,
            c.Name AS CategoryName,
            o.Id AS OrderId,
            CASE 
                WHEN EXISTS (SELECT 1 FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id AND rr.Status IN (N'Approved', N'Completed')) 
                THEN 0 
                ELSE oi.Quantity 
            END AS UnitsSold,
            CASE 
                WHEN EXISTS (SELECT 1 FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id AND rr.Status IN (N'Approved', N'Completed')) 
                THEN 0.00 
                ELSE (oi.Quantity * oi.UnitPrice) 
            END AS LineRevenue
        FROM dbo.OrderItems oi
        INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
        INNER JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
        INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        INNER JOIN dbo.Products p ON p.Id = pc.ProductId
        INNER JOIN dbo.Brands b ON b.Id = p.BrandId
        INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
        INNER JOIN
        (
            SELECT OrderId, MAX(PaidAt) AS PaidAt
            FROM dbo.Payments
            WHERE Status = N'Completed' AND PaidAt IS NOT NULL
            GROUP BY OrderId
        ) completed ON completed.OrderId = oi.OrderId
        WHERE o.Status IN (N'Completed', N'Delivered')
          AND completed.PaidAt >= @StartDate
          AND completed.PaidAt < @EndDate
    )
    SELECT 
        ProductId,
        ProductName,
        BrandId,
        BrandName,
        CategoryId,
        CategoryName,
        SUM(UnitsSold) AS UnitsSold,
        COUNT(DISTINCT OrderId) AS OrderCount,
        CONVERT(DECIMAL(18, 2), SUM(LineRevenue)) AS Revenue,
        CONVERT(DECIMAL(18, 2), SUM(LineRevenue) / NULLIF(SUM(UnitsSold), 0)) AS AverageSellingPrice
    FROM LineSales
    GROUP BY ProductId, ProductName, BrandId, BrandName, CategoryId, CategoryName
    ORDER BY UnitsSold DESC, Revenue DESC;
END;
GO

-- 9. UPDATE STORED PROCEDURE: sp_AdminSalesByBrandAndCategory (Deduct Approved Return Items)
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesByBrandAndCategory
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesLines TABLE
    (
        OrderId INT NOT NULL,
        Quantity INT NOT NULL,
        UnitPrice DECIMAL(18, 2) NOT NULL,
        BrandName NVARCHAR(100) NOT NULL,
        CategoryName NVARCHAR(100) NOT NULL
    );

    INSERT @SalesLines (OrderId, Quantity, UnitPrice, BrandName, CategoryName)
    SELECT oi.OrderId,
           CASE 
               WHEN EXISTS (SELECT 1 FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id AND rr.Status IN (N'Approved', N'Completed')) 
               THEN 0 
               ELSE oi.Quantity 
           END AS Quantity,
           oi.UnitPrice,
           b.Name,
           c.Name
    FROM dbo.OrderItems oi
    INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
    INNER JOIN dbo.ProductVariants v ON v.Id = oi.VariantId
    INNER JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = pc.ProductId
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    INNER JOIN
    (
        SELECT OrderId, MAX(PaidAt) AS PaidAt
        FROM dbo.Payments
        WHERE Status = N'Completed'
          AND PaidAt IS NOT NULL
        GROUP BY OrderId
    ) completed ON completed.OrderId = oi.OrderId
    WHERE o.Status IN (N'Completed', N'Delivered')
      AND completed.PaidAt >= @StartDate
      AND completed.PaidAt < @EndDate;

    SELECT BrandName AS DimensionName,
           ISNULL(SUM(Quantity), 0) AS UnitsSold,
           COUNT(DISTINCT OrderId) AS OrderCount,
           ISNULL(CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice)), 0.00) AS Revenue,
           ISNULL(CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice) / NULLIF(SUM(Quantity), 0)), 0.00) AS AverageUnitPrice
    FROM @SalesLines
    GROUP BY BrandName
    ORDER BY UnitsSold DESC, Revenue DESC, BrandName;

    SELECT CategoryName AS DimensionName,
           ISNULL(SUM(Quantity), 0) AS UnitsSold,
           COUNT(DISTINCT OrderId) AS OrderCount,
           ISNULL(CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice)), 0.00) AS Revenue,
           ISNULL(CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice) / NULLIF(SUM(Quantity), 0)), 0.00) AS AverageUnitPrice
    FROM @SalesLines
    GROUP BY CategoryName
    ORDER BY UnitsSold DESC, Revenue DESC, CategoryName;
END;
GO
