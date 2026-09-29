# Workflow: Real-Time Inventory Tracking & Stock Reconciliation

This document specifies how stock is tracked, locked, decremented, and synchronized in real-time across both online channels and physical in-store walk-in sales.

---

## 1. Architecture Flow

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Online / In-Store Buyer
    participant API as Web API / OrdersController
    participant DB as MSSQL (Inventories)
    participant Hub as SignalR (InventoryHub)
    participant Staff as Staff Dashboard
    participant Store as Storefront Browsers

    Customer->>API: Checkout or In-Store Sale Transaction
    activate API
    API->>DB: BEGIN TRAN
    API->>DB: SELECT Stock WITH (UPDLOCK, ROWLOCK)
    alt Stock Available
        API->>DB: UPDATE Inventories SET CurrentStock = CurrentStock - Qty
        API->>DB: INSERT INTO StockAuditLogs (...)
        API->>DB: COMMIT TRAN
        API->>Hub: Publish StockChangedEvent
        Hub-->>Staff: Live Badge Update (Alert if Stock <= Threshold)
        Hub-->>Store: Live Stock Count / Disable "Add to Cart" if 0
        API-->>Customer: Order Confirmed
    else Stock Insufficient
        API->>DB: ROLLBACK TRAN
        API-->>Customer: 409 Conflict: Insufficient Stock
    end
    deactivate API
```

---

## 2. In-Store Walk-In Sale Processing
1. Staff opens the Quick In-Store Sale POS screen on the Staff Dashboard.
2. Staff scans or selects helmet model, size, and color.
3. System verifies real-time available stock.
4. Staff selects Payment Method: Cash, Card, or HitPay QR in-store terminal.
5. Order is submitted to `POST /api/v1/orders/in-store`.
6. Stock is immediately decremented in MSSQL; SignalR instantly updates the online storefront so an online buyer cannot purchase the same physical helmet simultaneously.

## 3. Low-Stock Alert System
- Threshold: When `CurrentStock <= ReorderPoint` (default: 3 units per variant), the system:
  1. Sets `IsLowStock = 1` in `Inventories`.
  2. Creates an unread notification record in `RestockAlerts`.
  3. Sends a real-time SignalR toast message to all logged-in Staff/Admin dashboards.
  4. Flags the item with an amber/red warning badge on the inventory management table.
