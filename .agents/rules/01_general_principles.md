# Rule 01: General Engineering Principles & Best Practices

## 1. Core Architectural Tenets
- **Separation of Concerns:** Keep presentation, business logic, data access, and infrastructure strictly decoupled.
- **Single Source of Truth:**
  - Constants must be defined once: `Constants/AppConstants.cs` (C#) and `Scripts/constants.js` (JavaScript).
  - CSS design tokens must reside exclusively in `Content/css/variables.css`.
- **Stateless Application Tier:** The Web API must be stateless; session state is strictly avoided in favor of JWT claims and database-backed persistence.
- **Fail Fast & Explicitly:** Validate inputs at system boundaries (Web API request models, database constraints). Reject invalid payloads with structured error responses before hitting business logic.

## 2. Real-Time First Philosophy
- Inventory updates are critical business events.
- Any operation altering inventory (in-store sale, online checkout, restocking, return) must publish an event through SignalR to keep all connected browser sessions synchronized without manual refreshes.

## 3. Transaction Safety & ACID Compliance
- Financial transactions, order creations, and inventory deductions must be wrapped in ACID transactions with appropriate isolation levels.
- Never deduct stock and create an order in separate non-atomic steps.
- Stored procedures or repository methods must implement row-level locking (`UPDLOCK, ROWLOCK`) when reading and updating stock counts.

## 4. Documentation & Traceability
- Any significant system change, API modification, or schema migration must be logged in `docs/AI_CHANGELOG.md`.
- Code changes must be self-explanatory with clean naming conventions; documentation explains *why*, not just *what*.

## 5. C# Backend Exclusivity & JavaScript Presentation Boundary
- **C# is the Exclusively Authorized Backend Runtime:** All backend logic, business rules, REST API controllers, database interactions (ADO.NET / MSSQL), transaction management, OWIN middleware, and SignalR hub servers MUST be written in C#.
- **No JavaScript Backend or API Simulation:** JavaScript is strictly restricted to the browser client. It must NEVER simulate an in-memory database, run mock backend servers, or execute server-side business rules. JavaScript's sole purpose is UI event handling, progressive enhancement, CSS class toggling, and communicating with the C# Web API endpoints via standard HTTP requests.
