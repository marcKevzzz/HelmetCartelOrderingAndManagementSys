-- Small, idempotent data set for dynamic admin dashboard and analytics previews.
-- Uses helmet images already stored under Content/images/products/helmets.

CREATE OR ALTER PROCEDURE dbo.sp_SeedDashboardSampleData
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Today DATETIME2 = CONVERT(DATETIME2, CONVERT(DATE, SYSUTCDATETIME()));
    DECLARE @CatalogDate DATETIME2 = DATEADD(DAY, -12, @Today);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Categories WITH (UPDLOCK, HOLDLOCK) WHERE Slug = N'full-face')
            INSERT dbo.Categories (Name, Slug, Description, DisplayOrder)
            VALUES (N'Full Face', N'full-face', N'Full-coverage helmets for road and track riding.', 3);

        IF NOT EXISTS (SELECT 1 FROM dbo.Categories WITH (UPDLOCK, HOLDLOCK) WHERE Slug = N'open-face-urban')
            INSERT dbo.Categories (Name, Slug, Description, DisplayOrder)
            VALUES (N'Open Face / Urban', N'open-face-urban', N'Open-face helmets for everyday urban riding.', 4);

        IF NOT EXISTS (SELECT 1 FROM dbo.Brands WITH (UPDLOCK, HOLDLOCK) WHERE Name = N'Shoei')
            INSERT dbo.Brands (Name) VALUES (N'Shoei');

        DECLARE @Catalog TABLE
        (
            Slug NVARCHAR(220) PRIMARY KEY,
            CategorySlug NVARCHAR(120),
            BrandName NVARCHAR(100),
            ProductName NVARCHAR(200),
            Description NVARCHAR(MAX),
            RidingStyle NVARCHAR(50),
            BasePrice DECIMAL(18,2),
            MainImageUrl NVARCHAR(500),
            ColorName NVARCHAR(50),
            ColorHex NVARCHAR(255)
        );

        INSERT @Catalog VALUES
            (N'agv-vr46-graphic', N'full-face', N'AGV', N'AGV VR46 Graphic Full-Face Helmet',
             N'Full-face helmet with yellow, black, and white VR46 graphics. Model name is provisional.',
             N'Sport/Track', 29990.00, N'/Content/images/products/helmets/agv/agv-vr46-graphic-main-primary.jpg',
             N'Yellow Black Graphic', N'#E7D315'),
            (N'gille-dual-visor-open-face', N'open-face-urban', N'Gille', N'Gille Dual Visor Open-Face Helmet',
             N'Open-face helmet with a long outer visor and a second tinted visor visible in the supplied photos.',
             N'Casual/Urban', 2990.00, N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-main-primary.jpg',
             N'Plain Black', N'#1F1F1F'),
            (N'shoei-graphic-open-face', N'open-face-urban', N'Shoei', N'Shoei Graphic Open-Face Helmet',
             N'Open-face helmet with a wraparound visor, shown in blue and white graphics.',
             N'Casual/Urban', 30990.00, N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-main-primary.jpg',
             N'Blue Graphic', N'#345F88');

        INSERT dbo.Products
            (CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice, MainImageUrl, IsFeatured, CreatedAt)
        SELECT cat.Id, b.Id, c.ProductName, c.Slug, c.Description, c.RidingStyle, c.BasePrice,
               c.MainImageUrl, 1, @CatalogDate
        FROM @Catalog c
        JOIN dbo.Categories cat ON cat.Slug = c.CategorySlug
        JOIN dbo.Brands b ON b.Name = c.BrandName
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Products p WITH (UPDLOCK, HOLDLOCK) WHERE p.Slug = c.Slug);

        INSERT dbo.ProductColors (ProductId, Color, ColorHex, CreatedAt)
        SELECT p.Id, c.ColorName, c.ColorHex, @CatalogDate
        FROM @Catalog c
        JOIN dbo.Products p ON p.Slug = c.Slug
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.ProductColors pc WITH (UPDLOCK, HOLDLOCK)
            WHERE pc.ProductId = p.Id AND pc.Color = c.ColorName
        );

        DECLARE @Variants TABLE
        (
            Slug NVARCHAR(220),
            ColorName NVARCHAR(50),
            SKU NVARCHAR(100) PRIMARY KEY,
            Size NVARCHAR(20),
            OpeningStock INT
        );

        INSERT @Variants VALUES
            (N'agv-vr46-graphic', N'Yellow Black Graphic', N'SMP-AGV-VR46-M', N'M', 8),
            (N'agv-vr46-graphic', N'Yellow Black Graphic', N'SMP-AGV-VR46-L', N'L', 6),
            (N'gille-dual-visor-open-face', N'Plain Black', N'SMP-GILLE-DV-M', N'M', 10),
            (N'gille-dual-visor-open-face', N'Plain Black', N'SMP-GILLE-DV-L', N'L', 7),
            (N'shoei-graphic-open-face', N'Blue Graphic', N'SMP-SHOEI-GO-M', N'M', 7),
            (N'shoei-graphic-open-face', N'Blue Graphic', N'SMP-SHOEI-GO-L', N'L', 5);

        INSERT dbo.ProductVariants (ProductColorId, SKU, Size, CreatedAt)
        SELECT pc.Id, v.SKU, v.Size, @CatalogDate
        FROM @Variants v
        JOIN dbo.Products p ON p.Slug = v.Slug
        JOIN dbo.ProductColors pc ON pc.ProductId = p.Id AND pc.Color = v.ColorName
        WHERE NOT EXISTS (SELECT 1 FROM dbo.ProductVariants existing WITH (UPDLOCK, HOLDLOCK) WHERE existing.SKU = v.SKU);

        INSERT dbo.Inventories (VariantId, CurrentStock, ReservedStock, ReorderPoint, LastRestockedAt, UpdatedAt)
        SELECT pv.Id, v.OpeningStock, 0, 3, @CatalogDate, @CatalogDate
        FROM @Variants v
        JOIN dbo.ProductVariants pv ON pv.SKU = v.SKU
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Inventories i WITH (UPDLOCK, HOLDLOCK) WHERE i.VariantId = pv.Id);

        INSERT dbo.StockAuditLogs
            (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes, CreatedAt)
        SELECT pv.Id, NULL, N'RESTOCK', 0, v.OpeningStock, N'SAMPLE-CATALOG-OPENING',
               N'Sample opening inventory for the admin dashboard.', @CatalogDate
        FROM @Variants v
        JOIN dbo.ProductVariants pv ON pv.SKU = v.SKU
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.StockAuditLogs l WITH (UPDLOCK, HOLDLOCK)
            WHERE l.VariantId = pv.Id AND l.ReferenceNumber = N'SAMPLE-CATALOG-OPENING'
        );

        DECLARE @Gallery TABLE
        (
            Slug NVARCHAR(220),
            DisplayOrder INT,
            ImageUrl NVARCHAR(500),
            AltText NVARCHAR(250)
        );

        INSERT @Gallery VALUES
            (N'agv-vr46-graphic', 1, N'/Content/images/products/helmets/agv/agv-vr46-graphic-gallery-1.jpg', N'AGV VR46 Graphic alternate view'),
            (N'agv-vr46-graphic', 2, N'/Content/images/products/helmets/agv/agv-vr46-graphic-gallery-2.jpg', N'AGV VR46 Graphic side view'),
            (N'gille-dual-visor-open-face', 1, N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-1.jpg', N'Gille Dual Visor alternate view'),
            (N'gille-dual-visor-open-face', 2, N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-2.jpg', N'Gille Dual Visor side view'),
            (N'shoei-graphic-open-face', 1, N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-1.jpg', N'Shoei Graphic Open-Face alternate view'),
            (N'shoei-graphic-open-face', 2, N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-2.jpg', N'Shoei Graphic Open-Face side view');

        INSERT dbo.ProductGalleryImages (ProductId, ImageUrl, AltText, DisplayOrder, IsActive, CreatedAt)
        SELECT p.Id, g.ImageUrl, g.AltText, g.DisplayOrder, 1, @CatalogDate
        FROM @Gallery g
        JOIN dbo.Products p ON p.Slug = g.Slug
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.ProductGalleryImages existing WITH (UPDLOCK, HOLDLOCK)
            WHERE existing.ProductId = p.Id AND existing.DisplayOrder = g.DisplayOrder
        );

        DECLARE @Orders TABLE
        (
            OrderNumber NVARCHAR(50) PRIMARY KEY,
            DaysAgo INT,
            CustomerName NVARCHAR(100),
            CustomerEmail NVARCHAR(256),
            CustomerPhone NVARCHAR(30),
            OrderSource NVARCHAR(30),
            OrderStatus NVARCHAR(50),
            SKU NVARCHAR(100),
            Quantity INT,
            UnitPrice DECIMAL(18,2),
            PaymentGateway NVARCHAR(50),
            PaymentStatus NVARCHAR(50),
            GatewayReference NVARCHAR(100)
        );

        INSERT @Orders VALUES
            (N'HC-SAMPLE-D06-01', 6, N'Marco Reyes', N'marco.sample@example.com', N'09170000001', N'INSTORE_POS', N'Completed', N'SMP-AGV-VR46-M', 2, 29990.00, N'Cash', N'Completed', N'SAMPLE-CASH-D06'),
            (N'HC-SAMPLE-D04-01', 4, N'Anna Cruz', N'anna.sample@example.com', N'09170000002', N'ONLINE', N'Completed', N'SMP-AGV-VR46-L', 1, 29990.00, N'HitPay', N'Completed', N'SAMPLE-HITPAY-D04'),
            (N'HC-SAMPLE-D02-01', 2, N'Luis Santos', N'luis.sample@example.com', N'09170000003', N'INSTORE_POS', N'Completed', N'SMP-GILLE-DV-M', 1, 2990.00, N'Card_POS', N'Completed', N'SAMPLE-CARD-D02'),
            (N'HC-SAMPLE-D01-01', 1, N'Bea Lim', N'bea.sample@example.com', N'09170000004', N'ONLINE', N'ReadyForPickup', N'SMP-GILLE-DV-L', 1, 2990.00, N'HitPay', N'Completed', N'SAMPLE-HITPAY-D01'),
            (N'HC-SAMPLE-D00-01', 0, N'Noel Garcia', N'noel.sample@example.com', N'09170000005', N'ONLINE', N'Processing', N'SMP-SHOEI-GO-M', 1, 30990.00, N'HitPay', N'Completed', N'SAMPLE-HITPAY-D00'),
            (N'HC-SAMPLE-D00-02', 0, N'Mia Torres', N'mia.sample@example.com', N'09170000006', N'ONLINE', N'PendingPayment', N'SMP-SHOEI-GO-L', 1, 30990.00, N'HitPay', N'Pending', N'SAMPLE-HITPAY-PENDING');

        DECLARE @NewOrders TABLE (OrderId INT, OrderNumber NVARCHAR(50));

        INSERT dbo.Orders
            (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone, OrderSource, Status,
             Subtotal, DiscountAmount, Notes, CreatedAt, UpdatedAt)
        OUTPUT inserted.Id, inserted.OrderNumber INTO @NewOrders (OrderId, OrderNumber)
        SELECT o.OrderNumber, NULL, o.CustomerName, o.CustomerEmail, o.CustomerPhone, o.OrderSource,
               o.OrderStatus, o.Quantity * o.UnitPrice, 0,
               N'Sample order for dashboard and analytics preview.',
               DATEADD(HOUR, 10, DATEADD(DAY, -o.DaysAgo, @Today)),
               DATEADD(HOUR, 10, DATEADD(DAY, -o.DaysAgo, @Today))
        FROM @Orders o
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Orders existing WITH (UPDLOCK, HOLDLOCK) WHERE existing.OrderNumber = o.OrderNumber);

        INSERT dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
        SELECT n.OrderId, pv.Id, o.Quantity, o.UnitPrice
        FROM @NewOrders n
        JOIN @Orders o ON o.OrderNumber = n.OrderNumber
        JOIN dbo.ProductVariants pv ON pv.SKU = o.SKU;

        DECLARE @StockChanges TABLE
        (
            VariantId INT PRIMARY KEY,
            Quantity INT,
            ChangeType NVARCHAR(50),
            ReferenceNumber NVARCHAR(100),
            ChangedAt DATETIME2
        );

        INSERT @StockChanges
        SELECT pv.Id, o.Quantity,
               CASE WHEN o.OrderSource = N'ONLINE' THEN N'ONLINE_SALE' ELSE N'INSTORE_SALE' END,
               o.OrderNumber,
               DATEADD(HOUR, 10, DATEADD(DAY, -o.DaysAgo, @Today))
        FROM @NewOrders n
        JOIN @Orders o ON o.OrderNumber = n.OrderNumber
        JOIN dbo.ProductVariants pv ON pv.SKU = o.SKU
        WHERE o.PaymentStatus = N'Completed';

        DECLARE @LockedStock INT;
        SELECT @LockedStock = SUM(i.CurrentStock)
        FROM dbo.Inventories i WITH (UPDLOCK, HOLDLOCK, ROWLOCK)
        JOIN @StockChanges s ON s.VariantId = i.VariantId;

        IF EXISTS
        (
            SELECT 1
            FROM @StockChanges s
            LEFT JOIN dbo.Inventories i ON i.VariantId = s.VariantId
            WHERE i.Id IS NULL OR i.CurrentStock - i.ReservedStock < s.Quantity
        )
            THROW 52131, N'Insufficient inventory for sample order seed.', 1;

        INSERT dbo.StockAuditLogs
            (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes, CreatedAt)
        SELECT s.VariantId, NULL, s.ChangeType, i.CurrentStock, -s.Quantity, s.ReferenceNumber,
               N'Sample fulfilled order inventory movement.', s.ChangedAt
        FROM @StockChanges s
        JOIN dbo.Inventories i ON i.VariantId = s.VariantId;

        UPDATE i
        SET CurrentStock = i.CurrentStock - s.Quantity,
            UpdatedAt = s.ChangedAt
        FROM dbo.Inventories i
        JOIN @StockChanges s ON s.VariantId = i.VariantId;

        INSERT dbo.Payments
            (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt)
        SELECT n.OrderId, o.PaymentGateway, o.GatewayReference, o.Quantity * o.UnitPrice, o.PaymentStatus,
               CASE WHEN o.PaymentStatus = N'Completed' THEN DATEADD(HOUR, 10, DATEADD(DAY, -o.DaysAgo, @Today)) ELSE NULL END,
               DATEADD(HOUR, 10, DATEADD(DAY, -o.DaysAgo, @Today))
        FROM @NewOrders n
        JOIN @Orders o ON o.OrderNumber = n.OrderNumber;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

EXEC dbo.sp_SeedDashboardSampleData;
GO
