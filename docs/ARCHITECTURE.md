# System Architecture: Helmet Cartel Ordering and Management System

## 1. Executive Summary
The **Helmet Cartel Ordering and Management System** is a unified retail and e-commerce platform designed to replace spreadsheet-based stock keeping with real-time, transaction-synchronized inventory management. It powers both a public-facing customer storefront and an administrative staff operations dashboard.

This is an academic presentation system. The implementation uses ASP.NET Web Forms pages, Web API 2, ADO.NET stored-procedure repositories, SQL Server, and SignalR. Some page code-behind and controllers call repositories directly; the diagram shows logical responsibilities rather than a uniformly enforced service layer. Electronic payment handlers and demonstration data were excluded from the October 2026 correction scope. See `ACADEMIC_FIX_STATUS.md` for verified behavior and limitations.

---

## 2. High-Level Architecture Diagram

```
+-----------------------------------------------------------------------------------+
|                                  CLIENT LAYER                                     |
|  +-------------------------------------+   +------------------------------------+  |
|  |     Public Online Storefront        |   |      Staff Operations Dashboard    |  |
|  |   (Catalog, Cart, Checkout, Reviews)|   | (POS, Stock Alerts, Orders, Reports)|  |
|  +-------------------------------------+   +------------------------------------+  |
+--------------------------|-----------------------------------|--------------------+
                           | HTTPS REST / JSON                 | HTTPS REST / JSON
                           | WebSocket (SignalR)               | WebSocket (SignalR)
+--------------------------v-----------------------------------v--------------------+
|                         ASP.NET WEB APPLICATION HOST (IIS)                        |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  |                           OWIN STARTUP PIPELINE                             |  |
|  |    [CORS] -> [Security Headers] -> [JWT Auth Middleware] -> [SignalR Hubs]  |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  |                      CONTROLLERS / PRESENTATION LAYER                       |  |
|  |  AuthController | ProductsController | InventoryController | OrdersController|  |
|  |  PaymentsController (HitPay Webhook) | ReportsController                    |  |
|  +-----------------------------------------------------------------------------+  |
|                                         |                                         |
|  +--------------------------------------v--------------------------------------+  |
|  |                            BUSINESS SERVICES LAYER                          |  |
|  |  AuthService | ProductCatalogService | InventorySyncService                 |  |
|  |  OrderFulfillmentService | HitPayPaymentService | ReportingService          |  |
|  +-----------------------------------------------------------------------------+  |
|                                         |                                         |
|  +--------------------------------------v--------------------------------------+  |
|  |                           DATA ACCESS LAYER (DAL)                           |  |
|  |  Parameterized ADO.NET / Dapper Repositories | DbConnectionFactory          |  |
|  |  ACID Transaction Coordinators | Concurrency Row-Locking Mechanisms        |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------|-----------------------------------------+
                                          |
                        +-----------------v-----------------+
                        |   MICROSOFT SQL SERVER (MSSQL)    |
                        |   - Normalized Relational Tables  |
                        |   - Stored Procedures & Triggers  |
                        |   - Stock Audit Logs & Indexes    |
                        +-----------------------------------+
```

---

## 3. Core Architectural Modules

### 3.1. OWIN & Authentication Pipeline
- Uses **Katana OWIN** (`Microsoft.Owin`, `Microsoft.Owin.Security.OAuth`, `Microsoft.Owin.Cors`).
- OWIN maps SignalR. API JWT validation uses `CustomerAuthorizeAttribute` and `StaffAuthorizeAttribute`; it is not installed OWIN bearer middleware.
- JWTs are read from the authentication cookie or Bearer header. Lifetime is 60 minutes, or 14 days when Remember Me is selected. There is no separate refresh-token service.
- Role-based authorization partitions permissions:
  - `Admin`: Full system control (user management, pricing, restock approval, financial reports).
  - `Staff`: Inventory management, in-store POS checkout, order status progression.
  - `Customer`: Profile management, order placement, order history tracking.

### 3.2. Real-Time SignalR Engine
- **InventoryHub:**
  - Public storefront and staff clients receive inventory broadcasts.
  - After a transaction commits, `stockUpdated` reports available stock (`CurrentStock - ReservedStock`), SKU, low-stock state, and change source.
  - Enables instant disabling of "Add to Cart" or "Buy Now" on the storefront when an item sells out in-store or online.
- **OrderHub:**
  - Publishes `newOrderReceived(orderSummary)` to the staff dashboard.
  - Triggers audible and visual alerts for store staff to begin preparing the helmet package.
- **CustomerOrderHub:** validates the current account before joining a server-selected customer group. It sends order-status updates only to that account. Profile and tracking pages reload their authenticated order data after receiving an update.

### 3.3. Payment Processing Architecture (HitPay)
- The following is the intended electronic-payment integration. Its live gateway contract was not validated or changed in the presentation fixes. The configured simulation remains a demonstration, not evidence of gateway certification:
  1. Frontend sends checkout request to Web API.
  2. Web API queries product catalog for server-side validated pricing, computes total, and invokes HitPay API.
  3. Server receives a unique checkout URL and returns it to the client for redirect.
  4. Upon payment completion, HitPay posts a signed webhook payload to `POST /api/v1/payments/hitpay-webhook`.
  5. The server validates HMAC-SHA256 signature using `HitPaySalt`, updates order status, and deducts inventory within a database transaction.

### 3.4. Database Concurrency & Race Condition Elimination
- Inventory decrement uses pessimistic row-level locking (`WITH (UPDLOCK, ROWLOCK)`).
- Strict atomic updates:
  ```sql
  UPDATE Inventories 
  SET CurrentStock = CurrentStock - @Quantity, UpdatedAt = SYSUTCDATETIME()
  WHERE VariantId = @VariantId AND CurrentStock - ReservedStock >= @Quantity;
  ```
- If `@@ROWCOUNT = 0`, the transaction rolls back with a concurrency exception (`409 Conflict`), guaranteeing zero negative stock counts.

Online checkout reserves units. A negative `ONLINE_SALE` audit associated with the order identifies already committed stock. Fulfillment never consumes another order's reservation for an already paid order. Cancellation restores committed physical units or releases uncommitted reservations; it preserves completed payment history and records that any refund still needs manual confirmation. POS commits physical units immediately. Pending presentation orders are cancelled manually; there is no background reservation-expiry worker.

## 4. Presentation business processes

- Pickup: `Processing` to `ReadyForPickup` to `Completed`. Delivery: `Processing` to `Shipped` to `Delivered` to `Completed`; direct completion after shipment is also allowed. Dispatch requires courier and tracking details.
- Cash pickup settles when completed. COD stock commits at dispatch, and collection is recorded when delivered or completed. These are staff confirmations; there is no courier collection API.
- Returns and exchanges progress through approval, receipt, and completion. Only inspected sellable goods are restocked. Completion requires notes confirming a manual refund or replacement handover. Exchanges select an equal-price replacement and deduct its available stock; price-difference settlement and store credit are outside this workflow.
- Reports count settled completed/delivered orders, net merchandise discount and completed manual refunds, excluding shipping. Approval alone and exchanges do not reduce revenue. A completed return removes its line's units from net units sold.
- Checkout validates fulfillment/payment combinations and computes presentation shipping rates on the server using the supplied province. These rates are academic assumptions, not verified courier quotations.
