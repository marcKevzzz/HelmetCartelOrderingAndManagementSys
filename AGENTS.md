# AGENTS.md — Helmet Cartel Ordering and Management System

Welcome to the **Helmet Cartel Ordering and Management System** repository. This document defines the operating model, agent roster, rule hierarchy, workflows, and standards governing development across this codebase.

---

## 1. System Overview
- **Project Name:** Helmet Cartel Ordering and Management System
- **Domain:** Motorcycle Helmets & Riding Gear Inventory & Online E-Commerce Platform
- **Core Problem Solved:** Eliminates spreadsheet-based stock tracking by providing a real-time, transaction-linked inventory database for both online and in-store sales, paired with a public online storefront and a staff management dashboard.
- **Technology Stack:**
  - **Backend:** ASP.NET Web Application (Web API 2, OWIN Pipeline, .NET Framework 4.7.2)
  - **Real-Time Engine:** SignalR (for real-time stock sync and order alerts)
  - **Database:** Microsoft SQL Server (MSSQL) with strict ACID transactions & concurrency locking
  - **Authentication:** JWT (JSON Web Tokens) with OWIN middleware
  - **Payment Gateway:** HitPay (REST API + Webhook signature verification)
  - **Frontend:** Vanilla HTML5, Modern CSS (Design System with CSS Variables), Modular JavaScript (ES6+)

---

## 2. Agent Roster & Specializations

All autonomous and pair-programming agents interacting with this repository MUST operate under one or more of the following agent profiles:

| Agent Name | Role & Scope | Primary References |
|---|---|---|
| **System Architect** (`architect_agent.md`) | High-level system design, schema integrity, API contracts, OWIN pipeline architecture. | `docs/ARCHITECTURE.md`, `database/schema/` |
| **Backend Engineer** (`backend_engineer_agent.md`) | C# Web API controllers, repository/service layer, MSSQL queries, SignalR hubs, HitPay integration. | `Constants/AppConstants.cs`, `Services/`, `Hubs/` |
| **Frontend UI Engineer** (`frontend_ui_agent.md`) | Responsive UI, Shop.co/Helmet Cartel design system, CSS custom properties, client-side state, SignalR frontend listener. | `Content/css/variables.css`, `Scripts/constants.js` |
| **QA & Concurrency Engineer** (`qa_security_agent.md`) | Concurrency control (inventory race condition prevention), JWT validation, payment webhook tamper prevention, SQL injection avoidance. | `.agents/rules/05_security_and_auth_rules.md` |

---

## 3. Directory Layout & Organization

```
HelmetCartelOrderingAndManagementSys/
├── .agents/                                # AI Agent definitions, rules, and workflows
│   ├── rules/                              # Behavioral, architectural, and coding rules
│   │   ├── 01_general_principles.md        # Core engineering best practices
│   │   ├── 02_csharp_backend_rules.md      # ASP.NET, OWIN, Web API standards
│   │   ├── 03_frontend_ui_rules.md         # UI/UX, CSS design system, JS standards
│   │   ├── 04_database_mssql_rules.md      # MSSQL transactions, locking & indexing
│   │   └── 05_security_and_auth_rules.md   # JWT, HitPay HMAC, role authorization
│   ├── workflows/                          # Standard operating procedures & lifecycle flows
│   │   ├── order_fulfillment_workflow.md   # Order state machine from checkout to completion
│   │   ├── realtime_inventory_workflow.md  # Real-time stock decrement and SignalR broadcast
│   │   ├── hitpay_payment_workflow.md      # Checkout generation & webhook handling
│   │   └── restock_reporting_workflow.md   # Low-stock alerts and reporting pipelines
│   └── agents/                             # Agent profile specifications
│       ├── architect_agent.md
│       ├── backend_engineer_agent.md
│       ├── frontend_ui_agent.md
│       └── qa_security_agent.md
│
├── docs/                                   # System and architectural documentation
│   ├── ARCHITECTURE.md                     # Comprehensive architecture and component design
│   ├── API_SPECIFICATION.md                # REST API endpoints, DTO contracts, status codes
│   ├── UI_SPECIFICATION.md                 # UI design breakdown based on design template
│   ├── DATABASE_DESIGN.md                  # Relational schema, ERD, locking strategies
│   ├── SETUP_GUIDE.md                      # Developer onboarding and environment setup
│   └── AI_CHANGELOG.md                     # Major changes log and context preservation
│
├── database/                               # Database assets, scripts, and profiling
│   ├── schema/
│   │   └── 01_schema.sql                   # Full DDL schema creation script
│   ├── seeds/
│   │   └── 02_seed_data.sql                # Rich seed data (categories, brands, helmets, stock)
│   ├── queries/
│   │   └── 03_procedures_and_queries.sql   # Stored procedures, atomic stock decrements, reports
│   └── query_logs/
│       ├── README.md                       # Query logging and profiling instructions
│       └── query_performance_logs.md       # Baseline query execution logs and execution plans
│
└── HelmetCartelOrderingAndManagementSys/    # Core Web Application
    ├── App_Start/                          # WebApiConfig.cs, Startup.cs (OWIN/SignalR)
    ├── Constants/                          # Centralized backend constants (AppConstants.cs)
    ├── Controllers/                        # MVC Controllers and Web API Controllers
    │   └── Api/                            # REST API Endpoints (Auth, Products, Orders, etc.)
    ├── Hubs/                               # SignalR Hubs (InventoryHub, OrderHub)
    ├── Infrastructure/                     # Database connection factory, JWT, HitPay client
    ├── Models/
    │   ├── Entities/                       # Domain entities
    │   └── DTOs/                           # Request / Response Data Transfer Objects
    ├── Repositories/                       # Data access interfaces and implementations
    ├── Services/                           # Business logic layer
    ├── Content/                            # Frontend assets
    │   ├── css/                            # CSS design system (variables, components, layout)
    │   └── images/                         # Storefront and brand assets
    ├── Scripts/                            # JavaScript modules and SignalR client
    └── Views/                              # UI HTML / Razor pages
```

---

## 4. Ground Rules for Any AI Agent
1. **Never Hardcode Values:** All status strings, role names, configuration keys, and error codes MUST be referenced from `AppConstants.cs` on the backend and `constants.js` on the frontend.
2. **Prevent Inventory Race Conditions:** Every inventory change MUST execute within a database transaction using atomic decrements with `UPDLOCK, ROWLOCK` to prevent negative stock counts.
3. **Real-Time Broadcasts:** Whenever an order is completed or stock is updated, trigger the SignalR `InventoryHub` and `OrderHub` so all connected clients (storefront and staff dashboard) receive live updates immediately.
4. **HitPay Security:** All HitPay webhooks MUST have their HMAC-SHA256 signature verified before updating order or payment statuses.
5. **UI Consistency & Zero Inline Styles:** The frontend MUST adhere to the design system defined in `Content/css/variables.css` matching the Shop.co / Helmet Cartel dark-accented modern aesthetic. Inline `style="..."` attributes are strictly prohibited; all styles must use semantic classes and consume designated CSS variables.
6. **Log All Major Changes:** Every significant architectural or schema change MUST be documented in `docs/AI_CHANGELOG.md`.
7. **Encoding Integrity:** All pages must serve UTF-8 responses and use official HTML entities (`&#8369;`, `&mdash;`) or JS unicode escapes (`\u20B1`) to completely prevent character corruption (e.g. `â‚±` or `â€”`).
8. **C# Backend Mandate (No JavaScript Backend):** The backend MUST strictly be implemented in **C#** (ASP.NET Web API 2, OWIN pipeline, C# Controllers, Services, Repositories, ADO.NET / MSSQL transactions, SignalR C# hubs, and Web Forms code-behind). JavaScript is strictly forbidden from serving as or simulating a backend, mocking APIs, or managing persistent server state. JavaScript is strictly confined to client-side presentation, DOM interactions, event listeners, and consuming C# Web API endpoints via HTTP fetch/AJAX.
9. **Storefront Purchasing & Cart Interaction Standard:** Product cards on the landing page (`Default.aspx`) are navigational previews that link directly to the product detail page (`Pages/ProductDetail.aspx?id=...`) and MUST NOT contain an "Add to Cart" button directly on the home page card. The primary purchasing actions (size selection, color selection, quantity stepper, and "Add to Cart" button) reside exclusively on the Product Detail page (`Pages/ProductDetail.aspx`).
10. **Mandatory Stored Procedures for All Database Operations:** Every database operation (data retrieval, inserts, updates, transactions) MUST be encapsulated within dedicated MSSQL Stored Procedures (`dbo.sp_...`). Inline raw SQL strings in C# repositories or code-behind files are strictly prohibited. Repositories must execute using `CommandType.StoredProcedure` and parameterized `SqlParameter` collections.
11. **Even Spacing, Proportional Balance & Grid Discipline (Never Stack Arbitrary Margins/Paddings):** Forms, sections, and layout blocks MUST use structured CSS Grid or Flexbox with defined design system `gap` variables (e.g., `gap: var(--space-4)`, `gap: var(--space-6)`). Never stack loose, ad-hoc, or asymmetrical margins and paddings across elements to simulate layout spacing. Related inputs (such as First Name / Last Name) must be split into balanced, proportional columns (e.g. `1fr 1fr`).
12. **Mandatory Inline Input Validation:** Interactive forms (Checkout, Authentication, Account Settings, Address forms) MUST implement responsive inline validation with visible error messages directly beneath the offending input field (using `.inline-error-msg` or `.auth-error-msg`) and border/background highlights (`.is-invalid`), validated both on blur and submit attempt. Relying solely on floating toasts or top banners is strictly prohibited.

