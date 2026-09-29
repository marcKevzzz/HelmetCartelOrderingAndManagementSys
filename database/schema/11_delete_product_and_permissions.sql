-- =========================================================================
-- Migration 11: Product Deletion, Self-Deactivation Guard, & Trend Baselines
-- =========================================================================

SET NOCOUNT ON;
GO

-- 1. Create Stored Procedure for Safe Product Deletion
CREATE OR ALTER PROCEDURE dbo.sp_AdminDeleteProduct
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Id = @ProductId)
    BEGIN
        THROW 52020, N'Product not found.', 1;
    END

    BEGIN TRANSACTION;

    DECLARE @ProductName NVARCHAR(200);
    SELECT @ProductName = Name FROM dbo.Products WHERE Id = @ProductId;

    -- Check if product variants have historical customer orders
    DECLARE @HasOrders BIT = 0;
    IF EXISTS (
        SELECT 1 
        FROM dbo.OrderItems oi
        JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        WHERE pc.ProductId = @ProductId
    )
    BEGIN
        SET @HasOrders = 1;
    END

    IF @HasOrders = 1
    BEGIN
        -- Soft delete: Deactivate the product and its variants to preserve financial order history
        UPDATE dbo.Products 
        SET IsActive = 0, UpdatedAt = SYSUTCDATETIME() 
        WHERE Id = @ProductId;

        UPDATE pv
        SET pv.IsActive = 0
        FROM dbo.ProductVariants pv
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        WHERE pc.ProductId = @ProductId;

        COMMIT TRANSACTION;

        SELECT 
            @ProductId AS ProductId,
            @ProductName AS ProductName,
            N'SoftDeleted' AS Status,
            N'Product has historical order transactions. It has been deactivated and archived.' AS Message;
    END
    ELSE
    BEGIN
        -- Hard delete: No order history exists, so safely remove child records in strict dependency order
        DELETE FROM dbo.StockAuditLogs 
        WHERE VariantId IN (
            SELECT pv.Id 
            FROM dbo.ProductVariants pv
            JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
            WHERE pc.ProductId = @ProductId
        );

        DELETE FROM dbo.Inventories 
        WHERE VariantId IN (
            SELECT pv.Id 
            FROM dbo.ProductVariants pv
            JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
            WHERE pc.ProductId = @ProductId
        );

        DELETE FROM dbo.ProductDiscounts 
        WHERE ProductId = @ProductId;

        DELETE FROM dbo.ProductGalleryImages 
        WHERE ProductId = @ProductId;

        DELETE FROM dbo.ProductSpecificationValues 
        WHERE ProductId = @ProductId;

        DELETE pv
        FROM dbo.ProductVariants pv
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        WHERE pc.ProductId = @ProductId;

        DELETE FROM dbo.ProductColorStops
        WHERE ProductColorId IN (SELECT Id FROM dbo.ProductColors WHERE ProductId = @ProductId);

        DELETE FROM dbo.ProductColors 
        WHERE ProductId = @ProductId;

        DELETE FROM dbo.Products 
        WHERE Id = @ProductId;

        COMMIT TRANSACTION;

        SELECT 
            @ProductId AS ProductId,
            @ProductName AS ProductName,
            N'Deleted' AS Status,
            N'Product and its configuration were successfully deleted.' AS Message;
    END
END;
GO

-- 2. Enhance dbo.sp_AdminUpdateUser with Clear Self-Deactivation Guard
CREATE OR ALTER PROCEDURE dbo.sp_AdminUpdateUser
    @UserId INT, 
    @FirstName NVARCHAR(100), 
    @LastName NVARCHAR(100),
    @PhoneNumber NVARCHAR(30), 
    @RoleName NVARCHAR(50), 
    @IsActive BIT, 
    @ActorUserId INT
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
    FROM dbo.Users u WITH (UPDLOCK, ROWLOCK) 
    JOIN dbo.Roles r ON r.Id = u.RoleId 
    WHERE u.Id = @UserId;

    IF @RoleId IS NULL OR @OldRole IS NULL 
        THROW 52009, N'User or role not found.', 1;

    -- Strict Self-Deactivation and Self-Demotion Guard
    IF @UserId = @ActorUserId AND (@RoleName <> N'Admin' OR @IsActive = 0)
        THROW 52010, N'You cannot deactivate your own account or revoke your administrative privileges. Self-deactivation is strictly prohibited to prevent lockout.', 1;

    IF @OldRole = N'Admin' AND @OldActive = 1 AND (@RoleName <> N'Admin' OR @IsActive = 0)
       AND (SELECT COUNT(*) FROM dbo.Users u JOIN dbo.Roles r ON r.Id = u.RoleId WHERE r.Name = N'Admin' AND u.IsActive = 1) <= 1
        THROW 52011, N'At least one active administrator is required in the system.', 1;

    UPDATE dbo.Users 
    SET FirstName = LTRIM(RTRIM(@FirstName)), 
        LastName = LTRIM(RTRIM(@LastName)),
        FullName = CONCAT(LTRIM(RTRIM(@FirstName)), N' ', LTRIM(RTRIM(@LastName))),
        PhoneNumber = @PhoneNumber, 
        RoleId = @RoleId, 
        IsActive = @IsActive, 
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @UserId;

    COMMIT TRANSACTION;

    SELECT @UserId AS Id;
END;
GO

-- 3. Enhance dbo.sp_AdminDashboard with Prior Period Baseline Metrics for Trends
CREATE OR ALTER PROCEDURE dbo.sp_AdminDashboard 
    @IncludeRevenue BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayStart DATETIME2 = CONVERT(DATETIME2, CONVERT(DATE, SYSUTCDATETIME()));
    DECLARE @YesterdayStart DATETIME2 = DATEADD(DAY, -1, @TodayStart);

    SELECT
        (SELECT ISNULL(SUM(CurrentStock), 0) FROM dbo.Inventories) AS OnHandStock,
        (SELECT ISNULL(SUM(CurrentStock - ReservedStock), 0) FROM dbo.Inventories) AS AvailableStock,
        (SELECT COUNT(*) FROM dbo.Inventories WHERE IsLowStock = 1) AS LowStockCount,
        (SELECT COUNT(*) FROM dbo.Inventories WHERE CurrentStock - ReservedStock = 0) AS OutOfStockCount,
        (SELECT COUNT(*) FROM dbo.Orders WHERE Status IN (N'PendingPayment', N'Processing', N'ReadyForPickup')) AS ActiveOrders,
        (SELECT COUNT(*) FROM dbo.Orders WHERE CreatedAt >= @YesterdayStart AND CreatedAt < @TodayStart) AS YesterdayOrdersCount,
        CASE WHEN @IncludeRevenue = 1 THEN
            (SELECT ISNULL(SUM(Amount), 0) FROM dbo.Payments WHERE Status = N'Completed' AND PaidAt >= @TodayStart)
        ELSE NULL END AS TodayRevenue,
        CASE WHEN @IncludeRevenue = 1 THEN
            (SELECT ISNULL(SUM(Amount), 0) FROM dbo.Payments WHERE Status = N'Completed' AND PaidAt >= @YesterdayStart AND PaidAt < @TodayStart)
        ELSE NULL END AS YesterdayRevenue;
END;
GO

PRINT 'Migration 11 completed successfully.';
