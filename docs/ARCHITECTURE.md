# System Architecture: Helmet Cartel Ordering and Management System

## 1. Executive Summary
The **Helmet Cartel Ordering and Management System** is a unified retail and e-commerce platform designed to replace spreadsheet-based stock keeping with real-time, transaction-synchronized inventory management. It powers both a public-facing customer storefront and an administrative staff operations dashboard.

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
- Implements JWT bearer tokens for stateless API authorization.
- Token lifetime: Access Token (60 minutes), Refresh Token (7 days).
- Role-based authorization partitions permissions:
  - `Admin`: Full system control (user management, pricing, restock approval, financial reports).
  - `Staff`: Inventory management, in-store POS checkout, order status progression.
  - `Customer`: Profile management, order placement, order history tracking.

### 3.2. Real-Time SignalR Engine
- **InventoryHub:**
  - Clients subscribe to groups (`storefront` or `staff-dashboard`).
  - Upon transaction commit, broadcasts `stockUpdated(variantId, currentStock, isLowStock)`.
  - Enables instant disabling of "Add to Cart" or "Buy Now" on the storefront when an item sells out in-store or online.
- **OrderHub:**
  - Publishes `newOrderReceived(orderSummary)` to the staff dashboard.
  - Triggers audible and visual alerts for store staff to begin preparing the helmet package.

### 3.3. Payment Processing Architecture (HitPay)
- HitPay is integrated as a server-to-server gateway:
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
  WHERE VariantId = @VariantId AND CurrentStock >= @Quantity;
  ```
- If `@@ROWCOUNT = 0`, the transaction rolls back with a concurrency exception (`409 Conflict`), guaranteeing zero negative stock counts.
