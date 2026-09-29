# Rule 04: MSSQL Database, Concurrency & Query Standards

## 1. Schema Conventions & Naming
- **Table Names:** Plural PascalCase (e.g., `Products`, `ProductVariants`, `Inventories`, `Orders`, `OrderItems`).
- **Primary Keys:** Standardized as `Id INT IDENTITY(1,1) PRIMARY KEY` or `BIGINT`.
- **Foreign Keys:** `<SingularParentName>Id` (e.g., `ProductId`, `VariantId`, `OrderId`).
- **Audit Columns:** Every stateful table must contain `CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()` and `UpdatedAt DATETIME2 NULL`.
- **Soft Deletes:** Where applicable, use `IsActive BIT NOT NULL DEFAULT 1` or `IsDeleted BIT NOT NULL DEFAULT 0`.

## 2. Concurrency & Inventory Race Conditions
- **Critical Requirement:** Inventory counts must NEVER become negative or succumb to double-allocation under concurrent checkout spikes.
- **Stock Decrement Strategy:**
  - Always execute within an explicit database transaction (`BEGIN TRANSACTION` ... `COMMIT TRANSACTION`).
  - Use `UPDLOCK, ROWLOCK` when querying inventory rows for modification:
    ```sql
    SELECT CurrentStock, ReservedStock 
    FROM Inventories WITH (UPDLOCK, ROWLOCK) 
    WHERE VariantId = @VariantId;
    ```
  - Implement an atomic decrement statement with a conditional check:
    ```sql
    UPDATE Inventories
    SET CurrentStock = CurrentStock - @Quantity,
        UpdatedAt = SYSUTCDATETIME()
    WHERE VariantId = @VariantId AND CurrentStock >= @Quantity;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('Insufficient stock available for variant.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    ```

## 3. Indexing & Query Performance
- Create covering non-clustered indexes on frequent lookup keys (e.g., `IX_ProductVariants_ProductId`, `IX_Orders_OrderNumber`, `IX_Inventories_LowStockAlert`).
- Never perform table scans on high-traffic customer endpoints.
- All query performance tests and execution plans must be documented in `database/query_logs/`.

## 4. Mandatory Stored Procedures for All Database Operations
- **Zero Raw Inline SQL Mandate:** Raw, concatenated, or inline SQL string queries (`SELECT * FROM ...`, `INSERT INTO ...`, `UPDATE ...`) inside C# repositories or code-behind files are **strictly forbidden**.
- **Every Database Interaction via Stored Procedure:** All database operations—including authentication, product retrieval, inventory adjustments, order management, user registrations, and report generation—MUST be encapsulated within named MSSQL Stored Procedures (`dbo.sp_...`).
- **ADO.NET Invocation Standard:** Repositories must execute stored procedures exclusively using `CommandType.StoredProcedure` with strongly typed, parameterized `SqlParameter` collections. No dynamic SQL execution (`EXEC(...)`) is permitted inside stored procedures.
