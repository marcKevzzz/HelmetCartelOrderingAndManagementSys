-- ============================================================================
-- Migration 38: Standardize PublicationStatus on 'Draft', 'Published', 'Archived'
-- Ensures 'Unpublished' is mapped back to 'Draft' and default constraint is 'Draft'
-- ============================================================================

USE HelmetCartelDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- 1. Ensure CK_Products_PublicationStatus accepts Draft, Published, Archived
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Products_PublicationStatus')
BEGIN
    ALTER TABLE dbo.Products DROP CONSTRAINT CK_Products_PublicationStatus;
END;
GO

ALTER TABLE dbo.Products
ADD CONSTRAINT CK_Products_PublicationStatus
CHECK (PublicationStatus IN (N'Draft', N'Published', N'Archived'));
GO

-- 2. Update default constraint to 'Draft'
DECLARE @DefConstraint NVARCHAR(128);
SELECT @DefConstraint = name 
FROM sys.default_constraints 
WHERE parent_object_id = OBJECT_ID(N'dbo.Products') 
  AND parent_column_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.Products'), N'PublicationStatus', 'ColumnId');

IF @DefConstraint IS NOT NULL
BEGIN
    EXEC('ALTER TABLE dbo.Products DROP CONSTRAINT ' + @DefConstraint);
END;
GO

ALTER TABLE dbo.Products
ADD CONSTRAINT DF_Products_PublicationStatus DEFAULT N'Draft' FOR PublicationStatus;
GO

-- 3. Update any 'Unpublished' records back to 'Draft'
UPDATE dbo.Products
SET PublicationStatus = N'Draft'
WHERE PublicationStatus = N'Unpublished';
GO
