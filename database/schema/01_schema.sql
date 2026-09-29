-- =====================================================================================
-- DATABASE: Helmet Cartel Ordering and Management System
-- SCRIPT: 01_schema.sql - Production Relational Schema Definition
-- ENGINE: Microsoft SQL Server (MSSQL)
-- =====================================================================================

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'HelmetCartelDB')
BEGIN
    CREATE DATABASE HelmetCartelDB;
END
GO

USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================================
-- 0. Fresh database schema. Existing databases use 02_3nf_integrity_migration.sql.
-- =====================================================================================

-- Do not run this fresh-install script on a populated database.

-- =====================================================================================
-- 1. SECURITY & USERS
-- =====================================================================================

CREATE TABLE dbo.Roles (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(50) NOT NULL UNIQUE,
    Description NVARCHAR(255) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Users (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    RoleId INT NOT NULL,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    FullName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(256) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(512) NOT NULL,
    Salt NVARCHAR(128) NOT NULL,
    PhoneNumber NVARCHAR(30) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES dbo.Roles(Id)
);
CREATE INDEX IX_Users_RoleId ON dbo.Users(RoleId);

-- =====================================================================================
-- 2. PRODUCT CATALOG & VARIANTS
-- =====================================================================================

CREATE TABLE dbo.Categories (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Slug NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(500) NULL,
    DisplayOrder INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Brands (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL UNIQUE,
    LogoUrl NVARCHAR(255) NULL,
    Website NVARCHAR(255) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Products (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    CategoryId INT NOT NULL,
    BrandId INT NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    Slug NVARCHAR(220) NOT NULL UNIQUE,
    Description NVARCHAR(MAX) NULL,
    RidingStyle NVARCHAR(50) NOT NULL, -- 'Casual/Urban', 'Sport/Track', 'Touring/Adventure', 'Motocross/Off-Road'
    BasePrice DECIMAL(18,2) NOT NULL CHECK (BasePrice >= 0),
    DiscountPercentage INT NOT NULL DEFAULT 0 CHECK (DiscountPercentage BETWEEN 0 AND 100),
    MainImageUrl NVARCHAR(500) NULL,
    IsFeatured BIT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    CONSTRAINT FK_Products_Categories FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(Id),
    CONSTRAINT FK_Products_Brands FOREIGN KEY (BrandId) REFERENCES dbo.Brands(Id)
);
CREATE INDEX IX_Products_CategoryId ON dbo.Products(CategoryId);
CREATE INDEX IX_Products_BrandId ON dbo.Products(BrandId);
CREATE INDEX IX_Products_RidingStyle ON dbo.Products(RidingStyle);

CREATE TABLE dbo.ProductColors (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    Color NVARCHAR(50) NOT NULL,
    ColorHex NVARCHAR(255) NOT NULL,
    ColorType NVARCHAR(20) NOT NULL DEFAULT N'SOLID',
    GradientAngle INT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ProductColors_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id),
    CONSTRAINT UQ_ProductColors_Product_Color UNIQUE (ProductId, Color),
    CONSTRAINT CK_ProductColors_ColorType CHECK (ColorType IN (N'SOLID', N'LINEAR_GRADIENT')),
    CONSTRAINT CK_ProductColors_GradientAngle CHECK (GradientAngle IS NULL OR GradientAngle BETWEEN 0 AND 359)
);

CREATE TABLE dbo.ProductColorStops (
    ProductColorId INT NOT NULL,
    StopOrder TINYINT NOT NULL CHECK (StopOrder BETWEEN 1 AND 4),
    ColorHex NCHAR(7) NOT NULL,
    CONSTRAINT PK_ProductColorStops PRIMARY KEY (ProductColorId, StopOrder),
    CONSTRAINT FK_ProductColorStops_ProductColors FOREIGN KEY (ProductColorId) REFERENCES dbo.ProductColors(Id) ON DELETE CASCADE,
    CONSTRAINT CK_ProductColorStops_Hex CHECK (ColorHex LIKE N'#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')
);

CREATE TABLE dbo.ProductVariants (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProductColorId INT NOT NULL,
    SKU NVARCHAR(100) NOT NULL UNIQUE,
    Size NVARCHAR(20) NOT NULL,
    PriceAdjustment DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ProductVariants_ProductColors FOREIGN KEY (ProductColorId) REFERENCES dbo.ProductColors(Id),
    CONSTRAINT UQ_ProductVariants_Color_Size UNIQUE (ProductColorId, Size)
);

-- =====================================================================================
-- 3. INVENTORY & REAL-TIME STOCK TRACKING
-- =====================================================================================

CREATE TABLE dbo.Inventories (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    VariantId INT NOT NULL UNIQUE,
    CurrentStock INT NOT NULL CHECK (CurrentStock >= 0), -- Engine-level block against negative stock!
    ReservedStock INT NOT NULL DEFAULT 0 CHECK (ReservedStock >= 0),
    ReorderPoint INT NOT NULL DEFAULT 3 CHECK (ReorderPoint >= 0),
    IsLowStock AS (CASE WHEN CurrentStock - ReservedStock <= ReorderPoint THEN 1 ELSE 0 END) PERSISTED,
    LastRestockedAt DATETIME2 NULL,
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Inventories_ProductVariants FOREIGN KEY (VariantId) REFERENCES dbo.ProductVariants(Id),
    CONSTRAINT CK_Inventories_ReservedWithinStock CHECK (ReservedStock <= CurrentStock)
);
CREATE INDEX IX_Inventories_IsLowStock ON dbo.Inventories(IsLowStock);

CREATE TABLE dbo.StockAuditLogs (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    VariantId INT NOT NULL,
    UserId INT NULL, -- NULL for public online checkout
    ChangeType NVARCHAR(50) NOT NULL, -- 'ONLINE_SALE', 'INSTORE_SALE', 'RESTOCK', 'ADJUSTMENT', 'RETURN'
    PreviousStock INT NOT NULL,
    QuantityChanged INT NOT NULL,
    NewStock AS (PreviousStock + QuantityChanged) PERSISTED,
    ReferenceNumber NVARCHAR(100) NULL, -- Order Number or Supplier Invoice
    Notes NVARCHAR(500) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_StockAuditLogs_ProductVariants FOREIGN KEY (VariantId) REFERENCES dbo.ProductVariants(Id),
    CONSTRAINT FK_StockAuditLogs_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_StockAuditLogs_ChangeType CHECK (ChangeType IN (N'ONLINE_SALE', N'INSTORE_SALE', N'RESTOCK', N'ADJUSTMENT', N'RETURN')),
    CONSTRAINT CK_StockAuditLogs_StockNonnegative CHECK (PreviousStock >= 0 AND NewStock >= 0)
);
CREATE INDEX IX_StockAuditLogs_VariantId_CreatedAt ON dbo.StockAuditLogs(VariantId, CreatedAt DESC);

CREATE TABLE dbo.RestockAlerts (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    InventoryId INT NOT NULL,
    Severity NVARCHAR(20) NOT NULL, -- 'LOW_STOCK', 'CRITICAL_ZERO'
    IsDismissed BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    DismissedAt DATETIME2 NULL,
    CONSTRAINT FK_RestockAlerts_Inventories FOREIGN KEY (InventoryId) REFERENCES dbo.Inventories(Id),
    CONSTRAINT CK_RestockAlerts_Severity CHECK (Severity IN (N'LOW_STOCK', N'CRITICAL_ZERO'))
);
CREATE UNIQUE INDEX UX_RestockAlerts_OpenInventory ON dbo.RestockAlerts(InventoryId) WHERE IsDismissed = 0;

-- =====================================================================================
-- 4. ORDERS, PAYMENTS & HITPAY INTEGRATION
-- =====================================================================================

CREATE TABLE dbo.Orders (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    OrderNumber NVARCHAR(50) NOT NULL UNIQUE, -- HC-YYYYMMDD-XXXX
    UserId INT NULL, -- NULL for Guest Checkout
    CustomerName NVARCHAR(100) NOT NULL,
    CustomerEmail NVARCHAR(256) NOT NULL,
    CustomerPhone NVARCHAR(30) NOT NULL,
    OrderSource NVARCHAR(30) NOT NULL, -- 'ONLINE', 'INSTORE_POS'
    Status NVARCHAR(50) NOT NULL, -- 'PendingPayment', 'Processing', 'ReadyForPickup', 'Completed', 'Cancelled'
    Subtotal DECIMAL(18,2) NOT NULL CHECK (Subtotal >= 0),
    DiscountAmount DECIMAL(18,2) NOT NULL DEFAULT 0.00 CHECK (DiscountAmount >= 0),
    TotalAmount AS CONVERT(DECIMAL(18,2), Subtotal - DiscountAmount) PERSISTED,
    Notes NVARCHAR(500) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    CONSTRAINT FK_Orders_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_Orders_Source CHECK (OrderSource IN (N'ONLINE', N'INSTORE_POS')),
    CONSTRAINT CK_Orders_Status CHECK (Status IN (N'PendingPayment', N'Processing', N'ReadyForPickup', N'Completed', N'Cancelled')),
    CONSTRAINT CK_Orders_Amounts CHECK (DiscountAmount <= Subtotal)
);
CREATE INDEX IX_Orders_Status ON dbo.Orders(Status);
CREATE INDEX IX_Orders_CreatedAt ON dbo.Orders(CreatedAt DESC);

CREATE TABLE dbo.OrderItems (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    OrderId INT NOT NULL,
    VariantId INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(18,2) NOT NULL CHECK (UnitPrice >= 0),
    TotalPrice AS CONVERT(DECIMAL(18,2), Quantity * UnitPrice) PERSISTED,
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_ProductVariants FOREIGN KEY (VariantId) REFERENCES dbo.ProductVariants(Id)
);
CREATE INDEX IX_OrderItems_OrderId ON dbo.OrderItems(OrderId);
CREATE INDEX IX_OrderItems_VariantId_OrderId ON dbo.OrderItems(VariantId, OrderId);

CREATE TABLE dbo.Payments (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    OrderId INT NOT NULL,
    PaymentGateway NVARCHAR(50) NOT NULL, -- 'HitPay', 'Cash', 'Card_POS'
    GatewayReference NVARCHAR(100) NULL,
    Amount DECIMAL(18,2) NOT NULL CHECK (Amount >= 0),
    Status NVARCHAR(50) NOT NULL, -- 'Pending', 'Completed', 'Failed', 'Refunded'
    PaidAt DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Payments_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id),
    CONSTRAINT CK_Payments_Gateway CHECK (PaymentGateway IN (N'HitPay', N'Cash', N'Card_POS')),
    CONSTRAINT CK_Payments_Status CHECK (Status IN (N'Pending', N'Completed', N'Failed', N'Refunded'))
);
CREATE INDEX IX_Payments_OrderId ON dbo.Payments(OrderId);
CREATE UNIQUE INDEX UX_Payments_GatewayReference ON dbo.Payments(PaymentGateway, GatewayReference) WHERE GatewayReference IS NOT NULL;

CREATE TABLE dbo.HitPayWebhookLogs (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    HitPayPaymentId NVARCHAR(100) NULL,
    ReferenceNumber NVARCHAR(100) NULL,
    RawPayload NVARCHAR(MAX) NOT NULL,
    SignatureReceived NVARCHAR(256) NULL,
    IsSignatureValid BIT NOT NULL,
    ProcessingStatus NVARCHAR(50) NOT NULL, -- 'Processed', 'Rejected', 'Duplicate'
    ErrorMessage NVARCHAR(1000) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_HitPayWebhookLogs_ProcessingStatus CHECK (ProcessingStatus IN (N'Processed', N'Rejected', N'Duplicate'))
);
CREATE INDEX IX_HitPayWebhookLogs_ReferenceNumber ON dbo.HitPayWebhookLogs(ReferenceNumber);
GO

-- =====================================================================================
-- 5. REVIEWS, REPORTS & FAQS
-- =====================================================================================

CREATE TABLE dbo.ProductReviews (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    UserId INT NULL,                           -- Optional link to authenticated account
    OrderId INT NULL,                          -- Optional link for 'Verified Buyer' badge
    ReviewerName NVARCHAR(100) NOT NULL,       -- Display name (e.g. "Juan D.")
    Rating INT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Title NVARCHAR(150) NULL,
    Comment NVARCHAR(MAX) NOT NULL,
    IsVerifiedPurchase BIT NOT NULL DEFAULT 0,
    IsHidden BIT NOT NULL DEFAULT 0,           -- Auto-hidden after three reports
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ProductReviews_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT FK_ProductReviews_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE SET NULL,
    CONSTRAINT FK_ProductReviews_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id) ON DELETE NO ACTION,
    CONSTRAINT CK_ProductReviews_VerifiedLink CHECK (IsVerifiedPurchase = 0 OR OrderId IS NOT NULL)
);
CREATE INDEX IX_ProductReviews_ProductId_CreatedAt ON dbo.ProductReviews(ProductId, CreatedAt DESC);

CREATE TABLE dbo.ReviewReports (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ReviewId INT NOT NULL,
    UserId INT NULL,                           -- User who reported (or NULL if guest)
    IpAddress NVARCHAR(45) NULL,               -- IP address tracking
    Reason NVARCHAR(50) NOT NULL,              -- 'SPAM', 'OFFENSIVE', 'IRRELEVANT', 'FAKE'
    Notes NVARCHAR(255) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ReviewReports_ProductReviews FOREIGN KEY (ReviewId) REFERENCES dbo.ProductReviews(Id) ON DELETE CASCADE,
    CONSTRAINT FK_ReviewReports_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION,
    CONSTRAINT CK_ReviewReports_Reason CHECK (Reason IN (N'SPAM', N'OFFENSIVE', N'IRRELEVANT', N'FAKE'))
);
CREATE UNIQUE NONCLUSTERED INDEX UX_ReviewReports_Review_User 
ON dbo.ReviewReports (ReviewId, UserId) 
WHERE UserId IS NOT NULL;
CREATE INDEX IX_ReviewReports_ReviewId ON dbo.ReviewReports(ReviewId);

CREATE TABLE dbo.Faqs (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NULL,                        -- NULL = General store FAQ; Set = Specific helmet Q&A
    Question NVARCHAR(300) NOT NULL,
    Answer NVARCHAR(MAX) NOT NULL,
    DisplayOrder INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Faqs_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE
);
CREATE INDEX IX_Faqs_DisplayOrder ON dbo.Faqs(DisplayOrder ASC);
CREATE INDEX IX_Faqs_ProductId ON dbo.Faqs(ProductId);
GO
