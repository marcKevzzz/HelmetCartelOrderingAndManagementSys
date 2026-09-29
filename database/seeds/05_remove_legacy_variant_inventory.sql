-- One-time cleanup for the 14 legacy SKUs from the supplied query output.
-- Deletes each matching inventory row and unused variant; variants with order/audit history are deactivated.
USE HelmetCartelDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Targets TABLE (SKU NVARCHAR(100) NOT NULL PRIMARY KEY);
INSERT INTO @Targets (SKU) VALUES
    (N'SHO-RF14-BLK-M'),
    (N'SHO-RF14-BLK-L'),
    (N'SHO-RF14-WHT-L'),
    (N'SHO-RF14-RED-XL'),
    (N'AGV-PIST-CRB-M'),
    (N'AGV-PIST-CRB-L'),
    (N'ARA-CORS-GRY-M'),
    (N'ARA-CORS-GRY-L'),
    (N'HJC-RP11-BLK-M'),
    (N'HJC-RP11-BLK-L'),
    (N'SHO-NEO2-SLV-L'),
    (N'BEL-C500-BLK-M'),
    (N'AGV-AX9-WHT-L'),
    (N'SHK-VAR-ORG-M');

DECLARE @Work TABLE
(
    SKU NVARCHAR(100) NOT NULL PRIMARY KEY,
    VariantId INT NULL
);
DECLARE @DeletedInventory TABLE (VariantId INT NOT NULL);

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO @Work (SKU, VariantId)
    SELECT t.SKU, pv.Id
    FROM @Targets t
    LEFT JOIN dbo.ProductVariants pv WITH (UPDLOCK, HOLDLOCK) ON pv.SKU = t.SKU;

    DELETE ra
    FROM dbo.RestockAlerts ra
    JOIN dbo.Inventories i ON i.Id = ra.InventoryId
    JOIN @Work w ON w.VariantId = i.VariantId;

    DELETE i
    OUTPUT deleted.VariantId INTO @DeletedInventory (VariantId)
    FROM dbo.Inventories i
    JOIN @Work w ON w.VariantId = i.VariantId;

    -- Preserve historical references while removing these variants from sale.
    UPDATE pv
    SET IsActive = 0
    FROM dbo.ProductVariants pv
    JOIN @Work w ON w.VariantId = pv.Id
    WHERE EXISTS (SELECT 1 FROM dbo.OrderItems oi WHERE oi.VariantId = pv.Id)
       OR EXISTS (SELECT 1 FROM dbo.StockAuditLogs log WHERE log.VariantId = pv.Id);

    DELETE pv
    FROM dbo.ProductVariants pv
    JOIN @Work w ON w.VariantId = pv.Id
    WHERE NOT EXISTS (SELECT 1 FROM dbo.OrderItems oi WHERE oi.VariantId = pv.Id)
      AND NOT EXISTS (SELECT 1 FROM dbo.StockAuditLogs log WHERE log.VariantId = pv.Id);

    -- Remove the earlier procedure if it was installed by the previous script version.
    IF OBJECT_ID(N'dbo.sp_DeleteLegacyVariantInventory', N'P') IS NOT NULL
        DROP PROCEDURE dbo.sp_DeleteLegacyVariantInventory;

    COMMIT TRANSACTION;

    SELECT
        t.SKU,
        w.VariantId,
        (SELECT COUNT(*) FROM @DeletedInventory di WHERE di.VariantId = w.VariantId) AS InventoryRowsDeleted,
        CASE
            WHEN w.VariantId IS NULL THEN N'NOT_FOUND'
            WHEN EXISTS (SELECT 1 FROM dbo.ProductVariants pv WHERE pv.Id = w.VariantId)
                THEN N'DEACTIVATED_HISTORY_PRESERVED'
            ELSE N'VARIANT_DELETED'
        END AS Result
    FROM @Targets t
    JOIN @Work w ON w.SKU = t.SKU
    ORDER BY t.SKU;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
