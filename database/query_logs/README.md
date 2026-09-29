# Database Query Logging & Profiling Directory

This directory stores query execution benchmarks, SQL Server Extended Events logs, execution plan reviews, and concurrency test profiles.

## 1. Objectives
- Monitor and prevent slow table scans on product catalogs and inventory checks.
- Audit row locks under high concurrent checkouts (prevent deadlocks between `Orders` and `Inventories`).
- Verify execution plans use `UQ_ProductVariants_Color_Size` and `IX_Inventories_IsLowStock` where applicable. The older performance log describes the pre-migration schema.

## 2. Recommended Profiling Session Commands
To capture long-running queries (>500ms) or deadlocks in MSSQL:

```sql
-- Query DMVs for top 10 most expensive queries by CPU / Duration
SELECT TOP 10
    qs.total_worker_time / qs.execution_count AS AvgCpuTime_MicroSec,
    qs.total_elapsed_time / qs.execution_count AS AvgDuration_MicroSec,
    qs.execution_count,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1, 
        ((CASE qs.statement_end_offset 
            WHEN -1 THEN DATALENGTH(qt.text) 
            ELSE qs.statement_end_offset 
        END - qs.statement_start_offset)/2) + 1) AS StatementText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY AvgDuration_MicroSec DESC;
```

## 3. Log Submission Guidelines
- Any agent or developer optimizing a query must paste the execution plan summary and benchmark results into `query_performance_logs.md`.
