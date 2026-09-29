-- Run once on an existing HelmetCartelDB, before deploying revised procedures and seeds.
-- Rerunnable. Preserves existing rows, IDs, prices, and stock.
USE HelmetCartelDB;
GO

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.Products', N'U') IS NULL OR OBJECT_ID(N'dbo.ProductVariants', N'U') IS NULL
        THROW 51000, N'Core catalog tables missing. Run 01_schema.sql on a new database first.', 1;
    IF EXISTS
    (
        SELECT 1 FROM dbo.Payments WHERE GatewayReference IS NOT NULL
        GROUP BY PaymentGateway, GatewayReference HAVING COUNT(*) > 1
    )
        THROW 51009, N'Duplicate payment gateway references. Resolve before migration.', 1;

    IF OBJECT_ID(N'dbo.ReviewReports', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.ReviewReports (
            Id INT IDENTITY(1,1) PRIMARY KEY,
            ReviewId INT NOT NULL,
            UserId INT NULL,
            IpAddress NVARCHAR(45) NULL,
            Reason NVARCHAR(50) NOT NULL,
            Notes NVARCHAR(255) NULL,
            CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
            CONSTRAINT FK_ReviewReports_ProductReviews FOREIGN KEY (ReviewId) REFERENCES dbo.ProductReviews(Id) ON DELETE CASCADE,
            CONSTRAINT FK_ReviewReports_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION,
            CONSTRAINT CK_ReviewReports_Reason CHECK (Reason IN (N'SPAM', N'OFFENSIVE', N'IRRELEVANT', N'FAKE'))
        );
    END;

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.ReviewReports') AND name = N'FK_ReviewReports_Users' AND delete_referential_action <> 0)
        EXEC sys.sp_executesql N'ALTER TABLE dbo.ReviewReports DROP CONSTRAINT FK_ReviewReports_Users;';
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.ReviewReports') AND name = N'FK_ReviewReports_Users')
        EXEC sys.sp_executesql N'ALTER TABLE dbo.ReviewReports WITH CHECK ADD CONSTRAINT FK_ReviewReports_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION;';
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ReviewReports') AND name = N'UX_ReviewReports_Review_User')
        EXEC sys.sp_executesql N'CREATE UNIQUE INDEX UX_ReviewReports_Review_User ON dbo.ReviewReports(ReviewId, UserId) WHERE UserId IS NOT NULL;';
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ReviewReports') AND name = N'IX_ReviewReports_ReviewId')
        EXEC sys.sp_executesql N'CREATE INDEX IX_ReviewReports_ReviewId ON dbo.ReviewReports(ReviewId);';

    IF COL_LENGTH(N'dbo.ProductVariants', N'ProductId') IS NOT NULL
        EXEC sys.sp_executesql N'
            IF EXISTS (SELECT 1 FROM dbo.ProductVariants GROUP BY ProductId, Color HAVING COUNT(DISTINCT ColorHex) > 1)
                THROW 51001, N''One product/color has conflicting hex values. Resolve before migration.'', 1;
        ';

    IF OBJECT_ID(N'dbo.ProductColors', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.ProductColors (
            Id INT IDENTITY(1,1) PRIMARY KEY,
            ProductId INT NOT NULL,
            Color NVARCHAR(50) NOT NULL,
            ColorHex NVARCHAR(10) NOT NULL,
            CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
            CONSTRAINT FK_ProductColors_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id),
            CONSTRAINT UQ_ProductColors_Product_Color UNIQUE (ProductId, Color),
            CONSTRAINT CK_ProductColors_ColorHex CHECK (ColorHex LIKE N'#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')
        );
    END;

    IF COL_LENGTH(N'dbo.ProductVariants', N'ProductId') IS NOT NULL
    BEGIN
        IF COL_LENGTH(N'dbo.ProductVariants', N'ProductColorId') IS NULL
            EXEC sys.sp_executesql N'ALTER TABLE dbo.ProductVariants ADD ProductColorId INT NULL;';

        EXEC sys.sp_executesql N'
            IF EXISTS (
                SELECT 1 FROM dbo.ProductVariants v
                JOIN dbo.ProductColors c ON c.ProductId = v.ProductId AND c.Color = v.Color
                WHERE c.ColorHex <> v.ColorHex
            ) THROW 51007, N''Stored product colors conflict with variant hex values.'', 1;
        ';

        EXEC sys.sp_executesql N'
            INSERT INTO dbo.ProductColors (ProductId, Color, ColorHex)
            SELECT DISTINCT v.ProductId, v.Color, v.ColorHex
            FROM dbo.ProductVariants v
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.ProductColors c
                WHERE c.ProductId = v.ProductId AND c.Color = v.Color
            );
            UPDATE v SET ProductColorId = c.Id
            FROM dbo.ProductVariants v
            JOIN dbo.ProductColors c ON c.ProductId = v.ProductId AND c.Color = v.Color;
        ';

        EXEC sys.sp_executesql N'
            IF EXISTS (SELECT 1 FROM dbo.ProductVariants WHERE ProductColorId IS NULL)
                THROW 51002, N''Unmapped product variant color.'', 1;
            IF EXISTS (SELECT 1 FROM dbo.ProductVariants GROUP BY ProductColorId, Size HAVING COUNT(*) > 1)
                THROW 51003, N''Duplicate product/color/size variants. Resolve before migration.'', 1;
        ';

        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ProductVariants') AND name = N'IX_ProductVariants_ProductId')
            DROP INDEX IX_ProductVariants_ProductId ON dbo.ProductVariants;
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.ProductVariants') AND name = N'FK_ProductVariants_Products')
            ALTER TABLE dbo.ProductVariants DROP CONSTRAINT FK_ProductVariants_Products;

        EXEC sys.sp_executesql N'
            ALTER TABLE dbo.ProductVariants ALTER COLUMN ProductColorId INT NOT NULL;
            ALTER TABLE dbo.ProductVariants DROP COLUMN ProductId, Color, ColorHex;
        ';
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.ProductVariants') AND name = N'FK_ProductVariants_ProductColors')
        EXEC sys.sp_executesql N'ALTER TABLE dbo.ProductVariants ADD CONSTRAINT FK_ProductVariants_ProductColors FOREIGN KEY (ProductColorId) REFERENCES dbo.ProductColors(Id);';
    IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.ProductVariants') AND name = N'UQ_ProductVariants_Color_Size')
        EXEC sys.sp_executesql N'ALTER TABLE dbo.ProductVariants ADD CONSTRAINT UQ_ProductVariants_Color_Size UNIQUE (ProductColorId, Size);';
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ProductVariants') AND name = N'IX_ProductVariants_ProductColorId')
        DROP INDEX IX_ProductVariants_ProductColorId ON dbo.ProductVariants;

    -- Remove cached aggregates. Product procedures now calculate visible review totals.
    IF COL_LENGTH(N'dbo.Products', N'Rating') IS NOT NULL OR COL_LENGTH(N'dbo.Products', N'ReviewCount') IS NOT NULL
    BEGIN
        DECLARE @DropProductsConstraints NVARCHAR(MAX) = N'';
        SELECT @DropProductsConstraints = @DropProductsConstraints + N'ALTER TABLE dbo.Products DROP CONSTRAINT ' + QUOTENAME(dc.name) + N';'
        FROM sys.default_constraints dc
        JOIN sys.columns col ON col.object_id = dc.parent_object_id AND col.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Products') AND col.name IN (N'Rating', N'ReviewCount');
        SELECT @DropProductsConstraints = @DropProductsConstraints + N'ALTER TABLE dbo.Products DROP CONSTRAINT ' + QUOTENAME(cc.name) + N';'
        FROM sys.check_constraints cc
        JOIN sys.columns col ON col.object_id = cc.parent_object_id AND col.column_id = cc.parent_column_id
        WHERE cc.parent_object_id = OBJECT_ID(N'dbo.Products') AND col.name IN (N'Rating', N'ReviewCount');
        EXEC sys.sp_executesql @DropProductsConstraints;
        IF COL_LENGTH(N'dbo.Products', N'Rating') IS NOT NULL ALTER TABLE dbo.Products DROP COLUMN Rating;
        IF COL_LENGTH(N'dbo.Products', N'ReviewCount') IS NOT NULL ALTER TABLE dbo.Products DROP COLUMN ReviewCount;
    END;

    -- Replace redundant line total with a computed value. Stop if existing values disagree.
    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.OrderItems') AND name = N'TotalPrice' AND is_computed = 0)
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.OrderItems WHERE TotalPrice <> CONVERT(DECIMAL(18,2), Quantity * UnitPrice))
            THROW 51004, N'Order item totals disagree with quantity times unit price. Resolve before migration.', 1;
        DECLARE @DropOrderItemConstraints NVARCHAR(MAX) = N'';
        SELECT @DropOrderItemConstraints = @DropOrderItemConstraints + N'ALTER TABLE dbo.OrderItems DROP CONSTRAINT ' + QUOTENAME(dc.name) + N';'
        FROM sys.default_constraints dc
        JOIN sys.columns col ON col.object_id = dc.parent_object_id AND col.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.OrderItems') AND col.name = N'TotalPrice';
        SELECT @DropOrderItemConstraints = @DropOrderItemConstraints + N'ALTER TABLE dbo.OrderItems DROP CONSTRAINT ' + QUOTENAME(cc.name) + N';'
        FROM sys.check_constraints cc
        JOIN sys.columns col ON col.object_id = cc.parent_object_id AND col.column_id = cc.parent_column_id
        WHERE cc.parent_object_id = OBJECT_ID(N'dbo.OrderItems') AND col.name = N'TotalPrice';
        EXEC sys.sp_executesql @DropOrderItemConstraints;
        ALTER TABLE dbo.OrderItems DROP COLUMN TotalPrice;
        EXEC sys.sp_executesql N'ALTER TABLE dbo.OrderItems ADD TotalPrice AS CONVERT(DECIMAL(18,2), Quantity * UnitPrice) PERSISTED;';
    END;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'TotalAmount' AND is_computed = 0)
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.Orders WHERE TotalAmount <> CONVERT(DECIMAL(18,2), Subtotal - DiscountAmount))
            THROW 51005, N'Order totals disagree with subtotal minus discount. Resolve before migration.', 1;
        DECLARE @DropOrderConstraints NVARCHAR(MAX) = N'';
        SELECT @DropOrderConstraints = @DropOrderConstraints + N'ALTER TABLE dbo.Orders DROP CONSTRAINT ' + QUOTENAME(dc.name) + N';'
        FROM sys.default_constraints dc
        JOIN sys.columns col ON col.object_id = dc.parent_object_id AND col.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Orders') AND col.name = N'TotalAmount';
        SELECT @DropOrderConstraints = @DropOrderConstraints + N'ALTER TABLE dbo.Orders DROP CONSTRAINT ' + QUOTENAME(cc.name) + N';'
        FROM sys.check_constraints cc
        JOIN sys.columns col ON col.object_id = cc.parent_object_id AND col.column_id = cc.parent_column_id
        WHERE cc.parent_object_id = OBJECT_ID(N'dbo.Orders') AND col.name = N'TotalAmount';
        EXEC sys.sp_executesql @DropOrderConstraints;
        ALTER TABLE dbo.Orders DROP COLUMN TotalAmount;
        EXEC sys.sp_executesql N'ALTER TABLE dbo.Orders ADD TotalAmount AS CONVERT(DECIMAL(18,2), Subtotal - DiscountAmount) PERSISTED;';
    END;

    IF COL_LENGTH(N'dbo.ProductReviews', N'FlagCount') IS NOT NULL
    BEGIN
        EXEC sys.sp_executesql N'
            IF EXISTS (
                SELECT 1 FROM dbo.ProductReviews r
                WHERE r.FlagCount <> (SELECT COUNT(*) FROM dbo.ReviewReports reports WHERE reports.ReviewId = r.Id)
            ) THROW 51008, N''Review flag counts disagree with report rows. Resolve before migration.'', 1;
        ';
        DECLARE @DropReviewConstraints NVARCHAR(MAX) = N'';
        SELECT @DropReviewConstraints = @DropReviewConstraints + N'ALTER TABLE dbo.ProductReviews DROP CONSTRAINT ' + QUOTENAME(dc.name) + N';'
        FROM sys.default_constraints dc
        JOIN sys.columns col ON col.object_id = dc.parent_object_id AND col.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.ProductReviews') AND col.name = N'FlagCount';
        SELECT @DropReviewConstraints = @DropReviewConstraints + N'ALTER TABLE dbo.ProductReviews DROP CONSTRAINT ' + QUOTENAME(cc.name) + N';'
        FROM sys.check_constraints cc
        JOIN sys.columns col ON col.object_id = cc.parent_object_id AND col.column_id = cc.parent_column_id
        WHERE cc.parent_object_id = OBJECT_ID(N'dbo.ProductReviews') AND col.name = N'FlagCount';
        EXEC sys.sp_executesql @DropReviewConstraints;
        ALTER TABLE dbo.ProductReviews DROP COLUMN FlagCount;
    END;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.StockAuditLogs') AND name = N'NewStock' AND is_computed = 0)
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.StockAuditLogs WHERE NewStock <> PreviousStock + QuantityChanged)
            THROW 51006, N'Stock audit balances disagree with recorded changes. Resolve before migration.', 1;
        ALTER TABLE dbo.StockAuditLogs DROP COLUMN NewStock;
        EXEC sys.sp_executesql N'ALTER TABLE dbo.StockAuditLogs ADD NewStock AS (PreviousStock + QuantityChanged) PERSISTED;';
    END;

    -- Normalize old demo reviews that have no linked order.
    UPDATE dbo.ProductReviews SET IsVerifiedPurchase = 0
    WHERE IsVerifiedPurchase = 1 AND OrderId IS NULL;

    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.ProductReviews') AND name = N'CK_ProductReviews_VerifiedLink')
        ALTER TABLE dbo.ProductReviews WITH CHECK ADD CONSTRAINT CK_ProductReviews_VerifiedLink CHECK (IsVerifiedPurchase = 0 OR OrderId IS NOT NULL);
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.Inventories') AND name = N'CK_Inventories_ReservedWithinStock')
        ALTER TABLE dbo.Inventories WITH CHECK ADD CONSTRAINT CK_Inventories_ReservedWithinStock CHECK (ReservedStock <= CurrentStock);
    IF NOT EXISTS
    (
        SELECT 1 FROM sys.computed_columns
        WHERE object_id = OBJECT_ID(N'dbo.Inventories') AND name = N'IsLowStock' AND definition LIKE N'%ReservedStock%'
    )
    BEGIN
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Inventories') AND name = N'IX_Inventories_IsLowStock')
            DROP INDEX IX_Inventories_IsLowStock ON dbo.Inventories;
        IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Inventories') AND name = N'IsLowStock')
            ALTER TABLE dbo.Inventories DROP COLUMN IsLowStock;
        EXEC sys.sp_executesql N'ALTER TABLE dbo.Inventories ADD IsLowStock AS (CASE WHEN CurrentStock - ReservedStock <= ReorderPoint THEN 1 ELSE 0 END) PERSISTED;';
    END;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Inventories') AND name = N'IX_Inventories_IsLowStock')
        CREATE INDEX IX_Inventories_IsLowStock ON dbo.Inventories(IsLowStock);
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.Orders') AND name = N'CK_Orders_Source')
        ALTER TABLE dbo.Orders WITH CHECK ADD CONSTRAINT CK_Orders_Source CHECK (OrderSource IN (N'ONLINE', N'INSTORE_POS'));
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.Orders') AND name = N'CK_Orders_Status')
        ALTER TABLE dbo.Orders WITH CHECK ADD CONSTRAINT CK_Orders_Status CHECK (Status IN (N'PendingPayment', N'Processing', N'ReadyForPickup', N'Completed', N'Cancelled'));
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.Orders') AND name = N'CK_Orders_Amounts')
        ALTER TABLE dbo.Orders WITH CHECK ADD CONSTRAINT CK_Orders_Amounts CHECK (DiscountAmount <= Subtotal);
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.Payments') AND name = N'CK_Payments_Gateway')
        ALTER TABLE dbo.Payments WITH CHECK ADD CONSTRAINT CK_Payments_Gateway CHECK (PaymentGateway IN (N'HitPay', N'Cash', N'Card_POS'));
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.Payments') AND name = N'CK_Payments_Status')
        ALTER TABLE dbo.Payments WITH CHECK ADD CONSTRAINT CK_Payments_Status CHECK (Status IN (N'Pending', N'Completed', N'Failed', N'Refunded'));
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.StockAuditLogs') AND name = N'CK_StockAuditLogs_ChangeType')
        ALTER TABLE dbo.StockAuditLogs WITH CHECK ADD CONSTRAINT CK_StockAuditLogs_ChangeType CHECK (ChangeType IN (N'ONLINE_SALE', N'INSTORE_SALE', N'RESTOCK', N'ADJUSTMENT', N'RETURN'));
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.StockAuditLogs') AND name = N'CK_StockAuditLogs_StockNonnegative')
        ALTER TABLE dbo.StockAuditLogs WITH CHECK ADD CONSTRAINT CK_StockAuditLogs_StockNonnegative CHECK (PreviousStock >= 0 AND NewStock >= 0);
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.RestockAlerts') AND name = N'CK_RestockAlerts_Severity')
        ALTER TABLE dbo.RestockAlerts WITH CHECK ADD CONSTRAINT CK_RestockAlerts_Severity CHECK (Severity IN (N'LOW_STOCK', N'CRITICAL_ZERO'));
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.HitPayWebhookLogs') AND name = N'CK_HitPayWebhookLogs_ProcessingStatus')
        ALTER TABLE dbo.HitPayWebhookLogs WITH CHECK ADD CONSTRAINT CK_HitPayWebhookLogs_ProcessingStatus CHECK (ProcessingStatus IN (N'Processed', N'Rejected', N'Duplicate'));
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.ReviewReports') AND name = N'CK_ReviewReports_Reason')
        ALTER TABLE dbo.ReviewReports WITH CHECK ADD CONSTRAINT CK_ReviewReports_Reason CHECK (Reason IN (N'SPAM', N'OFFENSIVE', N'IRRELEVANT', N'FAKE'));

    -- Keep newest open alert per inventory; retain older alerts as dismissed history.
    ;WITH Ranked AS
    (
        SELECT Id, ROW_NUMBER() OVER (PARTITION BY InventoryId ORDER BY CreatedAt DESC, Id DESC) AS RowNumber
        FROM dbo.RestockAlerts WHERE IsDismissed = 0
    )
    UPDATE alert SET IsDismissed = 1, DismissedAt = COALESCE(alert.DismissedAt, SYSUTCDATETIME())
    FROM dbo.RestockAlerts alert JOIN Ranked r ON r.Id = alert.Id
    WHERE r.RowNumber > 1;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.RestockAlerts') AND name = N'UX_RestockAlerts_OpenInventory')
        CREATE UNIQUE INDEX UX_RestockAlerts_OpenInventory ON dbo.RestockAlerts(InventoryId) WHERE IsDismissed = 0;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Payments') AND name = N'UX_Payments_GatewayReference')
        CREATE UNIQUE INDEX UX_Payments_GatewayReference ON dbo.Payments(PaymentGateway, GatewayReference) WHERE GatewayReference IS NOT NULL;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'IX_Users_Email')
        DROP INDEX IX_Users_Email ON dbo.Users;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'IX_Users_RoleId')
        CREATE INDEX IX_Users_RoleId ON dbo.Users(RoleId);
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'IX_Orders_OrderNumber')
        DROP INDEX IX_Orders_OrderNumber ON dbo.Orders;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
