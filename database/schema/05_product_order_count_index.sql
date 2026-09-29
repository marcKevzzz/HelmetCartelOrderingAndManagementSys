-- Existing databases: support product order counts through the variant relationship.
IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.OrderItems')
         AND name = N'IX_OrderItems_VariantId_OrderId'
   )
BEGIN
    CREATE INDEX IX_OrderItems_VariantId_OrderId ON dbo.OrderItems(VariantId, OrderId);
END;
GO
