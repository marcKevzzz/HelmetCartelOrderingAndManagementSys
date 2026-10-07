# Academic proposal alignment review

Review date: 7 October 2026

**Correction update:** The findings below record the original review. Presentation-scope corrections were subsequently implemented at the user's request, excluding HitPay and simulations. Read `ACADEMIC_FIX_STATUS.md` for current verification, database application, and remaining limitations; the original verdict and failed connection attempt below are historical.

## Verdict and review boundary

The implementation substantially matches the proposed system's feature scope, but it does not yet justify a claim that every objective works correctly. It is a credible academic prototype with real C# and SQL implementations. The main remaining gaps affect inventory accuracy, customer authorization, real-time customer tracking, payment integration, and the truthfulness of displayed content.

The baseline is `docs/PROJECT_PROPOSAL.md`, supplemented by the supplied AGENTS.md, repository rules, and workflows. This review covers the current working tree, including pre-existing uncommitted changes. No application fixes or database mutations were made. A successful build is not proof that a business workflow succeeds.

Verification completed:

- Debug build of the ASP.NET project using installed Visual Studio MSBuild: passed.
- `node --test tests/receipt.test.mjs`: passed. Its assertions cover receipt calculations, voucher snapshots, payment labels, escaping, UTC dates, and cash/change formatting. This is not an integration test of payments or inventory.
- Source inspection of controllers, services, repositories, relevant later SQL migrations, frontend listeners, proposal, setup documentation, and seed content.
- A read-only connection to the configured SQL database failed with `Failed to generate SSPI context.` Therefore, installed procedure versions, real database records, runtime transactions, and concurrent purchases remain unverified.
- No browser walkthrough was performed. Responsive layout, accessibility, and actual print pagination remain unverified.

## Proposal traceability

| Proposal requirement | Implementation evidence | Assessment |
| --- | --- | --- |
| Public catalog and purchasing | Default.aspx, Shop and ProductDetail pages, ProductsController, checkout.js, OrdersController | Present. Product previews link to detail pages. Checkout integrity needs the fixes below. |
| Central inventory for online and in-store sales | InventoryRepository, OrderRepository, OrderService, POS page, stock stored procedures | Present. Online checkout reserves stock; POS completes a sale. Shared reservation handling has a correctness defect. |
| Staff order fulfillment | Admin/Orders pages, AdminController, sp_AdminUpdateOrderStatus | Present. Pickup and delivery transitions exist. Payment and shipping compatibility is insufficiently enforced. |
| Vouchers and recalculation | VoucherService, VoucherRepository, VouchersController, migrations 40/45/48 | Present. Server-side pricing and transactional voucher application are useful strengths. Abandoned orders can retain reservations and voucher usage. |
| Customer profile, history, receipts | AuthService/UserRepository, Profile page, receipt.js, TrackOrder page | Present. Live order-status delivery is disconnected. Public tracking exposes full order details. |
| Low-stock alerts and restocking reports | InventoryHub, InventoryService, admin inventory/report pages, reporting procedures | Present. Not every stock-changing flow broadcasts updates or produces consistent audit/alert evidence. |
| Staff/admin and customer roles | StaffAuthorize, StaffHubAuthorize, JWT provider, admin page gates | Partially implemented. Returns and separate review administration omit required checks. |
| Integrated payment options | HitPayService, PaymentsController, cash/COD/POS support | Cash/POS logic exists; configured electronic flow is simulation. Current HitPay webhook contract differs from the implementation. |
| Scope exclusions | No observed courier API, full accounting subsystem, loyalty program, or marketing automation | Broadly respected. Manual courier/tracking fields fit basic tracking. Returns, exchanges, reviews, and favorites are supporting extensions that should be acknowledged in the manuscript. |

Reports and catalog management are Admin-only in the API. The proposal describes staff managing listings and generating reports. This is acceptable if “staff/admin” includes the owner/admin role, but the manuscript needs an explicit permissions matrix. Do not claim an ordinary Staff account can perform Admin-only tasks.

## Prioritized findings

P1 means a core correctness or authorization defect that should be fixed before final acceptance. P2 means a material process, content, or maintainability gap. Findings are based on source paths; runtime exploitation was not attempted.

### 1. P1 — Returns and review administration are publicly callable

Evidence: `HelmetCartelOrderingAndManagementSys/Controllers/Api/ReturnsController.cs:93` and `:101`; `Controllers/Api/ReviewsController.cs:108` and `:116`; `App_Start/WebApiConfig.cs`; `Global.asax.cs`.

The returns controller exposes admin listing and processing routes without StaffAuthorize. The separate reviews controller exposes admin listing and visibility changes without an admin restriction. There is no global API authorization filter. The page gate applies to .aspx pages, not these API routes.

An unauthenticated request can reach return processing, which can approve a return and increase stock through `sp_AdminProcessReturnRequest`. Public return queries also accept arbitrary user/order IDs. Review creation preserves a client-supplied UserId instead of always deriving identity from the validated token.

Fix: enforce staff/admin authorization on administrative actions, enforce ownership on customer actions, and derive user IDs from validated authentication. Test direct API access as guest, Customer, Staff, and Admin.

### 2. P1 — Anonymous cancellation bypasses order ownership

Evidence: `Controllers/Api/OrdersController.cs:155`; `database/schema/31_stock_reservation_lifecycle_fix.sql:322`.

CancelOrder accepts a nullable authenticated user. The latest source definition of sp_CustomerCancelOrder rejects a mismatch only when both supplied UserId and order UserId are non-null. A guest supplies no UserId, so the ownership check is skipped. UserEmail is accepted but not used to establish ownership.

An anonymous caller with an integer order ID can cancel a PendingPayment or Processing order. This changes stock, payment records, and another customer's order history.

Fix: require authenticated ownership for account orders. If guest checkout remains supported, require a separate secure guest-order credential. Reject missing identity rather than interpreting it as permission.

### 3. P1 — Paid orders can consume another order's reservation

Evidence: `database/schema/31_stock_reservation_lifecycle_fix.sql:244`, `:254`, `:272`, and `:356`; `database/schema/36_schema_enhancements_and_snapshots.sql:426`.

Payment confirmation already subtracts the paid order's quantity from ReservedStock. Later fulfillment and cancellation still subtract quantity from the same aggregate reservation count whenever enough reserved stock remains. These branches do not consistently condition reservation release on whether the current order still owns a reservation.

Example: start with CurrentStock=3. Orders A and B reserve one unit each. Paying A produces CurrentStock=2 and ReservedStock=1. Completing A from ReadyForPickup subtracts the remaining reservation, producing ReservedStock=0, even though B still needs one unit. The system now exposes two available units when only one should be available. Cancelling paid A has the same reservation ownership problem.

Fix: track reservations by order/item, or make conversion/release explicitly conditional on that order's reservation state. Verify paid fulfillment, paid cancellation, cash fulfillment, and concurrent orders for the same SKU. Row locks alone do not correct ownership arithmetic.

### 4. P1 — Checkout trusts client shipping fees and invalid combinations

Evidence: `Repositories/OrderRepository.cs:113`, `:114`, and `:244`; `Models/DTOs/OrderDtos.cs`; `Scripts/constants.js:83`; `Scripts/storefront/checkout.js:326`.

The browser calculates shipping fees. The repository accepts any nonnegative ShippingFee and includes it in persisted totals. A caller can submit Delivery with ShippingFee=0 without a free-shipping voucher. The DTO has no required-field validation attributes, and online order creation does not enforce a payment/shipping allowlist or a complete delivery address.

Cash plus Delivery illustrates the inconsistency: OrderService treats Cash as a cash order, but the repository records a pending Cash payment only for Pickup. The resulting order can lack the payment record required for settlement reporting.

Fix: calculate shipping fees on the server from validated destination data. Validate required contact/address fields, allowed payment methods, and compatible fulfillment/payment combinations before reserving stock.

### 5. P1 — Customer real-time order tracking has no event delivery path

Evidence: `Hubs/OrderHub.cs:13`; `Scripts/realtime.js:17`; `Scripts/storefront/track-order.js:1221`; `Scripts/storefront/profile.js:2197`.

TrackOrder and Profile listen for a browser orderStatusChanged event. RealtimeManager creates only an inventoryHub proxy; it neither subscribes to orderHub nor dispatches the expected order-status event. OrderHub is restricted to staff, so simply attaching customers to that hub would also be inappropriate.

The pages load order data, but an already-open customer page does not receive staff fulfillment changes through this code. This directly conflicts with the proposal's real-time customer fulfillment objective.

Fix: add authenticated, customer-specific order subscriptions or an authorized refresh mechanism. Keep customer events limited to their own orders. Demonstrate a staff status change while the customer's page remains open.

### 6. P1 — Electronic payment simulation does not prove HitPay integration

Evidence: `Web.config:24`; `Controllers/Api/PaymentsController.cs:44` and `:87`; `Infrastructure/HitPaySignatureValidator.cs:29`; `Services/HitPayService.cs:45` and `:64`.

SimulationMode is enabled. The simulate route accepts an order number without ownership checks and allows success/failure mutations. Its failure procedure updates all payment rows for that order, including completed records: `database/schema/25_rma_returns_and_reviews_moderation.sql:452`. A failure simulation after success can therefore rewrite payment history.

The real gateway service supplies relative callback URLs and returns an invented checkout URL after an unsuccessful gateway request. Its redirect points to `/order-confirmation.html`, for which no page was found. The payment request ID is not persisted by this creation path.

Current HitPay documentation describes registered JSON webhooks, the Hitpay-Signature header, and HMAC over the raw JSON body. It deprecates the per-request webhook parameter. This controller instead reads form fields and an hmac parameter, and hashes reconstructed key=value pairs. It does not implement that documented contract. Source: [HitPay Online Payments](https://docs.hitpayapp.com/apis/guide/online-payments), checked 7 October 2026.

Fix: keep simulation explicitly labeled and restricted to authorized test orders. Never rewrite a completed payment as a failed attempt. For gateway acceptance, use valid callback URLs, persist the request ID, implement the selected documented webhook contract, validate amount/currency/reference, and test signed success, tampering, replay, and late payment. If the academic scope intentionally permits simulation, disclose that limitation instead of claiming completed external integration.

### 7. P2 — Reservations have no automatic abandonment lifecycle

Evidence: `Repositories/OrderRepository.cs:181`; `Services/OrderService.cs:78`; `.agents/workflows/order_fulfillment_workflow.md`; reservation/release procedures and application services inspected.

Online checkout reserves stock before payment. No scheduled expiry/reconciliation path was found to release abandoned PendingPayment orders. Failed payment simulation does not release stock or change the order to a terminal state. Gateway creation failure still returns a fallback URL after the reservation commits.

Stock and voucher redemption capacity can remain held until somebody cancels the order. This is a material gap for the claim that inventory stays accurate without manual reconciliation.

Fix: document and implement reservation expiry, safe release, retry behavior, and handling of a payment arriving after expiry. Test abandoned checkout and failed gateway creation.

### 8. P2 — Several stock changes omit broadcasts, audits, or alert creation

Evidence: `Services/OrderService.cs:83`; `Controllers/Api/AdminController.cs:98` and `:121`; `Controllers/Api/OrdersController.cs:155`; `Controllers/Api/ReturnsController.cs:118`; `database/schema/31_stock_reservation_lifecycle_fix.sql:244`; `database/schema/36_schema_enhancements_and_snapshots.sql:426`.

HitPay/simulation checkout reserves stock without broadcasting availability at order creation. Admin fulfillment, dispatch, customer cancellation, and return processing can change inventory but only broadcast order status or no event. The fulfillment procedure does not write a stock audit for its cash/COD stock decrement. The later payment confirmation definition in migration 36 no longer includes the RestockAlerts insertion present in migration 31.

Database state can change while open storefront and staff views remain stale. Some sale histories and persistent alert records are incomplete even if derived low-stock views remain available.

Fix: route all committed stock changes through consistent audit/alert handling and publish current availability after each relevant transaction. Verify two open clients across reservation, payment, fulfillment, cancellation, and restock.

### 9. P2 — Refund and exchange labels overstate completed business actions

Evidence: `database/schema/31_stock_reservation_lifecycle_fix.sql:348`; `Scripts/storefront/track-order.js:201`; `database/schema/48_fix_profile_vouchers_revenue_and_stepper.sql:263` and `:362`.

Customer cancellation immediately marks completed payment records Refunded without a gateway refund call or separate confirmation. TrackOrder treats Approved returns/exchanges as completed refund/exchange outcomes. Approval is a staff decision, not evidence that money or replacement merchandise was delivered.

Migration 48 defaults RefundAmount to the item total for Approved/Completed requests without distinguishing RETURN from EXCHANGE. Revenue queries subtract both request types. A same-price exchange with no refund can therefore reduce reported revenue as though it were a cash refund.

Fix: separate approval, physical return inspection, replacement fulfillment, refund initiation, and refund confirmation. Deduct only actual refunds. Label manual refunds explicitly and retain staff evidence. Treat exchanges independently from refunds.

### 10. P2 — Fulfillment state transitions ignore pickup versus delivery

Evidence: `database/schema/31_stock_reservation_lifecycle_fix.sql:189`.

The procedure validates old/new status pairs but does not inspect ShippingMethod. Pickup orders can be marked Shipped, while delivery orders can be marked ReadyForPickup. UI choices do not enforce an API/database business rule.

Fix: constrain transitions by fulfillment type and required metadata. Define when cash/COD collection is confirmed and when a sale is considered completed. The proposal says completed sales update inventory; source behavior currently commits prepaid stock at payment and COD stock at dispatch. Document the distinction between reservation, physical stock movement, payment, and fulfillment.

### 11. P2 — Fresh installation omits procedures used by the current application

Evidence: `database/setup/Build-MinimalDatabase.ps1:65`; `database/setup/Update-LatestSchema.ps1:2`; `database/schema/48_database_shopping_state.sql`; `database/schema/49_settled_daily_orders.sql`; `database/schema/50_activity_redirects_and_order_hitpay_ref.sql`.

The fresh installer builder stops at migration 43. Current application code also calls procedures supplied by later migrations, including database shopping state and settled daily orders. The upgrade runner defaults to ending at 41. Documentation still describes the generated schema as current or through 35 in places.

A newly installed evaluation database can build successfully yet fail when current features execute. Migration 47 also uses fixed product, user, and order IDs and deletes existing reviews; it is unsuitable as a general schema upgrade for arbitrary databases.

Fix: separate optional demo content from structural migrations. Maintain one documented fresh-install path through the actual required schema version. Verify installation into an empty disposable database, then smoke-test each module.

### 12. P2 — Seed and storefront content need evidence and honest labels

Evidence: `database/schema/47_realistic_products_specs_and_reviews.sql:295` and `:355`; `Default.aspx:13`; `Default.aspx.cs:100` and `:119`; `Scripts/storefront/track-order.js:201`.

Migration 47 deletes reviews and inserts written testimonials with IsVerifiedPurchase=1 and fixed user/order IDs. These are scripted samples, not collected customer feedback. They must not be presented as study evidence or actual verified purchases. It also assigns safety certifications broadly by product ID/brand/default rather than retaining per-model provenance.

The homepage claims rigorously tested DOT/ECE-certified helmets without evidence in the reviewed repository. “Satisfied Riders” displays completed order count, which does not measure distinct customers or satisfaction; failures fall back to hardcoded counts.

Fix: clearly mark demo testimonials, remove verified badges from fictional data, cite model-specific manufacturer evidence for technical claims, and distinguish assumed academic shipping rates from actual business policies. Rename the order-count metric accurately and show an unavailable state when its query fails. Exact product specifications were not independently validated in this review.

### 13. P2 — Repository standards and architecture documentation are only partially followed

Evidence: `App_Start/Startup.cs:11`; `Default.aspx.cs:87`; `Controllers/Api/AdminController.cs:102`; `Controllers/Api/OrdersController.cs:136`; `App_Start/WebApiConfig.cs:22`; `Pages/Storefront/TrackOrder/TrackOrder.aspx:89`.

The system uses C#, stored-procedure calls, transaction boundaries, and stock locks in important paths. These are good foundations. However:

- OWIN startup maps SignalR only. JWT checks are custom and distributed across attributes/controllers rather than installed bearer middleware as described by repository standards.
- Controllers and code-behind access repositories directly; some business calculations live in repositories. This differs from the mandated controller/service/repository layering.
- Hardcoded status strings, configuration keys, and error codes remain outside centralized constants.
- Static search found 59 matching lines containing inline style attributes across .aspx pages, contrary to the zero-inline-style rule.
- IncludeErrorDetailPolicy.Always and exception-message responses expose internal diagnostics.
- Authentication includes blur validation; this does not establish that every checkout/profile/address input meets the full validation standard.
- Workflow documentation lists PaymentFailed as an order state and email/SMS notifications, while the inspected state constraint excludes PaymentFailed and no corresponding notification service was found.

Fix: prioritize core behavior first, then reconcile architecture documentation with implementation and enforce the project's declared conventions. Do not add email/SMS merely because an outdated workflow mentions it; the proposal's actual scope should govern.

## Academic acceptance demonstration

Record these results after fixes, using synthetic data and two browser sessions:

1. Browse a product, choose a variant, add it from the detail page, and create an online order with correct server-calculated totals.
2. Purchase the final available unit simultaneously through online checkout and POS. Only one allocation succeeds; no negative or unowned reservation occurs.
3. Complete a paid pickup order while a second order reserves the same variant. The second reservation remains intact.
4. Cancel paid and unpaid orders. Verify stock, voucher capacity, payment history, and refund status independently.
5. Exercise cash pickup and COD delivery from creation through collection and completion. Reject incompatible transitions.
6. Reject anonymous return processing, review moderation, cross-customer cancellation, and cross-customer history access.
7. Change fulfillment status as staff while the customer page remains open. Verify the customer's own status updates without exposing another order.
8. Test payment success, failed attempts, duplicate webhook, invalid signature, abandoned payment, and late notification. Distinguish simulated results from gateway sandbox results.
9. Cross-check sales totals against a small known ledger containing a voucher, delivery fee, refund, and same-price exchange. Verify exchange is not counted as a refund.
10. Generate inventory and sales reports, demonstrate low-stock/restock updates, and reproduce setup on an empty database using the submitted instructions.

## Suggested manuscript wording

“The prototype implements an online merchandise storefront, inventory management, in-store merchandise sales recording, order fulfillment, vouchers, customer history, and basic sales and inventory reporting. Electronic payments are currently demonstrated through a simulation; external gateway acceptance and end-to-end concurrent workflow validation remain to be completed.”

After fixing and verifying the findings, replace the limitations with the measured results. Do not claim reduced errors, user satisfaction, performance improvements, or completed integration solely from the existence of screens and code.
