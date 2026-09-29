-- Rerunnable sample availability for the five supplied helmet brands.
-- Fill missing S-XXL variants, inventory, and visible specifications.
-- Existing nonzero prices, stock, variant adjustments, and stock history are preserved.
USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.sp_SeedSampleCatalogAvailability', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.sp_SeedSampleCatalogAvailability AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_SeedSampleCatalogAvailability
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;

    IF OBJECT_ID(N'dbo.ProductSpecificationValues', N'U') IS NULL
        THROW 50200, N'Run the product specification schema migration first.', 1;

    DECLARE @SampleSpecs TABLE
    (
        Slug NVARCHAR(220) NOT NULL,
        SpecificationKey NVARCHAR(80) NOT NULL,
        SpecificationValue NVARCHAR(1000) NOT NULL,
        PRIMARY KEY (Slug, SpecificationKey)
    );

    INSERT @SampleSpecs (Slug, SpecificationKey, SpecificationValue) VALUES
        (N'shoei-rf-1400-dedicated', N'helmet_type', N'Full-face sport helmet'),
        (N'shoei-rf-1400-dedicated', N'visible_finish', N'Matte black, pearl white, or racing red'),
        (N'shoei-rf-1400-dedicated', N'visor_style', N'CWR-F2 Pinlock-ready face shield'),
        (N'agv-pista-gp-rr-carbon', N'helmet_type', N'Full-face racing helmet'),
        (N'agv-pista-gp-rr-carbon', N'visible_finish', N'Carbon weave'),
        (N'agv-pista-gp-rr-carbon', N'visor_style', N'Panoramic face shield'),
        (N'shoei-neotec-2-modular', N'helmet_type', N'Flip-up modular touring helmet'),
        (N'shoei-neotec-2-modular', N'visible_finish', N'Anthracite metallic'),
        (N'shoei-neotec-2-modular', N'visor_style', N'Face shield with integrated sun visor'),
        (N'agv-ax9-dual-carbon', N'helmet_type', N'Dual-sport adventure helmet'),
        (N'agv-ax9-dual-carbon', N'visible_finish', N'Alpine white'),
        (N'agv-ax9-dual-carbon', N'visor_style', N'Panoramic visor and removable peak');

    DECLARE @StockChanges TABLE
    (
        VariantId INT NOT NULL PRIMARY KEY,
        PreviousStock INT NOT NULL,
        NewStock INT NOT NULL
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        -- A missing color needs a product-specific choice; never invent one silently.
        IF EXISTS
        (
            SELECT 1
            FROM dbo.Products p
            JOIN dbo.Brands b ON b.Id = p.BrandId
            WHERE p.IsActive = 1
              AND b.Name IN (N'Shoei', N'AGV', N'Gille', N'HNJ', N'Zebra')
              AND NOT EXISTS (SELECT 1 FROM dbo.ProductColors pc WHERE pc.ProductId = p.Id)
        )
            THROW 50201, N'An active catalog product has no color; add its actual color before seeding variants.', 1;

        -- Existing priced products keep their price. This fallback serves only zero-price samples.
        UPDATE p
        SET BasePrice = CASE b.Name
                            WHEN N'Shoei' THEN 29990
                            WHEN N'AGV' THEN 18990
                            WHEN N'Gille' THEN 2990
                            WHEN N'HNJ' THEN 1490
                            ELSE 2490
                        END,
            UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Products p
        JOIN dbo.Brands b ON b.Id = p.BrandId
        WHERE p.IsActive = 1 AND p.BasePrice = 0
          AND b.Name IN (N'Shoei', N'AGV', N'Gille', N'HNJ', N'Zebra');

        INSERT dbo.ProductVariants (ProductColorId, SKU, Size, PriceAdjustment, IsActive)
        SELECT pc.Id,
               CONCAT(N'HC-P', p.Id, N'-C', pc.Id, N'-', sizes.Size),
               sizes.Size, 0, 1
        FROM dbo.Products p
        JOIN dbo.Brands b ON b.Id = p.BrandId
        JOIN dbo.ProductColors pc ON pc.ProductId = p.Id
        CROSS JOIN (VALUES (N'S'), (N'M'), (N'L'), (N'XL'), (N'XXL')) sizes(Size)
        WHERE p.IsActive = 1
          AND b.Name IN (N'Shoei', N'AGV', N'Gille', N'HNJ', N'Zebra')
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.ProductVariants v WITH (UPDLOCK, HOLDLOCK)
              WHERE v.ProductColorId = pc.Id AND v.Size = sizes.Size
          );

        INSERT dbo.Inventories (VariantId, CurrentStock, ReservedStock, ReorderPoint)
        SELECT v.Id, 0, 0, 3
        FROM dbo.ProductVariants v
        JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        JOIN dbo.Brands b ON b.Id = p.BrandId
        WHERE p.IsActive = 1 AND v.IsActive = 1
          AND b.Name IN (N'Shoei', N'AGV', N'Gille', N'HNJ', N'Zebra')
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Inventories i WITH (UPDLOCK, HOLDLOCK)
              WHERE i.VariantId = v.Id
          );

        -- S/M/L use the base price. Larger shells receive a small sample surcharge.
        UPDATE v
        SET PriceAdjustment = CASE v.Size
                                  WHEN N'XL' THEN CASE WHEN p.BasePrice >= 10000 THEN 500 ELSE 75 END
                                  WHEN N'XXL' THEN CASE WHEN p.BasePrice >= 10000 THEN 1000 ELSE 150 END
                              END
        FROM dbo.ProductVariants v
        JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        JOIN dbo.Brands b ON b.Id = p.BrandId
        WHERE p.IsActive = 1 AND v.IsActive = 1 AND v.PriceAdjustment = 0
          AND v.Size IN (N'XL', N'XXL')
          AND b.Name IN (N'Shoei', N'AGV', N'Gille', N'HNJ', N'Zebra');

        -- Only untouched, empty inventory receives demo opening stock.
        -- A sold-out or manually adjusted variant has an audit trail and stays untouched.
        UPDATE i
        SET CurrentStock = CASE
                WHEN p.BasePrice >= 10000 THEN CASE v.Size
                    WHEN N'S' THEN 8 WHEN N'M' THEN 12 WHEN N'L' THEN 14
                    WHEN N'XL' THEN 10 ELSE 6 END
                ELSE CASE v.Size
                    WHEN N'S' THEN 12 WHEN N'M' THEN 18 WHEN N'L' THEN 20
                    WHEN N'XL' THEN 14 ELSE 8 END
            END,
            LastRestockedAt = SYSUTCDATETIME(),
            UpdatedAt = SYSUTCDATETIME()
        OUTPUT inserted.VariantId, deleted.CurrentStock, inserted.CurrentStock
            INTO @StockChanges (VariantId, PreviousStock, NewStock)
        FROM dbo.Inventories i WITH (UPDLOCK, ROWLOCK)
        JOIN dbo.ProductVariants v ON v.Id = i.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        JOIN dbo.Brands b ON b.Id = p.BrandId
        WHERE p.IsActive = 1 AND v.IsActive = 1
          AND i.CurrentStock = 0 AND i.ReservedStock = 0
          AND v.Size IN (N'S', N'M', N'L', N'XL', N'XXL')
          AND b.Name IN (N'Shoei', N'AGV', N'Gille', N'HNJ', N'Zebra')
          AND NOT EXISTS (SELECT 1 FROM dbo.StockAuditLogs a WHERE a.VariantId = v.Id);

        INSERT dbo.StockAuditLogs
            (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
        SELECT VariantId, NULL, N'ADJUSTMENT', PreviousStock,
               NewStock - PreviousStock, N'DEMO-CATALOG-OPENING',
               N'Sample opening stock for catalog demonstration.'
        FROM @StockChanges;

        UPDATE alert
        SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
        FROM dbo.RestockAlerts alert
        JOIN dbo.Inventories i ON i.Id = alert.InventoryId
        JOIN @StockChanges change ON change.VariantId = i.VariantId
        WHERE alert.IsDismissed = 0
          AND i.CurrentStock - i.ReservedStock > i.ReorderPoint;

        INSERT dbo.ProductSpecificationValues (ProductId, SpecificationId, SpecificationValue)
        SELECT p.Id, d.Id, sample.SpecificationValue
        FROM @SampleSpecs sample
        JOIN dbo.Products p ON p.Slug = sample.Slug AND p.IsActive = 1
        JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = sample.SpecificationKey AND d.IsActive = 1
        JOIN dbo.CategorySpecifications cs ON cs.CategoryId = p.CategoryId AND cs.SpecificationId = d.Id
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.ProductSpecificationValues existing WITH (UPDLOCK, HOLDLOCK)
            WHERE existing.ProductId = p.Id AND existing.SpecificationId = d.Id
        );

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Products p
            JOIN dbo.Brands b ON b.Id = p.BrandId
            WHERE p.IsActive = 1
              AND b.Name IN (N'Shoei', N'AGV', N'Gille', N'HNJ', N'Zebra')
              AND NOT EXISTS
              (
                  SELECT 1 FROM dbo.ProductColors pc
                  JOIN dbo.ProductVariants v ON v.ProductColorId = pc.Id AND v.IsActive = 1
                  WHERE pc.ProductId = p.Id
              )
        )
            THROW 50202, N'An active catalog product still has no active variant.', 1;

        COMMIT TRANSACTION;

        SELECT COUNT(*) AS StockRowsSeeded FROM @StockChanges;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

EXEC dbo.sp_SeedSampleCatalogAvailability;
GO
