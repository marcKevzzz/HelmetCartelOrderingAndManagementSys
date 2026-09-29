-- Rerunnable dashboard audit samples for local/demo environments.
-- Changes stock atomically so each audit row matches the resulting inventory.
USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.sp_SeedDashboardAuditSamples', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.sp_SeedDashboardAuditSamples AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_SeedDashboardAuditSamples
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Samples TABLE
    (
        SKU NVARCHAR(100) NOT NULL PRIMARY KEY,
        ChangeType NVARCHAR(50) NOT NULL,
        QuantityChanged INT NOT NULL,
        ReferenceNumber NVARCHAR(100) NOT NULL,
        Notes NVARCHAR(500) NOT NULL
    );

    INSERT @Samples (SKU, ChangeType, QuantityChanged, ReferenceNumber, Notes) VALUES
        (N'HC-P10-C92-S', N'RESTOCK',      6, N'DEMO-DASHBOARD-RESTOCK', N'Sample supplier restock for dashboard demonstration.'),
        (N'HC-P10-C92-M', N'ADJUSTMENT',  -2, N'DEMO-DASHBOARD-COUNT',   N'Sample cycle-count correction for dashboard demonstration.'),
        (N'HC-P10-C92-L', N'RETURN',       1, N'DEMO-DASHBOARD-RETURN',  N'Sample customer return for dashboard demonstration.'),
        (N'HC-P10-C92-XL',N'INSTORE_SALE',-1, N'DEMO-DASHBOARD-SALE',    N'Sample counter sale for dashboard demonstration.');

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @SKU NVARCHAR(100), @ChangeType NVARCHAR(50), @QuantityChanged INT,
                @ReferenceNumber NVARCHAR(100), @Notes NVARCHAR(500), @VariantId INT,
                @InventoryId INT, @PreviousStock INT, @ReservedStock INT, @NewStock INT;
        DECLARE sample_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT SKU, ChangeType, QuantityChanged, ReferenceNumber, Notes FROM @Samples;

        OPEN sample_cursor;
        FETCH NEXT FROM sample_cursor INTO @SKU, @ChangeType, @QuantityChanged, @ReferenceNumber, @Notes;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.StockAuditLogs WHERE ReferenceNumber = @ReferenceNumber)
            BEGIN
                SELECT @VariantId = NULL, @InventoryId = NULL, @PreviousStock = NULL, @ReservedStock = NULL;
                SELECT @VariantId = v.Id, @InventoryId = i.Id,
                       @PreviousStock = i.CurrentStock, @ReservedStock = i.ReservedStock
                FROM dbo.ProductVariants v
                JOIN dbo.Inventories i WITH (UPDLOCK, ROWLOCK) ON i.VariantId = v.Id
                WHERE v.SKU = @SKU AND v.IsActive = 1;

                IF @VariantId IS NULL
                    THROW 50301, N'Dashboard audit sample SKU was not found.', 1;
                SET @NewStock = @PreviousStock + @QuantityChanged;
                IF @NewStock < @ReservedStock OR @NewStock < 0
                    THROW 50302, N'Dashboard audit sample would make stock invalid.', 1;

                UPDATE dbo.Inventories
                SET CurrentStock = @NewStock,
                    LastRestockedAt = CASE WHEN @QuantityChanged > 0 THEN SYSUTCDATETIME() ELSE LastRestockedAt END,
                    UpdatedAt = SYSUTCDATETIME()
                WHERE Id = @InventoryId;

                INSERT dbo.StockAuditLogs
                    (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
                VALUES (@VariantId, NULL, @ChangeType, @PreviousStock, @QuantityChanged, @ReferenceNumber, @Notes);
            END;

            FETCH NEXT FROM sample_cursor INTO @SKU, @ChangeType, @QuantityChanged, @ReferenceNumber, @Notes;
        END;
        CLOSE sample_cursor;
        DEALLOCATE sample_cursor;

        COMMIT TRANSACTION;
        SELECT COUNT(*) AS SampleRowsPresent
        FROM dbo.StockAuditLogs WHERE ReferenceNumber LIKE N'DEMO-DASHBOARD-%';
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS(N'local', N'sample_cursor') >= -1
        BEGIN
            IF CURSOR_STATUS(N'local', N'sample_cursor') > -1 CLOSE sample_cursor;
            DEALLOCATE sample_cursor;
        END;
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

EXEC dbo.sp_SeedDashboardAuditSamples;
GO
