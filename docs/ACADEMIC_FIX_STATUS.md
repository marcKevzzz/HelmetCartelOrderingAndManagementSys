# Academic presentation fixes

Date: 7 October 2026. Baseline: `ACADEMIC_ALIGNMENT_REVIEW.md` and `PROJECT_PROPOSAL.md`.

## Scope and result

The presentation now has corrected customer authorization, shared inventory handling, checkout pricing, fulfillment transitions, manual return/exchange processing, and report calculations. These corrections support the academic demonstration of a real C# and SQL Server system. They do not establish that every production objective or every product specification has been independently verified.

Per the user's instruction, live HitPay integration, payment simulation handlers, configuration, and demonstration catalog/review data were left unchanged. Earlier uncommitted changes were preserved.

## Finding status

| Review finding | Correction or presentation boundary |
| --- | --- |
| 1–2: Returns/reviews administration and customer ownership | Administrative routes require Staff/Admin as appropriate. Customer return/review identity comes from the validated account. Tracking, return queries, and cancellation enforce ownership; anonymous cancellation is rejected. |
| 3: Paid-order reservation corruption | Migration 51 identifies committed stock by the order's sale audit. Paid fulfillment preserves other reservations; paid cancellation restores only physical units. Completed payment history is retained. |
| 4: Client shipping fees and invalid combinations | C# validates customer/address inputs and computes province-based fees. Cash is pickup-only; COD is delivery-only; POS card is excluded from online checkout. Client fees/region are overwritten before voucher calculation. Frontend estimates follow province rather than city-name substring matches. |
| 5: Customer real-time tracking | A customer hub joins only a server-selected authenticated account group. Status changes refresh profile/track data. Web Forms buttons and API changes publish stock and order notifications. End-to-end two-browser event delivery still requires a manual walkthrough. |
| 6: HitPay and electronic simulations | Excluded by user. No claim of live gateway validation. |
| 7: Abandoned reservations | The presentation uses explicit customer/staff cancellation to release reservations. The existing cancellation trigger releases voucher usage atomically. No background expiration worker was added; cancel unused pending orders before repeating the demonstration. |
| 8: Stock broadcasts/audits/alerts | Cash/POS fulfillment, cancellation, and returns/exchanges use sale/restock audit evidence and publish updates after commit. Low-stock alerts are refreshed for order and replacement variants. Gateway simulation handlers remain unchanged. |
| 9: Return and exchange accounting | Approval and receipt do not restock or count as completed refunds. Completion requires manual refund/handover notes. Refunds are bounded by the discounted item amount. Equal-price replacements deduct available stock and write an audit. Store credit and price-difference settlement are unsupported. |
| 10: Fulfillment | Pickup and delivery transitions are enforced in SQL. Dispatch requires courier/tracking. Cash pickup settles at completion; COD collection is staff-confirmed at delivery/completion. |
| 11: Installer mismatch | Fresh installer includes structural migrations through 52. Optional destructive demo migration 47 is skipped. Upgrade ranges must be explicit; backups are verified before applying changes. |
| 12: Content | Homepage certification/testing claim removed, order metric renamed accurately, unavailable metrics no longer use invented counts. Return/exchange labels distinguish processing from staff-recorded completion. Demo testimonials and model specifications were excluded and remain samples, not study evidence. Shipping rates are academic assumptions. |
| 13: Standards and architecture | Static page inline styles moved into CSS classes; checkout shows inline order/terms errors. New statuses/events and shipping fees use shared constants where added. Architecture documentation now describes custom JWT attributes, Web Forms, account-scoped events, and actual stock/payment timing. Existing mixed repository/service layering and legacy literals remain; no broad architectural rewrite was performed. |

## Verification

- Visual Studio MSBuild Debug build: passed.
- Fresh installer into a uniquely named disposable database: passed.
- `database/setup/Test-BusinessIntegrity.ps1`: passed. Covers paid fulfillment/cancellation reservation isolation, ownership rejection, cash sale audit, pickup/shipping rejection, discount/refund report consistency, manual return receipt/restocking, replacement handover and available stock, staff-only processing, invalid refund/transition rejection, competing last-unit reservations, and actual C# report/return data-reader contracts.
- `database/setup/Test-CheckoutPolicy.ps1`: passed against the compiled C# policy. Covers all shipping tiers, province/city ambiguity, fee overrides, and unsupported checkout combinations.
- `database/setup/Test-Vouchers.ps1`: passed against the generated installer. Covers voucher limits, pricing, rollback, repository paths, and concurrent redemption.
- `node --test tests/receipt.test.mjs`: passed. Modified JavaScript syntax checks passed.
- Live guest requests to return/review administration, customer tracking/return lookup, cancellation, and processing routes returned HTTP 401.
- Homepage, shop, product detail, checkout, tracking, and authentication pages returned HTTP 200 in IIS Express.
- Migrations 51–52 passed a transactional dry run and were applied to local `HelmetCartelDB`. A `COPY_ONLY` backup passed `RESTORE VERIFYONLY` before the update. No catalog/order/review reset was performed.

The browser automation runtime exited unexpectedly, so a visual and interactive browser walkthrough was not completed. Page HTTP responses confirm server compilation, not responsive layout or interactive behavior. Before presenting, check an authenticated cash-pickup order, a delivery order with tracking, a manual return, and an equal-price exchange; keep a second signed-in customer tab open to verify live status refresh.

## Presentation wording

Describe this as an academic prototype with real database transactions, account authorization, inventory synchronization, manual fulfillment, and demonstrated reporting. Explain electronic payments and seeded testimonials as simulations/samples. Do not claim deployed gateway processing, automatic refund settlement, courier integration, manufacturer certification validation, email/SMS delivery, or automatic reservation expiry.
