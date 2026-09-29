-- Remove only four original demo products outside the requested five-brand catalog.
-- Keeps related order and stock history; stops if any demo variant has either.
USE HelmetCartelDB;
GO

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @DemoProducts TABLE (ProductId INT PRIMARY KEY);
    INSERT INTO @DemoProducts (ProductId)
    SELECT Id
    FROM dbo.Products
    WHERE Slug IN
    (
        N'arai-corsair-x-statement',
        N'hjc-rpha-11-pro-carbon',
        N'bell-custom-500-carbon',
        N'shark-varial-off-road'
    );

    IF EXISTS
    (
        SELECT 1
        FROM @DemoProducts d
        JOIN dbo.ProductColors pc ON pc.ProductId = d.ProductId
        JOIN dbo.ProductVariants pv ON pv.ProductColorId = pc.Id
        JOIN dbo.OrderItems oi ON oi.VariantId = pv.Id
    )
        THROW 51020, N'Demo products have order history; cleanup stopped to preserve it.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @DemoProducts d
        JOIN dbo.ProductColors pc ON pc.ProductId = d.ProductId
        JOIN dbo.ProductVariants pv ON pv.ProductColorId = pc.Id
        JOIN dbo.StockAuditLogs log ON log.VariantId = pv.Id
    )
        THROW 51021, N'Demo products have stock audit history; cleanup stopped to preserve it.', 1;

    DELETE alert
    FROM dbo.RestockAlerts alert
    JOIN dbo.Inventories i ON i.Id = alert.InventoryId
    JOIN dbo.ProductVariants pv ON pv.Id = i.VariantId
    JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    JOIN @DemoProducts d ON d.ProductId = pc.ProductId;

    DELETE i
    FROM dbo.Inventories i
    JOIN dbo.ProductVariants pv ON pv.Id = i.VariantId
    JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    JOIN @DemoProducts d ON d.ProductId = pc.ProductId;

    DELETE pv
    FROM dbo.ProductVariants pv
    JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    JOIN @DemoProducts d ON d.ProductId = pc.ProductId;

    DELETE pc
    FROM dbo.ProductColors pc
    JOIN @DemoProducts d ON d.ProductId = pc.ProductId;

    DELETE p
    FROM dbo.Products p
    JOIN @DemoProducts d ON d.ProductId = p.Id;

    DELETE b
    FROM dbo.Brands b
    WHERE b.Name IN (N'Arai', N'HJC', N'Bell', N'Shark')
      AND NOT EXISTS (SELECT 1 FROM dbo.Products p WHERE p.BrandId = b.Id);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
