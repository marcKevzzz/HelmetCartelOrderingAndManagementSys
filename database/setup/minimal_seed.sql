-- Fresh database only. No demo login credentials, orders, payments, or full catalog.
USE [HelmetCartelMinimalDB];
GO

CREATE OR ALTER PROCEDURE dbo.sp_SeedMinimalDevelopmentData
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM dbo.Roles WITH (UPDLOCK, HOLDLOCK))
            THROW 52090, 'Minimal seed requires an empty database.', 1;

        INSERT dbo.Roles (Name, Description) VALUES
            (N'Admin', N'Full administration'), (N'Staff', N'Store operations'),
            (N'Customer', N'Storefront customer');
        INSERT dbo.Categories (Name, Slug, Description, DisplayOrder) VALUES
            (N'Modular', N'modular', N'Flip-up helmets for touring and everyday riding.', 1),
            (N'Dual Sport / Adventure', N'dual-sport-adventure', N'Helmets for road and adventure riding.', 2);

        INSERT dbo.Brands (Name) VALUES (N'AGV'), (N'Gille');

        DECLARE @ModularCategoryId INT = (SELECT Id FROM dbo.Categories WHERE Slug = N'modular');
        DECLARE @AdventureCategoryId INT = (SELECT Id FROM dbo.Categories WHERE Slug = N'dual-sport-adventure');
        DECLARE @AgvBrandId INT = (SELECT Id FROM dbo.Brands WHERE Name = N'AGV');
        DECLARE @GilleBrandId INT = (SELECT Id FROM dbo.Brands WHERE Name = N'Gille');

        INSERT dbo.Products
            (CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice, MainImageUrl, IsFeatured)
        VALUES
            (@ModularCategoryId, @AgvBrandId,
             N'AGV White Modular Helmet', N'agv-white-modular',
             N'White modular helmet with a flip-up chin section and dark visor. Model name is provisional.',
             N'Touring/Adventure', 18990.00,
             N'/Content/images/products/helmets/agv/agv-white-modular-main-primary.jpg', 1),
            (@AdventureCategoryId, @GilleBrandId,
             N'Gille Adventure Peak Helmet', N'gille-adventure-peak',
             N'Angular adventure helmet with raised peak and full face shield. Model name is provisional.',
             N'Touring/Adventure', 4490.00,
             N'/Content/images/products/helmets/gille/gille-adventure-peak-main-primary.jpg', 1);

        DECLARE @AgvProductId INT = (SELECT Id FROM dbo.Products WHERE Slug = N'agv-white-modular');
        DECLARE @GilleProductId INT = (SELECT Id FROM dbo.Products WHERE Slug = N'gille-adventure-peak');

        INSERT dbo.ProductColors (ProductId, Color, ColorHex) VALUES
            (@AgvProductId, N'White', N'#F5F5F5'),
            (@GilleProductId, N'Grey', N'#777777');

        DECLARE @AgvColorId INT = (SELECT Id FROM dbo.ProductColors WHERE ProductId = @AgvProductId);
        DECLARE @GilleColorId INT = (SELECT Id FROM dbo.ProductColors WHERE ProductId = @GilleProductId);

        INSERT dbo.ProductVariants (ProductColorId, SKU, Size) VALUES
            (@AgvColorId, N'MIN-AGV-WHITE-M', N'M'),
            (@AgvColorId, N'MIN-AGV-WHITE-L', N'L'),
            (@GilleColorId, N'MIN-GILLE-GREY-M', N'M'),
            (@GilleColorId, N'MIN-GILLE-GREY-L', N'L');

        INSERT dbo.ProductGalleryImages (ProductId, ImageUrl, AltText, DisplayOrder) VALUES
            (@AgvProductId, N'/Content/images/products/helmets/agv/agv-white-modular-gallery-1.jpg', N'AGV White Modular Helmet alternate view', 1),
            (@AgvProductId, N'/Content/images/products/helmets/agv/agv-white-modular-gallery-2.jpg', N'AGV White Modular Helmet side view', 2),
            (@AgvProductId, N'/Content/images/products/helmets/agv/agv-white-modular-gallery-3.jpg', N'AGV White Modular Helmet detail view', 3),
            (@GilleProductId, N'/Content/images/products/helmets/gille/gille-adventure-peak-gallery-1.jpg', N'Gille Adventure Peak Helmet alternate view', 1),
            (@GilleProductId, N'/Content/images/products/helmets/gille/gille-adventure-peak-gallery-2.jpg', N'Gille Adventure Peak Helmet side view', 2),
            (@GilleProductId, N'/Content/images/products/helmets/gille/gille-adventure-peak-gallery-3.jpg', N'Gille Adventure Peak Helmet detail view', 3);
        INSERT dbo.Inventories (VariantId, CurrentStock, ReservedStock, ReorderPoint, LastRestockedAt)
            SELECT Id, CASE WHEN Size = N'M' THEN 5 ELSE 2 END, 0, 3, SYSUTCDATETIME()
            FROM dbo.ProductVariants WITH (UPDLOCK, ROWLOCK);
        INSERT dbo.StockAuditLogs (VariantId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
            SELECT VariantId, N'RESTOCK', 0, CurrentStock, N'MINIMAL-SETUP', N'Sample opening stock'
            FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK);
        INSERT dbo.RestockAlerts (InventoryId, Severity)
            SELECT Id, N'LOW_STOCK' FROM dbo.Inventories WHERE IsLowStock = 1;
        INSERT dbo.Faqs ([Question], [Answer], DisplayOrder)
            SELECT N'Is this a sample catalog?', N'Yes. This small catalog uses two products and images from the supplied project content.', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
EXEC dbo.sp_SeedMinimalDevelopmentData;
GO
