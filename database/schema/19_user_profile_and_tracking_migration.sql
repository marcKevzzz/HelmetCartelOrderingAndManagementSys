-- =====================================================================================
-- 19_user_profile_and_tracking_migration.sql
-- Helmet Cartel Ordering and Management System
-- User Profile Management, Order Tracking, Payment History & Digital Receipts
-- =====================================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

USE HelmetCartelDB;
GO

-- 1. STORED PROCEDURE: sp_UpdateUserProfile
-- Updates user first name, last name, full name, phone number
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

    UPDATE dbo.Users
    SET FirstName = LTRIM(RTRIM(@FirstName)),
        LastName = LTRIM(RTRIM(@LastName)),
        FullName = LTRIM(RTRIM(@FirstName)) + N' ' + LTRIM(RTRIM(@LastName)),
        PhoneNumber = NULLIF(LTRIM(RTRIM(@PhoneNumber)), N''),
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @UserId;

    SELECT 
        u.Id,
        r.Name AS RoleName,
        u.FirstName,
        u.LastName,
        u.FullName,
        u.Email,
        u.PhoneNumber,
        u.CreatedAt
    FROM dbo.Users u
    INNER JOIN dbo.Roles r ON u.RoleId = r.Id
    WHERE u.Id = @UserId;
END;
GO

-- 2. STORED PROCEDURE: sp_ChangeUserPassword
-- Updates password hash and salt after current password verification
IF OBJECT_ID(N'dbo.sp_ChangeUserPassword', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_ChangeUserPassword AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_ChangeUserPassword
    @UserId INT,
    @NewPasswordHash NVARCHAR(512),
    @NewSalt NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1)
        THROW 53004, N'User account not found or inactive.', 1;

    IF @NewPasswordHash IS NULL OR LEN(@NewPasswordHash) = 0
        THROW 53005, N'Password hash is required.', 1;

    UPDATE dbo.Users
    SET PasswordHash = @NewPasswordHash,
        Salt = @NewSalt,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @UserId;

    SELECT 1 AS Success;
END;
GO

-- 3. STORED PROCEDURE: sp_GetUserOrders (Enhanced with tracking, fulfillment, and payment info)
IF OBJECT_ID(N'dbo.sp_GetUserOrders', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_GetUserOrders AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserOrders
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
        ISNULL((
            SELECT TOP 1 p.PaymentGateway 
            FROM dbo.Payments p 
            WHERE p.OrderId = o.Id 
            ORDER BY p.Id DESC
        ), 'HitPay') AS PaymentGateway,
        ISNULL((
            SELECT TOP 1 p.Status 
            FROM dbo.Payments p 
            WHERE p.OrderId = o.Id 
            ORDER BY p.Id DESC
        ), 'Pending') AS PaymentStatus,
        (
            SELECT TOP 1 p.GatewayReference 
            FROM dbo.Payments p 
            WHERE p.OrderId = o.Id 
            ORDER BY p.Id DESC
        ) AS GatewayReference,
        (
            SELECT COUNT(*) 
            FROM dbo.OrderItems oi 
            WHERE oi.OrderId = o.Id
        ) AS ItemCount,
        (
            SELECT STRING_AGG(p.MainImageUrl, ';')
            FROM (
                SELECT TOP 3 p.MainImageUrl
                FROM dbo.OrderItems oi
                JOIN dbo.ProductVariants pv ON oi.VariantId = pv.Id
                JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
                JOIN dbo.Products p ON pc.ProductId = p.Id
                WHERE oi.OrderId = o.Id
                ORDER BY oi.Id ASC
            ) p
        ) AS PreviewImages
    FROM dbo.Orders o
    WHERE o.UserId = @UserId OR (o.UserId IS NULL AND o.CustomerEmail = @UserEmail)
    ORDER BY o.CreatedAt DESC;
END;
GO

-- 4. STORED PROCEDURE: sp_GetUserOrderDetails
-- Multi-result set stored procedure for order tracking & digital receipt rendering
IF OBJECT_ID(N'dbo.sp_GetUserOrderDetails', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_GetUserOrderDetails AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserOrderDetails
    @UserId INT,
    @OrderId INT = NULL,
    @OrderNumber NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserEmail NVARCHAR(256);
    SELECT @UserEmail = Email FROM dbo.Users WHERE Id = @UserId;

    DECLARE @ResolvedId INT;
    IF @OrderId IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE Id = @OrderId AND (UserId = @UserId OR (UserId IS NULL AND CustomerEmail = @UserEmail));
    ELSE IF @OrderNumber IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE OrderNumber = @OrderNumber AND (UserId = @UserId OR (UserId IS NULL AND CustomerEmail = @UserEmail));

    IF @ResolvedId IS NULL
        THROW 53006, N'Order not found or access denied.', 1;

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
        (SELECT TOP 1 p.PaidAt FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS PaidAt
    FROM dbo.Orders o
    WHERE o.Id = @ResolvedId;

    -- Result Set 2: Order Items
    SELECT
        oi.Id,
        oi.OrderId,
        oi.VariantId,
        oi.Quantity,
        oi.UnitPrice,
        oi.TotalPrice,
        p.Name AS ProductName,
        p.Slug AS ProductSlug,
        p.MainImageUrl,
        c.Color,
        v.Size,
        v.SKU
    FROM dbo.OrderItems oi
    INNER JOIN dbo.ProductVariants v ON oi.VariantId = v.Id
    INNER JOIN dbo.ProductColors c ON v.ProductColorId = c.Id
    INNER JOIN dbo.Products p ON c.ProductId = p.Id
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

-- 5. STORED PROCEDURE: sp_GetUserPayments
-- Retrieves complete payment transaction history for a customer
IF OBJECT_ID(N'dbo.sp_GetUserPayments', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_GetUserPayments AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserPayments
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserEmail NVARCHAR(256);
    SELECT @UserEmail = Email FROM dbo.Users WHERE Id = @UserId;

    SELECT 
        py.Id AS PaymentId,
        py.OrderId,
        o.OrderNumber,
        py.PaymentGateway,
        py.GatewayReference,
        py.Amount,
        py.Status AS PaymentStatus,
        py.PaidAt,
        py.CreatedAt AS PaymentCreatedAt,
        o.CustomerName,
        o.CustomerEmail,
        o.ShippingMethod,
        o.TotalAmount AS OrderTotalAmount,
        (SELECT COUNT(*) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id) AS ItemCount
    FROM dbo.Payments py
    INNER JOIN dbo.Orders o ON py.OrderId = o.Id
    WHERE o.UserId = @UserId OR (o.UserId IS NULL AND o.CustomerEmail = @UserEmail)
    ORDER BY ISNULL(py.PaidAt, py.CreatedAt) DESC, py.Id DESC;
END;
GO
