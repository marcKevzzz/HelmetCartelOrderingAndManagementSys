# Workflow: Restocking, Auditing & Sales Reporting

This document defines the operational procedures for inventory restocking, historical audit tracking, and automated sales reporting to support data-driven procurement decisions for Helmet Cartel.

---

## 1. Restocking Workflow
1. **Low-Stock Detection:**
   - Background SQL job or API trigger queries `Inventories WHERE CurrentStock <= ReorderPoint`.
   - Items appear on the Staff Dashboard "Needs Restock" widget with urgency levels (Critical: 0 stock, Low: 1-3 stock).
2. **Purchase Order / Restock Entry:**
   - Staff receives physical stock delivery from brand distributor (Shoei, AGV, HJC, etc.).
   - Staff opens the "Restock Inventory" modal on the dashboard.
   - Selects Variant ID, enters restock quantity, supplier invoice number, and cost per unit.
   - Submits `POST /api/v1/inventory/restock`.
3. **Audit Trail Recording:**
   - System updates `Inventories.CurrentStock = CurrentStock + RestockQty`.
   - Inserts row into `StockAuditLogs` with `ChangeType = 'RESTOCK'`, previous stock, new stock, timestamp, and Staff User ID.
   - Clears `IsLowStock` flag if current stock exceeds reorder threshold.
   - SignalR broadcasts new stock availability to all active storefront visitors.

---

## 2. Sales & Inventory Reporting Workflow
1. **Report Types Supported:**
   - **Daily / Weekly / Monthly Sales Report:** Total revenue, number of completed orders, payment method breakdown (HitPay vs In-Store Cash/Card).
   - **Inventory Valuation Report:** Total on-hand units, retail valuation, cost valuation.
   - **Fast-Moving vs Slow-Moving Analysis (Turnover Velocity):** Units sold per model over 30/60/90 days to identify top-selling helmets and dead stock.
   - **Restocking Suggestion Report:** Generated using average daily sales rate:
     $$\text{Suggested Restock Qty} = (\text{Daily Run Rate} \times \text{Lead Time Days}) + \text{Safety Stock} - \text{Current Stock}$$
2. **Export Capabilities:**
   - CSV and PDF export options for staff management reviews.
