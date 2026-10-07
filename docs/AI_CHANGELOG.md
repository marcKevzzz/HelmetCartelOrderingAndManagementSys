# AI Change Log & Architectural Evolution: Helmet Cartel

## [2026-10-08] — Standardization of 2XL Sizing, Order History Quantity Multiplier Preservation, and Profile Address/Return Fixes

- **Size Standardization (XXL -> 2XL Canonicalization) Across Database, API, and Admin/Storefront:**
  - **Problem Solved:** Sizing was inconsistent across the system. The database stored `XXL` across 86 helmet variants in `dbo.ProductVariants` and 4 historical orders in `dbo.OrderItems` (with `-XXL` SKU suffixes), whereas the storefront shop filters (`ProductFilterControl.ascx`), Product Detail page (`ProductDetail.aspx`), and Admin Catalog Wizard (`CatalogItem.aspx`) presented `2XL`. This caused discrepancies in the Admin Inventory table (`Inventory.aspx`), order history, and receipts.
  - **Resolution (`60_standardize_2xl_and_rma_sequence.sql`, `AdminController.cs`, `OrderRepository.cs`):**
    - Created and executed Migration 60: standardizing all `Size = 'XXL'` to `'2XL'` and updating SKU suffixes `-XXL` to `-2XL` across `dbo.ProductVariants` and `dbo.OrderItems`.
    - Added `NormalizeVariantSize(string size)` to `AdminController.cs` for variant saving endpoints (`catalog/variants`).
    - Added `NormalizeSize(string size)` to `OrderRepository.cs` when creating orders and summarizing order items to guarantee canonical `2XL` storage regardless of entry point.
    - Verified distinct variant sizes in MSSQL: `[2XL, L, M, S, XL]`.

- **Profile Order History Quantity Badge (`x2`) Preservation Across Dropdown Toggling:**
  - **Problem Solved:** When a customer ordered multiple units of a product (e.g. quantity 2), the order card thumbnail originally displayed an `x2` indicator in the stacking deck preview. However, clicking the accordion toggle to expand the item details called `updateOrderCardDeck(orderId, items)` which passed `{ id: orderId }` without `itemCount`. This recalculated `extraCount` to `0` and completely wiped the `x2` indicator from the card header.
  - **Resolution (`profile.js`, `profile.css`, `Profile.aspx`):**
    - Updated `createStackingDeckHtml(order, items)`: dynamically computes `totalQuantity` from `items.reduce((sum, i) => sum + (Number(i.quantity) || 1), 0)` (or fallback to `order.itemCount`). When `distinctItemCount === 1 && totalQuantity > 1`, cleanly renders `<span class="deck-badge">x${totalQuantity}</span>`.
    - Updated `updateOrderCardDeck(orderId, items, order)`: retrieves the cached order object (`this.orderDetailsCache.get(orderId)` or `this.orders.find(...)`) rather than passing an empty dummy object, ensuring the deck badge retains `x2` and never disappears when the dropdown is clicked or toggled.
    - Enhanced expanded order row: added prominent `<span>Qty: <strong>${item.quantity}</strong></span>` in `.order-item-detail-specs` and styled a persistent `.order-item-detail-qty-badge` overlay on the item thumbnail for items with `quantity > 1`.

- **Fixed `ReferenceError: returnUrl is not defined` in Profile Addresses (`profile.js`):**
  - **Problem Solved:** Navigating to or initializing the profile page threw `ReferenceError: returnUrl is not defined` at line 1338 in `renderAddresses()`, causing `loadUserAddresses()` to reject and disrupting the tab initialization pipeline.
  - **Resolution:** Added `const returnUrl = this.getCheckoutReturnUrl();` at the beginning of `renderAddresses()` in `profile.js`.

- **Fixed 500 Internal Server Error on `POST /api/v1/returns` (`60_standardize_2xl_and_rma_sequence.sql`):**
  - **Problem Solved:** Submitting a return/exchange request failed with HTTP 500 because `sp_CreateReturnRequest` called `NEXT VALUE FOR dbo.Seq_RmaNumber`, but the sequence `dbo.Seq_RmaNumber` did not exist in `HelmetCartelDB`.
  - **Resolution:** Created sequence `dbo.Seq_RmaNumber` starting at 1002 in Migration 60, and enhanced `sp_CreateReturnRequest` with safe TRY/CATCH fallback sequence generation to prevent unhandled database exceptions during RMA submissions. Bumped script and stylesheet versions in `Profile.aspx` (`profile.js?v=20261008_fix1`, `profile.css?v=11`).

## [2026-10-07] — Catalog Recency Ordering (New/Updated on Top) & Most Popular Storefront Sorting Clarification

- **Catalog Table Automatic Recency Sorting (`sp_AdminCatalogProducts`, `Catalog.aspx.cs`, `AdminDTOs.cs`, `AdminDataRepository.cs`, `59_catalog_recent_sort_and_popular_order.sql`, `HelmetCartelDB_Complete.sql`):**
  - **Problem Solved:** Newly added or recently edited helmet models did not automatically display at the top of the Catalog management table (`Catalog.aspx`), forcing administrators to navigate across pagination pages to locate recently updated items.
  - **Resolution:**
    - Updated `dbo.sp_AdminCatalogProducts` to return `p.UpdatedAt` and sort deterministically by `ORDER BY ISNULL(p.UpdatedAt, p.CreatedAt) DESC, p.Id DESC`.
    - Added `UpdatedAt` property to `AdminCatalogItemDto` and mapped from `SqlDataReader` in `AdminDataRepository.cs`.
    - In `Catalog.aspx.cs`, added `.OrderByDescending(p => p.UpdatedAt ?? p.CreatedAt).ThenByDescending(p => p.Id)` after tab status filtering so the newest or most recently edited helmet model always occupies row 1 of the first page.

- **Storefront "Most Popular" Order Mechanics & Signature Synchronization (`sp_GetProductsPaged`):**
  - **Mechanics:** "Most Popular" in the shop is powered by `dbo.sp_GetProductsPaged` (`@SortBy = 'popular'`). It ranks products based on verified sales (`sales.UnitsSold DESC` from orders where status is NOT `Cancelled`, `Refunded`, or `PendingPayment`) combined with customer reviews (`review.Rating DESC` and `review.ReviewCount DESC`).
  - **Confirmed Orders vs Completed Orders:** The calculation uses all confirmed, paid orders (`Processing`, `Shipped`, `Delivered`, `Completed`) rather than exclusively `Completed`, ensuring newly paid orders immediately boost a helmet's popularity without waiting weeks for delivery finalization. Excludes unpaid or cancelled orders.
  - **Parameter Signature Guard:** Synchronized the exact parameter list (`@CategoryId, @BrandId, @Brand, @Category, @RidingStyle, @Search, @OnSale, @MinPrice, @MaxPrice, @Colors, @Sizes, @SortBy, @PageNumber, @PageSize, @TotalCount OUTPUT`), ensuring seamless ADO.NET execution with `ProductRepository.cs` and eliminating the 500 argument count error. Verified `GET /api/v1/products?pageSize=12` returns HTTP 200 with 35 items.

- **Product Detail Variant Dynamic Discount Calculation (`product-detail.js`, `ProductDetail.aspx`):**
  - **Problem Solved:** On the Product Detail page (`ProductDetail.aspx`), selecting a variant for a product with a fixed amount discount (e.g. Shoei J-Cruise II Tradisi with Base Price ₱34,000, Size L adjustment +₱500 = ₱34,500, fixed discount ₱250) displayed `₱34,500  ₱34,500  -₱250` because the client-side variant updater only handled `discountPercentage`. Since fixed discounts have `discountPercentage = 0`, the effective price fell back to the undiscounted original price.
  - **Resolution:** Added `calculateEffectiveVariantPrice(originalPrice)` in `product-detail.js` to compute discounts across both percentage and fixed amount types (`FixedAmount`: `Math.max(0, originalPrice - discountAmount)`). Updated `updateSelectedVariantUi()` to accurately compute the effective price (e.g. `₱34,250.00`), crossed-out original price (`₱34,500.00`), and formatted discount badge (`-₱250`). Updated `getSelectedProductDetails()` to ensure the cart and checkout payload use the exact discounted price.

- **Admin Catalog Table Discount Display & Badge Integration (`Catalog.aspx`, `AdminDTOs.cs`, `AdminDataRepository.cs`, `sp_AdminCatalogProducts`):**
  - **Problem Solved:** Products with active fixed discounts in `Pages/Admin/Catalog/Catalog.aspx` only displayed their base undiscounted price in the Pricing column and rendered `—` for the discount badge.
  - **Resolution:**
    - Updated `dbo.sp_AdminCatalogProducts` to return computed `HasActiveDiscount` (BIT) and `EffectivePrice` using `dbo.fn_CalculateEffectivePrice`.
    - Enhanced `AdminCatalogItemDto`:
      - `HasActiveDiscount`: dynamically verifies date ranges, `DiscountIsActive`, `DiscountPercentage > 0`, or `DiscountAmount > 0` for `FixedAmount`.
      - `EffectivePrice`: accurately computes fixed or percentage discount if not provided by SQL.
      - `DiscountBadgeText`: formats `-₱{Amount}` or `-{Percent}%`.
    - Updated `Catalog.aspx` Repeater item template: evaluates `Convert.ToDecimal(Eval("EffectivePrice")) < Convert.ToDecimal(Eval("BasePrice")) || (bool)Eval("HasActiveDiscount")` to render the bold discounted price, strikethrough original base price, and discount badge pill (`.table-discount-badge`).

- **Catalog Search Filtering vs Sorting To Top (`Catalog.aspx.cs`, `Catalog.aspx`):**
  - **Problem Solved:** When selecting a catalog model from the top search bar (which redirects to `Catalog.aspx?id={Id}`), the page previously showed all products and merely placed the target product at the top of the table.
  - **Resolution:** Updated `Catalog.aspx.cs` so that when `TargetProductId` is provided (via `?id={id}`), the catalog table explicitly filters down to that specific product (`products = products.Where(p => p.Id == TargetProductId.Value).ToList()`). Added `lnkClearFilter` to allow the admin to reset the filter with one click back to the full catalog.

- **Brand & Category Filtering in Catalog and Inventory via Search & Dropdowns (`Catalog.aspx`, `Catalog.aspx.cs`, `Inventory.aspx`, `Inventory.aspx.cs`, `sp_AdminGlobalSearch`, `sp_AdminCatalogProducts`, `sp_AdminInventoryVariants`):**
  - **Global Autocomplete Search (`sp_AdminGlobalSearch`):**
    - Brands search results now offer dual navigation targets:
      - `[Brand] (Catalog)`: navigates to `/Pages/Admin/Catalog/Catalog.aspx?brand={Name}`
      - `[Brand] (Inventory)`: navigates to `/Pages/Admin/Inventory/Inventory.aspx?brand={Name}`
    - Categories search results now offer dual navigation targets:
      - `[Category] (Catalog)`: navigates to `/Pages/Admin/Catalog/Catalog.aspx?category={Name}`
      - `[Category] (Inventory)`: navigates to `/Pages/Admin/Inventory/Inventory.aspx?category={Name}`
  - **Catalog Page (`Catalog.aspx`, `Catalog.aspx.cs`):**
    - Added `ddlBrandFilter` and `ddlCategoryFilter` dropdowns to the filter bar.
    - Supported URL parameters `?brand=...` and `?category=...`, automatically selecting the corresponding dropdown and querying `dbo.sp_AdminCatalogProducts`.
  - **Inventory Page (`Inventory.aspx`, `Inventory.aspx.cs`):**
    - Added `CurrentCategory` in ViewState and query parameter `?category=...` support alongside `?brand=...`.
    - Added `lnkClearFilter` control that appears dynamically whenever search, brand, category, or status filters are active.
  - **Direct Query Search:**
    - Typing a brand name or category name into the search bar (`?q=...` or `?search=...`) now automatically filters both `sp_AdminCatalogProducts` and `sp_AdminInventoryVariants` by matching brand and category names.
  - **Database Migration:** Packaged all stored procedure updates into `database/schema/58_fix_catalog_pricing_and_search_filters.sql` and synchronized into `database/setup/HelmetCartelDB_Complete.sql`.

- **Catalog Duplicate Item Validation Across All Layers (`CatalogItem.aspx`, `catalog-item.js`, `CatalogItem.aspx.cs`, `AdminController.cs`, `AdminDataRepository.cs`, `57_catalog_duplicate_validation.sql`, `HelmetCartelDB_Complete.sql`):**
  - **Problem Solved:** When creating or editing helmets in the Admin Catalog Wizard, users could mistakenly enter existing helmets with the identical Brand, Category, and Model Name combination, creating duplicate listings in the database and catalog.
  - **Real-Time Client-Side Validation (`catalog-item.js`, `CatalogItem.aspx`):**
    - Embedded lightweight catalog lookups array (`#existing-catalog-data`) via `ExistingProductsJson` on page load.
    - Evaluates brand, category, and case-insensitive trimmed product model names on typing (`input`), brand change (`change`), and category change (`change`) with zero-latency instant feedback.
    - Added dedicated inline error element `#errProductDuplicate` (*"This helmet model already exists in the catalog under this brand and category."*) directly below `txtProductName` and highlights input with `.is-invalid`.
    - Automatically excludes the current product ID (`ProductId > 0`) when editing an existing product so editing its other attributes does not trigger a false-positive conflict against itself.
    - **Wizard Step & Submission Guarding:** Blocks advancing to Step 2 ("Next: Specifications →") via `validateStep(1)` if duplicate exists. Blocks saving as draft or publishing to storefront via `handleFormSubmit(e, isDraftMode)`, automatically switching back to Tab 1, focusing `txtProductName`, and displaying an alert toast.
  - **Server-Side Verification & Stored Procedure Protection (`AdminDataRepository.cs`, `CatalogItem.aspx.cs`, `AdminController.cs`, `sp_AdminSaveProduct`, `sp_AdminCheckProductDuplicate`):**
    - Created `dbo.sp_AdminCheckProductDuplicate` returning `BIT IsDuplicate` and `dbo.sp_AdminGetCatalogItemLookups` returning `Id, BrandId, CategoryId, Name`.
    - Updated `dbo.sp_AdminSaveProduct` stored procedure to throw error `52102: 'A helmet model with this brand, category, and name already exists in the catalog.'` if duplicate parameters are passed.
    - Added API endpoint `GET /api/v1/admin/catalog/check-duplicate` secured with `[StaffAuthorize(adminOnly: true)]` and integrated server-side pre-save duplicate validation in `CatalogItem.aspx.cs`.
    - Synchronized all procedures into `database/setup/HelmetCartelDB_Complete.sql`.

- **Products API 500 Internal Server Error Resolution (`ProductRepository.cs`, `sp_GetProductsPaged`):**
  - Resolved `GET /api/v1/products?pageSize=50` 500 error caused by type casting in `ProductRepository.cs`. Changed `reader.GetBoolean(...)` to safe `Convert.ToBoolean(...)` for computed columns (`HasActiveDiscount`), validated via live endpoint testing returning HTTP 200 OK and valid JSON.


- **Catalog Discount Display Fix Across Storefront & Detail Pages (`fn_CalculateEffectivePrice`, `sp_GetProductsPaged`, `sp_GetProductById`, `sp_GetRelatedProducts`, `Default.aspx`, `Shop.aspx.cs`, `ProductDetail.aspx`, `ProductDTOs.cs`, `ProductRepository.cs`):**
  - **Case-Insensitive Discount Type Matching:** Updated `dbo.fn_CalculateEffectivePrice`, `dbo.sp_GetProductsPaged`, and `dbo.sp_GetProductById` to accept both PascalCase (`FixedAmount`) and UPPER_SNAKE_CASE (`FIXED_AMOUNT`), preventing fixed amount discounts from falling back to base price.
  - **Boolean Conversion & Alias Synchronization:** Standardized stored procedure output with `CONVERT(BIT, ...)` and aligned both `HasActiveDiscount` and `IsDiscountActive` aliases. Refactored `ProductRepository.cs` to use safe `Convert.ToBoolean(...)` rather than `reader.GetBoolean()`, eliminating `InvalidCastException` when reading computed SQL expressions.
  - **Storefront & Default Page Pricing Markup:** Updated `Default.aspx`, `Shop.aspx.cs`, and `ProductDetail.aspx` hero pricing to render discounts whenever `EffectivePrice < BasePrice` and format badges using `DiscountBadgeText` (supporting `-₱250` and `-%`), ensuring products with fixed discounts clearly display their current discounted price, struck-through original price, and badge.

- **Primary Image Gallery Deduplication (`ProductDetail.aspx.cs`):**
  - **Duplicate Gallery Thumbnail Prevention:** Resolved duplicate rendering of the primary image when `MainImageUrl` is added alongside `ProductItem.GalleryImages` (created by the admin catalog wizard). Implemented URL normalization and `HashSet<string>` deduplication so the hero image is never rendered twice in thumbnail strips or modal carousels.

- **Related Products Slug Navigation (`ProductDetail.aspx`):**
  - **Slug URL Alignment:** Corrected `NavigateUrl` in `rptRelatedProducts` on `ProductDetail.aspx` from `?id={Id}` to `?slug={Slug}`, aligning with the SEO and storefront URL routing standards. Also updated related product pricing markup to support fixed amount discount badges.

## [2026-10-07] — Review Moderation Modal Simplification, Admin Toast Design Alignment & Product Specifications Peek Redesign

- **Admin Review Inspect Modal Simplification (`Reviews.aspx`, `reviews.js`):**
  - **Removed Footer Actions:** Completely removed the 3 action buttons (`btn-delete-review-modal`, `btn-cancel-review-modal`, `btn-toggle-visibility-action`) and their footer container from `#admin-review-modal`. The dialog is now a clean, distraction-free inspection card that closes via the header `&times;` button or backdrop click. Moderation and admin-only deletion actions remain accessible directly from the reviews table rows.
  - **JS Listener Cleanup (`reviews.js`):** Safely removed listeners and references for the removed modal actions while preserving core review fetching, status filtering, search debouncing, and deletion workflows.

- **Admin Toast Design Alignment with Storefront (`admin.css`, `admin.js`):**
  - **Design Discrepancy Resolution:** Unified the admin toast notification styling to match the storefront design system. Admin toasts previously used dark slate `#18181B` cards with thick colored left borders. Updated `#adminToastContainer .toast` and `.admin-toast` to render as clean `#ffffff` white cards with `#e4e4e7` border, `#171717` typography, multi-layered soft drop shadows, and minimalist colored status icons without the thick left borders.

- **Product Specifications UI Cutoff & Receipt-Style Toggle Redesign (`ProductDetail.aspx`, `ProductDetail.aspx.cs`, `product-detail.js`, `storefront.css`):**
  - **Two-Row Cutoff & Peek Row Low Opacity:** When collapsed (`.product-details-section:not(.is-expanded)`), the technical specification table displays the 1st row normally, renders the 2nd row with low opacity (`.detail-spec-row--peek`, `opacity: 0.28`, `pointer-events: none`) as an elegant preview peek, and hides row 3 and beyond (`.detail-spec-row--extra`, `display: none`). Expanding the table smoothly restores the 2nd row to full opacity and reveals all specifications.
  - **Receipt-Style Toggle Button:** Restyled the "Show more" button (`#btn-toggle-details`) inside `.details-toggle-wrap` to match the Order Receipt toggle (`.btn-receipt-toggle`), featuring pill border radius, subtle hover elevation, and a 180-degree rotating caret SVG icon (`receipt-caret-icon`) indicating expanded/collapsed state.
  - **Code-Behind Threshold (`ProductDetail.aspx.cs`):** Updated `pnlSpecToggle.Visible = ProductSpecifications.Count > 1` so products with multiple specifications present the interactive peek and expand control.

## [2026-10-07] — Reviews Moderation: Admin-Only Permanent Review Deletion & Confirmation Modal

- **Review Deletion Architecture & Security Barrier:**
  - **Stored Procedure (`54_admin_delete_review.sql`):** Added `dbo.sp_AdminDeleteReview @ReviewId INT` with transactional isolation to permanently remove reviews and cascade-delete any related reports in `dbo.ReviewReports`.
  - **Repository Layer (`IReviewRepository.cs`, `ReviewRepository.cs`):** Implemented `DeleteReviewAsync(int reviewId)` executing `dbo.sp_AdminDeleteReview` via ADO.NET `CommandType.StoredProcedure`.
  - **API Controller Endpoint (`ReviewsController.cs`):** Added `DELETE /api/v1/reviews/admin/{id}` strictly secured by `[StaffAuthorize(adminOnly: true)]`. Staff users receive HTTP 403 Forbidden; only authenticated Admins can execute deletion.
  - **Frontend UI & Modal Confirmation (`Reviews.aspx`, `reviews.js`, `constants.js`, `api.js`, `admin.css`):**
    - **Admin-Only UI Enforcement:** Dynamically renders the red Delete button in the table actions cell and in the review inspect modal exclusively when the authenticated user holds the `Admin` role (`window.HC_IS_ADMIN`).
    - **Dedicated Confirmation Modal (`#adminDeleteReviewModal`):** Built accessible modal dialog displaying danger icon, warning message, product/brand, reviewer name, rating stars, and review comment snippet.
    - **Tactile Feedback & State Management:** Features loading state (`"Deleting..."`), success toast notifications via `AdminToast`, automatic list reload, and smooth modal closing.
  - **End-to-End Verification:** Automated tests verified Staff rejection with HTTP 403 Forbidden and Admin success with HTTP 200 OK and database confirmation.

## [2026-10-07] — Standalone Complete Database Script Generation for Multi-Device Setup

- **Self-Contained Database Deployment Script (`database/setup/HelmetCartelDB_Complete.sql`):**
  - **Purpose & Scope:** Created a comprehensive, self-contained SQL deployment script that builds the complete `HelmetCartelDB` schema and populates all active seed and catalog data on any new machine with a single execution in SSMS or Visual Studio.
  - **Unnecessary Objects Excluded:**
    - Omitted 14 obsolete and one-time seed stored procedures (`sp_SeedCatalogContent`, `sp_SeedDashboardAuditSamples`, `sp_SeedHelmetCatalog`, `sp_SeedSampleCatalogAvailability`, `sp_SeedShoeiRf1400Specifications`, `sp_AddProductGalleryImage`, `sp_CalculateVoucher`, `sp_ChangeOrderInventory`, `sp_GetFaqs`, `sp_GetInventoryByVariantId`, `sp_GetSalesSummaryReport`, `sp_UpdateOrderStatus`, `sp_UpsertCategorySpecification`, `sp_UpsertSpecificationDefinition`).
    - Excluded non-application/orphaned tables (0 exist; preserved all 28 legitimate application tables).
  - **Topological Ordering & Foreign Key Isolation:**
    - Structured execution sequence: Table Types (`SaleLineInput`) -> Scalar Functions (`fn_BaseColorFromHex`, `fn_CalculateEffectivePrice`) -> 28 Tables with primary keys, unique constraints, and indexes -> Data Inserts with `IDENTITY_INSERT` -> 37 Foreign Key constraints -> 7 Views (`v_VisibleProducts`, `v_VisibleProductVariants`, etc.) -> Triggers (`tr_Orders_ReleaseVoucher`) -> 105 Active Stored Procedures (`CREATE OR ALTER PROCEDURE`, including `sp_AdminDeleteReview`).
    - Handled computed columns (`Inventories.IsLowStock`, `OrderItems.TotalPrice`, `Orders.TotalAmount`, `StockAuditLogs.NewStock`) by excluding them from insert column targets.
  - **Automated Verification:**
    - Tested end-to-end execution against a fresh scratch database (`HelmetCartelDB_TestVerify`). All batches executed cleanly with 0 errors, validating 28 tables, 37 foreign keys, 105 stored procedures, 8 users, 36 products, and 440 variants/inventory records.


- **Return to Checkout Workflow (`Checkout.aspx`, `Checkout.aspx.cs`, `checkout.js`, `Profile.aspx`, `profile.js`, `profile.css`):**
  - **Issue Resolved:** When a customer on Checkout did not have an address configured, clicking the address component redirected to the profile addresses tab (`Profile.aspx?tab=addresses`), but there was no action or clear way to return to Checkout once in the Profile page or after saving their address.
  - **Checkout Address Component Return URL (`Checkout.aspx.cs`, `checkout.js`):**
    - Configured server-side `NavigateUrl` in `Checkout.aspx.cs` to pass `?tab=addresses&returnUrl={rawUrl}`.
    - Updated `checkout.js` on client load to dynamically bind `returnUrl` (including `mode=buynow` when applicable) and store `hc_checkout_return_url` in `sessionStorage`.
  - **Return to Checkout Alert Banner (`Profile.aspx`, `profile.css`, `profile.js`):**
    - Added a sleek dark gradient card (`.checkout-return-banner`) at the top of the Saved Delivery Addresses section in `Profile.aspx` with a high-contrast `Back to Checkout` action button.
    - Added a secondary `Back to Checkout` outline button in the address section header next to `Add New Address`.
    - Both elements automatically appear whenever the user navigates from Checkout or has items in their cart / buy-now session.
  - **One-Click Address Selection for Checkout (`profile.js`, `profile.css`):**
    - Added a primary `Use for Checkout` button on each address card when return to checkout is active. Clicking it selects the address for delivery and immediately redirects the customer back to Checkout.
  - **Automatic Return on Address Save (`profile.js`):**
    - After successfully saving a new or edited address, if a checkout return intent exists, `profile.js` automatically sets the newly added address for checkout, displays a status toast (`"Delivery address saved! Returning to checkout..."`), and seamlessly redirects back to the checkout page.

## [2026-10-07] — Toast Hover Column Expansion & Order Items Total Quantity Fix

- **Toast Hover Expand Into Column (`components.css`, `admin.css`, `realtime.js`, `admin.js`):**
  - **Stack to Column Transition on Hover:** When user hovers the toast stack (`.toast-container:hover`, `#adminToastContainer:hover`, `.admin-toast-container:hover`), the container expands dynamically from stacked deck layout (`grid-area: 1 / 1`) into a vertical column (`display: flex; flex-direction: column-reverse; gap: var(--space-2, 8px)`).
  - **Reveals All Active Toasts:** All toasts (including 4th+ cards) become fully visible (`transform: translateY(0) scale(1)`, `opacity: 1`, `visibility: visible`) with fluid `toastUnfold` entrance keyframes, arranged cleanly in reverse chronological order (newest on top, older below).
  - **Tactile Item Hover Feedback:** Hovering any individual toast in the column elevates it subtly (`transform: translateY(-2px) scale(1.01)`) with enhanced box-shadow.
  - **Smart Dismissal Timer Pause:** Added `dataset.isHovered` tracking on the container. When hovered, automatic dismissal timeouts pause so toasts do not vanish while the user is reading or clicking. Upon mouse leave, toasts smoothly resume dismiss timers after a grace period.
  - **Smooth Collapsible Exit:** Updated `.toast--exit` / `.is-fading` styles to smoothly collapse `max-height` and `padding` to zero, allowing remaining column items to flow upward seamlessly.

- **Orders Table Items Column Total Quantity Calculation (`53_order_items_quantity_count_fix.sql`, `OrderDetail.aspx`, `OrderDetail.aspx.cs`):**
  - **Root Cause:** In stored procedures `dbo.sp_AdminOrders`, `dbo.sp_AdminDailySettledOrders`, and `dbo.sp_GetUserOrders`, the `ItemCount` column was queried using `(SELECT COUNT(*) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id) AS ItemCount`. For an order containing 1 helmet line item with a quantity of 2 (or more), this returned `1` (distinct line count) rather than `2` (actual ordered units).
  - **Database Migration 53 (`53_order_items_quantity_count_fix.sql`):** Altered `dbo.sp_AdminOrders`, `dbo.sp_AdminDailySettledOrders`, and `dbo.sp_GetUserOrders` to use `ISNULL((SELECT SUM(oi.Quantity) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id), 0) AS ItemCount`.
  - **Verified Query Results:** Verified against live SQL Server: orders with Qty 2 (such as `HC-20261007-F09017DA15` and `HC-20261007-BD1B48AA68`) now accurately return `Items: 2`, and orders with Qty 3 (such as `HC-20261007-5CCE19001A`) return `Items: 3`.
  - **Order Detail Header Consistency (`OrderDetail.aspx`, `OrderDetail.aspx.cs`):** Updated `litItemCount` in `OrderDetail.aspx.cs` to reflect `totalUnits` (the sum of `item.Quantity`) and renamed the card header to `Order Items (<asp:Literal ID="litItemCount" runat="server" />)`.

## [2026-10-07] — Catalog Item Variant Reference Fix, Reviews Moderation Authorization & Users Table Responsive Sizing

- **Catalog Item Variant Matrix Fix (`catalog-item.js`):**
  - Resolved `Uncaught ReferenceError: isVarActive is not defined` at line 885 during `renderVariantMatrix`.
  - Added `const isVarActive = v.isActive !== false;` prior to checking `isVarActive` when appending variant pills to the container, enabling error-free variant loading, color syncing, and pill removal.
- **Reviews Moderation Role Authorization (`ReviewsController.cs`, `api.js`):**
  - Changed `[StaffAuthorize(adminOnly: true)]` to `[StaffAuthorize]` on `AdminGetReviews` (`/api/v1/reviews/admin`) and `ToggleReviewVisibility` (`/api/v1/reviews/admin/{id}/toggle-visibility`), allowing Staff members to inspect and moderate customer feedback without triggering HTTP 403 Forbidden.
  - Hardened `ApiClient.request` in `api.js` to safely read response body text and handle non-JSON or empty error responses gracefully without throwing `SyntaxError: Unexpected end of JSON input`.
- **Users Table Fluid Sizing & Responsive Overflow (`admin.css`, `Portal.master`):**
  - Adjusted `.admin-table-users` from rigid `min-width: 920px; table-layout: fixed` to `width: 100%; min-width: 740px; table-layout: auto`.
  - Proportioned UID, Contact, Role, Status, and Action columns while allowing User Details and Email to fill available space on normal desktop displays.
  - Preserved `.admin-table-wrapper` horizontal scrolling (`overflow-x: auto`) for compact tablet or mobile viewports below 740px.

## [2026-10-07] — Staff Role Authorization, User Access Control Modal & New Staff Account Setup

- **Staff Account Creation & Promotion (`dbo.sp_AdminUpdateUserRole`, `51_staff_role_and_user_update.sql`):**
  - Created new staff user `staff@gmail.com` with password `staff@gmail.com` (salted SHA-256 hash, RoleId = 2 `Staff`, active account).
  - Promoted `kevs@gmail.com` and `staffmember@helmetcartel.com` to the `Staff` role in `HelmetCartelDB`.
  - Verified login via `POST /api/v1/auth/login` for both accounts, returning JWT tokens with claims `role: "Staff"`.
- **Granular Staff Authorization & Section Access Control (`Global.asax.cs`, `Portal.master`, `StaffAuthorizeAttribute.cs`):**
  - **Authorized Staff Sections:** Staff accounts are authorized to open the operations portal including `Dashboard`, `Orders`, `POS Counter`, `Inventory`, `Returns`, `Catalog`, `Reviews`, and `Reports`.
  - **Admin-Only Restrictions:** Restricted `Users & Access Control` (`Users.aspx`) and `Vouchers` (`Vouchers.aspx`) strictly to `Admin` users. Non-admin staff attempting to open these URLs are redirected safely to `Inventory.aspx` in `Global.asax.cs`.
  - **Dynamic Navigation:** Updated `Portal.master` sidebar so `Users` and `Vouchers` navigation items are rendered only for users with the `Admin` role.
- **Edit System Role Modal in Users & Access Control (`Users.aspx`, `Users.aspx.cs`, `Users.aspx.designer.cs`, `AdminDataRepository.cs`, `admin.css`):**
  - Added an "Edit Role" button on each user row in `Users.aspx`.
  - Added a modal allowing administrators to reassign user roles between `Customer`, `Staff`, and `Admin`.
  - Added self-demotion guards on both the client (disabling role reduction for the current logged-in user) and database level (`dbo.sp_AdminUpdateUserRole`), preventing lockout of the final active admin.
  - Linked to `AdminDataRepository.UpdateUserRoleAsync` and wired PostBack execution with instant status toast notifications.

## [2026-10-07] — Academic presentation business-process corrections

- Added authenticated customer ownership filters for order tracking/cancellation, reviews, and returns, and staff/admin restrictions for administrative return/review routes.
- Added an account-scoped customer SignalR hub and post-commit notifications for order, cancellation, cash/POS, and return/exchange operations, including Web Forms fulfillment buttons.
- Added server checkout validation and province-based shipping pricing, and inline checkout order/terms feedback.
- Added migrations 51–52: reservation-safe paid fulfillment/cancellation, method-specific fulfillment transitions, cash/COD collection timing, sale/restock audits and persistent low-stock alerts, inspected manual return processing, equal-price replacement stock deduction, and consistent settled merchandise reporting.
- Preserved completed payment history on cancellation. Refund and exchange completion now records a staff-confirmed manual action rather than claiming automatic gateway settlement. Added replacement size/color selection to staff return processing.
- Updated the fresh installer through structural migration 52, skipped optional destructive demo cleanup 47, and required explicit upgrade ranges. Applied 51–52 to the local database after a verified COPY_ONLY backup.
- Removed page inline style attributes in favor of CSS classes, corrected unsupported homepage claims/order metrics, and aligned architecture/setup documentation with the implemented presentation behavior.
- Build, disposable-database business/voucher tests, compiled C# checkout-policy tests, receipt tests, JavaScript syntax checks, guest API restrictions, and public page HTTP checks passed. Browser automation failed to initialize; interactive UI and two-browser SignalR verification remain manual checks.
- HitPay integration, electronic payment simulations, and demonstration catalog/review data were excluded by the user and left unchanged. Existing uncommitted changes were preserved. See `docs/ACADEMIC_FIX_STATUS.md` for the full correction scope and limitations.

## [2026-10-07] — Order HitPay Reference Display, Activity Feed Direct Inspect Routing, Restock Audit Navigation, Daily Sales Chart-Only View & User Password Update

- **Storefront & Admin Toast Notification System (`components.css`, `admin.css`, `admin.js`, `realtime.js`, `Site.Master`, `Portal.master`):**
  - **Storefront Card Deck Integration:** Storefront toasts emitted via `RealtimeManager.showToast` (`realtime.js`) render inside `.toast-container` in `Site.Master` with identical top-middle stacked card deck positioning (`top: 24px; left: 50%; transform: translateX(-50%); display: grid`).
  - **Fixed Storefront DOM Append:** Corrected `container.appendChild(toast)` in `realtime.js` so client toasts (cart adds, wishlist updates, stock alerts) immediately mount and display.
  - **Stacked Card Deck Layout (Sonner Style):** Replaced vertical list stacking with CSS Grid overlapping card deck (`grid-area: 1 / 1` and `place-items: start center`).
    - *Front Card (`:last-child`):* `transform: translateY(0) scale(1)`, `z-index: 30`, full opacity, smooth top slide-in (`slideInToastTop`).
    - *2nd Card (`:nth-last-child(2)`):* `transform: translateY(11px) scale(0.94)`, `z-index: 20`, `opacity: 0.94`, peeking symmetrically underneath.
    - *3rd Card (`:nth-last-child(3)`):* `transform: translateY(21px) scale(0.88)`, `z-index: 10`, `opacity: 0.85`, peeking further underneath.
    - *4th+ Cards:* Softly concealed behind the stack (`opacity: 0`) to prevent visual overload.
  - **Interactive Hover & Exit Polish:** Subtle hover depth separation (`translateY(14px)` and `translateY(25px)`), click-to-dismiss support, and a smooth `toast--exit` fade/slide transition.
  - **Zero UI Disruption:** Preserved all existing visual tokens, pure white `#FFFFFF` surface, typography, SVG status icons, and color highlights without modifying toast content structure.

- **Standard Motorcycle Helmet Size Sequence Ordering: XS to 2XL (`ProductFilterControl.ascx`, `Shop.aspx.cs`, `ProductDetail.aspx`, `ProductDetail.aspx.cs`, `product-detail.js`):**
  - **Shop Filter Pills (`ProductFilterControl.ascx`):** Reordered size filter pills strictly from smallest to largest: `XS` &rarr; `S` &rarr; `M` &rarr; `L` &rarr; `XL` &rarr; `2XL` &rarr; `3XL`.
  - **Backend Filter Normalization (`Shop.aspx.cs`):** Registered `AllowedSizes = { "XS", "S", "M", "L", "XL", "2XL", "XXL", "3XL" }`. Enhanced `NormalizeCsv` so selecting `2XL` or `XXL` automatically includes both aliases for SQL queries in `sp_GetProductsPaged`.
  - **Product Detail Backend Ordering (`ProductDetail.aspx.cs`):** Implemented canonical `SizeOrderMap` and `GetSizeOrder` so helmet variants are extracted and sorted in strict `XS` &rarr; `S` &rarr; `M` &rarr; `L` &rarr; `XL` &rarr; `2XL` sequence rather than random database insertion order. Added `NormalizeDisplaySize` to present `XXL` as `2XL` consistently.
  - **Product Detail Fallback Pills (`ProductDetail.aspx`):** Replaced legacy fallback labels (`Small`, `Medium`, `Large`, `X-Large`) with standard abbreviations (`XS`, `S`, `M`, `L`, `XL`, `2XL`).
  - **Variant Matching Equivalence (`product-detail.js`):** Added `areSizesEqual` helper function to equate `2XL` and `XXL` (and `3XL` with `XXXL`) across quantity steppers, cart additions, and UI variant state updates so selecting `2XL` seamlessly resolves database variants named `XXL`.

- **Resolved Payment Simulation 500 Error (`/api/v1/payments/simulate`):**
  - **Root Cause:** In Migration 50 (`dbo.sp_GetOrderDetails`), Result Set 2 (Order Items) returned `rr.Status AS LatestRmaStatus` instead of `AS RmaStatus`. When `_orderService.ConfirmOnlinePaymentAsync` invoked `_orderRepository.GetOrderByOrderNumberAsync(orderNumber)`, `reader.GetOrdinal("RmaStatus")` threw `IndexOutOfRangeException`, causing an unhandled HTTP 500 response from `POST /api/v1/payments/simulate`.
  - **Stored Procedure Fix:** Updated `dbo.sp_GetOrderDetails` in `50_activity_redirects_and_order_hitpay_ref.sql` to output `rr.Status AS RmaStatus` in Result Set 2 and applied it to SQL Server.
  - **Defensive Reader Resilience (`OrderRepository.cs`):** Introduced `GetOrdinalOrDefault` helper to safely look up column ordinals with fallback (`RmaStatus` or `LatestRmaStatus`), eliminating exceptions if stored procedure column aliases vary.
  - **Diagnostic Logging & Exception Handling (`PaymentsController.cs`):** Wrapped `SimulatePayment` in a structured try-catch block with `System.Diagnostics.Trace.TraceError` logging to ensure clear error reporting and prevent untraced 500 faults.
  - **Verified End-to-End:** Executed payment simulation for pending online order `HC-20261007-BD1B48AA68` via `POST /api/v1/payments/simulate`, returning HTTP 200 with `status: "Processing"` and `paymentStatus: "Completed"`.

- **HitPay Reference Display in Order Detail (`OrderDetail.aspx`, `OrderDetail.aspx.cs`, `OrderDetail.aspx.designer.cs`):**
  - Exposed and rendered the HitPay / Payment Reference number (`order.GatewayReference`) directly in the financial summary box beneath Payment Method and Status with styled monospace typography (`.admin-cell-mono`).
  - Added support for loading orders by HitPay reference, order number, or search query (`?paymentRef=...`, `?orderNumber=...`, `?ref=...`) via `LoadOrderByLookupAsync`, allowing direct deep-linking from activity feed logs or search queries.
  - Updated `OrderRepository.cs` and `sp_GetOrderDetails` to resolve orders seamlessly by either order number or gateway payment reference.

- **Activity Feed Deep-Link Routing (`Dashboard.aspx.cs`, `dashboard.js`, `50_activity_redirects_and_order_hitpay_ref.sql`):**
  - **Payment Transactions:** Clicking "Inspect" on payment logs now redirects directly to the specific order in `OrderDetail.aspx?paymentRef={GatewayReference}` rather than a generic list.
  - **Order Events:** Clicking "Inspect" on order logs routes directly to `OrderDetail.aspx?orderNumber={OrderNumber}`.
  - **Customer Reviews:** Updated `sp_AdminRecentActivity` to output Review reference as `REV-{Id}`. The inspect button now links directly to `Reviews.aspx?reviewId={Id}`, which automatically scrolls to, highlights with a pulsing outline, and opens the review moderation modal for that exact review.
  - **Stock Restocks & Purchase Orders (`PO-DIST-...`):** Contextually detects purchase order and restock reference patterns (e.g. `PO-DIST-2026-X1`), automatically routing to `/Pages/Admin/Inventory/Inventory.aspx?view=audit&search={Reference}`.
  - Updated `Inventory.aspx.cs` to automatically activate the Stock In & Audit History view when a search starts with `PO-` or `RESTOCK-`, eliminating empty results when inspecting purchase order restocks.

- **Daily Sales Performance Log — Chart-Only Modern Visualization (`Reports.aspx`, `reports.js`, `Reports.aspx.cs`):**
  - Removed the raw table log and segmented view switcher tabs (`Velocity Chart`, `Split View`, `Table Log`) as requested.
  - Fixed and expanded the Dual-Axis Velocity Chart container (`height: 340px`) to render cleanly at full width, remaining fully responsive with interactive points that still open the itemized daily orders drawer upon click.
  - Safely guarded backend repeater bindings in `Reports.aspx.cs` to prevent null references while preserving Excel reporting generation.

- **User Security & Credentials (`kevs@gmail.com`):**
  - Reset and synchronized password for user account `kevs@gmail.com` to `kevs@gmail.com`, computing the salted SHA-256 hash matching `AuthService.cs` authentication standards.

## [2026-10-06] — Modern Analytics Visualizations (Dual-Axis Spline/Column Velocity & Brand Stacked Bullet Charts), Click-to-Drawer Drilldown, and Multi-Sheet Excel SpreadsheetML Export

- **Daily Sales Performance Log Modern Visualization (`Reports.aspx`, `reports.js`, `Reports.aspx.cs`):**
  - **Dual-Axis "Spline Area + Column" Velocity Chart:** Implemented an interactive dual-axis Chart.js visualization displaying settled gross revenue as a smooth spline curve with monochrome dark gradient fill on the left Y-axis (formatted with PHP currency `₱#,##0.00` and metric abbreviations `k`/`M`) alongside transaction order volume as sleek columnar bars on the right Y-axis.
  - **Interactive View Switcher Tabs:** Added a segmented control (`Velocity Chart`, `Split View`, `Table Log`) allowing administrators to dynamically switch between full chart view, synchronized side-by-side split view, or raw historical table view.
  - **Full Click-to-Drawer Integration:** Clicking any date point or columnar bar on the chart, or clicking any row or "Inspect" button in the table, immediately opens an in-page drilldown drawer itemizing all orders settled on that date.

- **Brand Inventory Health Breakdown Modern Visualization (`Reports.aspx`, `reports.js`, `Reports.aspx.cs`, `admin.css`):**
  - **Horizontal "Stock Health Stacked Progress Bar" (Bullet Chart per Brand):** Replaced static tabular displays with a stacked progress bullet bar displaying available healthy stock (Green `#16A34A`), low stock alerts (Amber `#F59E0B`), and committed/reserved orders (Blue `#3B82F6`), computed dynamically on both backend helpers (`GetHealthyPercent`, `GetLowStockPercent`, `GetReservedPercent`) and client cache.
  - **Health Legend & Stat Highlights:** Integrated top-level status indicator dots and numerical stat pills directly under each brand's bullet chart for instant stock inspection.
  - **Click-to-Drawer Drilldown:** Clicking any brand row or "Inspect" button opens the in-page Brand Inventory Inspection Drawer.

- **Brand Inventory Health Breakdown Table Layout & Balance Refinement (`reports.js`, `admin.css`):**
  - **Eliminated Redundant Columns & Sizing Squish:** Replaced the previous 6-column layout (which had separate redundant columns for SKU, On-hand / Reorder, Available, and Status causing horizontal overflow and clipping) with a clean, perfectly balanced **4-column layout** (`48% / 22% / 16% / 14%`).
  - **Unified Product & Specification Cell:** Consolidates product thumbnail, bold model name, variant color/size, monospace SKU pill, and category tag in one readable card.
  - **Unified Stock Availability Metric:** Replaced confusing duplicate columns with a clear primary quantity (`X units available`) accompanied by non-redundant threshold context (`Min: X` and on-hand if reserved units exist).
  - **Full-Width Fixed Table Discipline:** Applied `table-layout: fixed` and widened `.admin-drawer--lg` to `860px` with zero horizontal scrollbars.

- **Dashboard Chart Slider Removal & Activity Feed Direct Inspect Actions (`Dashboard.aspx`, `Dashboard.aspx.cs`, `dashboard.js`, `admin.css`):**
  - **Removed Chart Drawers/Sliders from Dashboard:** Eliminated modal sliders from the dashboard sales velocity line chart and brand doughnut chart as requested, keeping dashboard graphs focused and uncluttered.
  - **Direct Redirect / Inspect Action on Activity Feed Items:** Added responsive `Inspect →` buttons to every recent activity feed item (both server-rendered via ASP.NET Repeater and dynamically loaded via `dashboard.js`).
  - **Context-Aware Routing Helper (`GetActivityInspectUrl`):** Automatically routes administrators directly to the relevant management console:
    - Order & Payment events &rarr; `/Admin/Orders.aspx?search={Reference}`
    - Inventory movements &rarr; `/Admin/Inventory.aspx?search={Reference}`
    - RMA / Returns &rarr; `/Admin/Returns.aspx?search={Reference}`
    - Customer Reviews &rarr; `/Admin/Reviews.aspx`

- **Daily Settlement Drilldown Accuracy & Stored Procedure Alignment (`49_settled_daily_orders.sql`, `AdminDataRepository.cs`, `AdminController.cs`):**
  - **Created `dbo.sp_AdminDailySettledOrders`:** Encapsulated daily settlement querying into a dedicated stored procedure strictly matching `dbo.sp_AdminSalesDaily` logic (`p.Status = 'Completed' AND o.Status IN ('Completed', 'Delivered') AND CONVERT(DATE, p.PaidAt) = @TargetDate`).
  - **Resolved Order Count Discrepancy:** The daily settlement drilldown for dates like October 03, 2026 now displays the exact 4 settled transactions (Orders #18, #19, #20, #21 totaling ₱180,090.00) matching the KPI cards and sales log, rather than returning all 14 created/unsettled orders.

- **Multi-Sheet Excel Export via SpreadsheetML & Removal of CSV Export (`Reports.aspx.cs`, `Reports.aspx`, `Reports.aspx.designer.cs`):**
  - **Removed Legacy CSV Export:** Removed the obsolete "Export CSV" button (`btnExportReport`) and its associated CSV formatting methods, streamlining the analytics toolbar to a single primary action: `Export Excel Report (.xls)`.
  - **Native Multi-Worksheet Architecture (`btnExportExcel_Click`):** Generates a true XML Spreadsheet 2003 (`.xls` via SpreadsheetML) workbook served as `application/vnd.ms-excel; charset=utf-8` without requiring external third-party dependencies, featuring styled headers, numeric formatting, currency formatting (`"PHP " #,##0.00`), percentage formatting (`0.0%`), and color-coded alert cells (`#FEE2E2` red, `#FEF3C7` amber, `#DCFCE7` green, and `#DCFCE7` badges).
  - **7 Dedicated Worksheets Included:**
    1. *Executive & KPIs:* Period Gross Revenue, Completed Orders, AOV, Today's Live Revenue, Live Active Orders, Total Warehouse Stock, Active SKUs, Total Available Stock, Low Stock Alerts, and Out of Stock count.
    2. *Item Sales Performance:* Granular item-level breakdown of all individual helmet models sold during the reporting window, sorted by revenue and units (Rank, Product / Model Name, Manufacturer / Brand, Category, Units Sold, Completed Orders, Gross Revenue, Average Selling Price, Revenue Share %, and Top Performer Badge) with summary total row.
    3. *Complete Inventory Catalog:* Comprehensive master inventory list of all active helmet models, colorways, and sizes across certified manufacturers (Brand, Model Name, Category, Color, Size, SKU, On-Hand Units, Available Units, Reserved Units, Reorder Point, Availability Rate %, and Health Status badge) with summary total row.
    4. *Daily Sales Log:* Complete daily chronological log of sales dates, formatted days of the week, transaction counts, gross revenues, and daily AOV with summary total row.
    5. *Brand Inventory Health:* Brand name, SKU count, on-hand units, available units, reserved units, low stock alerts, availability rate percentage, and status with summary total row.
    6. *Sales by Dimension:* Itemized sales breakdowns for both Brands and Categories (Units sold, order count, revenue, average selling price, top seller and top revenue flags).
    7. *Critical Restock Audit:* Granular audit table of all variants at or below reorder threshold (Brand, product name, category, color, size, SKU, on-hand, available, reorder point, unit deficit, and stock status).

- **Dedicated Web API Endpoints (`AdminController.cs`):**
  - `GET /api/v1/admin/reports/daily-orders?date={date}`: Retrieves orders filtered by settlement date for the daily orders drawer.
  - `GET /api/v1/admin/reports/brand-inventory?brand={brand}`: Retrieves granular product variant stock information filtered by brand.

- **Profile Account Details Form Fix (`Profile.aspx`, `profile.js`):**
  - **Eliminated Nested `<form>` Element:** Replaced nested `<form id="form-edit-profile">` and `<form id="form-change-password">` with container `<div id="form-edit-profile">` and `<div id="form-change-password">` with `<button type="button">`. In ASP.NET WebForms (`Site.Master`), inner `<form>` tags are dropped by the browser HTML parser, which previously prevented submit listeners from executing and caused buttons to trigger full page WebForms postbacks.
  - **Input Enter Key Support:** Added keydown listeners on form inputs to allow Enter-key submissions seamlessly while preventing unwanted form postbacks.

- **Account Details Confirmation Modal (`Profile.aspx`, `profile.js`):**
  - **Dedicated Modal UI (`#profileSaveDetailsModal`):** Added a confirmation modal matching the platform design system (`.admin-modal-backdrop`, `.admin-modal--confirm`, `.admin-modal-icon-circle`) prompting customers to confirm personal details updates before saving.
  - **Responsive Inline Validation:** Enforced inline input validation for First Name and Last Name prior to displaying the confirmation modal.
  - **Atomic Save & Real-Time Sync:** Upon modal confirmation, saves changes via `ApiClient.updateProfile`, syncs `currentUser` in `localStorage`, updates the sidebar avatar/name in real time, and shows confirmation toast notifications.

- **Security Password Modal & Same-as-Old-Password Enforcement (`Profile.aspx`, `profile.js`, `AuthService.cs`):**
  - **Old Password Comparison Validation:** Added strict front-end and back-end validation preventing users from changing their password to their current password. Inline error is highlighted under `#err-pwd-new` ("New password cannot be the same as your old password.").
  - **Backend Dual Layer Security (`AuthService.ChangePasswordAsync`):** Validates that `request.NewPassword != request.CurrentPassword`, and verifies against the existing database password hash and salt using `VerifyPassword(request.NewPassword, userRecord.PasswordHash, userRecord.Salt)`.
  - **Dedicated Password Confirmation Modal (`#profileChangePasswordModal`):** Added a confirmation modal prompting customers to confirm updating their credentials before submitting the request.

- **Defensive Null Protection (`UserRepository.cs`):**
  - Added safe null-checking for `FullName` and `CreatedAt` in `UserRepository.UpdateProfileAsync` to defend against any unhandled `SqlNullValueException`.



- **TrackOrder Display Resolution (`TrackOrder.aspx` & `track-order.js`):**
  - **Restored Main Content Visibility:** Removed legacy inline `style="display: none;"` from `.track-order-content` which was failing to be cleared by class toggling alone. Updated `setLoading`, `showError`, and `renderOrder` to explicitly reset `style.display = "flex"` alongside removing `.is-hidden`, ensuring the live tracking layout immediately renders when an order is loaded.

- **Digital Receipt Direct File Download (`Scripts/receipt.js`, `Checkout.aspx`, `TrackOrder.aspx`, `Profile.aspx`):**
  - **Standalone Download Engine:** Implemented `downloadReceipt(element)` in `receipt.js` that compiles the rendered receipt card into a self-contained, beautifully styled `.html` file with embedded modern CSS and initiates a direct browser file download named `Receipt-{orderNumber}.html`.
  - **Print Redirection:** Routed `printReceipt` directly to `downloadReceipt` so that every receipt button across the platform (Order Confirmation, Live Order Tracking, Customer Profile, POS, and Admin) triggers a direct download.
  - **Modernized UI Buttons:** Updated buttons in `Checkout.aspx` (`#checkout-print-receipt`), `TrackOrder.aspx` (`#btn-print-receipt`), and `Profile.aspx` (`#btn-print-receipt`) with clean "Download Receipt" labels and tray download SVG icons.

- **SqlNullValueException Elimination in Sales Breakdown Reports (`sp_AdminSalesByBrandAndCategory` & `AdminDataRepository.cs`):**
  - **SQL Null Protection:** Fixed division by `NULLIF(SUM(Quantity), 0)` in `dbo.sp_AdminSalesByBrandAndCategory` when a brand or category's sold units equal 0 due to approved customer returns/refunds. Wrapped `AverageUnitPrice`, `UnitsSold`, and `Revenue` in `ISNULL(..., 0.00)`.
  - **C# Safe Reading:** Updated `AdminDataRepository.ReadSalesDimensionReport` with defensive `reader.IsDBNull(...)` checks across all columns, preventing unhandled `SqlNullValueException` during Excel/CSV report exports in `Reports.aspx.cs`.

- **Admin Account Settings Modal & Profile Update Fix (`Portal.master`, `admin.css`, `AuthController.cs`, `sp_UpdateUserProfile`):**
  - **Removed Footer Actions:** Removed the redundant `.admin-modal-footer` containing Sign Out and Close buttons; modal dismissal is cleanly managed via the top-right close icon or backdrop click, matching the modal screenshot requirements.
  - **Spacing & Layout:** Refactored `.admin-profile-card` to use flex column layout with consistent `gap: var(--space-5)`, improved input label margins, and wrapped form submit actions in `.admin-profile-btn-row` with pill button styling.
  - **SQL Stored Procedure Settings (QUOTED_IDENTIFIER ON):** Re-created `dbo.sp_UpdateUserProfile` with `SET ANSI_NULLS ON` and `SET QUOTED_IDENTIFIER ON`, resolving SQL Error `1934` caused by updating `dbo.Users` containing filtered indexes. Admin user updates now save cleanly.
  - **Cookie Header Fallback:** Added `Request.Headers.GetCookies(...)` inspection to `AuthController.GetAuthenticatedUser()` for robust authentication across all API endpoints.

- **Order Item Detail Row Simplification (`Scripts/storefront/profile.js`):**
  - **Removed Review Item Button:** Removed the inline `[ Review Item ]` button from inside `.order-item-detail-row` to avoid UI crowding and redundant actions within the customer order history cards.
  - **Removed Inline Return Button:** Removed the redundant inline `[ Return / Exchange ]` button from inside `.order-item-detail-row`. Return/Exchange capabilities are now cleanly centralized in the order actions.
  - **Preserved RMA Chips:** Existing and active RMA chips (`.track-rma-chip`) remain prominently displayed for items that already have pending or completed return/exchange requests.
  - **Clickable Product Previews:** Wrapped the helmet thumbnail image (`.order-item-detail-img-link`) and product name (`.order-item-title-link`) in clickable anchor links navigating directly to `/Pages/Storefront/ProductDetail/ProductDetail.aspx?id={productId}`.

- **Centralized Return / Exchange in Track Order (`TrackOrder.aspx` & `Scripts/storefront/track-order.js`):**
  - **Action Stack Integration:** Added `#btn-track-return-order` ("Return / Exchange") directly inside `.track-actions-stack` on the Track Order page, visible when the order status is `Delivered` or `Completed`.
  - **Multi-Item Selector Support:** When clicked for orders with multiple items, the customer RMA modal provides a dedicated item selection dropdown (`#rma-item-selector`) pre-selecting eligible items, or displaying the single purchased item directly.
  - **Clickable Item Previews:** Wrapped product images (`.track-item-img-link`) and titles (`.track-item-title-link`) in `TrackOrder.aspx` with direct links to the product detail page with subtle hover zoom and underline feedback.

- **Design System & Zero Inline Styles Compliance (`Content/css/storefront/profile.css`):**
  - Added dedicated styling rules for `.order-item-detail-img-link`, `.track-item-img-link`, `.order-item-title-link`, `.track-item-title-link`, `.rma-radio-group`, `.rma-radio-label`, `.rma-notice-box`, and `.track-summary-discount`.
  - Removed all `style="display: ..."` inline styles in favor of `.is-hidden` utility class manipulation.
  - Bumped cache busting versions on `profile.css?v=9`, `track-order.js?v=6`, and `profile.js?v=20261004_2`.

## [2026-10-04] — Profile Update Resiliency, QRPh Cancel Workflow, Single-Use Voucher Limit, Stepper Spacing, and Net Sales Revenue Calculation (Migration 48)

- **Account Details Saving Resiliency (MSSQL & C#):**
  - **Optional Phone Number:** Updated `dbo.sp_UpdateUserProfile` to allow `@PhoneNumber` to be optional or omitted; if null or empty, it retains the user's existing phone number rather than failing with error `53004`. Phone uniqueness check is now only evaluated if a non-empty, altered phone number is supplied.
  - **C# Backend Validation:** Updated `AuthService.UpdateProfileAsync` to remove the strict `ArgumentException` requiring phone numbers, making phone optional for both admin profile and storefront member edits.
  - **Credentials & JWT Headers:** Enhanced `ApiClient.request` in `Scripts/api.js` to automatically include `credentials: 'include'` and inspect fallback local/session storage keys (`hc_auth_token`, `auth_token`).
  - **Admin Profile Modal:** Updated `admin.js` to ensure `fetchAdminProfile`, `adminEditProfileForm`, and `adminChangePasswordForm` supply `Authorization: Bearer <token>` and `credentials: 'include'` headers.

- **QRPh Payment Simulation Cancel Flow (`checkout.js` & `Checkout.aspx`):**
  - **Cancellation Handling:** Added dedicated `onCancelCallback` in `showSimulationModal` in `checkout.js`. Dismissing or clicking the cancel button no longer calls `onSuccessCallback()`.
  - **Order Cancellation:** When the modal is closed or cancelled, `ApiClient.cancelOrder` is invoked immediately to release reserved stock.
  - **Checkout State:** The user remains on the Checkout page with their active cart preserved, receiving an alert toast ("Payment was cancelled. Your order was not placed"), avoiding unwanted redirection to order confirmation.
  - **Modal UI:** Added explicit `#btn-cancel-sim` ("Cancel Payment") button within `.sim-actions-grid` in `Checkout.aspx`.

- **Strict One-Time Voucher Limit Per Customer (`sp_PreviewVoucher`, `sp_ApplyOrderVoucher`, `checkout.js`):**
  - **Database Enforcement:** Updated `dbo.sp_PreviewVoucher` and `dbo.sp_ApplyOrderVoucher` to verify whether a customer (`UserId` or `CustomerEmail`) has already used the voucher code in an existing non-cancelled order (`dbo.VoucherRedemptions` joined with `dbo.Orders`).
  - **Rejection Exception:** If already used by that user or email, SQL throws error `54017`: `"You have already used this voucher code. Vouchers are limited to one use per customer."`.
  - **Constants & Controllers:** Updated `AppConstants.Vouchers.LastSqlError` to `54020` so error `54017` is caught as a friendly voucher error. In `VouchersController.Validate`, automatically populated authenticated customer info and passed `customerEmail` from client-side checkout.

- **Order Progress Stepper Spacing & Alignment (`checkout.css`):**
  - **Proportional Flex Columns:** Refactored `.order-tracker` and `.tracker-node` to utilize proportional flex distributions (`flex: 1 1 0; min-width: 0; padding: 0 var(--space-1); max-width: 580px; margin: var(--space-6) auto;`).
  - **Eliminated Collision:** Fixed the text label collision where "ORDER PLACED", "QC & PACKING", "IN TRANSIT / DISPATCHED", and "DELIVERED" overlapped on one line. Labels now have dedicated column widths, centered alignment, and proper word-wrapping.
  - **Perfect Connector Geometry:** Positioned `.tracker-line` from `12.5%` to `87.5%` (`top: 17px`), connecting the exact geometric centers of step 1 to step 4 across all viewports.

- **Merchandise Revenue & Approved Returns Deduction (MSSQL):**
  - **Excluded Delivery Fee:** Replaced `TotalAmount` / `p.Amount` with merchandise revenue `(Subtotal - DiscountAmount)` across `dbo.sp_AdminDashboard`, `dbo.sp_AdminSalesDaily`, and `dbo.sp_AdminSalesHourly`. Delivery fees paid by customers no longer inflate gross revenue.
  - **Deducted Approved Returns:** When a return/RMA request is approved or completed (`ReturnRequests.Status IN ('Approved', 'Completed')`), the refunded merchandise value is automatically deducted from sales revenue in `dbo.sp_AdminDashboard`, `dbo.sp_AdminSalesDaily`, and `dbo.sp_AdminSalesHourly`.
  - **Performance & Breakdown Reports:** Updated `dbo.sp_AdminSalesPerformance` and `dbo.sp_AdminSalesByBrandAndCategory` to subtract returned items from `UnitsSold` and `Revenue`.
  - **Return Approval Default:** In `dbo.sp_AdminProcessReturnRequest`, when an RMA is approved or completed without an explicit refund amount, `@RefundAmount` automatically defaults to the item's line total (`OrderItems.TotalPrice`).

## [2026-10-04] — Comprehensive Realistic Product Specifications, Authentic Customer Reviews, and "OUR HAPPY CUSTOMERS" Testimonial Carousel (Migration 47)

- **Comprehensive Realistic Product Details & Specifications (Migration 47, `database/schema/47_realistic_products_specs_and_reviews.sql`):**
  - **Cleaned Up Test Records:** Permanently deleted test drafts (Products 49 and 51, `asdas`, `xc`) along with their orphaned color variants, gallery images, and inventory records.
  - **Authentic Motorcycle Helmet Catalog:** Updated all 35 catalog helmets (Shoei, AGV, Gille, Zebra, HNJ) with realistic, authentic model names, marketing positioning, and comprehensive technical descriptions (e.g., Shoei RF-1400 Dedicated, AGV Pista GP RR Carbon, Shoei X-Fifteen Racing, Shoei Neotec II Touring Modular, AGV K6 S Ultra-lightweight, Shoei Hornet ADV Dual-Sport, Gille 135 GTS V1 Aerodynamic Full-Face, Zebra Sym Jet Dual Visor Modular, HNJ 902 Commuter Full-Face).
  - **Structured Technical Specifications Database:** Seeded 315 complete technical specification attributes across all 35 catalog items in `dbo.ProductSpecificationValues` across 9 official motorcycle engineering dimensions:
    1. `helmet_type`: Full Face, Modular (Flip-Up), Dual-Sport / Adventure, Open Face.
    2. `shell_material`: AIM+ Multi-Ply Matrix Composite, 100% Carbon Fiber, Carbon-Aramidic Fiberglass, High-Impact Thermoplastic / ABS.
    3. `safety_certifications`: ECE 22.06, SNELL M2020D / M2025, DOT FMVSS No. 218, FIM Racing Homologated, BPS / ICC certified.
    4. `visor_style`: CWR-F2 Pinlock-Ready 2D Racing Shield, Ultravision Optical Class 1 (5mm), Anti-Scratch MaxVision Pinlock, Integrated Drop-Down Sun Visor.
    5. `retention_system`: Double D-Ring (Titanium / Stainless Steel) Racing Retention or Quick-Release Steel Micrometric Ratchet Buckle.
    6. `ventilation`: Multi-Channel Dynamic EPS channeling with chin, crown, and brow intakes plus negative pressure vacuum exhaust extractors.
    7. `interior_liner`: 3D Max-Dry moisture-wicking removable/washable antimicrobial cheek pads with Emergency Quick Release System (E.Q.R.S.) and 2Dry Shalimar fabrics.
    8. `weight`: Exact weight in grams (e.g., 1,450g ± 50g, 1,255g ± 50g).
    9. `comm_ready`: Bluetooth communication integration readiness (e.g., Sena SRL3 / SRL-Mesh dedicated cutouts, AGV INSYDE / Cardo universal speaker pockets).

- **Authentic Customer Reviews (Migration 47, `dbo.ProductReviews`):**
  - Replaced placeholder and sample reviews with 12 realistic, authentic reviews written from the perspective of real Philippine motorcycle riders across diverse helmets and use cases (track days, expressway touring, daily city commuting, weekend dual-sport trails).
  - Included authentic rider names, verified purchase badges, realistic feedback highlighting helmet acoustics, ventilation, weight balance, and fitment.

- **"OUR HAPPY CUSTOMERS" Testimonial Slider & Reference Layout (`Default.aspx`, `Default.aspx.cs`, `storefront.js`, `storefront.css`, `components.css`):**
  - **Dynamic Review Capacity:** Increased `_reviewRepository.GetTopCustomerReviewsAsync` from 6 to 12 top rated reviews.
  - **Reference Card Layout (Exact Match to User Reference):**
    - Redesigned `.testimonial-card` to match the provided modern card design:
      - Clean bold customer name with verified green checkmark badge (`.verified-badge`).
      - Star rating row directly below the name displaying numerical score (`5.0`) alongside 5 gold star SVGs.
      - Decorative quote mark icon (`.testimonial-card__quote-icon`) in pale sage/mint (`#D2E6DC`) positioned at the top-right corner.
      - Body comment in relaxed typography with high readability.
      - Excluded profile image avatar and completely removed purchased product names as requested.
      - Soft rounded pill corners (`border-radius: var(--radius-xl)` / 20px) with subtle card shadow (`0 4px 20px rgba(0, 0, 0, 0.04)`).
  - **Non-Scrollable, Button-Driven Slider:**
    - Eliminated manual horizontal scrollbars, wheel scrolling, and swipe dragging (`overflow: hidden` on viewport, `transform: translateX` on track).
    - Slider is strictly controlled via top `#prev-testimonial` and `#next-testimonial` circular buttons.
    - Displays exactly **3 cards at a time** on desktop (> 1024px), **2 cards at a time** on tablet (641px – 1024px), and **1 card at a time** on mobile (<= 640px).
    - Smooth cubic-bezier sliding transition (`450ms`) with infinite looping upon reaching either boundary.
    - Removed bottom pagination dots for a distraction-free, button-only interface.

## [2026-10-04] — Instantaneous Return Modal Items Pre-Loading & Orders Optimization (Migration 46)

- **Instantaneous Return Modal Items Loading (`Profile.aspx`, `profile.js`, `dbo.sp_GetUserOrders`, `UserRepository.cs`, `AuthDTOs.cs`):**
  - **Identified Root Cause:** When opening the Return modal, `profile.js` had to fetch order details on-demand via `ApiClient.getUserOrderDetails(orderId)` or wait behind a background `prefetchOrderDetails` loop that fired up to 10 sequential HTTP requests on page load, choking browser connection pools and causing an extended "Loading purchased items..." wait.
  - **MSSQL Optimization (Migration 46):** Enhanced `dbo.sp_GetUserOrders` to project order items and RMA states directly as an `ItemsJson` subquery column (`FOR JSON PATH`).
  - **C# Repository & DTO:** Added `Items` list to `UserOrderSummaryDto` and deserialized `ItemsJson` in `UserRepository.GetUserOrdersAsync`.
  - **Frontend In-Memory Cache:** In `profile.js`, prepopulated `orderDetailsCache` immediately upon initial orders load with zero extra round trips. Removed the blocking `prefetchOrderDetails` loop.
  - **Instant Modal Rendering:** Updated `openRmaModal` in `profile.js` to immediately render the items checklist synchronously from cache (0ms delay), eliminating the "Loading purchased items..." stall. Removed hardcoded loading text from `Profile.aspx`.

## [2026-10-04] — Free Delivery Fee Vouchers, Multi-Item Order Return/Exchange Handling, Descriptive Return Statuses, Activity Feed QRPh Labeling, Vouchers Null Pointer Fix, and Admin Password Autocomplete

- **Multi-Item Order Returns & Exchange Workflow (`Profile.aspx`, `profile.js`, `profile.css`, `track-order.js`):**
  - **Dynamic Multi-Item Selection Checklist:** Redesigned the RMA modal in `Profile.aspx` from a single dropdown to a rich, accessible multi-item checklist with thumbnail preview, product specs (Color, Size, Quantity), line totals, and selection checkboxes.
  - **Multi-Item Batch Submission:** Customers who order multiple items can select 1, several, or all items in a delivered order to return or exchange in a single flow with a "Select All Eligible Items" toggle.
  - **Item-Level Return Independence & Prevention of Lockouts:** Prevents multi-item orders from being locked out of returns once 1 item is submitted. If an item already has an active RMA, it is rendered in a disabled state with its active status chip, allowing unreturned items to still be submitted independently.
  - **Item-Level Quick Actions in Order History:** Added "Return / Exchange Item" buttons directly on unreturned items inside the expanded order details dropdown in `Profile.aspx`, preselecting the clicked item when the modal opens.
- **Descriptive Return Status Wording in Order History & Tracking (`profile.js`, `track-order.js`, `profile.css`):**
  - Replaced ambiguous, raw return status codes (`Return: Completed`, `Return: Pending`) with informative, rider-friendly status descriptions:
    - `Return: Pending Staff Review`
    - `Return: Approved • Awaiting Item Handover`
    - `Return: Item Received • Inspection in Progress`
    - `Return: Completed • Refund Processed`
    - `Return: Request Declined` / `Return: Request Cancelled`
    - `Exchange: Pending Staff Review`
    - `Exchange: Approved • Awaiting Item Handover`
    - `Exchange: Item Received • Inspection in Progress`
    - `Exchange: Completed • Replacement Dispatched`
    - `Exchange: Request Declined` / `Exchange: Request Cancelled`
  - Added dedicated color-coded status badges in order header cards, footer hints, and item list chips (`.status--rma-completed`, `.status--rma-approved`, `.status--rma-received`, `.status--rma-pending`, `.status--rma-rejected`).
- **Free Delivery Fee Vouchers (Migration 45, `AppConstants.cs`, `constants.js`, `VoucherService.cs`, `VoucherRepository.cs`, `OrderRepository.cs`, `Vouchers.aspx`, `vouchers.js`, `checkout.js`):**
  - Added `FREE_SHIPPING` discount type allowing vouchers that grant 100% free delivery fee regardless of merchandise total or shipping region.
  - **Database Migration 45 (`database/schema/45_free_shipping_vouchers_and_activity_qrph.sql`):** Updated `CK_Vouchers_Discount` constraint on `dbo.Vouchers` and updated `dbo.sp_AdminSaveVoucher`, `dbo.sp_CalculateVoucher`, `dbo.sp_PreviewVoucher`, and `dbo.sp_ApplyOrderVoucher` to recognize `FREE_SHIPPING`.
  - **Storefront Checkout Application:** When a `FREE_SHIPPING` voucher is applied, the checkout summary dynamically waives shipping fee (`FREE (Voucher)`), sets discount equal to shipping cost, recalculates total amount, and preserves delivery details without charge.
  - **Admin Voucher Management:** Added `Free Delivery Fee (100% Off Shipping)` option in `Vouchers.aspx`, live preview badge (`.voucher-type-badge--free`), and custom ticket preview ("FREE DELIVERY").
- **Admin Activity Feed Payment Label (`dbo.sp_AdminRecentActivity` / Migration 45):**
  - Replaced *"Payment received via HitPay"* with *"Payment received via QRPh"* across both order status summaries and payment transaction logs in the recent activity feed.
- **Admin Password Autocomplete Warning Fix (`Portal.master`):**
  - Resolved browser DOM autocomplete warning by adding `autocomplete="current-password"` to `#adminPwdCurrent` and `autocomplete="new-password"` to `#adminPwdNew` and `#adminPwdConfirm`.
- **Vouchers.js TypeError Null Reference Fix (`Vouchers.aspx`, `vouchers.js`):**
  - Fixed `Uncaught TypeError: Cannot read properties of null (reading 'checked') at saveVoucher` by adding the Active Status toggle checkbox (`#voucher-active`) to the modal in `Vouchers.aspx` and adding safe optional chaining fallbacks in `vouchers.js`.

- **Dynamic Default Page Hero Stats & Stored Procedure (`dbo.sp_GetStorefrontStats`, `Default.aspx`, `Default.aspx.cs`):**
  - Updated `dbo.sp_GetStorefrontStats` to query exact live counts:
    - `TotalBrands`: count of registered brands in `dbo.Brands`.
    - `TotalProducts`: count of active products in catalog `dbo.Products`.
    - `CompletedOrders`: count of completed customer transactions in `dbo.Orders WHERE Status = 'Completed'`.
  - Wired into `Default.aspx.cs` directly during `Page_Load` and rendered into `litBrandsCount`, `litHelmetsCount`, and `litRidersCount` as formatted strings (`5+ Brands`, `37+ High-Quality Helmets`, `9+ Satisfied Riders`).
- **Dynamic Customer Reviews Across Any Products (`dbo.sp_GetTopCustomerReviews`, `ReviewRepository.cs`, `Default.aspx`):**
  - Updated `dbo.sp_GetTopCustomerReviews` to fetch the top 6 highest rating customer reviews (`Rating DESC, CreatedAt DESC`) across any product reviews in `dbo.ProductReviews`.
  - Fixed star rating evaluation casting `Convert.ToDecimal(Eval("Rating"))` in `rptHappyCustomers` repeater template, rendering authentic 5-star cards with reviewer names, verified badges, and testimonials in `Default.aspx`.
- **Mega Menu Categories, Brands & Spotlight (`Site.Master`):**
  - Verified 5 Categories, 5 Brands, 4 Popular Finishes.
  - Featured AGV Pista GP RR Carbon Racing Helmet (₱78,000) with local asset `/Content/images/products/helmets/agv/pistagprrgc7.webp` in SPOTLIGHT.
- **Responsiveness & Equal Product Card Sizing (`layout.css`, `components.css`, `storefront.css`):**
  - Resolved `brand-ticker` mobile overflow by constraining max width to viewport and wrapping list cleanly without document blowouts.
  - Enforced strict equal heights and proportional balance across `.product-card` with flex column layouts, 2-line title clamps, and `margin-top: auto` on rating and pricing elements.
- **Collapsible Checkout Receipt with Caret Toggle (`Checkout.aspx`, `receipts.css`, `checkout.js`):**
  - Styled collapsible receipt container (`.checkout-receipt-document.is-collapsed`) with height constraint and gradient bottom fade mask.
  - Added interactive toggle button with caret SVG (`#btn-toggle-receipt`) to expand and collapse receipt height on demand.
- **Admin Authentication Role Redirection (`auth.js`):**
  - Configured sign-in response logic to redirect `Admin` and `Staff` users straight to the Admin Management side (`APP_CONSTANTS.ROUTES.ADMIN_DASHBOARD`), while directing regular `Customer` users to the storefront or requested return URL.

## [2026-10-03] — TrackOrder Cancel & RMA Actions, Completed Order Item Reviews, Self-Review Visibility & Self-Report Prevention, Refund/Exchange Indicators, and All-Activity Feed Expansion (Migration 44)

- **Order Cancellation & Return/Exchange Actions in TrackOrder (`TrackOrder.aspx`, `track-order.js`, `profile.css`):**
  - Integrated dynamic cancellation action (`#btn-track-cancel-order`) inside `TrackOrder.aspx` for orders in `PendingPayment` or `Processing` status. Removed the SVG icon for a sleek text-only button, and enforced strict status checks ensuring the button is completely hidden on completed, delivered, shipped, or cancelled orders.
  - Added dedicated cancellation modal (`#track-cancel-modal`) enabling customers to specify cancellation reasons with notes, executing via `POST /api/v1/orders/{orderId}/cancel`.
  - Added item-level Return/Exchange initiation button directly on each delivered order item, opening the RMA modal prefilled with order details.
  - Replaced return button with a dedicated RMA status badge (`.track-rma-chip`) showing `RMA #{rmaNumber} &bull; {status}` once an RMA has been submitted.
  - Redesigned the order history footer return status indicators in `Profile.aspx` from pill chips to clean, italic text-only hints (`.order-status-hint--rma`) matching screenshot 3.
  - Improved layout of purchased items in TrackOrder: separated product specs and horizontal action buttons from right-aligned pricing (`{quantity} pcs × {unitPrice}` over total price), avoiding awkward vertical button stacking.
  - Renamed "Purchased Gear Details" and related modal/button labels from "Gear" to "Item" or "Product".
  - Prefilled realistic random waybill / tracking numbers in Admin Dispatch modal and TrackOrder courier cards.
  - Added prominent header RMA banner (`#track-rma-banner`) summarizing order-level RMA resolution status (Pending, Approved, Refunded, Exchanged, Rejected).


- **Verified Buyer Product Review from Completed Orders (`TrackOrder.aspx`, `track-order.js`, `Profile.aspx`, `profile.js`):**
  - Added "Write Review" action for completed order items in both TrackOrder and Customer Profile order history.
  - Added dedicated interactive review modal (`#track-review-modal`) with dynamic 5-star rating picker, review headline, and detailed feedback comment.
  - Links submission to `POST /api/v1/reviews` with `OrderId` and `ProductId`, automatically granting the `Verified Buyer` badge upon completion.
  - Automatically replaces the review action button with a `.track-reviewed-chip` ("Reviewed &#10003;") once submitted.

- **Self-Review Visibility and Self-Reporting Prevention (Migration 44, `sp_GetProductReviews`, `sp_ReportReview`, `ReviewsController.cs`, `ProductDetail.aspx`, `product-detail.js`):**
  - **Self-Reporting Block:** Updated `dbo.sp_ReportReview` with database-level validation to prevent a user from reporting their own reviews (`IF @UserId = @ReviewAuthorId THROW 'You cannot report your own review.'`).
  - **Suppressed Report UI:** Suppressed the "Report this review" action entirely on the author's own review cards on `ProductDetail.aspx`.
  - **Author Visibility for Hidden/Moderated Reviews:** Resolved the UX policy requirement: authors can view their own review even if flagged/hidden (`IsHidden = 1`), rendered in a muted/disabled state (`.review-card-full.is-hidden-disabled`) with an informational banner: *"Your review is currently hidden / under moderation (visible only to you)"*, preventing confusion and duplicate reviews while protecting public shoppers from unmoderated content.

- **Refunded and Exchanged Status Indicators (`Profile.aspx`, `profile.js`, `TrackOrder.aspx`, `track-order.js`, `profile.css`):**
  - Added explicit visual status pills (`.status--refunded`, `.status--exchanged`, `.status--rma-pending`, `.status--rma-approved`) in Order History cards and TrackOrder headers.
  - Seamlessly updates order status displays to reflect when an order has been partially or fully refunded or exchanged based on `LatestRmaResolution` and `LatestRmaStatus`.

- **Comprehensive Scope for Recent Activity Feed (Migration 44, `sp_AdminRecentActivity`, `AdminDataRepository.cs`, `Dashboard.aspx.cs`, `dashboard.js`):**
  - Created and executed Migration 44 (`database/schema/44_orders_rmas_reviews_activity_enhancements.sql`) expanding `dbo.sp_AdminRecentActivity` to capture **ALL** core system events:
    - **Orders:** Placed orders, payment completions, and in-store POS checkouts.
    - **Stock:** Real-time stock audit logs, restocks, sales deductions, and adjustments.
    - **Returns/RMAs:** Return and exchange requests filed by customers, as well as approvals, rejections, and resolutions by staff/admin.
    - **Customer Reviews:** New product reviews submitted by verified buyers.
    - **Review Moderation:** Review moderation reports submitted for staff inspection.
    - **Payments & Refunds:** Electronic payments received and processed refunds.
  - Added SVG icons and badge styling for `RMA`, `Review`, and `Payment` activities in admin dashboard feeds.


- **Receipt Seal Clean-up (`receipt.js`, `track-order.js`):**
  - Removed "Helmet Cartel MSSQL Ledger" from receipt seals across all customer, order tracking, and checkout receipt templates.
  - Standardized the verified transaction seal text to `Verified Electronic Transaction` accompanied by the official SVG check shield icon.

- **Recent Activity Feed Dynamic Pagination & Actor Role Badges (Migration 43, `sp_AdminRecentActivity`, `AdminController.cs`, `Dashboard.aspx`, `dashboard.js`, `admin.css`):**
  - Created and executed Migration 43 (`database/schema/43_activity_feed_load_more_and_actor_role.sql`):
    - Added `@Offset INT = 0` and `@Limit INT = 8` parameters using `OFFSET @Offset ROWS FETCH NEXT @Limit ROWS ONLY`.
    - Added dynamic `ActorRole` calculation returning `Customer`, `Admin`, or `Staff` based on user role and transaction channel.
    - Updated `database/setup/Build-MinimalDatabase.ps1` to include Migration 43.
  - Updated backend data access in `Repositories/AdminDataRepository.cs` and `Controllers/Api/AdminController.cs` (`[HttpGet, Route("dashboard/activity")]`).
  - Added role badges to both server-rendered repeater items in `Dashboard.aspx` and dynamically loaded items via `#btnLoadMoreActivities` in `dashboard.js`.
  - Added CSS styling in `admin.css` for `.admin-activity-role-badge` (`--customer`, `--admin`, `--staff`), `.admin-activity-footer`, and `.admin-activity-load-more` with loading spinner.

- **Modal Consistency Throughout System (`admin.css`, `components.css`, `storefront.css`):**
  - Standardized modal card container with rounded borders (`var(--radius-xl)`), hidden overflow, and smooth entrance animation.
  - Standardized modal headers with bottom border (`1px solid var(--color-border-subtle)`), title typography, and alignment.
  - Standardized modal action panels/footers with subtle tinted background (`var(--color-surface-subtle)`), top border, and rounded bottom corners matching the modal frame.
  - Standardized circular close buttons (`.admin-modal-close-btn`, `.modal-close-btn`, `.review-modal-dialog .modal-close-btn`): 34px diameter, circular pill geometry, subtle background, and smooth 90-degree hover rotation.

- **Admin User Capsule Profile & Security Management (`Portal.master`, `admin.js`, `admin.css`):**
  - Re-wired `.admin-user-capsule` in the admin topbar to open a dedicated Admin Account Settings modal (`#adminProfileModal`).
  - Implemented the exact two-card structure requested:
    - **Personal Information Card:** First Name, Last Name, read-only Email Address with helper explanation, Mobile Phone Number, and "Save Profile Changes" button.
    - **Password & Security Card:** Current Password, New Password (minimum 6 characters), Confirm New Password, and "Update Password" button.
  - Connected forms to live backend endpoints `PUT /api/v1/auth/profile` and `PUT /api/v1/auth/change-password` with inline validation and toast feedback.
  - Added automatic display update for topbar avatar initials and admin full name on page load and profile save.

- **Storefront Login Toast Feedback & Redirect to Default (`auth.js`, `site.js`):**
  - Updated customer sign-in and sign-up in `Scripts/storefront/auth.js` to redirect to `APP_CONSTANTS.ROUTES.HOME` (`/Default.aspx`) instead of the profile page when no return URL is provided.
  - Stored friendly welcome message in `sessionStorage.getItem('hc_login_toast')`.
  - Added pending login toast detection to `SiteController.init()` in `Scripts/site.js` to automatically display `RealtimeManager.showToast(...)` upon arriving at `Default.aspx`.


## [2026-10-03] — Unified Admin Global Search Expansion, Navbar Reordering & Full System Simulation

- **Unified Admin Global Search Expansion (Migration 42 & `sp_AdminGlobalSearch`):**
  - Removed page-level local search inputs from Vouchers (`Pages/Admin/Vouchers/Vouchers.aspx`), Reviews (`Pages/Admin/Reviews/Reviews.aspx`), and Returns (`Pages/Admin/Returns/Returns.aspx`).
  - Expanded `dbo.sp_AdminGlobalSearch` via Migration 42 (`database/schema/42_admin_global_search_expansion.sql`) to include:
    - **Vouchers:** Searches voucher codes and discount values from `dbo.Vouchers` and aggregates usage count via subquery on `dbo.VoucherRedemptions`, linking directly to `/Pages/Admin/Vouchers/Vouchers.aspx?q=...`.
    - **Reviews:** Searches reviewer names, comment text, review titles, and associated product names from `dbo.ProductReviews` joined with `dbo.Products`, linking to `/Pages/Admin/Reviews/Reviews.aspx?q=...`.
    - **Returns:** Searches RMA numbers, reasons, customer notes, order numbers, and tracking references from `dbo.ReturnRequests` joined with `dbo.Orders`, linking to `/Pages/Admin/Returns/Returns.aspx?q=...`.
  - Applied Migration 42 to `HelmetCartelDB` (`.\SQLEXPRESS`) and integrated it into `database/setup/Build-MinimalDatabase.ps1`.
  - Wired client scripts (`vouchers.js`, `reviews.js`, `returns.js`, `admin.js`) to support real-time debounced filtering and URL query parameter routing (`?q=`) driven by the Admin Global Search header input.

- **Admin Sidebar Navigation Reordering (`Portal.master`):**
  - Reordered the admin sidebar navigation menu according to the exact requested 10-item standard:
    1. **Dashboard** — overview and alerts (`/Pages/Admin/Dashboard/Dashboard.aspx`)
    2. **Orders** — incoming purchases and fulfillment (`/Pages/Admin/Orders/Orders.aspx`)
    3. **POS Counter** — in-store sales (`/Pages/Admin/POS/POS.aspx`)
    4. **Inventory** — stock checks and adjustments (`/Pages/Admin/Inventory/Inventory.aspx`)
    5. **Returns** — after-sales handling (`/Pages/Admin/Returns/Returns.aspx`)
    6. **Catalog** — products, variants, and pricing (`/Pages/Admin/Catalog/Catalog.aspx`)
    7. **Vouchers** — promotional codes (`/Pages/Admin/Vouchers/Vouchers.aspx`, role-restricted)
    8. **Reviews** — customer feedback moderation (`/Pages/Admin/Reviews/Reviews.aspx`)
    9. **Reports** — sales and inventory analysis (`/Pages/Admin/Reports/Reports.aspx`)
    10. **Users** — accounts and access control (`/Pages/Admin/Users/Users.aspx`)

- **Comprehensive End-to-End System Simulation & Verification (`test_system_simulation.ps1`):**
  - Successfully simulated and verified the entire business lifecycle against the active IIS Express backend and SQL Server (`.\SQLEXPRESS`):
    - **Phase 1 (Customer Auth):** Customer `juan@rider.com` login, JWT issuance, profile retrieval (`/auth/me`), and addresses check.
    - **Phase 2 (Browse & Filter):** Querying categories, brands, text search for "Shoei", and product variant inspection.
    - **Phase 3 (Voucher Validation):** Tested `POST /api/v1/vouchers/validate` for code `CARTEL10` with Shoei RF-1400 Size M variant; validated 10% discount calculation.
    - **Phase 4 (Online Checkout):** Online order placed with delivery details and voucher; verified atomic reservation of stock (`ReservedStock` incremented, `AvailableStock` decremented).
    - **Phase 5 (Payment Simulation):** Processed GCASH simulated payment (`POST /api/v1/payments/simulate`); verified order status set to `Processing`, payment status to `Completed`, `CurrentStock` decremented by 1, and `StockAuditLogs` record created (`ChangeType = 'ONLINE_SALE'`).
    - **Phase 6 (Admin Fulfillment):** Admin login, dispatched order (`POST /api/v1/admin/orders/{id}/dispatch`) setting courier Lalamove Express and tracking number (`Status = Shipped`), and completed order (`Status = Completed`).
    - **Phase 7 (Verified Customer Review):** Submitted customer 5-star review linked to completed order (`POST /api/v1/reviews`); verified verified-purchase badge integrity in `dbo.ProductReviews`.
    - **Phase 8 (Order History & Digital Sales Receipt):** Verified order in customer order history (`/auth/my-orders`) and full digital sales receipt data (`/orders/track/{orderNumber}`).
    - **Phase 9 (Admin Inventory Restock):** Restocked +10 units via `POST /api/v1/admin/inventory/adjust`; verified stock updated in `dbo.Inventories` and audit log created (`ChangeType = 'RESTOCK'`).
    - **Phase 10 (In-Store POS Sale):** Executed cash POS sale of 2 units via `POST /api/v1/orders/in-store`; verified atomic stock decrement (-2 units) and audit log (`ChangeType = 'INSTORE_SALE'`).
    - **Phase 11 (Analytics & Reconciliation):** Verified unified global search for vouchers, catalog items, and reviews; verified admin dashboard KPIs and sales/inventory performance analytics reports. All 11 phases passed 100%.

## [2026-10-03] — Promotional Vouchers KPI Cards Dashboard Alignment

- **KPI Cards Layout & Design Alignment (`Vouchers.aspx`, `vouchers.css`, `vouchers.js`):**
  - Redesigned the 4 Voucher KPI summary cards (`Total Vouchers`, `Active & Ready`, `Total Redemptions`, `Expired / Inactive`) to match the exact vertical design and aesthetic of the Admin Dashboard KPI cards.
  - Replaced the horizontal icon box layout with the Dashboard standard: uppercase muted label on top (`.admin-kpi-label`), bold metric value in the middle (`.admin-kpi-value`), and dynamic trend/status pill badges on the bottom (`.admin-trend-badge`, `.admin-trend--up`, `.admin-trend--down`, `.admin-trend--neutral`).
  - Standardized card container styling with subtle surface background (`var(--color-surface-subtle)`), rounded border (`var(--radius-lg)`), and clean `--space-5` padding.
  - Updated `updateKPIs()` in `vouchers.js` to calculate dynamic active/expired percentages and redemption trends, rendering SVG directional arrows and badges in real-time.
  - Bumped asset cache versions (`vouchers.css?v=3`, `vouchers.js?v=3`) to ensure immediate browser display without cached styles.

## [2026-10-03] — Checkout confirmation transition and QRPh demo controls

- Fixed completed checkout leaving the review form visible above confirmation: stepper and interactive grid now use explicit hidden attributes with scoped CSS overrides. Confirmation receives keyboard focus and scrolls into view.
- Changed customer checkout and receipt gateway labels to QRPh while preserving existing backend gateway identifiers. Removed the waiting-for-scan prompt and decline button; a single Complete Demo Payment action waits for the C# payment confirmation before showing success. Closing without paying still displays the saved pending order.
- Removed accumulated modal click listeners, guarded repeated submissions and disabled closing during confirmation. Payment demonstration remains clearly identified. Build, JavaScript syntax and receipt assertions passed.

## [2026-10-03] — Checkout Experience Overhaul: Promo Code Redesign, Toast Suppression, Payment Simulation Fix, Step 4 Tracker Icon, and Digital Sales Receipt Alignment

- **Digital Sales Receipt Alignment (`receipt.js`, `receipts.css`):**
  - Restored and standardized the official Helmet Cartel Digital Sales Receipt format matching reference design (#REC-XXXXXX, Flagship Store & Fulfillment Hub details, 2-column Billed To & Fulfillment & Payment card, item & specification table, subtotal/discount/shipping fee/total paid breakdown, and verified electronic transaction ledger seal).
  - Replaced inline styling on receipt table cells with semantic CSS classes (`.receipt-col-qty`, `.receipt-col-price`, `.receipt-col-total`) adhering strictly to the zero inline styles rule.
  - Bumped module query parameters across consumers (`checkout.js`, `profile.js`, `order-receipt.js`, `pos.js`) to `?v=20261003-3` ensuring immediate cache invalidation.
- **Interactive HitPay Payment Simulation Method Fix (`api.js`):**
  - Added missing `simulatePayment(data)` method to `ApiClient` in `api.js` targeting `POST /api/v1/payments/simulate`. Resolved TypeError `ApiClient.simulatePayment is not a function` during interactive QR Ph checkout simulation.
- **Checkout Step Navigation Toast Suppression (`checkout.js`):**
  - Removed disruptive step transition toast notifications when navigating between Step 1 (Customer & Delivery), Step 2 (Payment), and Step 3 (Review & Confirm).
- **Confirmation Tracker Step 4 Icon Fix (`Checkout.aspx`):**
  - Fixed `#tracker-step-4 .tracker-icon` SVG on the order confirmation screen to render a pending circle (`<circle cx="12" cy="12" r="2"></circle>`) instead of a completed checkmark. Checkmark is only dynamically applied upon order collection.
- **Order Summary Promo Code Redesign (`Checkout.aspx`, `checkout.css`, `checkout.js`):**
  - Relocated the promo code block directly below the Total Amount line in the Order Summary sidebar.
  - Redesigned into a pill-shaped input container with a coupon tag SVG icon, input field with placeholder `Add promo code`, and a solid black pill `Apply` button (`.btn-checkout-promo-apply`).
  - Styled discount amounts in vibrant red (`.summary-calc-discount`, `#DC2626`) showing discount percentage or code label in parentheses matching the design reference.

## [2026-10-03] — View receipt from admin order details

- Added View Receipt in `od-header-actions` before the main fulfillment action. It opens the shared receipt renderer using the existing Staff/Admin-authorized order-detail API and includes Print / Save Receipt, Escape/backdrop closing, focus trapping and focus restoration.
- Verified the running page's button placement and receipt against a saved order: merchandise 2,834.00 plus delivery 150.00 equals total paid 2,984.00. Build and JavaScript checks passed.

## [2026-10-03] — Repair catalog saving before specification persistence (Migration 41)

- Reproduced the running catalog editor failure: `sp_AdminSaveProduct` referenced nonexistent `fn_GetEffectivePrice`, stopping the request before specifications were saved. The live procedure differed from the repository definition.
- Added a rerunnable procedure repair using the existing `fn_CalculateEffectivePrice` and current product columns, included it in fresh setup and the upgrade runner, and installed it after a verified database backup.
- Verified standard and custom specifications survive draft saving and reopening, and custom removal persists. Restored the tested draft's original specification values. Added a rollback-only SQL regression covering product creation, publication, specification updates, removal and clearing.

## [2026-10-03] — Digital Receipt Loader Hardening & Constants Module Cache Busting

- **Digital Receipt Undefined Constants Fix (`receipt.js`, `constants.js`, `AppConstants.cs`):**
  - Diagnosed runtime error `Unable to load receipt: Cannot read properties of undefined (reading 'SIMULATION_PREFIX')` occurring when opening official transaction receipts.
  - Root Cause: Browser caching of the ES module specifier `constants.js` had held an earlier evaluation from before `RECEIPTS: { BRAND: 'HELMET CARTEL', SIMULATION_PREFIX: 'SIM-' }` was declared, causing `APP_CONSTANTS.RECEIPTS` to evaluate to `undefined` during `String(reference || '').startsWith(APP_CONSTANTS.RECEIPTS.SIMULATION_PREFIX)`.
  - Added robust fallback object extraction in `receipt.js` for `RECEIPTS`, `UI`, `PAYMENT_METHODS`, `PAYMENT_STATUS`, and `SHIPPING_METHODS` (`safeConstants.RECEIPTS || { BRAND: 'HELMET CARTEL', SIMULATION_PREFIX: 'SIM-' }`), preventing any missing constant or module skew from throwing a runtime exception.
  - Added cache-busting query strings (`?v=20261003`) to the module specifiers in `receipt.js`, `profile.js`, `checkout.js`, and `pos.js`.
  - Attached `window.APP_CONSTANTS = APP_CONSTANTS` in `constants.js` to ensure reliable global availability across browser contexts.
  - Added `AppConstants.Receipts` (`Brand`, `SimulationPrefix`) to backend `AppConstants.cs` preserving backend/frontend constant parity.


- **Vouchers Portal Page & Navigation Overhaul (`Vouchers.aspx`, `vouchers.css`, `vouchers.js`, `Portal.master`):**
  - Redesigned the raw two-column voucher workspace into a full-width layout matching the portal's design system.
  - Added SVG tag icon to the Vouchers navigation link in `Portal.master`.
  - Added 4 KPI Summary Cards (Total Vouchers, Active Codes, Total Redemptions, Expired / Depleted) with metric calculation.
  - Added Search Bar and Segmented Status Filter Tabs (`All Vouchers`, `Active`, `Inactive`, `Expired / Depleted`) with live search and counter metadata.
  - Redesigned the Vouchers table with monospace coupon ticket chips, single-click copy-to-clipboard button, discount badges, usage progress bars, expiry indicators, and single-click active toggle switches.
  - Converted the create/edit form into a focused, accessible modal dialog with backdrop, structured two-column grid (`admin-form-grid-2`), inline error messages, and an interactive live coupon ticket preview card updating in real time.
  - Integrated system toast notifications (`showAdminToast`) on creation, updates, status toggling, and copy actions.

## [2026-10-03] — Online vouchers and shared transaction receipts (Migration 40)

- Added Admin-only voucher management and C# validation/list/create/update APIs. Codes support percentage/fixed-peso discounts, minimum merchandise spend, optional expiry and total usage limit. Checkout supports one code, Apply/Remove, inline errors, server-priced totals and protection against stale responses.
- Added `Vouchers`, `VoucherRedemptions`, immutable order `VoucherCode` snapshots and persisted POS `CashTendered`. Redemption revalidates the saved merchandise lines inside the order/stock transaction and holds a voucher row update lock through commit. Pending orders consume usage; cancellation releases it once through a transaction-bound trigger. Existing orders retain their totals.
- Updated online variant pricing to use the same effective-price function as voucher preview and POS, including fixed-amount and time-limited product promotions.
- Replaced customer, checkout-confirmation and POS receipt rendering with shared `receipt.js` and `receipts.css`. Receipts show actual payment status/references, voucher savings, cash/change and Philippine timestamps. Removed fabricated store/TIN details and receipt inline styles. Added isolated receipt-only A4 printing and keyboard focus handling.
- Included both migration 39 scripts plus migration 40 in the compact fresh installer; upgrade runner now supports multiple files per migration number.
- Validation: Debug build, isolated fresh database installation, voucher eligibility/rounding/caps, cancellation/idempotency, two-connection last-use contention, actual C# checkout/history/receipt/POS mappings, order/reservation rollback, renderer assertions and browser layout checks at 375/768/1200 px. Test databases are removed afterward. Native print-preview pagination remains a manual verification step because the in-app browser does not expose its print dialog.


## [2026-10-03] — Technical Specifications Persistence & Postback Fix (Migration 39)

- **Technical Specifications Persistence Hardening (`CatalogItem.aspx`, `CatalogItem.aspx.cs`, `catalog-item.js`, `AdminDataRepository.cs`):**
  - Resolved specification persistence issue where technical specifications were not saved when editing or creating helmet models.
  - Hardened `SaveProductAsync` in `CatalogItem.aspx.cs` to prioritize `Request.Form` raw postback values (`ctl00$MainContent$hdnSpecificationsJson`, `hdnSpecificationsJson`, `hdnSpecificationsJson.UniqueID`) over control state, preventing dropped client-side updates.
  - Made specification saving call `_adminRepo.SaveProductSpecificationsAsync(productId, specsJson ?? "[]")` unconditionally so clearing specifications correctly removes them in the database rather than skipping execution.
  - Applied the same authoritative `Request.Form` extraction to `colorsJson`, `variantsJson`, and `galleryJson`.
  - Updated `addCustomSpecRow` and `serializeSpecifications` in `catalog-item.js` to preserve existing database keys (e.g. `helmet_type`, `visible_finish`, `visor_style`) via `data-spec-key` on custom rows without mangling or regenerating slugs.
  - Rebuilt solution with MSBuild to ensure the updated DLL is active in IIS Express.
- **SQL Stored Procedure Hardening (`39_robust_product_specifications.sql`):**
  - Updated `dbo.sp_AdminSaveProductSpecifications` to support multiple JSON property casings (`key`, `SpecificationKey`, `specificationKey`, `name`, `DisplayName`, `displayName`, `value`, `SpecificationValue`, `specificationValue`).
  - Added `GROUP BY p.SpecKey` and `GROUP BY d.Id` in `dbo.sp_AdminSaveProductSpecifications` to protect against duplicate key constraint violations and multi-match MERGE errors.
  - Updated `dbo.sp_GetProductSpecifications` to use `LEFT JOIN dbo.CategorySpecifications` so custom and unassigned category specifications are never omitted from storefront product detail rendering.

## [2026-10-03] — Single-Click Variant Active / Inactive Toggling in Catalog Item & Inventory Operations (Migration 39)

- **Single-Click Variant Status in Catalog Item Wizard (`CatalogItem.aspx`, `catalog-item.js`, `CatalogItem.aspx.cs`):**
  - Added dedicated **Status** column to the Variant Pricing & Inventory Matrix table (`#tablePricingMatrix`).
  - Added single-click status toggle button (`.admin-variant-status-btn`) to each row and `.admin-variant-pill-status` to variant pills in Step 3.
  - Clicking the toggle flips between **Active** (emerald green badge with indicator dot) and **Inactive** (muted gray badge) with a single click.
  - Automatically dims inactive variant rows (`.is-row-inactive`) and pills (`.is-inactive`) for instant visual feedback.
  - Updated `ProcessColorsAndVariantsAsync` in `CatalogItem.aspx.cs` to deserialize and pass the actual `isActive` boolean value to `dbo.sp_AdminSaveVariant` `@IsActive` rather than hardcoding to `true`.
  - Updated review summary to report both active and total SKU count (e.g. `12/15 Active SKUs`).
- **Single-Click Variant Active Toggling in Inventory Operations Table (`Inventory.aspx`, `Inventory.aspx.cs`, `inventory.js`):**
  - Updated the Admin Inventory Operations table (`rptInventory`) to include a dedicated **Status** column alongside **Stock Status** (In Stock / Low Stock / Out of Stock).
  - Wired single-click `.js-toggle-inventory-active` buttons with optimistic UI updates and immediate server confirmation.
  - Added segmented filter tabs for **Active** and **Inactive** variants alongside **All**, **In Stock**, **Low Stock**, and **Out of Stock**.
  - Built Web API endpoint `POST /api/v1/admin/inventory/variants/{id}/toggle-active` with SignalR `variantStatusChanged` real-time broadcast and page WebMethod `ToggleVariantStatus` fallback.
  - Updated `StaffAuthorizeAttribute` to support session token authentication via `hc_auth_token` cookie for seamless browser fetch calls.
- **Database Schema Migration 39 (`39_inventory_variant_active_toggle.sql`):**
  - Updated `dbo.sp_AdminInventoryVariants` to project `v.IsActive` and query across all variants of non-deleted products rather than hiding inactive variants.
  - Added support for `@StockStatus = 'active'` and `@StockStatus = 'inactive'` in `dbo.sp_AdminInventoryVariants`.
  - Created `dbo.sp_AdminToggleVariantActive` for atomic, race-condition-free toggling of variant `IsActive` using `UPDLOCK, ROWLOCK`.

## [2026-10-03] — Published Active/Inactive Segments, Unpublished Draft Lifecycle, Minimalist Placeholder Image, & Product Edit Deserialization Fix (Migration 38)

- **Published Active / Inactive Action (`CatalogItem.aspx`, `catalog-item.js`, `admin.css`):**
  - Added an `.admin-status-toggle-pill` segmented control directly to the left of the "Discard Changes" button in the sticky top action header when an item is **Published**.
  - Provides instant switching between **Active** (with green indicator dot) and **Inactive** (with red/amber indicator dot) without altering publication status.
  - Linked with client-side state (`hdnIsActive`) and form dirty tracking, preserving the operational active status upon saving changes.
  - Added dedicated Unpublish action (`btnUnpublish`) for published items to transition them back to Unpublished state.
- **Dedicated Publication Filter Tabs & Status Badges (`Catalog.aspx`, `Catalog.aspx.cs`):**
  - Expanded catalog filter tabs into 4 explicit, distinct categories:
    1. **All Products** (`all`)
    2. **Published Active** (`published_active`): Products where `PublicationStatus = 'Published' AND IsActive = 1`.
    3. **Published Inactive** (`published_inactive`): Products where `PublicationStatus = 'Published' AND IsActive = 0`.
    4. **Draft Unpublished** (`unpublished`): Products where `PublicationStatus = 'Unpublished' OR PublicationStatus = 'Draft'`.
  - Added dedicated CSS badge classes (`.admin-badge--published-active`, `.admin-badge--published-inactive`, `.admin-badge--draft`) with distinctive background, text, and border styling.
- **Product Edit Deserialization & Query Column Alignment Fix:**
  - Resolved `IndexOutOfRangeException` errors on `ColorType`, `VariantId`, `Color`, and `ColorHex` that previously occurred when loading product details via `dbo.sp_AdminGetProductComplete`.
  - Updated `dbo.sp_AdminGetProductComplete` (Result 3 and Result 4) to project `ColorType`, `GradientAngle`, `VariantId`, `Color`, and `ColorHex`.
  - Hardened `AdminDataRepository.cs` (`GetProductCompleteAsync`) using `HasColumn()` checks across all mapped collection properties, ensuring existing published and unpublished helmet models load smoothly in Edit mode without falling back to "New Helmet Model".
- **Minimalist Vector Silhouette Placeholder Asset:**
  - Generated and deployed a clean, modern vector graphic illustration of a motorcycle helmet profile on neutral background (`/Content/images/placeholder-helmet.png`), replacing the previous real AGV Pista helmet photograph for items without custom photography.
- **Drafts to Unpublished Migration (Migration 38):**
  - Updated `CK_Products_PublicationStatus` to accept `'Unpublished'` alongside `'Draft'`, `'Published'`, and `'Archived'`.
  - Updated `DF_Products_PublicationStatus` default constraint to `'Unpublished'`.
  - Backfilled existing `'Draft'` products in `dbo.Products` to `'Unpublished'`.
  - Updated `dbo.sp_AdminSaveProduct` to resolve `'Unpublished'` as default when unpublishing.

- **Order Snapshot Immutability & Financial Audit Integrity (Migration 36):**
  - Added order-time snapshot columns (`ProductName`, `SKU`, `ColorName`, `Size`) to `dbo.OrderItems`.
  - Backfilled historical order items with variant, color, and product metadata.
  - Updated `dbo.sp_AddOrderItem` and POS order creation (`dbo.sp_CreatePhysicalSale`) to automatically capture these snapshot values within the transaction at insertion time, preventing subsequent catalog edits from altering past order receipts.
  - Updated `dbo.sp_GetOrderDetails` and `dbo.sp_GetUserOrderDetails` to project snapshot columns with fallback to live variant tables.
- **Dedicated Publication Lifecycle (`PublicationStatus`):**
  - Added `PublicationStatus NVARCHAR(20)` with `CK_Products_PublicationStatus` constraint (`'Draft'`, `'Published'`, `'Archived'`) defaulting to `'Draft'`.
  - Decoupled publication status from `IsActive` (which is now strictly an administrative operational switch).
  - Backfilled active catalog items as `'Published'` and inactive items as `'Draft'`.
  - Updated `dbo.v_VisibleProducts`, storefront queries, `dbo.sp_AdminCatalogProducts`, `dbo.sp_AdminSaveProduct`, and `dbo.sp_AdminGetProductComplete` to respect the publication lifecycle.
  - Enhanced Admin Catalog UI (`Catalog.aspx`) with segmented status badges (Published, Disabled, Draft, Archived).
- **Concurrency & Integrity Hardening:**
  - Resolved `dbo.sp_ConfirmHitPayOrder` reservation calculation so confirmed orders cleanly transition reserved stock without double-subtracting against available quantities.
  - Added filtered unique index `UX_UserAddresses_UserDefault` on `dbo.UserAddresses(UserId)` where `IsDefault = 1`.
  - Added filtered unique index `UX_ReturnRequests_ActiveItem` on `dbo.ReturnRequests(OrderItemId)` where `Status <> 'Rejected' AND Status <> 'Cancelled'`.
  - Added foreign key index `IX_Orders_UserId` on `dbo.Orders(UserId)`.
  - Created sequence `dbo.Seq_RmaNumber` for atomic, race-condition-free RMA number generation in `dbo.sp_CreateReturnRequest`.
- **Top Selling Sort Realignment:**
  - Corrected `dbo.sp_GetProductsPaged` and `ProductRepository.cs` (`GetTopSellingAsync`) to sort by actual paid/completed sales volume (`SUM(Quantity)` from `dbo.OrderItems`) rather than review ratings.
- **Contract Phase Drop of Deprecated Fields (Migration 37):**
  - Dropped unused `dbo.ProductDiscounts` table (all scheduled discounts are actively handled on `dbo.Products`).
  - Dropped index `IX_Products_RidingStyle` and default constraints on `IsFeatured` and `RidingStyle`.
  - Updated all views and stored procedures (`dbo.v_VisibleProducts`, `dbo.sp_GetProductsPaged`, `dbo.sp_GetProductById`, `dbo.sp_GetProductBySlug`, `dbo.sp_GetRelatedProducts`, `dbo.sp_AdminCatalogProducts`, `dbo.sp_AdminGetProductComplete`, `dbo.sp_AdminInventoryProducts`, `dbo.sp_AdminGlobalSearch`, `dbo.sp_AdminDeleteProduct`, `dbo.sp_AdminSaveProduct`, `dbo.sp_AdminCreateProductWithVariants`) to remove references to `IsFeatured` and `RidingStyle`.
  - Dropped `IsFeatured` and `RidingStyle` columns from `dbo.Products`.
  - Removed `IsFeatured` and `RidingStyle` properties from C# DTOs (`ProductListDto`, `ProductDetailDto`, `ProductFilterParams`, `AdminCatalogItemDto`, `AdminProductCompleteDto`, `AdminSaveProductDto`, `AdminInventoryItemDto`).
  - Removed `btnTabFeatured` from `Catalog.aspx` and `CatalogItem.aspx`'s `chkIsFeatured`.
  - Updated `Build-MinimalDatabase.ps1` to include Migrations 36 and 37 and regenerated `new_database_minimal.sql`.

- Removed three unreferenced SQL scripts: `queries/clear_orders_and_payments.sql` (blanket destructive reset), `seeds/05_remove_legacy_variant_inventory.sql` (one-off 14-SKU cleanup), and `seeds/07_seed_orders.sql` (fixed-ID sample orders superseded by SKU-based compact setup samples).
- Removed obsolete `Build-ActiveVisibilityMigration.ps1` and `Build-NormalizationMigration.ps1` generators; retained migrations 17 and 24 as ordered upgrade history and updated their comments.
- Preserved canonical procedure sources, numbered migrations, and documented full-catalog seed dependencies. Repeated historical procedure definitions remain necessary for upgrades and are not deleted merely because newer migrations supersede them.
- Included missing migrations 25, 26, 28, 29, 30 and 35 in `Build-MinimalDatabase.ps1`, restoring returns, stock-reservation and current reporting definitions to fresh installations; rebuilt the generated installer.
- Added `database/README.md` and corrected setup/normalization documentation. This cleanup changes repository artifacts only; it does not execute SQL or remove database records or deployed procedures.

## [2026-10-03] — Catalog Draft Image Placeholder Standard, Inventory Single-Page Pagination Hide, & POS Image Rendering Fix

- **Catalog Draft Item Image Placeholder Standard:**
  - **Root Cause:** In `AdminDataRepository.cs` (`SaveProductAsync`), omitting a primary image defaulted `@MainImageUrl` to `"/Content/images/products/helmets/agv/images.jpg"`. In `Catalog.aspx.cs`, `ResolveImageUrl` also defaulted empty image paths to `agv/images.jpg`.
  - **Resolution:**
    - Updated `AdminDataRepository.cs` to insert `DBNull.Value` when `@MainImageUrl` is empty or whitespace.
    - Updated `Catalog.aspx.cs`, `Catalog.aspx`, `catalog.js`, `Inventory.aspx`, `Inventory.aspx.cs`, `Reports.aspx.cs`, and `admin.js` to use the standard placeholder `/Content/images/placeholder-helmet.png`.
    - Added defensive inline `onerror="this.onerror=null;this.src='/Content/images/placeholder-helmet.png';"` attributes across catalog and inventory image tags.
    - Created and executed **Migration 35** ([35_fix_draft_placeholder_images.sql](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/database/schema/35_fix_draft_placeholder_images.sql)) to reset existing draft items with `agv/images.jpg` back to `NULL`.

- **Inventory Single-Page Pagination Auto-Hide (`Inventory.aspx.cs`):**
  - **Root Cause:** In `Inventory.aspx.cs` (`LoadInventoryDataAsync`), `pnlInventoryPagination.Visible` was set to `totalCount > 0`, causing pagination buttons to render even when there was only 1 page.
  - **Resolution:** Updated visibility condition to `pnlInventoryPagination.Visible = totalPages > 1;`, cleanly hiding previous/page/next controls whenever inventory fits on a single page or is filtered down to a single page.

- **POS Product Card Image Rendering & Layout Fix (`pos.js`, `pos.css`, `POS.aspx`):**
  - **Root Cause:** In `pos.js`, `safeImage()` only checked for leading `/` or `https://`, rejecting relative paths or unnormalized URLs and falling back to `agv/images.jpg`. Furthermore, `.pos-product-media-wrap` in `pos.css` lacked an intrinsic aspect-ratio or height, causing lazy-loaded images to collapse before load, and stale module script cache kept older views without images.
  - **Resolution:**
    - Normalized `safeImage()` in `pos.js` to support all standard paths (`~/`, relative, `http://`, `https://`, `data:image/`) with fallback to `/Content/images/placeholder-helmet.png`.
    - Added inline `onerror="this.onerror=null;this.src='/Content/images/placeholder-helmet.png';"` to both POS catalog cards and cart item images.
    - Styled `.pos-product-media-wrap` with `aspect-ratio: 1 / 1;` and `.pos-product-image` with `height: 100%; object-fit: cover;`, ensuring uniform, crisp helmet displays across the grid.
    - Bumped asset versioning query parameters in `POS.aspx` to `pos.css?v=5` and `pos.js?v=8` to ensure instant browser cache refresh.

## [2026-10-03] — Admin Catalog Draft Item Editing Fix & Process RMA Modal UI Balance Overhaul

- **Admin Catalog Draft Item Editing Fix (Migration 34 / `sp_AdminGetProductComplete`):**
  - **Root Cause:** When attempting to edit a draft helmet model (`IsActive = 0`) from `/Admin/Catalog.aspx`, `CatalogItem.aspx.cs` called `_adminRepo.GetProductCompleteAsync(ProductId)`. The underlying stored procedure `dbo.sp_AdminGetProductComplete` queried `dbo.v_VisibleProducts`, which filters strictly on `IsActive = 1`. Consequently, draft products returned `null`, triggering `Response.Redirect("/Admin/Catalog.aspx?err=not_found")`.
  - **Resolution (Migration 34):** Updated `dbo.sp_AdminGetProductComplete`, `dbo.sp_AdminColors`, and `dbo.sp_AdminVariants` in [34_fix_admin_product_draft_editing.sql](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/database/schema/34_fix_admin_product_draft_editing.sql) to query base tables (`dbo.Products`, `dbo.ProductColors`, `dbo.ProductVariants`, `dbo.Inventories`) directly. Administrators can now seamlessly open, view, edit, configure, and save draft helmet models and inactive variants without triggering "not found".
  - Applied migration 34 with checksum backup verification, updated [Update-LatestSchema.ps1](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/database/setup/Update-LatestSchema.ps1), and updated [Build-MinimalDatabase.ps1](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/database/setup/Build-MinimalDatabase.ps1).

- **Process RMA Request Modal UI Balance & CSS Variable Overhaul (`Returns.aspx`, `returns.js`, `admin.css`):**
  - **Eliminated All Inline Styles:** Stripped out all hardcoded inline styles (`style="..."`, `#fff`, `#e11d48`, `rgba(...)`) from `#admin-rma-modal` in adherence to Rule 5 of `AGENTS.md`.
  - **Balanced 2-Column Bento Overview Card:** Replaced single stacked text lines with a structured `.admin-rma-overview-card` featuring a 2-column grid layout for RMA reference, customer details, claimed gear specifications, and a cleanly bordered quotation blockquote for customer-provided reasons.
  - **Balanced Operational Decision Grid:** Grouped decision inputs (Status and Resolution Type) into a proportional 2-column CSS Grid (`.admin-rma-form-grid`) with defined `--space-4` gap discipline (Rule 11), followed by a currency-addon settlement input, restock card, and admin feedback textarea.
  - **Design System Token Integration:** All typography, surfaces, borders, paddings, and button pills consume root CSS variables (`--color-surface-card`, `--color-surface-muted`, `--color-border-subtle`, `--space-4`, `--radius-md`, `--btn-pill`).



- **Admin OrderDetail Visual Layout & Architecture Overhaul (`OrderDetail.aspx` & `OrderDetail.aspx.cs`):**
  - **Streamlined 4-Card Status Strip:** Configured the top KPI cards to display:
    1. **Delivery** (Plain text: "Delivery" / "Store Pickup", destination city subtext)
    2. **Payment** (Plain text: "Paid" / "Pending" / "COD Pending", gateway subtext)
    3. **Order Status** (Status badge pill)
    4. **Date** (Formatted order placement date & time)
  - **Structured 2-Column Workspace:**
    - Left column: Detailed ordered items table with product thumbnail, name, color, size badge, SKU, unit price, quantity badge, and line total, followed by Financial Summary and Delivery Instructions/Notes.
    - Right column: Stacked cards for Customer & Contact Information, Delivery & Logistics Details (destination address, shipping region, courier partner, tracking number), Payment Record, and Dispatch Modal.
  - **Zero Inline Styles Compliance:** Replaced all inline styles with semantic CSS classes adhering strictly to the Shop.co / Helmet Cartel design system tokens.

- **Orders Table Simplification (`Orders.aspx` & `Orders.aspx.cs`):**
  - Converted Delivery and Payment table cells to clean, normal text (removing pill badges) for greater scannability.
  - Reduced redundant customer contact columns (email/phone) from the table view, routing deep inspection to `OrderDetail.aspx?id={orderId}`.

- **Storefront Return & Exchange Modal Fix (`Profile.aspx`, `profile.js`, `track-order.js`):**
  - Fixed issue where clicking "Return / Exchange" resulted in no action.
  - Removed conflicting `.is-hidden` CSS class from `#profileRmaModal`.
  - Updated `openRmaModal` to open the modal immediately on click (`is-open` and `modal-open`), preloading order items asynchronously without UI delay.
  - Updated order status eligibility in both `Profile.aspx` and `TrackOrder.aspx` to support both `Completed` and `Delivered` orders.

- **Dashboard Revenue & Order Velocity Timeframe Switcher (`Dashboard.aspx`, `Dashboard.aspx.cs`, `dashboard.js`):**
  - Added interactive timeframe tabs (`Day`, `Week`, `Month`) directly in the chart card header.
  - Created `dbo.sp_AdminSalesHourly` (Migration 30) providing a 24-hour hourly revenue breakdown for today.
  - Pre-calculated and passed `Day`, `Week`, and `Month` velocity datasets into `data-*` attributes, allowing instant client-side switching and animation.

- **Sales Performance Analytics Razor-Sharp Vector Graph & Monochrome Overhaul (`Reports.aspx`, `reports.js`, `admin.css`):**
  - **Complete Elimination of Canvas Blurriness (Native DOM/Vector Graphics):**
    - Replaced the raster `<canvas>` rendering engine with a 100% vector-based HTML/CSS layout.
    - Native OS DirectWrite/FreeType text rendering guarantees crystal-clear, zero-blur text and tick labels on every screen scale (100%, 125%, 150%, 200%, Retina, and 4K displays).
  - **Strictly Top 5 (Removed `topTabs`):**
    - Eliminated the `Top 5 / 10 / 20` segmented tabs limit switcher (`#topTabs`) per requirements.
    - Slices strictly to the **Top 5** ranking entities across all dimensions.
  - **Retained Interactive Dimension & Metric Filters:**
    - **Dimension View:** `Item` (Helmet models), `Brand` (Aggregated brands), and `Category` (Aggregated riding styles).
    - **Metric View:** `Units Sold` (Volume), `Revenue` (`₱` settlement amount), and `Orders` (Transaction count).
  - **Monochrome Black & White Palette (Matching Reference Image):**
    - Top #1 rank rendered in solid deep black (`#18181B`).
    - Subsequent ranks (#2 to #5) rendered in soft neutral monochrome gray (`#E4E4E7`).
    - Values formatted and placed directly adjacent to the tip of each horizontal bar in bold `#18181B`.
    - Subtle vertical dashed grid lines extending upwards from numeric bottom X-axis ticks.
    - Solid vertical Y-axis baseline border with right-aligned product labels.


- **Order Cancellation Bug Fix & Stock Restoration (Migration 29 / `sp_CustomerCancelOrder`):**
  - **Payment Check Constraint:** Fixed `CK_Payments_Status` check constraint on `dbo.Payments` to include `N'Cancelled'`. Previously, cancelling an order threw `500/400 Conflict with CK_Payments_Status`.
  - **Stock Restoration Logic:** In `dbo.sp_CustomerCancelOrder`, if an order was paid (`Status = 'Processing'`), the previously decremented `CurrentStock` is now atomically restored (`inv.CurrentStock + oi.Quantity`), and an audit log with `ChangeType = 'RESTOCK'` is recorded. If unpaid (`PendingPayment`), reserved stock is released.
  - **Payment Status Update:** Payments are marked `Refunded` for completed payments and `Cancelled` for pending payments.

- **Analytics "Completed Orders" Scope Isolation (Migration 29):**
  - Fixed `dbo.sp_AdminSalesReport`, `dbo.sp_AdminSalesDaily`, and `dbo.sp_AdminSalesByBrandAndCategory` to strictly filter by `o.Status IN (N'Completed', N'Delivered')`.
  - Paid orders still in `Processing` (Preparing Order) are no longer counted as "Completed Orders" or final revenue until they are collected or delivered.

- **Activity Feed Encoding & 8-Hour Timezone Discrepancy Fix (`Dashboard.aspx.cs`):**
  - **Character Encoding:** Replaced raw unicode bullet characters with clean `&bull;` in `sp_AdminRecentActivity` and sanitized `â€¢` / `•` in `FormatActivityDetail`.
  - **Timezone Normalization:** Fixed `FormatActivityTime` in `Dashboard.aspx.cs`. UTC database timestamps parsed as `DateTimeKind.Unspecified` were previously misidentified as local time by `.ToUniversalTime()`, subtracting 8 hours a second time and displaying "8h ago" instead of "just now". Explicitly specified `DateTimeKind.Utc` and formatted relative age accurately.

- **Dedicated Admin Order Detail View (`OrderDetail.aspx` & `OrderDetail.aspx.cs`):**
  - Added a "View" action button with eye icon in `Orders.aspx` linking to `OrderDetail.aspx?id={orderId}`.
  - Built comprehensive `OrderDetail.aspx` page showing:
    - Customer details: full name, email, phone number.
    - Delivery details: delivery method (Store Pickup vs. Door-to-Door Delivery), complete destination address, courier partner, tracking number, and delivery notes.
    - Items itemization table: product thumbnail, name, brand, SKU, color, size, unit price, quantity, and line total.
    - Financial summary: items subtotal, delivery fee, discount amount, and total amount.
    - Payment information: gateway / channel and live payment status.
    - Operational state transitions: Dispatch modal (for courier delivery), Mark Ready for Pickup, Mark Collected, Mark Delivered, and Finalize Order.

- **Variant Stock Limits & Out-of-Stock Handling:**
  - **Shop / Product Detail (`product-detail.js` & `storefront.css`):**
    - Size pills for variants with 0 stock are visually struck through and disabled (`.is-out-of-stock`).
    - Attempting to click an out-of-stock size triggers a toast informing the customer the size is unavailable.
    - Quantity stepper max limit is clamped to the selected variant's `availableStock`. "Add to Cart" and "Buy Now" buttons are disabled and labelled "Out of Stock" when inventory is depleted.
  - **Shopping Cart (`Cart.aspx`, `cart.js`, and `site.js`):**
    - Items in cart with 0 available stock display an "Out of Stock" badge (`.cart-item__stock-badge--oos`) and disabled steppers.
    - Checkbox selection for out-of-stock items is disabled and automatically excluded from checkout selection.
  - **Wishlist / Favorites (`favorites.js`):**
    - Products in wishlist where all variants are out of stock display an "Out of Stock" badge on the thumbnail card.
  - **Cart vs. Buy Now Isolation (`checkout.js`):**
    - Regular cart checkout strictly removes checked-out items via type-safe numeric comparison (`Number(c.variantId) === Number(item.variantId)`).
    - Buy Now preserves existing cart items untouched, but automatically refreshes cart item stock against the server in the background so depleted items become visibly disabled.

- **Terminology Standardization ("Delivery" over "Fulfillment"):**
  - Replaced "Fulfillment" with "Delivery" across all customer and admin views (`Cart.aspx`, `Checkout.aspx`, `TrackOrder.aspx`, `Orders.aspx`, `OrderDetail.aspx`, `checkout.js`, `track-order.js`).
  - Standardized labels to "Delivery Method", "Delivery Fee", "Delivery Address", and "Delivery Status & ETA".

- **Profile Active Tab Persistence (`profile.js`):**
  - Updated `switchTab(tabName)` to persist active tab selection in `sessionStorage` and sync the URL query string via `window.history.replaceState`.
  - Upon page reload or navigation, `Profile.aspx` automatically restores the customer's exact active section (Orders, Addresses, Wishlist, Security).

- **System-Wide Status Consistency & Visual Alignment:**
  - **Status Texts:** Standardized order statuses across storefront (`Profile.aspx`, `TrackOrder.aspx`) and admin dashboard (`Orders.aspx`):
    - `Processing`: Uniformly displayed as **"Preparing Order"** for both Store Pickup and Door-to-Door Delivery (replacing inconsistent "Waiting for delivery" and "Processing").
    - `ReadyForPickup`: **"Ready for Pickup"**
    - `Shipped`: **"In Transit"**
    - `Delivered`: **"Delivered"**
    - `Completed`: **"Completed"**
    - `PendingPayment`: **"Pending Payment"**
    - `Cancelled`: **"Cancelled"**
  - **Design & Colors:** Unified pill badge styling, font weight, border-radius, and harmonious color scheme between Admin and Storefront:
    - `Preparing Order` / `Pending Payment`: Warm Amber (`#FEF3C7` bg, `#92400E` text, `#FDE68A` border)
    - `Ready for Pickup` / `In Transit`: Indigo (`#EEF2FF` bg, `#4338CA` text, `#C7D2FE` border)
    - `Delivered` / `Completed`: Soft Emerald (`#ECFDF5` bg, `#047857` text, `#A7F3D0` border)
    - `Cancelled`: Soft Red (`#FEF2F2` bg, `#B91C1C` text, `#FECACA` border)
  - **No Icons on Status:** Removed pulsing dots, icons, and glyphs from all status badges to ensure pure, clean text pills.

- **Admin Orders Action Buttons & Direct Execution (`Orders.aspx.cs`):**
  - Resolved issue where clicking "Mark Ready" popped up a confirmation dialog and failed to execute the status change.
  - Removed intrusive `data-admin-confirm="true"` popups from operational buttons (`Mark Ready`, `Collected`, `Mark Fulfilled`, `Mark Delivered`, `Finalize`).
  - Added postback detection in `Orders.aspx.cs` `Page_Load` for `rptOrders` events, executing `_adminRepo.UpdateOrderStatusAsync(orderId, targetStatus)` and triggering real-time SignalR notifications via `OrderHub`.

- **Recent Activity Feed Human-Readable Single-Log Format (`sp_AdminRecentActivity` / Migration 28):**
  - Consolidated order activities into strictly **1 descriptive log per order** instead of generating a separate cryptic stock log (`... - ONLINE_SALE -1`).
  - Orders format descriptive, human-readable details: e.g. `Placed order for AGV Red Bull Graphic Full-Face Helmet (Orange Red Graphic, L) x1 • Store Pickup • Paid via HitPay (₱32,990.00)`.
  - Filtered out `ONLINE_SALE` and `INSTORE_SALE` from `Stock` audit activity so only staff inventory restocks and adjustments appear under Stock movements.

- **Stock In History Clean Isolation (`Inventory.aspx.cs`):**
  - Excluded sales decrements (`ONLINE_SALE`, `INSTORE_SALE`) from the "Stock In History" tab in Admin Inventory.
  - Ensured "Stock In History" strictly accounts for inward stock additions and manual adjustments, preventing customer purchases from displaying as `+1 unit` stock additions.

- **Analytics / Reports Revenue & Category Breakdown (Migration 27):**
  - Created and verified `dbo.sp_AdminSalesByBrandAndCategory` in `HelmetCartelDB`, enabling accurate breakdown of units sold, revenue, and average unit price by certified brand and helmet category.

- **SignalR WebSocket Back-Forward Cache (bfcache) Resilience (`realtime.js`):**
  - Added `pagehide` and `pageshow` listeners in `realtime.js` to cleanly disconnect SignalR hubs before browser page freezing and reconnect on page restoration, eliminating WebSocket cache drop errors in the browser console.


- **Direct Single-Item "Buy Now" Checkout Architecture:**
  - **Problem Solved:** Previously, clicking "Buy Now" on the Product Detail page (`ProductDetail.aspx`) appended the item to `CartManager` (`localStorage`), incremented the cart badge, and routed to Checkout where all other previously selected items in the user's cart were included in the order.
  - **Single-Item Isolation:**
    - Added dedicated storage key `APP_CONSTANTS.STORAGE_KEYS.BUY_NOW_ITEM: 'hc_buy_now_item'` in `Scripts/constants.js`.
    - Updated `product-detail.js`: "Buy Now" (`#btn-buy-now`) directly packages the selected variant, size, color, quantity, and price into `BUY_NOW_ITEM` storage without calling `CartManager.addItem()` and without modifying the persistent cart or cart badge.
    - Routes directly to `/Pages/Storefront/Checkout/Checkout.aspx?mode=buynow`.
  - **Contextualized Checkout Experience (`Checkout.aspx`, `checkout.js`):**
    - Checkout detects `isBuyNowMode` and calls `getCheckoutItems()`, returning exclusively the single `BUY_NOW_ITEM`. The regular shopping cart is never loaded or mixed into the order.
    - Order summary sidebar, totals, and review item list calculate and render strictly for that single item.
    - Contextualized navigation:
      - Breadcrumb updates from `Home > Cart > Checkout` to `Home > [Product Name] > Checkout`.
      - Step 1 Back button switches from "Back to Cart" to "Back to Product" (`ProductDetail.aspx?id=...`).
      - Step 3 Edit link switches from "Edit Cart" to "Change Options" (`ProductDetail.aspx?id=...`).
    - Order completion clears `BUY_NOW_ITEM` upon success while leaving all items previously in the user's shopping cart completely preserved and untouched.

## [2026-10-02] — Order History Cancel/Return Actions, Real Item Images, HitPay QR Ph Simulation, and Atomic Inventory & COD Fulfillment Standard

- **Storefront Order History Enhancements (`Profile.aspx`, `profile.css`, `profile.js`):**
  - Removed redundant dropdown info strip (`Fulfillment: ...`, `Payment: ...`, `Destination: ...`) from the order card dropdown footer, as destination and delivery status are already tracked in the dedicated Track Order view.
  - Replaced with dynamic, state-aware action buttons in `.order-dropdown-secondary-actions`:
    - **Cancel Order Button:** Conditionally rendered for `PendingPayment` or `Processing` orders prior to dispatch. Triggers `#profileCancelOrderModal`, allowing customers to provide a cancellation reason and confirm.
    - **Return / Exchange Button:** Conditionally rendered for `Delivered` or `Completed` orders. Triggers `#profileRmaModal`, allowing customers to select specific purchased gear, request type (`RETURN` or `EXCHANGE`), reason, and notes.
    - Status hint displayed for in-transit orders or cancelled orders with zero inline styles and strict CSS variable tokens.
- **Order Item & Stacking Deck Image Integrity:**
  - Resolved root cause of identical black placeholder helmet images appearing across order items in profile history:
    - Updated `dbo.Products` image references: Shoei RF-1400 Dedicated Helmet (`/Content/images/products/helmets/shoei/images-2.jpg`) and AGV Pista GP RR Carbon Helmet (`/Content/images/products/helmets/agv/pistagprrgc7.webp`).
    - Added `MainImageUrl` and `ImageUrl` to `OrderItemSummaryDto` and updated `UserRepository.cs` / `dbo.sp_GetUserOrderDetails` to select and map product images to item details.
    - Enhanced `dbo.sp_GetUserOrders` with `PreviewImages` aggregated via `STRING_AGG(p.MainImageUrl, ';')` and populated `PreviewImageList` in `UserOrderSummaryDto`.
    - Updated `createStackingDeckHtml` in `profile.js` to immediately render actual product thumbnails from `previewImageList` upon initial render without waiting for accordion expand.
- **HitPay QR Ph-Only Channel & Minimalist Simulation Modal (`Checkout.aspx`, `checkout.css`, `checkout.js`, `PaymentsController.cs`):**
  - Updated HitPay payment method selection to strictly feature **QR Ph** (`PaymentChannels.QrPh = "QRPH"` in `AppConstants.cs`), removing extraneous GCash and Maya options.
  - Redesigned `#payment-simulation-modal` to a clean, focused dialog strictly showing:
    - Amount to pay (`#sim-order-amount`)
    - Dynamic QR code frame with scanner beam
    - Simulated process controls (`#btn-success-sim` and `#btn-fail-sim`)
    - Modal close button (`#btn-close-sim-modal`)
    - Completely eliminated extraneous timer widgets, app selectors, and merchant information boxes.
- **SQL Server QUOTED_IDENTIFIER ON Recompilation (Migration 26):**
  - **Root Cause:** Encountered `409 Conflict: UPDATE failed because the following SET options have incorrect settings: 'QUOTED_IDENTIFIER'` when calling `dbo.sp_ReserveStockAtomic` during order placement. In MSSQL, tables with indexed views, computed columns, or filtered indexes require `QUOTED_IDENTIFIER ON` at the time stored procedures are created (`sys.sql_modules.uses_quoted_identifier`).
  - **Resolution:** Created `database/schema/26_fix_quoted_identifiers.sql` with explicit `SET ANSI_NULLS ON;` and `SET QUOTED_IDENTIFIER ON;` directives. Recompiled `dbo.sp_ReserveStockAtomic`, `dbo.sp_CustomerCancelOrder`, `dbo.sp_AdminUpdateOrderStatus`, `dbo.sp_CreateReturnRequest`, and `dbo.sp_GetUserOrders`. Verified via `sys.sql_modules` that zero procedures remain with `uses_quoted_identifier = 0`. Verified order creation via `POST /api/v1/orders` now returns `200 OK`.
- **Root Favicon 404 Resolution (`favicon.ico`):**
  - Generated standard binary `favicon.ico` in the application root (`HelmetCartelOrderingAndManagementSys/favicon.ico`) to prevent automatic browser 404 errors.
  - Linked both `<link rel="icon" type="image/x-icon" href="~/favicon.ico" />` and `<link rel="icon" type="image/svg+xml" href="~/Content/images/favicon.svg" />` in `Site.Master` and `Portal.Master`. Verified HTTP 200 OK on `/favicon.ico`.

## [2026-10-02] — Returns & Exchanges (RMA), Reviews Moderation, Interactive Payment Simulation & Storefront CSS Resolution

- **Storefront CSS 404 Resolution:**
  - Resolved `storefront.css` and `checkout.css` 404 errors caused by unresolved ASP.NET Web Forms `~/` tildes rendered literally inside `<asp:Content PlaceHolderID="HeadContent">` blocks across storefront pages (`Checkout.aspx`, `Cart.aspx`, `Favorites.aspx`, `Shop.aspx`, `ProductDetail.aspx`, `Default.aspx`, `TrackOrder.aspx`, `Profile.aspx`).
  - Wrapped page-specific stylesheet links with `<%= ResolveUrl("~/Content/...") %>` and eliminated redundant duplicate `storefront.css` tags. Verified HTTP 200 OK across all storefront assets.
- **Unified Modal System Design Standards:**
  - Standardized `.modal-backdrop`, `.modal-dialog`, `.modal-header`, `.modal-body`, `.modal-footer`, `.modal-alert`, `.modal-close-btn` classes in `Content/css/components.css`.
  - Guaranteed zero inline styles across all dialogs in strict adherence to Rule 5 & Rule 11 of `AGENTS.md`.
- **Interactive Payment Simulation Module:**
  - Created `SimulatePaymentRequestDto` in `Models/DTOs/HitPayDTOs.cs` and added `POST /api/v1/payments/simulate` in `Controllers/Api/PaymentsController.cs`.
  - Implemented interactive checkout payment modal (`#payment-simulation-modal`) in `Checkout.aspx` and `Scripts/storefront/checkout.js` with selectable simulated channels (GCash, Maya, Card, QRPH), testing both successful authorizations (with transactional stock decrement via `ConfirmOnlinePaymentAsync`) and declined simulations (logging failure status in `dbo.Payments` via dedicated stored procedure `dbo.sp_RecordPaymentFailure`).
- **Customer Reviews & Admin Moderation Module:**
  - Added Admin Reviews Moderation API: `GET /api/v1/reviews/admin` and `POST /api/v1/reviews/admin/{id}/toggle-visibility` with stored procedures `dbo.sp_AdminGetReviews` and `dbo.sp_AdminToggleReviewVisibility`.
  - Built responsive Admin Reviews page (`Pages/Admin/Reviews/Reviews.aspx` and `Scripts/admin/reviews.js`) featuring segmented status filter tabs (`All`, `Flagged / Reported`, `Published`, `Hidden`), live search, inspect dialog, and instant hide/unhide toggling.
  - Verified storefront star ratings, report dialog (`#report-review-modal`), and new review submission (`#write-review-modal`) in `ProductDetail.aspx` and `Scripts/storefront/product-detail.js`.
- **Returns & Exchanges (RMA) Module:**
  - **Database Architecture (Migration 25):** Created `dbo.ReturnRequests` table and stored procedures `dbo.sp_CreateReturnRequest`, `dbo.sp_GetCustomerReturnRequests`, `dbo.sp_AdminGetReturnRequests`, and `dbo.sp_AdminProcessReturnRequest`.
  - **Concurrency & ACID Inventory Safety:** Enforced atomic stock restock in `dbo.sp_AdminProcessReturnRequest` with `UPDLOCK, ROWLOCK` on `dbo.Inventories`, recording an audit entry in `dbo.StockAuditLogs` with `ChangeType = 'RETURN'`, serialized with the unique RMA reference number.
  - **Backend Layer:** Created `ReturnRequest.cs`, `ReturnRequestDtos.cs`, `IReturnRepository.cs`, `ReturnRepository.cs`, and `ReturnsController.cs` (`POST /api/v1/returns`, `GET /api/v1/returns/order/{orderId}`, `GET /api/v1/admin/returns`, `POST /api/v1/admin/returns/{id}/process`).
  - **Storefront Tracking & RMA Submission:** Added item-level Return/Exchange triggers and standardized `#customer-rma-modal` to `Pages/Storefront/TrackOrder/TrackOrder.aspx` and `Scripts/storefront/track-order.js` for completed orders.
  - **Admin RMA Management:** Integrated "Returns / RMA" into `Pages/Admin/Portal.master` sidebar; built `Pages/Admin/Returns/Returns.aspx` and `Scripts/admin/returns.js` with status tabs, search debounce, and a comprehensive RMA Decision modal.
- **Verification:**
  - Full project compiled via MSBuild (`0 Warning(s)`, `0 Error(s)`).
  - Runtime end-to-end API and database test verified: created RMA `RMA-202610020001`, processed with restock, verified `dbo.Inventories.CurrentStock` incremented from 14 to 15, and verified `dbo.StockAuditLogs` logged `ChangeType = 'RETURN'`.

## [2026-10-02] — Remove redundant Users.FullName

- Added migration 24 to drop Users.FullName after updating active-only global search to derive the name from FirstName/LastName. Existing DTO FullName result aliases remain compatible. Added a dependency guard, migration-range support in the backed-up upgrade runner, and fresh-setup inclusion.
- Audited table columns and documented normalization boundaries in database/schema/NORMALIZATION.md. Preserve historical transaction/review/payment facts, address-specific recipients, and SQL computed expressions supporting constraints/indexes; repeated values alone do not demonstrate a 3NF violation.
- Applied migration 24 after a new checksum-verified backup. Verified the column is absent, no direct u.FullName references remain, and login/profile/admin users/search/address/dashboard procedures execute successfully.

## [2026-10-02] — Cross-Device Environment Synchronization & IIS Express 500.19 (0x80070003) Resolution

- **Root Cause Identification:** Resolved IIS Express `HTTP Error 500.19 (0x80070003 - Path Not Found)` caused by machine-specific paths committed to Git (`.vs/.../applicationhost.config` pointing to `C:\Users\QCU\...` when pulled on a device with user `Admin`).
- **Immediate Fix Verified:** Corrected `physicalPath` in `.vs/HelmetCartelOrderingAndManagementSys.slnx/config/applicationhost.config` to match the local repository path. Restarted IIS Express and verified runtime `200 OK` on both `http://localhost:61909/` and `https://localhost:44359/`.
- **Permanent Cross-Device Git Hygiene:**
  - Updated `.gitignore` to strictly exclude `.vs/`, `*.user`, `*.suo`, `[Bb]in/`, and `[Oo]bj/`, preventing machine-specific paths and compiled binaries from leaking between devices.
  - Untracked `.vs/`, `bin/`, and `obj/` from git index (`git rm -r --cached`) so pull/push operations across different machines never overwrite local directory paths or lock compiled binaries.
  - Created `Start-DevServer.ps1` helper script that dynamically inspects and auto-syncs `applicationhost.config` to the current local repository folder before starting IIS Express on any workstation.

## [2026-10-02] — Safe upgrade through migration 23

- Hardened migration 22: removed the invented phone-number backfill, validate normalized duplicates, preserve unknown legacy phones using a filtered unique index, and retain FullName as a computed compatibility column. Validate existing name equivalence before conversion.
- Preserve address-specific recipient/contact columns across migrations 22–23; widen existing address phone fields to support the latest procedure contract without narrowing existing values.
- Updated fresh-database generation through migration 23, placing these migrations after legacy sample seeding. Added Update-LatestSchema.ps1 with rollback-only validation, a unique COPY_ONLY/CHECKSUM backup, RESTORE VERIFYONLY, and transactional migration application.
- Applied migrations 18–23 to the configured HelmetCartelDB after verified backup. Build passed; login/profile/orders/payments/addresses/admin/dashboard/multi-brand procedure checks and rollback-only recipient-contact write checks passed. One legacy missing phone remains unknown until the account owner supplies a real number.

## [2026-10-01] — Modular Directory Restructuring, Zero-Inline Script/Style Decoupling & Legacy 301 Routing

- **Zero-Inline JavaScript & CSS Mandate Achieved:**
  - Extracted all inline `<script>` blocks from `Checkout.aspx` (~580 LOC), `Cart.aspx` (~190 LOC), `Favorites.aspx` (~155 LOC), `Orders.aspx`, and `Inventory.aspx` into dedicated external JavaScript ES modules.
  - Eliminated all inline `<style>` and internal styles across `.aspx`, `.ascx`, and `.master` files.
- **Dedicated Modular Folder Structure in `Pages/`:**
  - `Pages/` now strictly contains three functional subdirectories: `Admin/`, `Auth/`, and `Storefront/`:
    - `Pages/Auth/`: Dedicated folder housing `Auth.aspx`, `Auth.aspx.cs`, and `Auth.aspx.designer.cs`.
    - `Pages/Storefront/`: Feature-dedicated folders:
      - `Cart/`: `Cart.aspx`, `Cart.aspx.cs`, `Cart.aspx.designer.cs`
      - `Checkout/`: `Checkout.aspx`, `Checkout.aspx.cs`, `Checkout.aspx.designer.cs`
      - `Favorites/`: `Favorites.aspx`, `Favorites.aspx.cs`
      - `ProductDetail/`: `ProductDetail.aspx`, `ProductDetail.aspx.cs`, `ProductDetail.aspx.designer.cs`
      - `Profile/`: `Profile.aspx`, `Profile.aspx.cs`, `Profile.aspx.designer.cs`
      - `Shop/`: `Shop.aspx`, `Shop.aspx.cs`, `Shop.aspx.designer.cs`, `ProductFilterControl.ascx`, `ProductFilterControl.ascx.cs`, `ProductFilterControl.ascx.designer.cs`
      - `TrackOrder/`: `TrackOrder.aspx`, `TrackOrder.aspx.cs`, `TrackOrder.aspx.designer.cs`
    - `Pages/Admin/`: Moved from root `/Admin` into `Pages/Admin/` with feature subdirectories:
      - `Catalog/`, `CatalogItem/`, `Dashboard/`, `Inventory/`, `Orders/`, `POS/`, `Reports/`, `Users/`, `Reviews/`, `Payments/`, and root `Portal.master`.
- **CSS & JS Architecture Reorganization:**
  - Created `Content/css/storefront/` (`storefront.css`, `checkout.css`, `profile.css`, `auth.css`).
  - Created `Content/css/admin/` (`admin.css`, `pos.css`).
  - Created `Scripts/storefront/` (`checkout.js`, `cart.js`, `favorites.js`, `product-detail.js`, `profile.js`, `storefront.js`, `track-order.js`, `auth.js`).
  - Created `Scripts/admin/` (`admin.js`, `catalog.js`, `catalog-item.js`, `dashboard.js`, `inventory.js`, `orders.js`, `pos.js`, `reports.js`, `search-history.js`, `session.js`).
  - Standardized shared tokens in `Content/css/` (`variables.css`, `reset.css`, `layout.css`, `components.css`) and shared modules in `Scripts/` (`api.js`, `constants.js`, `realtime.js`, `site.js`, `cart.js`, `favorites.js`).
- **Canonical Routing & Backward-Compatible HTTP 301 Redirection:**
  - Added centralized `APP_CONSTANTS.ROUTES` to `Scripts/constants.js` powering all client-side navigation.
  - Implemented `LegacyPageRedirects` in `Global.asax.cs` delivering seamless HTTP 301 Moved Permanently redirects for all old URLs (e.g. `/Pages/Cart.aspx`, `/Pages/Shop.aspx`, `/Admin/Dashboard.aspx`), preserving query strings.
  - Updated admin authorization gate in `Global.asax.cs` to guard `~/Pages/Admin/` and redirect unauthenticated requests to `~/Pages/Auth/Auth.aspx`.
- **MSBuild Compilation & Zero-Regression Verification:**
  - Updated `HelmetCartelOrderingAndManagementSys.csproj` with clean `<Compile>` and `<Content>` entries.
  - MSBuild succeeded with 0 Warnings and 0 Errors.
  - Verified live runtime HTTP 200 responses across all storefront pages and HTTP 301/302 redirects.


- **Checkout State Persistence Across Page Refresh (`Pages/Checkout.aspx`):**
  - Implemented `saveCheckoutState()`, `getStoredCheckoutState()`, and `clearCheckoutState()` using `localStorage` (`hc_checkout_state`).
  - Automatically captures and restores user selections on page reload:
    - Fulfillment selection (`pickup` vs. `delivery`) and dynamic shipping fee calculations.
    - Selected recipient address (`selectedAddressId`), ensuring the chosen address card remains selected after refresh or after returning from editing addresses in profile.
    - Selected payment method card (`hitpay`, `cod`, `cash`).
    - Active checkout step (`1`, `2`, or `3`), with defensive validation ensuring step restoration only occurs if prerequisites are met.
    - Terms and conditions agreement checkbox state.
  - Automatically resets/clears the saved draft state upon successful order placement (`clearCheckoutState`), guaranteeing subsequent checkout sessions start clean.
- **Loading Spinner on Place Order Action (`Pages/Checkout.aspx` & `Content/css/checkout.css`):**
  - Added `.btn-spinner` element inside `#btn-place-order` with rotation keyframe animation (`btnSpinnerAnim`).
  - Added `.btn--loading` state to `#btn-place-order`: displays the rotating spinner, updates copy to `"Processing Transaction..."`, hides the chevron arrow icon, and disables user interaction to prevent duplicate order submissions.
  - Restores default button state and removes `.btn--loading` if validation or network requests fail.

## [2026-10-01] — Resolution of POST /api/v1/orders 500 Internal Server Error & Simulation Mode Refinement

- **HitPay Simulation Stock Double-Deduction Elimination (`Services/OrderService.cs`):**
  - Identified that `dbo.sp_ConfirmHitPayOrder` already executes atomic stock decrements via `UPDLOCK, ROWLOCK` in MSSQL and inserts `dbo.StockAuditLogs`.
  - Removed the redundant secondary call to `_inventoryService.ProcessSaleDeductionAsync` in HitPay Simulation Mode, which previously caused secondary deduction failures ("Insufficient stock") when stock was low or exactly equal to item quantity.
- **Robust Exception Handling & Detailed Error Diagnostics (`Controllers/Api/OrdersController.cs` & `WebApiConfig.cs`):**
  - Wrapped `OrdersController.CreateOnlineOrder` in try-catch to return formatted `ApiResponse<OrderSummaryDto>.Fail(...)` rather than bubbling up unhandled 500 exceptions.
  - Enabled `config.IncludeErrorDetailPolicy = IncludeErrorDetailPolicy.Always;` in `App_Start/WebApiConfig.cs` for clear diagnostics during development.
  - Added `DatabaseError = "DATABASE_ERROR"` constant to `AppConstants.ErrorCodes`.
- **String Length Clamping & Defensive Parameter Mapping (`Repositories/OrderRepository.cs`):**
  - Added defensive string truncation guards for `CustomerName` (max 100), `CustomerEmail` (max 256), `CustomerPhone` (max 30), and `ShippingAddress` (max 300) before binding to `dbo.sp_CreateOrder` parameters, preventing SQL parameter truncation exceptions when customers use extended formatted phone numbers or addresses.
- **Verified Order Creation Endpoint:**
  - Tested `POST /api/v1/orders` with live payload; verified successful order generation (`HC-...`), status `Processing`, payment status `Completed` (HitPay Simulation), and HTTP 200 response with zero errors.

## [2026-10-01] — Address Recipient Persistence Fix, Autocomplete Attributes & C# Backend Audit

- **Database Column Restoration & Stored Procedure Update (`database/schema/23_add_recipient_contact_to_user_addresses.sql`):**
  - Restored `RecipientName NVARCHAR(100)` and `PhoneNumber NVARCHAR(50)` on `dbo.UserAddresses`.
  - Updated `dbo.sp_SaveUserAddress` to accept and persist `@RecipientName` and `@PhoneNumber` (with fallbacks to user account if null/empty).
  - Updated `dbo.sp_GetUserAddresses` to return `RecipientName` and `PhoneNumber`.
  - Resolved SQL error `Procedure sp_SaveUserAddress has too many arguments specified`.
- **C# Repository & Service Layer Resilience (`UserRepository.cs` & `AuthService.cs`):**
  - Updated `AuthService.SaveUserAddressAsync` to validate required fields (`StreetAddress`, `City`, `Province`) while gracefully normalizing optional fields (`Barangay`, `PostalCode`, `AddressLabel`), eliminating false `ArgumentException` errors when optional fields were left blank in the UI.
  - Ensured `UserRepository.SaveUserAddressAsync` and `GetUserAddressesAsync` handle null DB values safely with `reader.IsDBNull`.
- **DOM Autocomplete Attributes (`Pages/Profile.aspx`):**
  - Added `autocomplete="username"` to `#edit-email`, `autocomplete="given-name"` to `#edit-first-name`, `autocomplete="family-name"` to `#edit-last-name`, and `autocomplete="tel"` to `#edit-phone`.
  - Added standard autocomplete attributes (`name`, `tel`, `street-address`, `address-level3`, `address-level2`, `address-level1`, `postal-code`) to `#addressModal` inputs, eliminating browser DOM autocomplete warnings.
- **C# Backend Architecture Verification:**
  - Audited all codebase files and scripts. Confirmed 100% adherence to the C# Backend Mandate:
  - All database access, transactions, and mutations execute exclusively in C# (`Controllers/Api/`, `Services/`, `Repositories/`) via ADO.NET `SqlConnection` and dedicated MSSQL stored procedures (`dbo.sp_...`).
  - No JavaScript is used for backend operations, persistence, or API simulation; client-side scripts in `Scripts/` are strictly limited to DOM events, UI presentation, and standard HTTP `fetch()` requests to the C# Web API 2 endpoints.

## [2026-10-01] — Checkout Streamlining, Recipient Contact on Address & HitPay Simulation Mode

- **Recipient Name & Phone Number Dedicated to Address Entity:**
  - Extended `SaveUserAddressRequestDto` in `Models/DTOs/AuthDTOs.cs` to include `RecipientName` and `PhoneNumber`.
  - Updated `UserRepository.SaveUserAddressAsync` in `Repositories/UserRepository.cs` to bind `@RecipientName` and `@PhoneNumber` to stored procedure `dbo.sp_SaveUserAddress`.
  - Added Recipient Full Name (`#addr-recipient-name`) and Recipient Phone Number (`#addr-phone`) inputs to `#addressModal` in `Pages/Profile.aspx`.
  - Updated `Scripts/profile.js` (`openAddressModal`, `handleAddressFormSubmit`, `renderAddresses`, `setDefaultUserAddress`) to populate, validate, persist, and display recipient name and phone on saved address cards.
- **Customer Contact Details Replaced with Selected Address Component (`Pages/Checkout.aspx`):**
  - Removed all manual contact input fields (`First Name`, `Last Name`, `Email Address`, `Mobile Phone`) from Step 1 in `Pages/Checkout.aspx`.
  - Implemented `.checkout-address-card` component styled with location pin icon, recipient name, phone number, formatted multiline address, and right chevron `>`.
  - Clicking `.checkout-address-card` routes to `/Pages/Profile.aspx?tab=addresses` allowing customers to add, edit, or select addresses with designated recipient details.
  - Sourced order payload customer information (`customerName`, `customerPhone`, `shippingAddress`, `shippingCity`, etc.) directly from the selected profile address.
- **Removed Manual Delivery Destination Form:**
  - Completely removed `#delivery-address-section` (street, barangay, city, province, postal code, delivery notes, save address checkbox) from `Pages/Checkout.aspx`.
  - Selecting "Door-to-Door Courier Delivery" no longer displays a manual address form; the selected address card provides the required destination data and calculates dynamic shipping rates.
- **Shipping Method Copy Polish (Simulation Friendly):**
  - Removed `&bull; Free helmet fitting &amp; visor check` from In-Store Pickup option.
  - Updated Door-to-Door Courier Delivery description to: `Simulated door-to-door courier dispatch via J&T Express, Lalamove, or Grab Express`.
- **Step 3 (Review & Confirm Order) Simplification & Mobile Order Summary Layout:**
  - Removed "Customer & Fulfillment", "Payment Method", and "Total Breakdown" cards from Step 3 in `Pages/Checkout.aspx`.
  - Preserved strictly the Itemized Gear Breakdown (`Order Items`), Terms of Sale agreement checkbox, and Place Order actions in Step 3.
  - Updated `@media (max-width: 992px)` in `Content/css/checkout.css` to use `display: flex; flex-direction: column;` with `.checkout-main { order: 1; }` and `.checkout-sidebar { order: 2; }`, guaranteeing the Order Summary is displayed at the bottom on mobile viewports.
- **HitPay Online Payment Simulation Mode:**
  - Added `<add key="HitPay:SimulationMode" value="true" />` in `Web.config`.
  - Updated `Services/OrderService.cs` in `CreateOnlineOrderAsync` to check `HitPay:SimulationMode`.
  - When `true`, automatically simulates an instant paid transaction: sets payment status to `Completed` and order status to `Processing`, generates simulated gateway reference `SIM-...`, commits inventory stock deduction, broadcasts SignalR updates via `InventoryHub` and `OrderHub`, and displays order confirmation immediately without leaving the site.
  - When `false`, smoothly preserves the complete HitPay API payment request generation pipeline for easy toggle to live/sandbox gateway transactions.

## [2026-10-01] — Profile Layout, Empty Cart Display, Auth Redirect & Mobile Navigation Enhancements

- **Profile Section Headers Desktop Single-Row Layout:**
  - Updated `.profile-section-header` in `Content/css/profile.css` to `display: flex; align-items: center; justify-content: space-between; gap: var(--space-4); width: 100%;` without line-wrapping on desktop (`min-width: 0` on child text container, `flex-shrink: 0` on actions), keeping titles, descriptions, and pill buttons (such as `+ Add New Address` and `Sort by`) aligned on a single row on desktop viewports.
  - Wrapped Tab 1 (`tab-pane-orders`) in `Pages/Profile.aspx` in `.profile-section-card` and `.profile-section-header` with uppercase bold display typography (`ORDER HISTORY`), ensuring consistent visual structure across all profile tabs.
- **Empty Cart State Matching Reference Design:**
  - Redesigned empty cart display across both the slide-out cart drawer (`Scripts/site.js`) and dedicated cart page (`Pages/Cart.aspx`).
  - Implemented 64px circular pill container with shopping cart icon, bold uppercase heading `YOUR CART IS EMPTY`, subtitle copy, and rounded pill button `Explore Catalog ↗` with hover state.
- **Global Profile Navigation & Admin Redirect Consistency:**
  - Implemented `initNavUser()` in `Scripts/site.js` to run universally across every page loaded via `Site.Master`.
  - When an authenticated customer clicks the navbar account button (`#nav-user-btn`), it reliably routes to `/Pages/Profile.aspx` (or `/Admin/Dashboard.aspx` if an admin or staff member).
  - Fixed issue where clicking the profile icon while already on `Profile.aspx` reverted to `Auth.aspx`.
- **Mobile Navigation Drawer Integration & Sidebar Optimization:**
  - Removed deprecated links (`Wishlist & Favorites`, `Shopping Cart`, `Sign In / Register`, `Staff Dashboard`) from the mobile navigation drawer in `Site.Master`.
  - Integrated the profile navigation menu items (`Account details`, `Order history`, `Wishlist`, `Addresses`, `Payment methods`, `Security & Password`, and `Sign Out`) directly into the mobile drawer.
  - Added `@media (max-width: 992px)` and `@media (max-width: 768px)` rules hiding `.profile-sidebar` on mobile view (`display: none !important;`), allowing full-width presentation of content cards while using the mobile navigation drawer.
  - Added smooth client-side tab switching in `profile.js` when tapping mobile drawer tab links.
  - Fixed syntax issue in `Scripts/site.js` (unclosed `renderCartDrawer()` block).
- **Home Product Cards 2-Column Mobile Grid:**
  - Updated `.products-grid` in `Content/css/components.css` and `Content/css/storefront.css` at mobile viewports (`<= 540px` and `<= 35rem`) from `1fr` to `repeat(2, minmax(0, 1fr))` with `gap: var(--space-3)`.
  - Added text clamping and flexible wrapping for titles, ratings, and pricing badges matching `.products-grid-3col` on the shop catalog page.

- **Order Item Cards Mobile Padding Reduction & Single-Line Truncation:**
  - Reduced horizontal and vertical padding across `.profile-container`, `.profile-section-card`, `.order-row-card__header`, `.order-row-card__dropdown`, and `.order-item-detail-row` under `@media (max-width: 768px)`, freeing up over 60px of horizontal space on mobile screens.
  - Added `min-width: 0` to `.order-item-detail-info` and `white-space: nowrap; overflow: hidden; text-overflow: ellipsis;` to `.order-item-detail-title` to enforce strict single-line display with ellipsis truncation on overflow.
  - Added `white-space: nowrap; overflow: hidden; text-overflow: ellipsis;` to `.order-item-detail-specs`, streamlined thumbnail dimensions (46px), and set `white-space: nowrap` on line totals and quantity tags.
  - Added `title` attribute on `.order-item-detail-title` for full product title tooltip in `profile.js`.

## [2026-10-01] — Authentication Gates, Modal Prompts, Checkout Enhancements & Saved Address System

- **Mandatory Authentication Gates & Global Auth Prompt Modal:**
  - Implemented client-side authentication guards across interactive storefront touchpoints: clicking favorite hearts, adding products to the shopping cart, and proceeding to checkout now require user authentication.
  - Added global confirmation modal (`#auth-prompt-modal-overlay` in `Site.Master` & `Content/css/components.css`) offering "Sign In / Register" or "Continue Browsing" options with clean backdrop blur, auto-closing, and return URL redirect tracking.
  - Intercepted unauthenticated actions in `site.js` (cart drawer checkout), `storefront.js` (product card favorite hearts), `product-detail.js` ("Add to Cart", "Favorite", "Buy Now"), and `Pages/Cart.aspx` ("Proceed to Checkout").
- **Saved Delivery Addresses System & Redundancy Removal:**
  - Created `dbo.UserAddresses` table and stored procedures `dbo.sp_GetUserAddresses`, `dbo.sp_SaveUserAddress`, `dbo.sp_DeleteUserAddress` in `database/schema/21_user_addresses_and_checkout_enhancement.sql`.
  - **Phone & Recipient Redundancy Fixed:** Resolved the inconsistency where `Users.PhoneNumber` is optional while address previously demanded a mandatory phone. `UserAddresses.PhoneNumber` and `UserAddresses.RecipientName` are now optional (`NVARCHAR NULL`), automatically falling back to the user's registered account profile name and phone number if left empty.
  - Added "Saved Delivery Addresses" tab to `Pages/Profile.aspx` and `profile.js`: lets customers view saved shipping addresses, add/edit addresses with modal dialog, set default addresses, and delete old addresses.
  - Added address selector (`#saved-address-select`) in `Pages/Checkout.aspx` with one-click auto-fill and "Save this address to my profile" option (`#chk-save-address`).
- **Dynamic Shipping Fee & Checkout Polish:**
  - Removed `#ship-region` dropdown and obsolete `(NCR)` suffix from fulfillment fee display and sidebar.
  - Implemented dynamic shipping fee calculator based on user-entered `City / Municipality` and `Province`. If the location is unlisted/unrecognized, it defaults to **₱175.00** per project requirements (otherwise regional tiers apply: NCR ₱150, GMA ₱250, Luzon ₱350, Visayas ₱450, Mindanao ₱500).
  - Completely removed `Estimated VAT (12% Included)` calculation, markup, and sidebar line items to align with proposal project scope.
  - Redesigned Step 3 (Review & Confirm Order) into structured, modern cards: Customer & Fulfillment Summary, Payment Method, Itemized Gear Breakdown, and Financial Totals.
  - Removed trust badge promotional filler texts (`100% Genuine DOT & ECE Certified Helmets` and `7-Day Hassle-Free Size Replacement Guarantee`).

- **User Profile Page (`Pages/Profile.aspx`):**
  - Designed and developed a full-featured customer account page adhering strictly to the design system in `Content/css/variables.css` matching the Helmet Cartel / Shop.co aesthetic with zero inline styles (`style="..."` prohibited) and balanced grid layouts.
  - Implemented 3 dedicated tabs with seamless switching:
    1. **Order Tracking & History:** Visual 4-step progress stepper (`Pending` &rarr; `Processing` &rarr; `Shipped` &rarr; `Delivered`), order cards with item counts, courier badges (`J&T Express`, `Lalamove`, `Ninja Van`), tracking numbers with one-click copy, and collapsible itemized gear breakdown. Integrated with SignalR `OrderHub` for real-time live status updates without page reload.
    2. **Payment History & Digital Receipts:** Clean transactions table displaying transaction ID, date, method, gateway reference, and status badge (`Completed`, `Pending`, `Failed`). Includes interactive printable digital receipt modal (`#receipt-modal`) with itemized unit pricing, subtotal, shipping fee, total amount (`&#8369;`), and print stylesheet (`@media print`).
    3. **Account & Security:** Inline-validated customer profile update form (First Name, Last Name, Phone Number) and secure password change form with real-time feedback (`.is-invalid` borders and visible `.auth-error-msg` directly beneath input fields).
- **Shop Catalog Price Filter Enhancements (`Pages/Shop/ProductFilterControl.ascx` & `storefront.js`):**
  - Updated price filter labels to contain interactive numerical inputs (`#price-min-input`, `#price-max-input`) with `&#8369;` prefix, allowing riders to type their desired price range directly while preserving the dual-range slider.
  - Synchronized dual slider thumbs, typed inputs, URL query parameters, and instant catalog filtering.
  - Resolved `ReferenceError: minDisplay is not defined` by removing obsolete display element bindings and unifying input handling.
  - Corrected dual slider track styling: set unselected background track (`.dual-range-track-bg`) to light gray (`#E2E8F0`) and configured `::-webkit-slider-runnable-track` to `transparent`, ensuring only the active selected range between handles is rendered in black (`#000000`).
  - Enforced boundary constraints and minimum difference: `min` cannot exceed `max` and `max` cannot fall below `min`, strictly maintaining at least a 1 unit difference (`minGap = 1`) across both slider dragging and direct input typing.
- **Backend Architecture & MSSQL Stored Procedures (`19_user_profile_and_tracking_migration.sql`):**
  - Created and executed stored procedures: `dbo.sp_UpdateUserProfile`, `dbo.sp_ChangeUserPassword`, `dbo.sp_GetUserOrders`, `dbo.sp_GetUserOrderDetails`, and `dbo.sp_GetUserPayments`.
  - Added repository and service methods in `UserRepository`, `AuthService`, and `OrderService`.
  - Added RESTful endpoints in `AuthController` (`PUT /api/v1/auth/profile`, `PUT /api/v1/auth/change-password`, `GET /api/v1/auth/my-orders`, `GET /api/v1/auth/my-payments`, `GET /api/v1/auth/my-orders/{id}`, `GET /api/v1/auth/my-orders/by-number/{orderNumber}`) and `OrdersController` (`GET /api/v1/orders/track/{orderNumber}`) with dual JWT authentication (Bearer authorization header and HttpOnly cookie).
  - Verified full compilation with MSBuild (`0 Errors`) and live API tests.

## [2026-09-30] — Login cookie async-context fix

- Capture the HTTP context before asynchronous login/registration and pass it explicitly when issuing the authentication cookie, preventing an absent ambient context from silently skipping the cookie required by admin access.
- Corrected the authentication background to the existing hero.webp asset and added an explicit SVG favicon. Session lifetimes and server-side expiry validation are unchanged.

## [2026-09-30] — Login lifetime and admin session expiry

- Login now sends RememberMe to C#: signed tokens and authentication cookies last 14 days when selected, otherwise one hour (registration defaults to one hour). Lifetimes are centralized in AppConstants.
- Added a server-side guard for all admin ASPX requests, including postbacks, and a shared client expiry timer with focus/tab restoration and API 401 checks. Expired sessions return to Auth.aspx with an expiry message and return URL.
- Added an HttpOnly, SameSite=Lax authentication cookie and a server logout endpoint; admin sign-out clears it and the client token/profile.

## [2026-09-30] — Active-only catalog and inventory visibility

- Added migration 17 with shared active-only read views and 27 updated stored procedures covering catalog, inventory, POS, global/storefront search, product details, reviews, stock activity/history, dashboard totals, and inventory analytics. Draft products and inactive variants remain stored but cannot contribute to these operational lists or totals.
- Preserved historical order/payment records and revenue reporting. No product, variant, stock, or transaction rows were deleted.
- Included the migration in the database setup bundle; added reproducible migration generation and rollback-only visibility regression checks. Applied to local HelmetCartelDB and verified draft/inactive exclusion and dashboard stock totals.

## [2026-09-30] — Full-Page Catalog Editor, Technical Specifications, Dynamic Taxonomies & UI Polish

- **POS Search Dropdown, Storefront Search UI Alignment & Currency Symbol Encoding Fix:**
  - **POS Search Results in Dropdown:** Connected `#adminGlobalSearch` on `/Admin/POS.aspx` to render matching sellable variants into `#adminSearchDropdown` with product thumbnail, title, color • size • SKU subtitle, in-stock badge, effective price, and quick-add button. Clicking an item or pressing Enter immediately adds the variant to the POS sale cart with toast confirmation and updates the totals.
  - **Add Button Style (`Add →`):** Updated the quick-add action in the POS search dropdown to use the light subtle pill button (`.pos-quick-add-btn`) with text `Add &rarr;` matching the user's reference design, with subtle borders, hover background transitions, and active scale animations.
  - **Peso Sign (`₱`) Encoding Resolution:** Fixed corrupted `?` characters appearing in place of the Philippine Peso sign (`₱`) in search results by migrating `dbo.sp_AdminGlobalSearch` in [16_pos_global_search.sql](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/database/schema/16_pos_global_search.sql) to use `NCHAR(8369)` and `NCHAR(8226)` for bullet dots, completely eliminating Windows-1252 codepage truncation. Added sanitization in [AdminDataRepository.cs](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Repositories/AdminDataRepository.cs) to ensure `\u20B1` is strictly preserved.
  - **Storefront Search List Design Alignment:** Redesigned the public storefront search suggestions in [Scripts/site.js](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/site.js) and [Content/css/layout.css](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Content/css/layout.css) to match the admin search dropdown design language, featuring uppercase bold group headers (`MATCHING HELMETS`), rounded thumbnails (`.search-thumb`), semibold product titles, muted brand/category subtitles, pill price badges (`.search-badge`), and clean view-all footer.

- **Request Size Limit Resolution, Server-Side Image Persistence & Empty Preview Integrity:**
  - **Resolved `Maximum request length exceeded` Error:** Configured [Web.config](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Web.config) with `maxRequestLength="51200"` (50MB) and `executionTimeout="300"` under `<httpRuntime>`, and added `<requestLimits maxAllowedContentLength="52428800" />` under `<system.webServer><security><requestFiltering>`, eliminating runtime request length exceptions during image uploads.
  - **Client-Side Image Compression:** Added `optimizeImageFile()` in [catalog-item.js](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/admin/catalog-item.js) to scale images exceeding 1600px width/height and compress to quality 0.85 via canvas before generating data URLs, reducing 5-10MB camera files to ~250KB without visual degradation.
  - **Server-Side Base64 Image Persistence:** Added `SaveBase64ImageIfPresent()` and `ProcessGalleryImagesListAsync()` in [CatalogItem.aspx.cs](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Admin/CatalogItem.aspx.cs). Base64 data URLs in both `txtMainImageUrl` and `hdnGalleryJson` are decoded and saved to physical disk files under `~/Content/images/products/helmets/{brand}/` using [ImageUploadHelper.SaveImageBytes](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Infrastructure/ImageUploadHelper.cs), ensuring only clean web URLs are saved into `dbo.Products.MainImageUrl` and `dbo.ProductGalleryImages.ImageUrl` (`NVARCHAR(500)`).
  - **Zero Initial Image Preview & Null Image Support:** Removed fallback defaulting to `agv/images.jpg` in both `CatalogItem.aspx.cs` and `dbo.sp_AdminSaveProduct` (in [15_catalog_enhancements.sql](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/database/schema/15_catalog_enhancements.sql)). When no images are provided, `MainImageUrl` is cleanly set to `NULL`, Tab 5 displays the empty notice, and Tab 6 review summary displays the `#reviewSummaryThumbEmpty` placeholder. When images ARE inputted, preview tiles in Tab 5 and the review card in Tab 6 render immediately.

- **Catalog Item Draft Status Badges, Drop Indicator & Clean Slate Image Handling:**
  - **Dynamic Draft Status Badge:** Replaced `DRAFT (Unpublished)` with dynamic status indicators in [CatalogItem.aspx](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Admin/CatalogItem.aspx) and [catalog-item.js](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/admin/catalog-item.js): displays `DRAFT (Saved)` if the draft is stored in MSSQL (`ProductId > 0` and `!isDirty`), `DRAFT (Not Saved)` when adding a new item or when unsaved modifications are made, and `PUBLISHED` for active catalog models.
  - **No Initial Image Preview:** Removed automatic syncing of placeholder/primary URLs into the gallery grid on clean-slate loads in `initExistingData()`. The review card in Tab 6 now displays a clean `#reviewSummaryThumbEmpty` placeholder when no images have been uploaded, preventing premature or unexpected image displays.
  - **Fixed Between-Tile Drop Indicator:** Corrected styling on `.admin-upload-drop-indicator` in [admin.css](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Content/css/admin/admin.css) to `position: absolute; z-index: 20; width: 4px;` with active visibility. Updated coordinate calculations and dragover/dragenter event handling on tiles and grid in [catalog-item.js](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/admin/catalog-item.js), smoothly opening space and showing the vertical indicator directly between tiles during drag-and-drop reordering.

- **Unselected Initial Sizes State:**
  - Removed automatic pre-selection of sizes (`S`, `M`, `L`, `XL`, `2XL`) on clean-slate creation in both `initExistingData()` and `resetFormState()` within [catalog-item.js](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/admin/catalog-item.js).
  - All size pills (`XS`, `S`, `M`, `L`, `XL`, `2XL`, `3XL`) start in the unselected, muted outline state (`aria-pressed="false"`, no `.is-active`), allowing administrators to select only the intended sizes for the helmet.

- **Draft Saving Full Persistence & Catalog Table Redirect:**
  - **Redirect to Catalog Table:** Configured draft save in [CatalogItem.aspx.cs](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Admin/CatalogItem.aspx.cs) to redirect to `/Admin/Catalog.aspx?msg=draft_saved` upon completion, returning the administrator directly to the catalog management table with a confirmation toast.
  - **Full Input Reset for New Items:** Enhanced `resetFormState()` in [catalog-item.js](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/admin/catalog-item.js) and clean-slate handling in code-behind to guarantee all inputs, specifications, colors, variants, gallery images, and hidden JSON payloads are completely cleared when adding a new item.
  - **Fixed Specification Deserialization:** Resolved property casing mismatch (`s.SpecificationKey` vs `s.specificationKey`) in `initExistingData()` so technical specifications (both core and custom) are fully restored and visible when opening saved drafts or products.
  - **Upsert-Safe Database Operations:**
    - Updated `dbo.sp_AdminSaveColor` and `dbo.sp_AdminSaveVariant` in `database/schema/15_catalog_enhancements.sql` to auto-resolve existing records by product ID and color/size/SKU when `@Id = 0`, eliminating unique constraint violations on re-saving drafts.
    - Added `dbo.sp_AdminClearProductGallery` and invoked it in `ProcessGalleryImagesAsync` before inserting gallery images, preventing `UQ_ProductGalleryImages_Product_DisplayOrder` constraint collisions.
  - **Catalog Toast Handler:** Added query parameter listener in [catalog.js](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/admin/catalog.js) to display toast notifications for `draft_saved` and `published` states.

- **Header Navigation, Action Icons, Unsaved Modal & Specs Validation:**
  - **Back Icon Button:** Replaced breadcrumb navigation with `.admin-back-btn` circular pill button placed inline with the page title, styled with `border-radius: var(--radius-pill)` and hover shift animation.
  - **Header Action Icons:** Added SVG icons to Discard (trash/delete), Save as Draft (floppy/save), and Publish (checkmark) buttons in `.admin-item-header-actions`, converting save/publish buttons to `<asp:LinkButton>` for clean server postbacks.
  - **Server Alert Banner Removal:** Removed `phServerAlert` / `MainContent_divServerAlert` / `.admin-alert-banner` from [CatalogItem.aspx](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Admin/CatalogItem.aspx), replacing server alert handling with non-intrusive client-side toast notifications (`showAdminToast`).
  - **Unsaved Changes Confirmation Modal:** Implemented `#modalUnsavedChanges` modal triggered on clicking the back button or Discard with unsaved dirty changes, offering "Save as Draft", "Discard & Leave", or "Keep Editing".
  - **Clean Slate Data Reset on Create:** Explicitly cleared all form inputs, specs, colors, variants, and gallery data in both C# code-behind and JS `resetFormState()` on page load and `pageshow` events when creating a new helmet (`ProductId == 0`), preventing stale draft data from persisting when navigating back and clicking "Add" again.
  - **Specification Input Validation:** Added dynamic validation for both predefined core specs and custom specification rows, highlighting incomplete custom label/value pairs with `.is-invalid` and displaying `#errCustomSpecs`.

- **Form Validation, Error Alignment & Image Gallery Drag Polish:**
  - **Required Technical Specifications (Tab 2):** Designated core specifications (Shell Material, Safety Certifications, and Helmet Weight) as required with asterisks (`<span class="admin-required-star">*</span>`), added inline error validation messages (`#errSpecShellMaterial`, `#errSpecSafetyCertifications`, `#errSpecWeight`), and integrated step 2 into `validateStep()` and `handleFormSubmit()`.
  - **Color Error Alignment (Tab 3):** Encapsulated the color creator card inside `.admin-color-creator-column` so `#errColors` renders directly beneath `.admin-color-creator-card` instead of in the left chips column of the CSS grid.
  - **Sizes Inline Error (Tab 3):** Added `<span class="inline-error-msg" id="errSizes">` directly beneath `#sizesSelector` and enforced that at least one size pill must be active when advancing or publishing.
  - **Image Dropzone Required State (Tab 5):** Styled `.admin-dropzone.is-invalid` with red dashed border, light red tint, and red icon/text highlighting when an image has not been uploaded.
  - **Between-Tile Image Insertion & Pill Indicator (Tab 5):** Added base CSS for `.admin-upload-drop-indicator` ensuring it is strictly hidden initially (`display: none; opacity: 0; visibility: hidden;`), styled with `border-radius: var(--radius-pill)`, and placed directly between images during drag while subsequent tiles smoothly shift right (`.is-shifted-right`) instead of swapping tiles.

- **Size Selector Pill Transformation & Color Suggestions Cleanup:**
  - Removed `.admin-color-suggestions-row` from the Colorway Palette section in [CatalogItem.aspx](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Admin/CatalogItem.aspx) and cleaned up corresponding handlers in [catalog-item.js](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/admin/catalog-item.js).
  - Replaced checkbox-based size selector with `.admin-size-pills-row` containing standalone pill buttons (`.admin-size-pill`) for sizes `XS`, `S`, `M`, `L`, `XL`, `2XL`, and `3XL`, completely removing checkboxes.
  - Styled size selector pills to be solid black pill with white text when active (`.admin-size-pill.is-active`), and muted outline with transparent background when inactive, using `var(--radius-pill)`.
  - Wired two-way state synchronization in [catalog-item.js](file:///c:/Users/Admin/source/repos/HelmetCartelOrderingAndManagementSys/HelmetCartelOrderingAndManagementSys/Scripts/admin/catalog-item.js) for `syncVariantsWithColors()`, `updateReviewSummary()`, and `initExistingData()` based on `.admin-size-pill.is-active`.

- **Catalog Item Form Validation & Script Isolation Fixes:**
  - Resolved JavaScript conflict where legacy modal code in `Scripts/admin/admin.js` was interfering with the full-page editor; wrapped legacy modal logic with `if (document.getElementById('addProductModal'))`.
  - Added comprehensive step-by-step inline validation across all 5 entry tabs (`#errBrand`, `#errCategory`, `#errProductName`, `#errDescription`, `#errColors`, `#errVariants`, `#errBasePrice`, `#errGalleryImages`) with `.is-invalid` borders and visible `.inline-error-msg` spans.
  - Implemented automatic forward-navigation guarding in `switchWizardTab`: stepping forward validates all previous steps and focuses the first invalid element before advancing.
  - Implemented full validation on both "Publish Helmet" (all required fields) and "Save as Draft" (minimum product name & brand).
  - Ensured all styles strictly utilize `var(--radius-pill)` per design system standards (eliminating `var(--radius-pill)`).
- **Discount & Toggles UI Refinements:**
  - Standardized the Promotional Discount input into a joined group (`.admin-input-joined`) with retail amount on the left and unit dropdown (`%` or `₱`) on the right; completely removed "Discount Scheme".
  - Standardized segmented pill toggles (`.admin-segmented-pill` with `.admin-pill-segment.is-active`) for Discount Campaign Status (`ACTIVE` / `INACTIVE`) and Color Finish Type (`SOLID` / `GRADIENT`).
- **Predefined Shade-Based Color Names:**
  - Added motorcycle shade library and RGB/HSL distance detector to automatically prefill and suggest colorway names (e.g., Matte Black, Pearl White, Racing Red, Yamaha Blue, Hi-Vis Yellow, Nardo Gray, Kawasaki Green, etc.) whenever a hex is picked or typed.
  - Added quick predefined shade pill buttons in the Color Palette section for one-click colorway creation.
- **Smooth Drag-and-Drop Image Gallery & Media Section Clean-Up:**
  - Cleaned up Tab 5 markup by removing manual URL text boxes, file size hints, and secondary angle labels, replacing them with a modern drag-and-drop file dropzone and reorderable gallery tiles grid.
  - Implemented smooth between-tile insertion indicator (`.admin-upload-drop-indicator`) that shifts tiles dynamically without swapping, automatically designating the first tile as Primary and synchronizing with the hidden `txtMainImageUrl`.

- **Full-Page Catalog Editor (`/Admin/CatalogItem.aspx`):**
  - Converted product creation and editing from the 5-tab modal in `Admin/Catalog.aspx` into a dedicated full-page editor with sticky header, breadcrumbs, status pill (`DRAFT` / `PUBLISHED`), "Discard Changes" (with dirty-form guard), "Save as Draft" (`IsActive = 0`), and "Publish Helmet" (`IsActive = 1`).
  - Removed `#addProductModal` (340+ lines of obsolete markup) and wired "Add Helmet Model" and table row "Edit" actions to navigate directly to `/Admin/CatalogItem.aspx` and `/Admin/CatalogItem.aspx?id=...`.
- **Riding Style Removal & Storefront Clean-up:**
  - Completely removed Riding Style from the admin interface and stored procedure `dbo.sp_AdminSaveProduct` (now optional, falling back to Category name or `'Standard'`).
  - Replaced mega-menu and mobile navigation "Riding Styles" in `Site.Master` with "Popular Finishes" (`Matte Black`, `Pearl White`, `Racing Red`, `Graphic Editions`).
  - Cleaned Bento box cards in `Default.aspx` by removing the redundant `ridingStyle` query parameter.
- **Dynamic Taxonomies (Brands & Categories):**
  - Added on-the-fly creation for Brands and Categories via quick popover modals (`#modalQuickBrand`, `#modalQuickCategory`) connecting to C# Web API endpoints (`/api/v1/admin/catalog/brands` and `categories`), automatically appending and selecting new entries without page reloads.
- **Structured Technical Specifications:**
  - Implemented 9 core rider specifications (Shell Material, Safety Certifications, Weight, Retention System, Visor, Pinlock, Ventilation, Interior Liner, Intercom) with dynamic custom specification rows.
  - Implemented `dbo.sp_AdminSaveProductSpecifications` for atomic JSON batch upserting and `dbo.sp_AdminGetProductComplete` for comprehensive multi-table product retrieval.
- **Discount & Finish Type UI Enhancements (Screenshots 1 & 2):**
  - Implemented joined input group (`.admin-input-joined`) matching Screenshot 1 (amount on left, unit select `[% / ₱]` on right).
  - Implemented segmented pill toggles (`.admin-segmented-pill`) matching Screenshot 2 (pill track with active floating white thumb) for Discount Status (`ACTIVE` / `INACTIVE`) and Color Finish Type (`SOLID` / `GRADIENT`).
  - Removed background from `.admin-color-creator-card` (now transparent border treatment).
- **Smooth Drag-and-Drop Image Gallery:**
  - Implemented smooth image reordering with a between-tile insertion indicator line (`.admin-upload-drop-indicator`) instead of swapping/replacing tiles.
- **Wizard Tabination & Design System Harmonization:**
  - Preserved the established 6-step tabbed wizard workflow ("tabination") with numbered step tabs across the top (`1. Basic Info`, `2. Specifications`, `3. Variants & Stock`, `4. Pricing & Discount`, `5. Images & Upload`, `6. Review`), with smooth sequential navigation and backward/forward footers.
  - Enclosed the entire editor in the standard `.admin-card-container.admin-wizard-page` card container, eliminating nested inner section cards and inconsistent classes to keep the exact visual design of the admin design system.
  - Harmonized form controls to the standard `.admin-form-group`, `.admin-form-label`, `.admin-form-input`, `.admin-form-select`, `.admin-form-textarea`, and `.admin-matrix-input`.
  - Zero inline styles: all styles use semantic classes and CSS custom properties matching `AGENTS.md`.

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

## [2026-10-01] — Storefront markup migration to asp:HyperLink server controls

- Replaced all `<a href="<%= ResolveUrl(...) %>">` anchor tags across the entire storefront codebase with `<asp:HyperLink runat="server" NavigateUrl="~/..." CssClass="...">` controls.
- Eliminated Visual Studio design-time markup parser errors ("The server tag is not well formed") across all pages:
  - `Site.Master`: Top announcement bar, brand logo, mega-menu trigger, header action buttons (`navCartBtn`, `navUserBtn`), category/brand/color mega-menu links, spotlight featured card, CTA banner links, footer links, mobile drawer links, sliding cart drawer checkout link, and auth modal sign-in button.
  - `Default.aspx`: Hero action button, brand ticker item links, top-selling section action buttons, and bento riding-style cards.
  - `Pages/Storefront/Shop/Shop.aspx`: Breadcrumbs and catalog product card links.
  - `Pages/Storefront/ProductDetail/ProductDetail.aspx`: Breadcrumbs and related product card links.
  - `Pages/Storefront/Cart/Cart.aspx`: Breadcrumb links and empty-cart catalog exploration button.
  - `Pages/Storefront/Favorites/Favorites.aspx`: Breadcrumb links.
  - `Pages/Storefront/Checkout/Checkout.aspx`: Breadcrumb links, address selection card, return to cart links, and continue shopping button.
  - `Pages/Storefront/Profile/Profile.aspx`: Breadcrumb links and empty-state order catalog button.
  - `Pages/Storefront/TrackOrder/TrackOrder.aspx`: Breadcrumb links, order view return links, and catalog links.
  - `Pages/Auth/Auth.aspx`: Brand logo and return to storefront link.
- Added designer declarations for server controls in `Site.Master.designer.cs` (`shopMegaTrigger`, `navCartBtn`, `navUserBtn`, `authModalSigninBtn`).
- Updated `Scripts/site.js` and `Scripts/storefront/storefront.js` DOM selectors to seamlessly support both kebab-case and camelCase control IDs.
- Validated via MSBuild (0 errors, 0 warnings) and verified live HTTP 200 responses across all storefront endpoints on IIS Express.

## [2026-10-02] — Brand and category sales reporting

- Added `dbo.sp_AdminSalesByBrandAndCategory` migration 27 to aggregate completed order-line units, distinct orders, revenue, and average unit price by brand and category for the selected reporting period.
- Added brand and category sales breakdown tables to the admin Analytics & Reports page, with top-seller and top-revenue badges and date-range-aware winner summaries.
- Extended CSV export to include sales by brand, sales by category, and the existing brand inventory report.


## [2026-10-02] — Stock reservation lifecycle correction

- Fixed cash-pickup and COD checkout flow so reserved stock is not deducted a second time before payment or fulfillment.
- HitPay confirmation now converts a reservation into a sale once and fulfillment avoids duplicate deductions, including legacy orders with an existing online-sale audit entry.
- Product-detail stock responses now expose `CurrentStock`, `ReservedStock`, and `AvailableStock`; storefront quantity checks use `AvailableStock` to match Admin inventory.
- Migration 31 includes an idempotent repair for legacy pending cash/COD orders that were both reserved and deducted.
