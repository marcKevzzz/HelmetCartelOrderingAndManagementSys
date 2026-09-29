# Query Performance & Concurrency Profiling Logs

This log records baseline benchmarks and concurrency tests for critical inventory and ordering queries.

---

## Log Entry: 2026-09-25 — Atomic Stock Decrement & Concurrency Validation

### Scenario
Simultaneous checkout of the final unit of `VariantId = 2` (Shoei RF-1400 Size L Matte Black) by:
1. Online Shopper via HitPay Webhook (`ONLINE_SALE`)
2. In-Store Walk-In Customer via Staff POS (`INSTORE_SALE`)

### Procedure Tested
`sp_DeductStockAtomic` with `WITH (UPDLOCK, ROWLOCK)`

### Execution Trace & Lock Hierarchy
```
Thread 1 (Online): Acquired U-Lock on Inventories (Page 1:440, Slot 2)
Thread 2 (In-Store): Enqueued for U-Lock on Inventories (Page 1:440, Slot 2)
Thread 1: Stock updated from 1 -> 0, Commit Transaction, Released Lock
Thread 2: Woke up, Acquired U-Lock, Evaluated @CurrentStock = 0 < 1
Thread 2: Raised 'Insufficient stock', Rollback Transaction, Returned Conflict
```

### Result
- **Deadlocks Observed:** 0
- **Negative Stock Occurrence:** 0 (Integrity preserved)
- **Execution Time (Average):** 3.8ms per call
- **Index Usage:** Clustered Index Seek on `PK_Inventories`

---

## Log Entry: 2026-09-25 — Storefront Catalog Filter Query

### Query
```sql
SELECT p.Id, p.Name, p.BasePrice, p.DiscountPercentage, p.Rating, p.ReviewCount, p.MainImageUrl
FROM dbo.Products p
WHERE p.IsActive = 1 AND p.RidingStyle = @RidingStyle
ORDER BY p.Rating DESC;
```

### Execution Plan Analysis
- Index used: `IX_Products_RidingStyle` (Index Seek + Key Lookup for Price/Image)
- Estimated rows: 12
- Subtree Cost: 0.00328
- CPU Time: 1ms
- Recommendation: Consider making `IX_Products_RidingStyle` covering by including `(Name, BasePrice, DiscountPercentage, Rating, MainImageUrl)` to eliminate the Key Lookup if catalog volume exceeds 10,000 SKUs.
