# AI Change Log & Architectural Evolution: Helmet Cartel

## [2026-09-29] — Mobile Navigation, Inventory Drill-down, and POS Counter

- Made the admin sidebar header close the mobile drawer and kept backdrop, Escape, navigation-link, ARIA, and desktop compact-state behavior in sync. Replaced the sidebar Brands List with a database-backed Inventory brand filter before Category.
- Added expandable Analytics brand details with product images, categories, variant stock/status, and exact Inventory links. Migration 14 adds the detail procedure and exact product/variant filters.
- Built the responsive POS counter with image-based variant search/filtering, live stock, a persisted current sale, optional customer details, Cash and approved external card-terminal checkout, mobile sale drawer, and printable receipt. POS uses authenticated C# APIs, the database effective-price function, locked inventory transactions, stock audit/payment records, and existing SignalR broadcasts.
- Updated the small-database builder and generated installer to include migration 14. Verified the .NET build, the Analytics/Inventory/POS pages, and rolled-back Cash/Card sale transactions; an insufficient-cash sale left stock and orders unchanged.

## [2026-09-29] — Catalog Wizard Layout, Image Ordering, and Product Preview

- Removed the Catalog Add Stock action and added an eye-icon preview that opens the real storefront product-detail page in a scaled admin modal.
- Reworked the Variants & Stock tab into clearly labeled color configuration sections, added automatic shade-based color names, changed size checkboxes into black/white toggle pills, and simplified matrix inputs to a bottom-border treatment.
- Simplified the Images tab to upload and draggable image tiles. Drag order is synchronized back to the file input so the first tile is saved as the primary image; remove controls now use a transparent background and turn red on hover.
- Replaced the Review summary header with a compact product-detail preview containing the primary image, storefront pricing, description, color swatches, size options, and disabled cart action.
- Removed the stock-in helper sentence, pricing preview panel, image-format helper sentence, image-preview heading, and direct image URL fields from the visible workflow.

## [2026-09-29] — Dynamic Admin Metrics, Activity Samples, and Stock Modal Repair

- Replaced dashboard stock placeholders with stored-procedure metrics reconstructed from stock audit history. Total stock, available stock, and low-stock alerts now compare the current value with the previous-day snapshot.
- Added selected-range inventory snapshots for Analytics so Total Warehouse Units and Active SKUs display the percentage change from the selected start date through the selected end date.
- Updated trend badges to use trending-up, trending-down, and dash SVG icons, with semantic design tokens for their colors and spacing.
- Repaired the Add Stock modal by removing conflicting inline display state and wiring open, close, backdrop, Escape, and live-preview behavior through reusable JavaScript handlers.
- Corrected stock-in auditing to use the schema-supported `RESTOCK` change type and allow a nullable actor until admin identity is connected to Web Forms authentication.
- Added an idempotent compact sample with three additional image-backed helmets, six SKUs, six orders/payments, and matching stock audit activity for the dashboard feed and charts.

## [2026-09-29] — Global Search Dropdown Visibility & Inventory Stock History Filter Isolation

- **Global Search Dropdown List Display:**
  - Resolved root cause preventing the `#adminSearchDropdown` autocomplete results list from appearing when typing or focusing on `#adminGlobalSearch`.
  - Removed `is-hidden` class (which enforced `display: none !important;`) and `hidden` attribute from the dropdown container in `Admin/Portal.master`.
  - Updated `Scripts/admin/admin.js` and `Scripts/admin/search-history.js` to ensure `dropdown.classList.remove('is-hidden')`, `dropdown.removeAttribute('hidden')`, and `dropdown.style.display = 'block'` are executed when rendering search results and recent queries.
  - Consolidated `.admin-search-dropdown` styles in `Content/css/admin/admin.css` to eliminate display conflicts.
  - Verified backend `/api/v1/admin/global-search?q=...` API responses returning categorized results across Brands, Catalog, and Inventory.
- **Inventory Stock History Filter Bar Clean-up:**
  - Moved the active stock `<div class="admin-filters-bar">` (containing status tabs `All`, `In Stock`, `Low Stock`, `Out of Stock` and category dropdown) inside `<asp:Panel ID="pnlActiveStock">` in `Admin/Inventory.aspx`.
  - When switching to the "Stock In History" tab (`pnlAuditHistory.Visible = true; pnlActiveStock.Visible = false;`), the active stock filters bar is now completely removed from rendering, keeping only the dedicated stock history activity tabs and log table.

## [2026-09-29] — Search Optimization, Trend Indicators, Stock History Filters, Left-Aligned Modals & Wizard Data Preservation

- **1. Search and Add Stock Optimization:**
  - Updated `dbo.sp_AdminInventoryVariants` and `dbo.sp_AdminGlobalSearch` stored procedures to support composite multi-word search queries (matching `CONCAT(Brand, ' ', Model)`, `CONCAT(Brand, ' ', Model, ' ', Color)`), fixing product search across all pages.
  - Added "Add Stock" action button across all relevant product cards/rows including Inventory search results and Catalog rows (`Admin/Catalog.aspx`), linking directly to the filtered inventory variant.
  - Ensured global search topbar maintains and reflects the active search query string on page load.
- **2. Dashboard and Analytics Metric Trend Badges:**
  - Added `admin-trend-badge` indicators with directional SVGs (up/green, down/red, neutral/gray) to:
    - **Dashboard:** Total Stock (`litOnHandStockTrend`), Available Stock (`litAvailableStockTrend`), Low Stock Alerts (`litLowStockTrend`), Active Orders, and Today's Revenue.
    - **Analytics / Reports:** Total Warehouse Units (`litTotalUnitsTrend`) and Active SKUs (`litTotalVariantsTrend`).
  - Removed "Low Stock Risks" KPI card completely from Analytics (`Admin/Reports.aspx`).
  - Cleaned up comparison strings and removed misleading static comparison labels like "vs prior 30 days".
- **3. Inventory Stock History & Positive Quantity Added Fix:**
  - Moved the active stock table pagination footer (`.admin-table-footer.admin-table-footer--center`) inside `<asp:Panel ID="pnlActiveStock">`, completely eliminating footer leak when viewing Stock History.
  - Replaced filler text in `admin-filters-left` with functional filter controls (Change Type segmented tabs: All Activities, Restocks, Adjustments, and brand dropdown).
  - Wired up `admin-meta-top` metadata to display actual record counts and total positive units added (`litAuditUnitsAdded`).
  - Fixed quantity display bug (`+-1 units`) by introducing `FormatQuantityAdded` helper returning positive counts (`+1 unit`, `+10 units`).
- **4. Modal Form Layout & Action Alignment:**
  - Standardized `.admin-modal--form` and `.admin-modal-footer` with left-aligned form fields/labels and right-aligned actions across `#stockAdjustModal`, `#adminDeleteProductModal`, and `#adminSignOutModal`.
  - Implemented responsive mobile stacking (`flex-direction: column-reverse`) on small viewports.
- **5. Add Helmet Modal Wizard Enhancements:**
  - Reduced input and textarea placeholder opacity to `0.45` (`color: var(--color-text-muted)`).
  - Improved layout across Tabs 2 (Variants & Stock), 3 (Pricing), 4 (Images & Upload), and 5 (Review).
  - Enhanced Tab 5 (Review) with product thumbnail, brand/category tags, model overview, pricing breakdown, and variant chips.
  - Implemented in-memory value snapshot in `renderVariantMatrix()` to preserve all user-entered SKU, price adjustment, and stock values across tab switches.

## [2026-09-28] — Admin Inventory Pagination, Zero Horizontal Scroll Desktop Layout, Global Search & Dynamic Variant Matrix

- **Inventory Pagination & Desktop Layout (Zero Horizontal Scroll):**
  - Implemented 50-items-per-page pagination on `Admin/Inventory.aspx` with clean monochrome page controls (Previous, numbered pages 1, 2, 3..., Next), dynamic range calculation (e.g. `Showing 1-50 of 440 variants`), and responsive status pill updates.
  - Enforced strict desktop layout discipline: configured `table-layout: fixed; width: 100%;` and `overflow-x: hidden;` on desktop table wrapper, with percentage column widths across all 12 columns and text-overflow ellipsis (`text-overflow: ellipsis; white-space: nowrap; overflow: hidden;`) with full title tooltips, completely eliminating x-axis scroll on desktop viewports.
  - Formatted Stock counts as 3-digit numbers (e.g., `002`, `020`, `450`, `1,512`).
  - Added dedicated **Stock Adjustment** modal and row action (`+/- Stock`) powered by `dbo.sp_AdminAdjustStock` and `AdminDataRepository.AdjustStockAsync`, supporting Restock (+), Deduct (-), reason logging (Supplier Restock, Recount, Damaged, Showroom, Return), and real-time SignalR `InventoryHub` broadcast.
- **Global Search Dropdown with Autocomplete:**
  - Added instant search autocomplete dropdown in `Admin/Portal.master` topbar attached to `#adminGlobalSearch` and `#adminSearchDropdown`.
  - Backed by stored procedure `dbo.sp_AdminGlobalSearch` and REST API `GET /api/v1/admin/global-search?q=...` returning categorized results across **Inventory / Helmets** (brand, model, color, size, SKU, stock), **Orders** (order number, customer name, email, phone, status, total), and **Users / People** (full name, email, phone, role badge).
  - Clicking any result directly navigates to the filtered destination with matching `?q=...` support across `Inventory.aspx`, `Orders.aspx`, and `Users.aspx`.
- **Users Directory 3-Digit UID Formatting:**
  - Formatted user IDs as 3-digit identifiers (e.g., `#001`, `#002`, `#003`).
  - Added real-time query string search filtering by name, email, phone, or UID in `Admin/Users.aspx.cs`.
- **Catalog Management & Dynamic Variant Matrix Generation:**
  - Added "Add Helmet Model" modal in `Admin/Catalog.aspx` allowing input of basic specifications, multiple colors (solid hex or CSS linear gradients), and size checkboxes (S, M, L, XL, 2XL).
  - Dynamically computes and renders the variant matrix grid with individual generated SKUs, price adjustments (`+0.00`), initial stock counts (`10`), and reorder points (`3`).
  - Submits transactionally to MSSQL stored procedure `dbo.sp_AdminCreateProductWithVariants`, atomically inserting the product, color mappings, active variants, initial inventories, and audit logs.
- **Clean Minimalist Headers & Sidebar Active State:**
  - Removed unnecessary export and share buttons (`Export CSV`, `Share`, `Stock List`) from page headers across `Inventory.aspx`, `Orders.aspx`, `Catalog.aspx`, `Reports.aspx`, and `Users.aspx`.
  - Set active sidebar navigation items to solid black background (`#000000`) with high-contrast white text and stroke icons.
  - Re-engineered sidebar transitions to provide smooth animation on both expanding and collapsing (`cubic-bezier(0.4, 0, 0.2, 1)`).

## [2026-09-28] — Admin Portal Redesign (Bikezy-Inspired Layout), File Relocation & C# Backend ASP Components

- **Design System & Layout Architecture (Bikezy Reference):**
  - Redesigned the admin layout to replicate the modern, spacious dashboard aesthetic from the user's reference:
    - **Floating Sidebar:** Clean rounded sidebar card (`border-radius: var(--radius-xl)`), dark brand badge, `MENU` navigation, collapsible `BRANDS LIST` (Shoei, AGV, HNJ, Gille, Zebra), and `OTHER` links (Storefront, Settings, Sign Out).
    - **Unnecessary Components Stripped:** Removed trial/pro SaaS subscription banners entirely. Removed bike-specific attributes (VIN, Model Year, J-Stock) and replaced with helmet domain attributes (Brand, Model, Category, Stock, Price, SKU, Status, Actions).
    - **Monochrome Elegance:** Strictly consumed CSS custom properties from `Content/css/variables.css` (`--color-primary`, `--color-surface-*`, `--color-text-*`, `--color-border-*`, `--space-*`, `--radius-*`, `--shadow-*`). Used minimalist monochrome badges (`Completed`, `Pending`, `Not Completed`) and buttons.
    - **Top Bar:** Sleek search pill with magnifying glass icon, keyboard shortcut badge (`⌘+K`/`Ctrl+K`), quick filter dropdown, notifications bell with status dot, settings gear icon, and admin user capsule with monogram avatar.
    - **Data Table:** Card container with rounded borders, select-all checkbox, helmet image thumbnail, brand, model name, category, stock number, PHP price (`₱`), SKU code, status pill, and actions (`•••`, eye view link).
- **ASP.NET Server Components & C# Backend (Zero Mocking / No Heavy Client JS):**
  - Refactored `Admin/Inventory.aspx` to use native ASP.NET server controls (`<asp:Repeater>`, `<asp:LinkButton>`, `<asp:DropDownList>`, `<asp:Literal>`) powered by C# code-behind `Admin/Inventory.aspx.cs`.
  - Added strongly typed stored procedure `dbo.sp_AdminInventoryProducts` in `database/queries/05_admin_operations.sql` and `AdminDataRepository.GetInventoryProductsAsync` supporting search, brand filtering, category filtering, and stock status filtering.
  - Implemented `Admin/Dashboard.aspx` and `Admin/Dashboard.aspx.cs` with executive monochrome KPI metric cards.
- **Directory Structure & Asset Relocation:**
  - Relocated admin stylesheet to `Content/css/admin/admin.css` and admin scripts to `Scripts/admin/admin.js`.
  - Cleaned up misplaced `Admin/admin.css` and `Admin/admin.js` from the `Admin/` folder.
  - Registered all new files and code-behind dependencies in `HelmetCartelOrderingAndManagementSys.csproj`.

## [2026-09-28] — Admin UI/UX Monochrome Redesign, Collapsible Sidebar & Action Icons

- **Strict Monochrome Design System:** Fully redesigned `Admin/admin.css` to consume design system tokens from `Content/css/variables.css` and `Content/css/components.css`. Enforced a refined black and white monochrome aesthetic (`#000000`, `#FFFFFF`, neutral grays `#171717`, `#525252`, `#737373`, `#E5E5E5`, `#F8F8F8`) aligning the operations portal directly with the Shop.co / Helmet Cartel storefront aesthetic. Removed arbitrary yellow/gold colors and loose spacing.
- **Collapsible Sidebar with SVG Icons:**
  - Modern collapsible sidebar supporting desktop toggle (260px wide to 74px compact) with animated chevron/dock toggle and `localStorage` persistence (`hc_admin_sidebar_collapsed`).
  - Added clean inline SVG vector icons for all navigation items: Dashboard, Orders, Inventory, Point of Sale, Catalog, Reports, Users, Reviews, Payments, Storefront link, and Sign Out.
  - Added compact "HC" monogram brand header when collapsed, with full text gracefully hidden.
  - Added mobile off-canvas drawer navigation triggered by the topbar hamburger button, accompanied by a blurred backdrop overlay (`#admin-sidebar-overlay`) with touch-friendly tap-to-close.
- **Icons for Actions:** Integrated SVG icons across all datatable and workspace actions:
  - View (`eye`), Edit (`edit`/pencil), Manage (`manage`/sliders), Restock (`restock`/plus-square), Adjust (`sliders`), History (`history`/clock), Add Item/Product/User (`plus`), Apply Filters (`filter`), Mark Status / Complete Sale (`check`), Hide/Restore Reviews (`eye-off`/`eye`), Remove (`trash`), Print Receipt (`printer`), and Upload (`upload`).
- **Confirmation Modals & Inline Validation:**
  - Re-engineered `confirmAction(...)` into a structured, accessible modal dialog with an alert icon, clear prompt, secondary cancel button, and primary/danger confirm button, with keyboard accessibility (Escape, Tab focus-trap).
  - All add and edit forms render inside modal dialogs with inline validation (`.is-invalid` borders, `.inline-error-msg` messages directly beneath inputs).
- **Toast Notifications for Datatables:**
  - Styled toasts matching the storefront design (`.admin-toast`), featuring pure white background, subtle border, elevation shadow, SVG status icon, message text, and dismiss button.
  - Added and audited toast triggers for every add, update, restock, adjust, status transition, review visibility change, and POS sale completion across datatables.
- **Responsive & Mobile Friendly:**
  - Responsive datatables in horizontal scroll containers with sticky headers (`thead th`).
  - Fluid KPI metric cards (4-column grid scaling to 2-column on tablet and 1-column on mobile).
  - Form grids automatically collapse from 2 columns to 1 column on smaller viewports.

## [2026-09-28] — Role-based admin portal

- Added `/Admin/` pages for Dashboard, Orders, Inventory, POS, Catalog, Reports, Users, Reviews, and payment diagnostics. Admin-only navigation and API authorization use fresh database roles; Staff can operate orders, stock, and POS; Customer cannot call admin APIs. Added responsive modal forms, confirmation dialogs, inline errors, and toast feedback.
- Added stored-procedure-only admin repositories and APIs. Multi-item physical sales and HitPay confirmation update orders, payments, inventory, audit records, and restock alerts atomically. Stock and order SignalR events now broadcast after committed changes.
- Added additive first/last name and structured linear-gradient migration. Existing names and color strings remain intact; legacy gradients gain ordered stops. Public signup creates Customers only, while Admin manages roles and account status. `FullName` remains for compatibility.
- Added sales and stock reports from completed payments, review moderation, and read-only payment/webhook diagnostics. Inventory valuation is deferred until acquisition cost is stored.
- Added a combined order and stock activity feed to the dashboard and a SKU/product search to the POS picker. Catalog gallery positions now use `INT`, so the admin editor can manage images beyond the storefront's five thumbnail slots. Committed sales and stock changes remain successful if a later SignalR notification fails; notification errors are traced.
- Added optional `database/seeds/07_dashboard_audit_samples.sql`. Its stored procedure adds four idempotent demo audit events and adjusts stock inside one transaction so audit balances stay valid.
- Updated local SQL Server using `database/schema/06_admin_portal_migration.sql`, `database/queries/03_procedures_and_queries.sql`, `database/queries/05_admin_operations.sql`, and `database/queries/06_admin_catalog.sql`. Backup: `HelmetCartelDB_admin_portal_20260928_0650.bak` in the SQL Server default Backup directory. Verified three names, 88 colors, both legacy gradients, and a rolled-back two-item POS sale.

## [2026-09-28] — Complete sample catalog availability

- Added rerunnable `database/seeds/06_sample_catalog_availability.sql` with `dbo.sp_SeedSampleCatalogAvailability`. It fills missing S–XXL variants and inventory for the five supplied brands, adds sample opening stock with stock audit records, gives XL/XXL variants sample price adjustments, and adds missing visible specifications for the four original five-brand products. Existing nonzero stock, price adjustments, prices, and specification values are preserved.
- Applied the seed to local `HelmetCartelDB`: 35 actual product rows (highest ID 39), 440 variants, 440 inventory rows, 105 specification values, and 176 adjusted variants. `dbo.sp_GetProductsPaged` now reports 35 products; the four previously missing products had no active variants. IDs 3, 4, 6, and 8 remain deleted as previously requested.
- Opening quantities and adjustments are demonstration values and need review before real sales. Run this seed after `05_catalog_content.sql` on an existing installation.

## [2026-09-28] — Gradient Color Selection & Color Input Capabilities
- **Gradient Swatch UI & Rendering:** Enhanced `.color-swatch` in `Content/css/storefront.css` and `Pages/ProductDetail.aspx` to render rich CSS gradients (`linear-gradient(...)`, `radial-gradient(...)`, and comma-separated hex codes). Added drop-shadowed checkmarks (`filter: drop-shadow(0 1px 2px rgba(0,0,0,0.75))`) and active rings (`box-shadow: 0 0 0 2px #000000, 0 2px 8px rgba(0,0,0,0.18)`) ensuring high contrast and legibility over any gradient.
- **Database Schema Expansion:** Altered `dbo.ProductColors.ColorHex` from `NVARCHAR(10)` to `NVARCHAR(255)` on the live database and in `database/schema/01_schema.sql`, dropping the restrictive 6-character hex CHECK constraint `CK_ProductColors_ColorHex` so gradient CSS definitions and multi-hex strings are fully accepted.
- **Base Color Algorithm Gradient Resilience:** Updated SQL function `dbo.fn_BaseColorFromHex(@ColorHex NVARCHAR(255))` in `database/queries/03_procedures_and_queries.sql` and the live MSSQL database to gracefully extract the primary hex from gradient strings or return `'Multi'`, preventing filtering crashes.
- **Gradient Color Input Mechanisms:**
  - Added stored procedure `dbo.sp_AddProductColor` for atomic upserting of product colors with hex or gradient strings.
  - Implemented `IProductRepository.AddProductColorAsync` and REST API endpoint `POST /api/v1/products/{id}/colors` supporting direct JSON inputs (e.g. `{ "color": "Solar Flare", "colorHex": "linear-gradient(135deg, #FF416C, #8A2387)" }` or `{ "color": "Cyber Sunrise", "colorHex": "#00F2FE, #4FACFE" }`).
  - Removed `.Take(5)` limitation on `UniqueColors` in `Pages/ProductDetail.aspx.cs` so all product colors and gradients are presented to shoppers.

## [2026-09-28] — 5-Thumbnail Rail Height Matching, Extra Images Modal & Unlimited Product Images
- **Mathematical Height Matching:** Aligned `.product-gallery__main` and `.product-gallery__thumbs` to an exact shared height formula using CSS variables (`--gallery-thumb-size: clamp(86px, 8.8vw, 102px); --gallery-gap: var(--space-3); --gallery-total-height: calc((5 * var(--gallery-thumb-size)) + (4 * var(--gallery-gap)));`). This guarantees the main product image and the 5 stacked thumbnail slots match pixel-for-pixel with zero vertical misalignment.
- **Overflow Scroll Prevention & 5-Slot Left Rail:** Disabled scrolling on `.product-gallery__thumbs` (`overflow: hidden; max-height: var(--gallery-total-height);`). Extra thumbnail items past slot 5 are hidden from the rail via `.gallery-thumb--hidden` (`display: none !important;`).
- **5th Thumbnail `+N...` Frosted Glass Overlay:** When a product has 6 or more total images, the 5th thumbnail slot renders a semi-transparent frosted glass badge (`.gallery-thumb__more`) displaying `+{count - 5}...` (e.g. `+1...` when 6 images exist) over a subtly dimmed image preview (`filter: brightness(0.6)`).
- **Interactive Extra Images Modal Dialog:** Clicking the 5th thumbnail opens `#gallery-modal`, presenting an accessible modal dialog with responsive cards for all additional product views. Clicking any card updates `#main-product-img`, marks the selection active, mirrors the chosen image into the 5th thumbnail slot, and smoothly closes the modal.
- **Removal of 6-Image Product Limit:** Relaxed database constraint `CK_ProductGalleryImages_DisplayOrder` from `DisplayOrder BETWEEN 1 AND 5` to `DisplayOrder >= 1` in `database/schema/03_product_gallery.sql` and live MSSQL. Removed `TOP (5)` and `@DisplayOrder > 5` check in stored procedures `dbo.sp_GetProductById` and `dbo.sp_AddProductGalleryImage` in `database/queries/03_procedures_and_queries.sql`. Removed `.Take(Math.Max(0, 6 - GalleryImages.Count))` in `Pages/ProductDetail.aspx.cs` to allow unlimited gallery views per product.

## [2026-09-28] — Vertical Product Gallery & Left-Hand Thumbnails
- **Left-Aligned Thumbnail Rail:** Repositioned `.product-gallery__thumbs` to the left side of the main product image in a vertical column (`display: grid; grid-template-columns: clamp(96px, 10vw, 124px) 1fr; gap: var(--space-4);`) matching the Shop.co / modern luxury e-commerce layout.
- **Vertical Main Product Image Layout:** Restructured `.product-gallery__main` into a vertical portrait ratio (`aspect-ratio: 4 / 5; max-height: 560px;`) with smooth thumbnail switching and rounded container framing.
- **Adaptive Mobile Gallery:** On narrow viewports (≤ 768px), the gallery automatically falls back to a full-width main image with a horizontal scrollable thumbnail strip beneath it (`order: 1` and `order: 2`).


## [2026-09-28] — Product Info Sizing Balance & Grid Discipline
- **Unified Product Info Flex Rhythm:** Restructured `.product-info` on `ProductDetail.aspx` using a structured vertical Flexbox layout with design-system gaps (`gap: var(--space-4)`), eliminating asymmetric stacked margins and arbitrary loose paddings.
- **Consistent Section Dividers & Proportional Gaps:** Standardized the divider lines across color selector, size selector, quantity stepper, and action buttons (`border-top: 1px solid var(--color-border-subtle)` with uniform `padding-top: var(--space-4)`).
- **Harmonized Action Buttons & Control Heights:** Aligned `.btn--fav-detail`, `.btn--add-cart`, and `.btn--buy-now` to a unified 50px height with consistent pill border-radii and typography. Balanced `.size-pill` at 42px height and `.quantity-stepper-lg` at 44px height.


## [2026-09-28] — Hero Section Viewport Balance & Clean Search Suggestions Dropdown
- **Balanced Hero Section Viewport Scaling:** Standardized the landing page hero section (`Default.aspx`) to fill the screen viewport height below the navigation while leaving `--hero-ticker-peek: 70px` for the black brand ticker strip to cleanly peek in at the fold. Added design tokens in `Content/css/variables.css` (`--hero-min-height`, `--hero-title-size`, `--hero-desc-size`, `--hero-stat-number-size`, `--hero-stat-label-size`).
- **Harmonious Grid Balance:** Realigned `.hero-content` to vertically center text, description, CTA button, and stats counters, while grounding `.hero-media__img` at the bottom edge of the hero section without clipping.
- **Clean Search Dropdown State:** Fixed `#nav-search-dropdown` in `Scripts/site.js` so focusing or clicking `#nav-search-input` when there is no query and no search history kept in local storage will no longer display a blank "Search the helmet catalog" dropdown box. It opens only when real history items or typed query suggestions exist.


## [2026-09-28] — Product order count and mobile storefront
- Product detail now counts distinct non-cancelled orders through product colors and variants, and hides the count when zero. Added an order-item lookup index for new and existing databases; rerun `database/queries/03_procedures_and_queries.sql` after applying the index migration.
- Moved brand, category, riding style, available sizes, and color count into the Product Details block below the description.
- Added a collapsible mobile shop filter panel and narrow-screen layouts for shop cards, pagination, gallery thumbnails, review controls, related products, cart items, wishlist cards, and checkout steps and forms. Removed inline checkout styles touched by this change.

## [2026-09-27] — Catalog photos, content and purchasing state
- Added 113 selected source photos under the web project's product image tree, with a source-to-product manifest. Added an idempotent stored procedure seed for gallery images, nine distinct image-based helmets, editable nonzero price estimates, visible product specifications and ten unverified reviews explicitly labeled as samples. Existing nonzero prices and inventory are preserved.
- Corrected the Gille FF005 Visage and 135 GTS V1 category mappings to match the visible helmet type.
- Cart items now use SQL variant IDs, current database prices and stock. Product detail matches both size and color, checks stock, and computes variant adjustments before the product discount.
- Wishlist cards now show database prices and ratings without invented defaults and refresh saved products from the product API. Shop cards have a wishlist action that loads the selected product from the API. Cart item controls, stock warnings and checkout selection use the same IDs. Removed client-only automatic discounts and promo codes that the order API did not honor.
- Existing catalog seed inventory remains zero until real stock is recorded. The new prices and sample review content should be reviewed before stocking products for sale.

## [2026-09-27] — Product detail page flow and recommendations
- Replaced the detail, review, and FAQ tabs with a vertical product details block, a single-column review discussion, and related product cards.
- Product details show the description and first three specifications by default; Show more reveals the remaining product-specific specifications.
- Added `sp_GetRelatedProducts` and a repository method that return up to four active products, ordered by matching category, matching riding style, then catalog rating.
- Kept database-backed reviews, ratings, filtering, sorting, reporting, and submission; removed Shoei-only FAQ content from the product page.
- Re-run `database/queries/03_procedures_and_queries.sql` on existing databases to install the related-product procedure.

## [2026-09-27] — Category-aware product specifications
- Added normalized specification definitions, category-to-spec mappings, and product-specific specification values.
- Added stored procedures to read specifications, add definitions, map specs to categories, and upsert product values, plus an idempotent seed procedure for the supplied Shoei RF-1400 details.
- Product detail specifications now load from MSSQL and only display values that exist for the selected product; removed the hardcoded Shoei certification badge strip.
- Run `database/schema/04_product_specifications.sql`, then `database/queries/04_product_specification_procedures.sql`; execute `dbo.sp_SeedShoeiRf1400Specifications` after the target product is present.

## [2026-09-27] — Product detail variants and gallery
- Product detail now renders no more than five distinct color variants and derives thumbnails from the product's own image data instead of fixed sample images.
- Added `ProductGalleryImages` for up to five optional images per product, while `Products.MainImageUrl` remains the primary image; together they support six gallery thumbnails.
- Extended `sp_GetProductById` with a gallery result set and added `sp_AddProductGalleryImage` for controlled gallery inserts.
- Existing catalog entries have only their primary image until extra product-specific views are added through the stored procedure.
- Existing databases: run `database/schema/03_product_gallery.sql`, then rerun `database/queries/03_procedures_and_queries.sql`.

This file maintains a historical ledger of major architectural decisions, directory reorganizations, and design implementations. All AI agents working on this project must inspect this file before proposing architectural changes and log new milestones upon completion.

---

## [2026-09-27] — Product Detail Script Modularization: Zero Inline JavaScript

### 1. External JavaScript Architecture (`Scripts/product-detail.js`)
- Extracted and centralized all client interactions into a dedicated ES6 module [`Scripts/product-detail.js`](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/product-detail.js).
- Cleanly decoupled server data injection via a non-executable `<script type="application/json" id="product-detail-data">` payload.
- Registered `Scripts/product-detail.js` in `HelmetCartelOrderingAndManagementSys.csproj` and loaded via `<script type="module" src="...">`.

### 2. Elimination of All Inline Event Handlers (`Pages/ProductDetail.aspx`)
- Stripped every `onclick="..."` attribute across the entire page:
  - Gallery thumbnails: event delegation/listeners updating `#main-product-img` and `.active` classes.
  - Color swatches: event listeners toggling `.active` state and injecting vector checkmark icons.
  - Size pills: clean listener switching `.active` pills.
  - Quantity steppers: semantic `#btn-qty-dec` and `#btn-qty-inc` click handlers.
  - Tab navigation: `data-tab` attributes driving pane visibility (`#tab-details`, `#tab-reviews`, `#tab-faqs`).
  - FAQ accordions: listener toggling `.is-open` on `.faq-accordion-item`.
  - Review action popovers and reporting: event delegation for `.review-more-btn` and `.btn-report-review`.
  - Modals: semantic IDs and backdrop click dismissals for both Report and Write Review dialogs.

---

## [2026-09-27] — Product Detail Page Reviews Architecture: Reporting, Star Filtering, & Verified Buyer System

### 1. Star-Based Review Filter & Verified Buyer Controls (`Pages/ProductDetail.aspx`)
- Upgraded the reviews filter dropdown menu (`#review-filter-menu`) to render visual **Gold/Empty SVG Stars** matching the store design system instead of plain text:
  - 5 Stars (★★★★★), 4 Stars (★★★★☆), 3 Stars (★★★☆☆), 2 Stars (★★☆☆☆), 1 Star (★☆☆☆☆).
  - Each star filter row displays a dynamic count pill indicating how many reviews on the helmet match that rating.
  - Active star state highlights row in obsidian primary (`#000000`) while preserving vibrant amber stars (`var(--color-accent-amber)`) and semi-transparent empty stars.
- Implemented "Verified Purchases Only" filter checkbox with an authentic green checkmark badge (`.review-verified-badge--sm`) and count badge.
- Dynamic client-side filter engine (`applyReviewFilters()`) instantaneously combines rating criteria and verified status, updating the total count display (`#reviews-count-display`) and showing a responsive empty-filter state if zero reviews match.

### 2. Community Review Reporting Workflow
- Added review action popovers (`•••`) on each review card with a "Report this review" action.
- Built accessible Report Modal (`#report-review-modal`) supporting community flagging reasons (`SPAM`, `OFFENSIVE`, `IRRELEVANT`, `FAKE`) with optional reporter notes.
- Integrated `POST /api/v1/reviews/report` invoking `dbo.sp_ReportReview` with stored procedure execution, IP/User duplicate prevention, and automatic review auto-hiding when flag count reaches $\ge 3$.
- Instant UI state reflection: shows a confirmation toast notification, updates the review card with a persistent amber "Reported" pill, and locks the reporting action to prevent duplicate clicks.

### 3. C# Web API Backend & Stored Procedure Execution
- Added `Models/DTOs/ReviewDTOs.cs` defining `ProductReviewDto`, `ReportReviewRequestDto`, `ReportReviewResultDto`, and `AddReviewRequestDto`.
- Added `IReviewRepository` and `ReviewRepository` executing MSSQL stored procedures (`dbo.sp_GetProductReviews`, `dbo.sp_ReportReview`, and `dbo.sp_AddProductReview`) via parameterized `SqlParameter` and ADO.NET (strict compliance with Rule 8 and Rule 10).
- Created `Controllers/Api/ReviewsController.cs` exposing REST endpoints for reviews retrieval and reporting.

---

## [2026-09-27] — Database-Driven Shop Catalog

- Extended `dbo.sp_GetProductsPaged` with color-family and size filters, broader product search, effective-price filtering and sorting, and stable paged totals. `dbo.fn_BaseColorFromHex` maps stored hex values to ten fixed shop colors.
- Shop cards now show database images, brand, category, name, description, price, discount, rating, and review count. Filter and sort selections use URL parameters; pagination is based on the filtered count.
- Replaced hardcoded desktop search suggestions with product API results, added mobile suggestions, and corrected navigation category/style links to match stored values.
- Copied the 22 supplied images into the upload helper's canonical `Content/images/products/helmets/{brand}/` tree and corrected the web project's content entries.
- Re-run `database/queries/03_procedures_and_queries.sql` on an existing database before using the new shop filters.

## [2026-09-27] — Brand-Segmented Helmet Image Storage Architecture

### 1. Brand-Segmented Image Storage (`Content/images/products/helmets/{brand}/`)
- Reorganized helmet image storage from a flat product folder into dynamic brand-segmented subdirectories:
  - Base Directory: `Content/images/products/helmets/`
  - Subdirectories: `/hnj/`, `/gille/`, `/shoei/`, `/agv/`, `/zebra/`, `/bell/`, `/arai/`, `/hjc/`, `/shark/`
  - Physical Directory: `c:\Users\Admin\source\repos\HelmetCartelOrderingAndManagementSys\HelmetCartelOrderingAndManagementSys\Content\images\products\helmets\{brand}\`
  - Database & Web URL format: `/Content/images/products/helmets/{brand}/{filename}`
- Migrated all existing catalog image assets into their respective brand folders under `Content/images/products/helmets/`.
- Updated `database/seeds/03_helmet_catalog_seed.sql` to reference `/Content/images/products/helmets/{brand}/...`.

### 2. Upgraded ImageUploadHelper (`Infrastructure/ImageUploadHelper.cs`)
- Added `CleanBrandSlug(string brand)` to sanitize brand names into filesystem-safe and URL-safe slugs (e.g. `"Shoei"` -> `"shoei"`, `"HNJ"` -> `"hnj"`).
- Added `GetBrandHelmetFolder(string brand)` resolving `~/Content/images/products/helmets/{brand}/`.
- Updated `SaveUploadedImage(FileUpload, brand, prefix, ...)` and all overloads to route uploads dynamically to the brand subfolder.
- Added `GetApplicationRootPath()` to provide robust physical path resolution across both hosted (IIS / IIS Express via `Server.MapPath`) and unhosted (CLI / test runner via project root detection) runtime environments.
- Added `Brand` property to `ImageUploadResult`.

### 3. Dashboard Image Upload UI & Zero Inline Styles Integration
- Updated [`Pages/Dashboard.aspx`](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Pages/Dashboard.aspx) with `<asp:DropDownList ID="ddlImageBrand">` containing all supported helmet brands.
- Refactored all inline styles into clean design-system classes in [`Content/css/dashboard.css`](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Content/css/dashboard.css) (`.image-upload-grid`, `.image-upload-field`, `.image-upload-label`, `.image-upload-result`, `.image-upload-preview`).
- Updated [`Pages/Dashboard.aspx.cs`](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Pages/Dashboard.aspx.cs) to pass the selected brand into `ImageUploadHelper.SaveUploadedImage(...)`.

---

## [2026-09-27] — Normalized Reviews, Community Reports, and FAQs Schema Deployment

### 1. Database Schema Extension (`database/schema/01_schema.sql`)
- Added normalized tables:
  - `dbo.ProductReviews`: Stores immediate-publishing customer ratings (1-5 stars), reviewer headline, body comment, verified buyer badge, and community flag counter (`FlagCount`).
  - `dbo.ReviewReports`: Normalized junction table for community reporting/flagging. Enforces `UNIQUE (ReviewId, UserId)` to prevent duplicate report spamming and records report reasons (`SPAM`, `OFFENSIVE`, `IRRELEVANT`, `FAKE`).
  - `dbo.Faqs`: Streamlined, normalized FAQ repository with `DisplayOrder` and polymorphic `ProductId` (supports both global store FAQs when `ProductId IS NULL` and product-specific Q&As when assigned).
- Maintained strict reverse-dependency drops at script header.

### 2. Seed Data Enhancement (`database/seeds/02_seed_data.sql`)
- Seeded general store FAQs covering in-store cash pickup, helmet head measurement guide, 3-day exchange policy, and safety certifications.
- Seeded product-specific FAQs (Pinlock compatibility for Shoei RF-1400, biplano spoiler replacement for AGV Pista).
- Seeded verified customer reviews with 5-star ratings across flagship products.

### 3. Dedicated Stored Procedures (`database/queries/03_procedures_and_queries.sql`)
- Implemented `dbo.sp_GetProductReviews`: Retrieves unhidden reviews for product view.
- Implemented `dbo.sp_AddProductReview`: Atomically inserts reviews and automatically recalculates and syncs `Rating` and `ReviewCount` in `dbo.Products`.
- Implemented `dbo.sp_ReportReview`: Logs user report, increments `FlagCount`, and automatically sets `IsHidden = 1` if flag threshold (`>= 3`) is reached.
- Implemented `dbo.sp_GetFaqs`: Retrieves global and product-scoped FAQs.
- Verified all tables, seed data, and procedures on local `.\SQLEXPRESS` (`HelmetCartelDB`).

---

## [2026-09-27] — Server-Side Data-Binding via ASP Components & Image Upload Helper

### 1. Server-Side Data-Binding with ASP Components & C# Code-Behind
- Migrated primary data retrieval from client-side JavaScript DOM population to native ASP.NET Web Forms server controls and C# code-behind:
  - **`Default.aspx` & `Default.aspx.cs`:** Implemented `<asp:Repeater ID="rptNewArrivals">` and `<asp:Repeater ID="rptTopSelling">` using `IProductRepository.GetNewArrivalsAsync()` and `GetTopSellingAsync()`. Added `RenderStars()` helper for dynamic SVG star rating generation.
  - **`Pages/Shop.aspx` & `Shop.aspx.cs`:** Implemented `<asp:Repeater ID="rptCatalog">`, `<asp:Literal ID="litProductsCount">`, and `<asp:Panel ID="pnlNoProducts">`. Dynamically filters by category, brand, riding style, search keywords, and sort orders in C# `Page_Load` via `ProductFilterParams`.
  - **`Pages/Shop/ProductFilterControl.ascx` & code-behind:** Replaced hardcoded category and brand items with `<asp:Repeater ID="rptCategoryFilter">` and `<asp:Repeater ID="rptBrandFilter">` bound to database categories and brands.
  - **`Pages/Dashboard/InventoryTableControl.ascx` & code-behind:** Replaced client-generated inventory table rows with `<asp:Repeater ID="rptInventory">` bound to `IInventoryRepository.GetInventoryListAsync()`.
  - **`Pages/Dashboard.aspx` & `Dashboard.aspx.cs`:** Implemented `<asp:Repeater ID="rptOrders">` for the order fulfillment pipeline and server `<asp:Literal>` tags for real-time dashboard stock, alert, and revenue metrics.
  - **`Scripts/storefront.js` & `Scripts/dashboard.js`:** Preserved server-rendered ASP component cards and rows upon initial load to eliminate double-fetching and layout shifts while preserving client interactivity.

### 2. Image Input & Storage Helper (`ImageUploadHelper.cs`)
- Created [`Infrastructure/ImageUploadHelper.cs`](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Infrastructure/ImageUploadHelper.cs) to process image uploads:
  - Accepts `<asp:FileUpload>`, `HttpPostedFile`, `HttpPostedFileBase`, and `byte[]`.
  - Validates file existence, extension whitelist (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`), MIME types, and maximum file size (default: 5 MB).
  - Automatically creates physical destination directories if missing (`Directory.CreateDirectory`).
  - Generates sanitized, collision-free unique filenames (`[prefix_]yyyyMMdd_HHmmss_[shortguid].[ext]`).
  - Returns structured `ImageUploadResult` with the database-ready relative web path (e.g. `/Content/images/products/...`), physical disk path, file size, and success status.
  - Provides `DeleteImage(relativeOrVirtualPath)` to delete obsolete image files safely.
- Added a working **Product Image Uploader** card into [`Pages/Dashboard.aspx`](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Pages/Dashboard.aspx) with `<asp:FileUpload>` and preview controls.

---

## [2026-09-27] — Full Database Integration & Mandatory Stored Procedures Migration (Rule 10 & Rule 8 Compliance)

### 1. Database Connection & Schema Deployment
- Deployed relational database `HelmetCartelDB` to local SQL Server Express instance (`.\SQLEXPRESS`).
- Successfully executed `01_schema.sql`, `02_seed_data.sql`, and `03_procedures_and_queries.sql`.
- Updated connection string in `Web.config` (`DefaultConnection`) to target `.\SQLEXPRESS` with `Integrated Security=True;Encrypt=True;TrustServerCertificate=True;`.
- Explicitly ensured `SET ANSI_NULLS ON` and `SET QUOTED_IDENTIFIER ON` across all stored procedure batches to support computed columns (`IsLowStock PERSISTED` on `dbo.Inventories`).

### 2. Mandatory Stored Procedures Refactoring (Rule 10 & Rule 8)
- Completely eliminated all inline raw SQL text across C# repositories (`ProductRepository.cs`, `OrderRepository.cs`, `InventoryRepository.cs`).
- Implemented and verified the following stored procedures:
  - `dbo.sp_GetProductsPaged`: Retrieves filtered and paginated catalog with brand and category joins.
  - `dbo.sp_GetProductById`: Returns multi-result set for product metadata, image gallery, and variant inventory matrix.
  - `dbo.sp_GetCategories`: Retrieves active categories with product counts.
  - `dbo.sp_GetBrands`: Retrieves active brands with product counts.
  - `dbo.sp_CreateOrder` & `dbo.sp_AddOrderItem`: Handles order creation with transactional integrity.
  - `dbo.sp_GetOrderDetails`: Retrieves order summary and child line items.
  - `dbo.sp_GetRecentOrders`: Retrieves staff order queue.
  - `dbo.sp_UpdateOrderStatus`: Safely modifies order fulfillment states.
  - `dbo.sp_GetVariantPriceInfo`: Retrieves variant unit pricing and active status for checkout calculation.
  - `dbo.sp_GetInventoryList`: Returns real-time stock levels with low-stock indicators.
  - `dbo.sp_GetInventoryStatusByVariantId`: Returns inventory counts for specific variant.
  - `dbo.sp_DeductStockAtomic`: Pessimistic locking (`UPDLOCK, ROWLOCK`) with negative stock checks and audit logging into `dbo.StockAuditLogs`.
  - `dbo.sp_RestockInventory`: Restocks variant with audit logging.

### 3. Cash on In-Store Pickup Order Flow
- Supported In-Store Pickup order creation via `POST /api/v1/orders`.
- Orders placed with payment method `Cash` deduct stock atomically via `dbo.sp_DeductStockAtomic`, generate audit trail logs in `dbo.StockAuditLogs`, and return an immediate order confirmation without requiring HitPay payment redirects.
- Client storefront (`storefront.js`) now dynamically consumes `/api/v1/products` live from `.\SQLEXPRESS`.

---

## [2026-09-25] — Initial Architecture Realization & Folder Restructuring

### 1. Context & Motivation
- The project is transitioning from a traditional spreadsheet stock tracking system into a real-time, transaction-linked e-commerce and retail management platform.
- The approved visual template (`E-commerce Website Template_page-0001.jpg`) represents a modern streetwear e-commerce layout (Shop.co style). This design was adapted for Helmet Cartel (high-contrast monochrome, off-white card backgrounds, rounded pill buttons, bento box riding style category layouts, and verified customer testimonials).
- Supported Stack: ASP.NET Web Application (.NET Framework 4.7.2), OWIN Pipeline, SignalR for real-time inventory updates, MSSQL with atomic row-locking, JWT authentication, and HitPay payment gateway.

### 2. Major Directory Restructuring
- **Root Customizations (`.agents/`):**
  - Added `.agents/rules/` (General principles, C# standards, Frontend UI standards, MSSQL rules, Security & Auth rules).
  - Added `.agents/workflows/` (Order fulfillment, Real-time inventory sync, HitPay payment gateway, Restock & reporting).
  - Added `.agents/agents/` (Architect, Backend Engineer, Frontend UI Engineer, QA & Security Engineer).
  - Added root `AGENTS.md` index.
- **Documentation Suite (`docs/`):**
  - `ARCHITECTURE.md`: High-level layer diagrams, OWIN pipeline, SignalR flow, HitPay integration.
  - `API_SPECIFICATION.md`: REST API endpoint contracts, schemas, headers, query parameters.
  - `UI_SPECIFICATION.md`: Complete design system tokens, typography scales, layout blueprints.
  - `DATABASE_DESIGN.md`: Relational schema definitions, constraints, ERD, and concurrency model.
  - `SETUP_GUIDE.md`: Developer onboarding, database setup, and credentials.
  - `AI_CHANGELOG.md`: This file.
- **Database Suite (`database/`):**
  - `schema/01_schema.sql`: Full DDL script for MSSQL tables, primary/foreign keys, indexes, check constraints.
  - `seeds/02_seed_data.sql`: Seed data for helmet categories, brands, variants, stock, and users.
  - `queries/03_procedures_and_queries.sql`: Stored procedures for atomic stock decrement (`UPDLOCK, ROWLOCK`), low-stock triggers, sales summaries.
  - `query_logs/`: Guidelines and baseline performance query logs.
- **Application Structure (`HelmetCartelOrderingAndManagementSys/`):**
  - `Constants/`: Centralized `AppConstants.cs` for C# backend.
  - `Content/css/`: UI Context with CSS custom properties (`variables.css`), reset, layout, components, storefront, and dashboard stylesheets.
  - `Scripts/`: Frontend constants (`constants.js`), API client, Cart state, SignalR real-time client, storefront scripts, dashboard scripts.
  - `Hubs/`: SignalR hubs (`InventoryHub.cs`, `OrderHub.cs`).
  - `Models/Entities/` and `Models/DTOs/`: Strict separation of database domain models and API contracts.
  - `Repositories/` and `Services/`: Clean data access and business logic decoupling.

### 3. Key Design Decisions & Invariants
- **Stock Negative Constraint:** Enforced in SQL (`CHECK (CurrentStock >= 0)`) as well as in stored procedures using `UPDLOCK, ROWLOCK`.
- **Zero Inline Styles / Zero Magic Strings:** All styling must reference `variables.css`. All status strings and roles must reference `AppConstants.cs` or `constants.js`.
- **HitPay Webhook Verification:** Strict HMAC-SHA256 signature check is required before processing any payment status transition.
- **Real-Time Sync:** Both online checkouts and in-store walk-in POS transactions trigger SignalR broadcasts to update inventory counts across all active client browsers instantaneously.

---

## [2026-09-25] — ASP.NET Web Forms Architecture & UI Monochrome Refinement

### 1. Architectural Conversion to Master Page & Web Forms (.aspx)
- **Root Master Page (`Site.Master`):** Houses the global layout, top announcement bar, header with fitted SVG icons (Search, Cart with live count badge, User/Staff profile), main `ContentPlaceHolder`, overlapping floating newsletter, and global footer.
- **Root Default Page (`Default.aspx`):** Storefront home view inheriting `~/Site.Master` containing the balanced Hero section, Brand Ticker, New Arrivals, Top Selling, Bento Box ("Browse by Riding Style"), and Customer Testimonials carousel.
- **Pages Directory (`Pages/`):**
  - `Pages/Cart.aspx`: Shopping cart with item list, quantity steppers, and HitPay checkout summary.
  - `Pages/Dashboard.aspx`: Staff & Admin operations dashboard with real-time SignalR indicator, stock metrics, walk-in POS cashier sale, inventory matrix, and order fulfillment pipeline.
  - `Pages/Shop.aspx`: Product catalog filter page with sidebar filters and paginated product grid.
  - `Pages/ProductDetail.aspx`: Product details page with image gallery thumbnails, size/color selectors, quantity stepper, and tabbed specifications.
- **Component Subfolders:**
  - `Pages/Dashboard/InventoryTableControl.ascx`: Reusable Web Forms user control component for the live inventory table.
  - `Pages/Shop/ProductFilterControl.ascx`: Reusable Web Forms user control component for catalog filtering.

### 2. UI & Design System Polishing
- **Monochrome Palette:** Enforced high-contrast, pure monochrome grayscale palette matching the template context (`#000000`, `#FFFFFF`, `#F2F0F1`, `#E5E5E5`, `#525252`).
- **Balanced Typography:** Balanced font scales across all viewports (Hero heading scaled to `clamp(2rem, 3.8vw, 3.25rem)`, section titles scaled to `clamp(1.5rem, 2.5vw, 2.125rem)`, balanced body text at `15px`), eliminating viewport distortion and uneven proportions.
- **Fitted SVG Vectors:** Replaced all emojis with fitted, crisp inline SVG icons for Search, Cart, Profile, Close, Stepper, Trash, Stars, and Verified Checkmarks.
- **White Toast Notifications:** Refined toast notifications to use a pure white background (`#FFFFFF`), 1px border (`#E5E5E5`), minimal edge curve (`border-radius: 8px`), and vector status icons (Success, Alert, Info).
- **Minimized Edge Curves:** Decreased card and container radii from exaggerated 40px/20px to sleek, refined 8px - 16px edges.

---

## [2026-09-25] — Shop.co Hero Section Realization & Container Max-Width Expansion

### 1. Widescreen Container Scaling
- **Container Max-Width:** Increased `--container-max-width` from `1200px` to `1440px` with responsive padding `clamp(1rem, 3.5vw, 3.5rem)` in [variables.css](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Content/css/variables.css), eliminating cramped margins on high-resolution displays.
- **Header & Navbar:** Expanded search bar width to `580px`, styled with `#F0F0F0` capsule background and fitted search vector; updated navigation to match template structure ("Shop ⌵", "On Sale", "New Arrivals", "Brands").

### 2. Shop.co Hero Section & Typography Alignment
- **Local Webfonts:** Installed local `integralcf-bold.woff2` and `satoshi` fonts into `Content/fonts/` with `@font-face` definitions and Google Fonts fallback.
- **Hero Grid & Proportions:** Updated `.hero-grid` to `1.15fr 0.85fr` with bottom alignment in [layout.css](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Content/css/layout.css).
- **Hero Image Integration:** Integrated transparent cutout models (`hero.webp`) resting directly on `#F2F0F1` background, extending down flush to the brand ticker strip. Added `.webp` MIME type mapping to `Web.config`.
- **Accents & Sparkles:** Configured 4-point star SVGs (`viewBox="0 0 104 104"`) positioned at top-right (104px) and middle-left (56px).
- **Metrics & Stats:** Added vertical dividers between `200+`, `2,000+`, and `30,000+` counters with clean Satoshi bold typography.
- **Brand Ticker Strip:** Updated `.brand-ticker` in [Default.aspx](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Default.aspx) to render pure white brand assets for `VERSACE`, `ZARA`, `GUCCI`, `PRADA`, and `Calvin Klein`.

---

## [2026-09-25] — C# Backend Authority Mandate, Storefront Cart Standards & Zero Inline Styles

### 1. C# Backend Exclusivity & Architectural Mandate
- **Strict C# Backend:** Updated `AGENTS.md`, `01_general_principles.md`, `02_csharp_backend_rules.md`, and `03_frontend_ui_rules.md` to establish that **C# is the exclusively authorized backend runtime** (ASP.NET Web API 2, OWIN pipeline, C# controllers, services, repositories, ADO.NET / MSSQL transactions, SignalR hubs, and Web Forms code-behind).
- **No JavaScript Mock Backend:** Prohibited using JavaScript to simulate in-memory mock databases or mock APIs. Frontend JavaScript is strictly confined to client-side presentation, DOM manipulation, progressive enhancement, UI event listeners, and consuming live C# Web API endpoints via HTTP requests.
- **MSSQL Database Activation:** Created and started `(localdb)\MSSQLLocalDB`, executed production schema (`01_schema.sql`), seed data (`02_seed_data.sql`), and stored procedures (`03_procedures_and_queries.sql`), configuring `Web.config` connection strings.
- **Live C# API Integration:** Verified and connected `storefront.js` directly to `/api/v1/products/new-arrivals`, `/api/v1/products/top-selling`, and `/api/v1/products`.

### 2. Storefront Cart & Purchasing Interaction Standards
- **Home Page (`Default.aspx`):** Removed all "Add to Cart" buttons from product cards. Cards now serve strictly as navigational preview links navigating directly to `Pages/ProductDetail.aspx?id=...`.
- **Product Detail Page (`Pages/ProductDetail.aspx`):** Brought back and elevated the primary "Add to Cart" purchasing component. Styled `#btn-add-detail` with `.btn--add-cart` pill curves, hover transitions, and a fitted shopping cart vector icon. Dynamically reads selected size, color swatch, and quantity stepper, adds items to `CartManager`, updates the header cart badge, and shows interactive success toasts.

### 3. Mojibake Elimination & Zero Inline Styles
- **Character Encoding Integrity:** Eliminated `â‚±` and `â€”` mojibake artifacts across all markup and scripts by enforcing UTF-8 globalization in `Web.config`, adopting official HTML entities (`&#8369;`, `&mdash;`), and using JS unicode escapes (`\u20B1`).
- **Zero Inline Styles Mandate:** Replaced all inline `style="..."` attributes with semantic stylesheet classes backed by CSS custom properties in `variables.css` across `Default.aspx`, `Shop.aspx`, `ProductDetail.aspx`, `Cart.aspx`, `Dashboard.aspx`, `InventoryTableControl.ascx`, and `ProductFilterControl.ascx`.
- **Unused Files Clean-up:** Purged all dead `.html` prototype files (`cart.html`, `dashboard.html`, `index.html`) from the repository.

---

## [2026-09-25] — Full-Screen Authentication Architecture & Database Stored Procedure Mandate

### 1. Database Stored Procedure Mandate (Project Rule Grounding)
- **Rule Hierarchy Update:** Updated `AGENTS.md` (Ground Rule 10) and `.agents/rules/04_database_mssql_rules.md` (Section 4) to mandate that **all database operations MUST execute via named MSSQL Stored Procedures (`sp_...`)** using ADO.NET `CommandType.StoredProcedure` with strongly typed parameters. Raw inline SQL query strings within C# code are strictly prohibited.
- **Authentication & User Stored Procedures Created:** Added and deployed four stored procedures in `database/queries/03_procedures_and_queries.sql` to `(localdb)\MSSQLLocalDB` (`HelmetCartelDB`):
  - `sp_GetUserByEmail`: Securely fetches user credentials (`Id`, `RoleId`, `RoleName`, `FullName`, `Email`, `PasswordHash`, `Salt`, `PhoneNumber`, `IsActive`) for authentication.
  - `sp_RegisterUser`: Inserts a new customer account within an atomic transaction, validating email uniqueness and checking role foreign keys.
  - `sp_GetUserProfile`: Returns safe user profile fields.
  - `sp_GetUserOrders`: Returns customer order history with item counts, payment gateway, and total amounts.

### 2. C# Backend Authentication Layer
- **C# DTOs (`Models/DTOs/AuthDTOs.cs`):** Defined `LoginRequestDto`, `RegisterRequestDto`, `AuthResponseDto`, `UserProfileDto`, `UserRecordDto`, and `UserOrderSummaryDto`.
- **Infrastructure (`Infrastructure/JwtTokenProvider.cs`):** Implemented RFC 7519 compliant HMAC-SHA256 JWT generation and validation without unnecessary third-party package dependencies.
- **Data Access Repository (`Repositories/UserRepository.cs` & `IUserRepository.cs`):** Built repository executing `sp_GetUserByEmail`, `sp_RegisterUser`, `sp_GetUserProfile`, and `sp_GetUserOrders` exclusively via `CommandType.StoredProcedure` and typed `SqlParameter` objects.
- **Service Layer (`Services/AuthService.cs` & `IAuthService.cs`):** Implemented SHA-256 password hashing, salt generation, credential verification, and JWT token issuance.
- **Web API 2 Controller (`Controllers/Api/AuthController.cs`):** Created endpoints:
  - `POST /api/v1/auth/login`: Authenticates credentials and returns JWT token + user profile.
  - `POST /api/v1/auth/register`: Creates new customer account and returns JWT token.
  - `GET /api/v1/auth/me`: Validates bearer token and returns current user profile.
  - `GET /api/v1/auth/my-orders`: Returns order history for the authenticated user.

### 3. Full-Screen Authentication UI (No Floating Cards)
- **View (`Pages/Auth.aspx`):** Built a 100vw / 100vh full-screen, split-editorial authentication experience matching the luxury dark motorcycle streetwear aesthetic:
  - **Left Editorial Showcase (50%):** Dark atmospheric background with hero helmet imagery, brand typography, certification badge (`ECE 22.06 & DOT CERTIFIED`), headline (`RIDE PROTECTED. RIDE UNAPOLOGETIC.`), and three key value pillars (Real-Time Stock Locks, Seamless HitPay Gateway, Track & Street Heritage).
  - **Right Interactive Console (50%):** Full-height canvas with clean header (`← Return to Storefront`), 256-bit SSL badge, pill-shaped mode switcher ("Sign In" vs "Create Account"), floating input fields with password visibility toggle, and full-width pill action buttons.
  - **Quick Demo Access:** Added one-click demo account selector pills (`Admin`, `Staff`, `Customer`) for fast testing and grading.
- **Stylesheet (`Content/css/auth.css`):** 100% powered by CSS variables from `variables.css` (zero inline styles).
- **Client Script (`Scripts/auth.js`):** Manages asynchronous API calls, token persistence in `localStorage` (`hc_auth_token`, `hc_user_profile`), and dynamic role-based redirection (`Dashboard.aspx` for Admin/Staff, `Default.aspx` for Customers).
- **Global Navigation Integration:** Linked account icon in `Site.Master` header to `~/Pages/Auth.aspx`, updated `storefront.js` to reflect active session state in tooltips, and added session indicator + logout button to `Dashboard.aspx`.

---

## [2026-09-25] — North-East Directional Button Micro-Interactions & Product Detail "Buy Now" Action

### 1. North-East Arrow Button Micro-Interactions
- **Zero Button Transformation on Hover:** Eliminated disruptive button jumps and scaling (`translateY` removed from `.btn--hero:hover`, `.auth-submit-btn:hover`, `.btn--apply-filters:hover`, and `.btn--add-cart:hover`). Buttons preserve their exact layout geometry and dimensions.
- **Directional Icon Movement:** Created `.btn-arrow-icon` class in `components.css` with North-East arrow SVG vectors (`<line x1="7" y1="17" x2="17" y2="7"></line><polyline points="7 7 17 7 17 17"></polyline>`). On hover, the icon smoothly translates in the direction it points (`transform: translate(3px, -3px)`) with cubic-bezier easing.
- **System-Wide Application:** Integrated the North-East arrow across:
  - Hero "Shop Now" button (`Default.aspx`)
  - "View All" buttons for New Arrivals and Top Selling (`Default.aspx`)
  - "Sign In to Cartel" and "Create Account" submit buttons (`Pages/Auth.aspx`)
  - "Go to Checkout" button (`Pages/Cart.aspx`)
  - "Apply Filter" button (`Pages/Shop/ProductFilterControl.ascx`)
  - "Subscribe to Newsletter" button (`Site.Master`)
  - "Buy Now" button (`Pages/ProductDetail.aspx`)

### 2. Product Detail "Buy Now" Button
- **Layout & Visual Hierarchy:** Added `#btn-buy-now` with `.btn--buy-now` styling alongside `.btn--add-cart` in `.product-actions-row` on `Pages/ProductDetail.aspx`.
  - `.btn--add-cart` styled as high-contrast border outline button (`#FFFFFF` background, `1.5px solid #000000`) with fitted cart icon.
  - `.btn--buy-now` styled as bold black solid button (`#000000` background, `#FFFFFF` text) with North-East arrow icon.
  - Responsive collapse for mobile viewports below 580px to full-width stack.
- **Instant Checkout Flow:** Implemented client script handler on `btn-buy-now` that extracts current quantity, active size pill, and active color swatch, appends the product to `CartManager`, updates the header cart badge, and immediately navigates the user directly to `Pages/Cart.aspx`.

---

## [2026-09-26] — Storefront Proportions, Product Details & FAQs Redesign, Direct Checkout & Project Proposal Alignment

### 1. Typography & Proportions Refinements
- **Product Card Pricing & Titles:** Refined `.product-card__title` (0.875rem), `.price-current` (0.95rem), `.price-original` (0.95rem), and discount badges in `Content/css/components.css` for balanced catalog scanning.
- **Product Detail Action Controls:** Adjusted `.size-pill`, `.quantity-stepper-lg`, `.btn--add-cart`, `.btn--buy-now`, and `.btn--fav-detail` in `Content/css/storefront.css` for balanced visual proportions.

### 2. Product Details & FAQs Tab Overhaul
- **Product Details Tab (`#tab-details`):** Overhauled with a structured, dark-accented layout matching the design system:
  - Overview hero callout highlighting engineering & safety philosophy.
  - 4-card feature highlights grid (`AIM+ Shell`, `Dual-Layer EPS`, `CWR-F2 Shield`, `E.Q.R.S.`).
  - Comprehensive technical specifications table with alternating rows.
  - SNELL, DOT, 5-Year Warranty, and Authenticity certification badge strip.
- **FAQs Tab (`#tab-faqs`):** Implemented an interactive accordion component with rotating chevron indicators and comprehensive answers regarding sizing, Bluetooth intercom installation, visors, warranty, and liner care.

### 3. Cart Variant Deduplication & Direct "Buy Now" Checkout
- **Cart Variant Indexing (`Scripts/cart.js`):** Implemented deterministic `uniqueVariantId` (`${prodId}_${size}_${color}`) to ensure selecting identical product configurations increments quantities rather than creating duplicate lines.
- **Buy Now Flow:** Updated `btn-buy-now` event listener in `Pages/ProductDetail.aspx` to route directly to `Pages/Checkout.aspx`.

### 4. Capstone Project Proposal Alignment (`docs/PROJECT_PROPOSAL.md`)
- Integrated **Customer Account Management & Payment Transaction History** and **Promotional Voucher Management** into Specific Objectives, Project Scope, and Core Features.

---

## [2026-09-27] — Storefront Card Navigation & Selector Syntax Fixes

### 1. Storefront QuerySelector Syntax Fix
- **Selector Correction (`Scripts/storefront.js`):** Fixed syntax error on line 258 (`card?.querySelector('.')` replaced with `card?.querySelector('.price-current')`) in the wishlist heart click delegation listener.
- **Cache-Busting:** Bumped script references to `storefront.js?v=5` in `Default.aspx` and `Pages/Shop.aspx`.
- **API Client Method Extensions (`Scripts/api.js`):** Added `getProducts(params)` and `getProductById(id)` helper methods to `ApiClient`.
- **API Response Unpacking (`Scripts/storefront.js`):** Updated `loadLiveProducts()` to handle array, `{ items: [...] }`, and `{ data: [...] }` envelopes seamlessly.

### 2. Dynamic Product Detail Page (`Pages/ProductDetail.aspx` & `Pages/ProductDetail.aspx.cs`)
- **Code-Behind Integration:** Implemented `LoadProductDetailsAsync` in `Pages/ProductDetail.aspx.cs` utilizing `IProductRepository.GetProductByIdAsync` and `RegisterAsyncTask` (`Async="true"` page directive).
- **Dynamic Markup Binding:** Linked breadcrumb title, hero image, product title, star ratings, current price, original price, discount badge, description, variant color swatches, and size pills to the dynamically loaded product.
- **Model & Query Updates (`Models/DTOs/ProductDTOs.cs` & `Repositories/ProductRepository.cs`):** Added `Description` property to `ProductListDto` and included `p.Description` in `GetProductByIdAsync`.
- **MSSQL IsLowStock Cast Fix:** Resolved `System.InvalidCastException` across `ProductRepository.cs` and `InventoryRepository.cs` when reading computed SQL column `IsLowStock` by using `Convert.ToBoolean(...)`.
- **Dynamic Cart & Wishlist Interactions:** Refactored `getSelectedProductDetails()` in `Pages/ProductDetail.aspx` to extract the loaded product data and matched variant SKU, ID, size, color, price adjustment, and image.

---

## [2026-09-27] — HNJ Top Box Integration & Storefront Brand Filtering

### 1. HNJ Top Box Implementation
- **Brand & Category Provisioning:** Added brand `HNJ` (Id: 7) in `dbo.Brands` and new category `Top Boxes & Luggage` (Id: 6, Slug: `top-boxes-luggage`) in `dbo.Categories`.
- **Product & Variants Seed:** Added `HNJ 45L Heavy-Duty Aluminum Motorcycle Top Box` (Id: 1001, BasePrice: 4850.00, 10% discount) with variants `HNJ-TB45-BLK` (45L / Matte Deep Black), `HNJ-TB45-SLV` (45L / Anodized Silver), and `HNJ-TB55-BLK` (55L / Matte Deep Black, +600.00) in `dbo.ProductVariants` and `dbo.Inventories`.
- **Product Visuals:** Generated and added high-resolution product photography for HNJ 45L Top Box in `Content/images/hnj_topbox.jpg`.
- **Storefront Fallback Sample Data:** Added HNJ Top Box (id: 1001) with category metadata in `SAMPLE_PRODUCTS` within `Scripts/storefront.js`.

### 2. Multi-Channel Brand & Category Filtering
- **Backend API Filtering (`Repositories/ProductRepository.cs` & `Models/DTOs/ProductDTOs.cs`):** Added `Brand` and `Category` string parameters to `ProductFilterParams` and parameterized WHERE filtering in `GetProductsAsync` (e.g. `GET /api/v1/products?brand=HNJ`).
- **Sidebar Filter Control UI (`Pages/Shop/ProductFilterControl.ascx`):** Added dedicated "Brands" accordion filter section with buttons for All Brands, Shoei, AGV, Arai, HJC, Bell, Shark, and HNJ (Top Box), along with "Top Boxes & Luggage" in the Categories list.
- **Client-Side Reactive Filter Controller (`Scripts/storefront.js`):**
  - Implemented `applyInitialUrlFilters()`: reads URL parameters `?brand=...` or `?category=...` on load and immediately highlights the active button and filters the product grid.
  - Implemented reactive event listeners for brand buttons (`.filter-brand-btn`) and category items (`.filter-category-item`), syncing state with URL (`history.replaceState`) without page reloads.
  - Added dual price range slider live filtering and "Apply Filter" feedback.
  - Implemented custom empty state (`.shop-empty-state` in `Content/css/storefront.css`) with "Reset All Filters" button.
- **Brand Ticker Strip Navigation (`Default.aspx`):** Converted home page brand logos (Zebra, Gille, HNJ, Shoei, AGV) into interactive links routing directly to `Pages/Shop.aspx?brand=...`.

### 3. Visual Scale Alignment & Filter Streamlining
- **Top Box Proportional Image Scaling (`Content/images/hnj_topbox.jpg`):** Scaled and centered the HNJ Top Box product photograph with balanced canvas padding (~55-60% object scale on neutral light background), ensuring exact visual parity with helmet product cards and gallery hero views.
- **Filter Redundancy Removal (`Pages/Shop/ProductFilterControl.ascx`):** Removed the redundant Riding Style accordion from the Shop sidebar filter, consolidating product filtering around the primary `Categories` list while keeping Riding Style exclusively on the Homepage Bento Grid and Shop mega-menu for lifestyle discovery.

### 4. Helmet-Centric Scope Refinement
- **Top Box Scope Removal:** Removed Top Box category and HNJ top box products from MSSQL database (`dbo.Categories`, `dbo.Products`, `dbo.ProductVariants`, `dbo.Inventories`), seed script (`02_seed_data.sql`), sidebar filter (`ProductFilterControl.ascx`), and frontend sample catalog (`Scripts/storefront.js`) to focus exclusively on motorcycle helmets for the academic project scope.



## [2026-09-27] — Catalog 3NF and SQL integrity migration

- Added `ProductColors` and changed variants to reference one color row per product. Updated demo and image catalog seeds, plus procedure result sets, to preserve application fields.
- Replaced product rating and review counts, review report counts, order totals, order item totals, and stock audit end balances with query-time aggregates or computed columns. Historical order prices and contact details remain stored at purchase time.
- Added transactional `02_3nf_integrity_migration.sql` for existing databases. It preserves product, variant, order, and inventory IDs, checks inconsistent legacy data, and can run again safely.
- Added checks for reservation bounds, order/payment/status values, nonnegative audit balances, and verified review links. Added unique open-alert and payment-reference indexes; removed duplicate indexes.
- Changed review report user FK to `NO ACTION` to avoid multiple SQL Server cascade paths; migration creates the report table if an older schema run skipped it.
- Reworked stock procedures to reject nonpositive quantities and honor reserved stock; low-stock status and storefront availability now use unreserved stock. Review procedure checks linked completed purchases. Procedure deployments alter existing definitions without dropping them.
- Added `sp_ValidateOrderTotals` to check each order's item sum before `OrderRepository` commits its header and items transaction.
- Updated database design and setup instructions. SQL Server execution was not available in this workspace; apply migration before deploying revised procedures.
- Restricted initial demo brands/products to the requested catalog. Added guarded cleanup script for existing databases; it preserves order and stock audit history and removes Arai, HJC, Bell, and Shark only when no products remain under those brands.

## [2026-09-27] — Storefront review and filter controls

- Product detail reviews initially show five posts, with five more revealed per click. Review rating/verified filters and sorting reapply the five-post limit and hide the load button when no further matches remain.
- Added product brand, category, and riding style to the detail summary and database descriptions to homepage product cards.
- Centered shop page numbers when Previous or Next is unavailable. Category and brand selections now wait for Apply Filter; Clear all removes catalog filters and returns to page one while preserving search and sort.
- Changed the add-to-cart toast to use a cart SVG and refreshed asset version references.

## [2026-09-27] — Catalog navigation and local search history

- Routed desktop and mobile riding style links to matching shop results, New Arrivals to newest sorting, Brands to the shop brand filter, and On Sale to discounted products. Homepage riding style cards now use direct shop links.
- Added `OnSale` to the catalog filter contract and `sp_GetProductsPaged` count and row queries. Existing databases must rerun `database/queries/03_procedures_and_queries.sql` before deploying this application change.
- Added up to five recent search queries in local browser storage, shown in desktop and mobile search when the input is empty, with a Clear control.
- Replaced the nonfunctional newsletter alert form and unsupported first-order discount message with catalog discovery links.
- Updated the add-to-cart toast to use the exact cart path shown in the site navigation.

## [2026-09-29] - Local JWT file and minimal fresh database installer

- JWT configuration now recognizes the supplied App_Data/Jwt_Secret after environment/app-setting overrides and before the generated fallback. Centralized configuration keys and ignored the private file in Git.
- Added a reproducible standalone SQLCMD installer built from the current schema and procedure migrations, guarded against existing databases, with only two products and four inventory rows. The compact catalog uses the existing AGV White Modular and Gille Adventure Peak seed context, including their local main and gallery images. No full inventory, transaction history, or shared login credentials are imported.
- Existing database and connection string are unchanged; execution and connection instructions are in SETUP_GUIDE.md.
