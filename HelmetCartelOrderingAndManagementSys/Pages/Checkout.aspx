<%@ Page Title="Secure Checkout" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Checkout.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.CheckoutPage" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="<%= ResolveUrl("~/Content/css/storefront.css?v=7") %>" />
    <link rel="stylesheet" href="<%= ResolveUrl("~/Content/css/checkout.css?v=2") %>" />
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="container checkout-container">
        <!-- Breadcrumb Navigation -->
        <nav class="shop-breadcrumb" aria-label="Breadcrumb">
            <a href="<%= ResolveUrl("~/Default.aspx") %>" class="shop-breadcrumb__link">Home</a>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2">
                <polyline points="9 18 15 12 9 6"></polyline>
            </svg>
            <a href="<%= ResolveUrl("~/Pages/Cart.aspx") %>" class="shop-breadcrumb__link">Cart</a>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2">
                <polyline points="9 18 15 12 9 6"></polyline>
            </svg>
            <span class="shop-breadcrumb__current" id="breadcrumb-current">Checkout</span>
        </nav>

        <!-- 3-Step Progress Stepper Header -->
        <div class="checkout-stepper" id="checkout-stepper">
            <div class="step-node is-active" id="step-node-1" data-step="1">
                <div class="step-circle" id="step-circle-1">1</div>
                <div class="step-meta">
                    <span class="step-label">Step 1</span>
                    <span class="step-title">Customer &amp; Pickup</span>
                </div>
            </div>
            <div class="step-connector" id="step-connector-1"></div>
            <div class="step-node" id="step-node-2" data-step="2">
                <div class="step-circle" id="step-circle-2">2</div>
                <div class="step-meta">
                    <span class="step-label">Step 2</span>
                    <span class="step-title">Payment</span>
                </div>
            </div>
            <div class="step-connector" id="step-connector-2"></div>
            <div class="step-node" id="step-node-3" data-step="3">
                <div class="step-circle" id="step-circle-3">3</div>
                <div class="step-meta">
                    <span class="step-label">Step 3</span>
                    <span class="step-title">Review</span>
                </div>
            </div>
        </div>

        <!-- Checkout Interactive Grid -->
        <div class="checkout-grid" id="checkout-interactive-grid">
            <!-- Left Main Column: Step Panels -->
            <div class="checkout-main">
                <!-- STEP 1: Customer Contact & Store Pickup -->
                <div class="checkout-panel is-active" id="panel-step-1">
                    <h2 class="checkout-panel__title">Customer &amp; In-Store Pickup Details</h2>
                    <p class="checkout-panel__subtitle">Enter your contact details to reserve your helmet for direct store collection.</p>

                    <div class="form-section">
                        <h3 class="form-section-title">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                                <circle cx="12" cy="7" r="4"></circle>
                            </svg>
                            Customer Contact Details
                        </h3>
                        <div class="form-row">
                            <div class="form-group">
                                <label class="form-label" for="ship-first-name">First Name *</label>
                                <input type="text" class="form-input" id="ship-first-name" placeholder="Juan" required />
                                <span class="inline-error-msg" id="err-ship-first-name"></span>
                            </div>
                            <div class="form-group">
                                <label class="form-label" for="ship-last-name">Last Name *</label>
                                <input type="text" class="form-input" id="ship-last-name" placeholder="Dela Cruz" required />
                                <span class="inline-error-msg" id="err-ship-last-name"></span>
                            </div>
                        </div>
                        <div class="form-row">
                            <div class="form-group">
                                <label class="form-label" for="ship-email">Email Address *</label>
                                <input type="email" class="form-input" id="ship-email" placeholder="juan.delacruz@gmail.com" required />
                                <span class="inline-error-msg" id="err-ship-email"></span>
                            </div>
                            <div class="form-group">
                                <label class="form-label" for="ship-phone">Mobile Phone *</label>
                                <input type="tel" class="form-input" id="ship-phone" placeholder="+63 917 123 4567" required />
                                <span class="inline-error-msg" id="err-ship-phone"></span>
                            </div>
                        </div>
                    </div>

                    <div class="form-section">
                        <h3 class="form-section-title">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                                <circle cx="12" cy="10" r="3"></circle>
                            </svg>
                            Store Collection Location
                        </h3>
                        <div class="shipping-options-list">
                            <div class="shipping-card is-selected" data-shipping-method="pickup" data-shipping-cost="0">
                                <div class="shipping-card__left">
                                    <div class="shipping-card__radio"></div>
                                    <div>
                                        <div class="shipping-card__title">Helmet Cartel Flagship Hub (Quezon City)</div>
                                        <div class="shipping-card__desc">128 Commonwealth Ave, QC &bull; Mon - Sat: 9:00 AM - 7:00 PM &bull; Complimentary helmet fitting &amp; visor check</div>
                                    </div>
                                </div>
                                <div class="shipping-card__price">FREE</div>
                            </div>
                        </div>
                    </div>

                    <div class="checkout-panel-actions">
                        <a href="<%= ResolveUrl("~/Pages/Cart.aspx") %>" class="btn btn--outline">
                            <svg class="shop-breadcrumb__icon icon--back" viewBox="0 0 24 24" fill="none" stroke-width="2">
                                <polyline points="9 18 15 12 9 6"></polyline>
                            </svg>
                            <span>Back to Cart</span>
                        </a>
                        <button type="button" class="btn btn--primary" id="btn-goto-step-2">
                            <span>Continue to Payment</span>
                            <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <line x1="7" y1="17" x2="17" y2="7"></line>
                                <polyline points="7 7 17 7 17 17"></polyline>
                            </svg>
                        </button>
                    </div>
                </div>

                <!-- STEP 2: Payment Method -->
                <div class="checkout-panel" id="panel-step-2">
                    <h2 class="checkout-panel__title">Choose Payment Method</h2>
                    <p class="checkout-panel__subtitle">All payments are encrypted, PCI-DSS compliant, and protected by HitPay escrow security.</p>

                    <div class="payment-methods-grid">
                        <!-- Option 1: HitPay E-Wallets & QR PH -->
                        <div class="payment-method-card is-selected" data-payment="hitpay">
                            <div class="payment-method-header">
                                <div class="payment-method-title-wrap">
                                    <div class="shipping-card__radio"></div>
                                    <div>
                                        <div class="shipping-card__title">HitPay Online Checkout (GCash / Maya / QR PH)</div>
                                        <div class="shipping-card__desc">Instant payment confirmation via Philippine E-Wallets and QR PH</div>
                                    </div>
                                </div>
                                <span class="payment-badge">Recommended</span>
                            </div>
                            <div class="payment-method-details">
                                <p class="shipping-card__desc">You will be securely redirected to the official HitPay gateway to complete your payment via GCash, Maya, ShopeePay, or QR PH.</p>
                                <div class="payment-icons payment-icons--checkout">
                                    <span class="payment-icon-pill">GCash</span>
                                    <span class="payment-icon-pill">Maya</span>
                                    <span class="payment-icon-pill">QR PH</span>
                                    <span class="payment-icon-pill">ShopeePay</span>
                                </div>
                            </div>
                        </div>

                        <!-- Option 2: Credit / Debit Card -->
                        <div class="payment-method-card" data-payment="card">
                            <div class="payment-method-header">
                                <div class="payment-method-title-wrap">
                                    <div class="shipping-card__radio"></div>
                                    <div>
                                        <div class="shipping-card__title">Credit / Debit Card</div>
                                        <div class="shipping-card__desc">Visa, Mastercard, JCB, American Express</div>
                                    </div>
                                </div>
                                <div class="payment-icons">
                                    <span class="payment-icon-pill">VISA</span>
                                    <span class="payment-icon-pill">MC</span>
                                </div>
                            </div>
                            <div class="payment-method-details">
                                <div class="form-row form-row--full">
                                    <div class="form-group">
                                        <label class="form-label" for="card-holder">Name on Card *</label>
                                        <input type="text" class="form-input" id="card-holder" placeholder="Juan Dela Cruz" />
                                        <span class="inline-error-msg" id="err-card-holder"></span>
                                    </div>
                                </div>
                                <div class="form-row form-row--full">
                                    <div class="form-group">
                                        <label class="form-label" for="card-number">Card Number *</label>
                                        <input type="text" class="form-input" id="card-number" placeholder="4111 2222 3333 4444" maxlength="19" />
                                        <span class="inline-error-msg" id="err-card-number"></span>
                                    </div>
                                </div>
                                <div class="form-row">
                                    <div class="form-group">
                                        <label class="form-label" for="card-exp">Expiration (MM/YY) *</label>
                                        <input type="text" class="form-input" id="card-exp" placeholder="MM/YY" maxlength="5" />
                                        <span class="inline-error-msg" id="err-card-exp"></span>
                                    </div>
                                    <div class="form-group">
                                        <label class="form-label" for="card-cvv">CVV / CVC *</label>
                                        <input type="password" class="form-input" id="card-cvv" placeholder="123" maxlength="4" />
                                        <span class="inline-error-msg" id="err-card-cvv"></span>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Option 3: Bank Transfer -->
                        <div class="payment-method-card" data-payment="bank">
                            <div class="payment-method-header">
                                <div class="payment-method-title-wrap">
                                    <div class="shipping-card__radio"></div>
                                    <div>
                                        <div class="shipping-card__title">Direct Bank Transfer / OTC</div>
                                        <div class="shipping-card__desc">BDO, BPI, or UnionBank Online Deposit</div>
                                    </div>
                                </div>
                                <div class="payment-icons">
                                    <span class="payment-icon-pill">BDO</span>
                                    <span class="payment-icon-pill">BPI</span>
                                    <span class="payment-icon-pill">UB</span>
                                </div>
                            </div>
                            <div class="payment-method-details">
                                <p class="shipping-card__desc">Deposit directly into our verified corporate account. Bank details and upload instructions will be emailed with your order confirmation.</p>
                            </div>
                        </div>

                        <!-- Option 4: Cash on In-Store Pickup -->
                        <div class="payment-method-card" data-payment="cash">
                            <div class="payment-method-header">
                                <div class="payment-method-title-wrap">
                                    <div class="shipping-card__radio"></div>
                                    <div>
                                        <div class="shipping-card__title">Cash on In-Store Pickup</div>
                                        <div class="shipping-card__desc">Pay in cash or POS card terminal upon collecting your helmet</div>
                                    </div>
                                </div>
                            </div>
                            <div class="payment-method-details">
                                <p class="shipping-card__desc">Pick up at Helmet Cartel Hub, 108 Katipunan Ave, Quezon City. Present your order confirmation code to staff.</p>
                            </div>
                        </div>
                    </div>

                    <div class="checkout-panel-actions">
                        <button type="button" class="btn btn--outline" id="btn-back-to-step-1">
                            <svg class="shop-breadcrumb__icon icon--back" viewBox="0 0 24 24" fill="none" stroke-width="2">
                                <polyline points="9 18 15 12 9 6"></polyline>
                            </svg>
                            <span>Back to Customer &amp; Pickup</span>
                        </button>
                        <button type="button" class="btn btn--primary" id="btn-goto-step-3">
                            <span>Continue to Review</span>
                            <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <line x1="7" y1="17" x2="17" y2="7"></line>
                                <polyline points="7 7 17 7 17 17"></polyline>
                            </svg>
                        </button>
                    </div>
                </div>

                <!-- STEP 3: Review & Place Order -->
                <div class="checkout-panel" id="panel-step-3">
                    <h2 class="checkout-panel__title">Review &amp; Confirm Order</h2>
                    <p class="checkout-panel__subtitle">Please double-check your customer details and selected gear before placing your order.</p>

                    <!-- Shipping Summary Block -->
                    <div class="review-block">
                        <div class="review-block__header">
                            <span class="review-block__title">Customer &amp; Pickup Hub</span>
                            <span class="review-block__edit" id="btn-edit-shipping">Edit</span>
                        </div>
                        <div class="review-block__content" id="review-shipping-summary">
                            Juan Dela Cruz &bull; +63 917 123 4567<br />
                            <strong>Pickup Hub:</strong> Helmet Cartel Flagship Hub &bull; 128 Commonwealth Ave, QC &bull; FREE
                        </div>
                    </div>

                    <!-- Payment Summary Block -->
                    <div class="review-block">
                        <div class="review-block__header">
                            <span class="review-block__title">Payment Method</span>
                            <span class="review-block__edit" id="btn-edit-payment">Edit</span>
                        </div>
                        <div class="review-block__content" id="review-payment-summary">
                            HitPay Online Checkout (GCash / Maya / QR PH)
                        </div>
                    </div>

                    <!-- Selected Items Summary List -->
                    <div class="review-block">
                        <div class="review-block__header">
                            <span class="review-block__title">Order Items</span>
                            <a href="<%= ResolveUrl("~/Pages/Cart.aspx") %>" class="review-block__edit">Edit Cart</a>
                        </div>
                        <div class="review-items-list" id="review-items-list">
                            <!-- Populated dynamically via JS -->
                        </div>
                    </div>

                    <!-- Policy Checkbox -->
                    <div class="checkout-terms">
                        <input type="checkbox" id="chk-agree-terms" checked />
                        <label for="chk-agree-terms">
                            I confirm that my selected helmet size and specifications are accurate, and I agree to Helmet Cartel's <a href="#">Terms of Sale</a> and Safety Inspection Warranty.
                        </label>
                    </div>

                    <div class="checkout-panel-actions">
                        <button type="button" class="btn btn--outline" id="btn-back-to-step-2">
                            <svg class="shop-breadcrumb__icon icon--back" viewBox="0 0 24 24" fill="none" stroke-width="2">
                                <polyline points="9 18 15 12 9 6"></polyline>
                            </svg>
                            <span>Back to Payment</span>
                        </button>
                        <button type="button" class="btn btn--primary" id="btn-place-order">
                            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2">
                                <rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
                                <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
                            </svg>
                            <span id="btn-place-order-text">Place Order &amp; Pay</span>
                            <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <line x1="7" y1="17" x2="17" y2="7"></line>
                                <polyline points="7 7 17 7 17 17"></polyline>
                            </svg>
                        </button>
                    </div>
                </div>
            </div>

            <!-- Right Column: Sticky Order Summary Sidebar -->
            <aside class="checkout-sidebar">
                <h3 class="checkout-sidebar__title">Order Summary</h3>

                <div class="summary-rows-list">
                    <div class="summary-calc-row">
                        <span>Items Subtotal</span>
                        <span id="sidebar-subtotal">&#8369;0</span>
                    </div>
                    <div class="summary-calc-row">
                        <span>Fulfillment</span>
                        <span id="sidebar-shipping">FREE (In-Store Pickup)</span>
                    </div>
                    <div class="summary-calc-row">
                        <span>Estimated VAT (12% Included)</span>
                        <span id="sidebar-tax">&#8369;0</span>
                    </div>
                </div>

                <hr class="summary-divider" />

                <div class="summary-total-row">
                    <span>Total Amount</span>
                    <span class="summary-total-price" id="sidebar-total">&#8369;0</span>
                </div>

                <!-- Trust Badges -->
                <div class="checkout-trust-badges">
                    <div class="checkout-trust-badge">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#16A34A" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
                        <span>100% Genuine DOT &amp; ECE Certified Helmets</span>
                    </div>
                    <div class="checkout-trust-badge">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#16A34A" stroke-width="2"><polyline points="20 6 9 17 4 12"></polyline></svg>
                        <span>7-Day Hassle-Free Size Replacement Guarantee</span>
                    </div>
                </div>
            </aside>
        </div>

        <!-- STEP 4: Order Confirmation / Success View -->
        <div class="checkout-success-panel" id="checkout-success-panel">
            <div class="success-check-badge">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="20 6 9 17 4 12"></polyline>
                </svg>
            </div>
            <h1 class="success-title">ORDER CONFIRMED!</h1>
            <p class="success-subtitle">Thank you for riding with Helmet Cartel. Your order has been placed and inventory is reserved.</p>

            <!-- Order Receipt Card -->
            <div class="order-receipt-card">
                <div class="receipt-row">
                    <span>Order Reference Number</span>
                    <span class="receipt-number" id="receipt-order-no">#HC-2026-88192</span>
                </div>
                <div class="receipt-row">
                    <span>Transaction Date &amp; Time</span>
                    <span id="receipt-date">September 26, 2026 - 12:30 PM</span>
                </div>
                <div class="receipt-row">
                    <span>Payment Channel</span>
                    <span id="receipt-payment">HitPay (GCash Verified)</span>
                </div>
                <div class="receipt-row">
                    <span>Pickup Location</span>
                    <span id="receipt-address">Helmet Cartel Hub &bull; 128 Commonwealth Ave, QC</span>
                </div>
                <div class="receipt-row">
                    <span>Collection Status</span>
                    <span id="receipt-eta" class="receipt-eta">Ready for Store Pickup in 1-2 Hours</span>
                </div>
                <div class="receipt-row receipt-row--bold">
                    <span>Total Paid</span>
                    <span id="receipt-total">&#8369;34,750</span>
                </div>
            </div>

            <!-- Order Timeline Tracker -->
            <div class="order-tracker">
                <div class="tracker-line"></div>
                <div class="tracker-node is-done">
                    <div class="tracker-icon">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                    </div>
                    <span class="tracker-text">Order Placed</span>
                </div>
                <div class="tracker-node is-active">
                    <div class="tracker-icon">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="3"></circle></svg>
                    </div>
                    <span class="tracker-text">QC &amp; Packing</span>
                </div>
                <div class="tracker-node">
                    <div class="tracker-icon">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="2"></circle></svg>
                    </div>
                    <span class="tracker-text">Ready for Pickup</span>
                </div>
                <div class="tracker-node">
                    <div class="tracker-icon">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                    </div>
                    <span class="tracker-text">Collected</span>
                </div>
            </div>

            <div class="success-actions">
                <button type="button" class="btn btn--outline" onclick="window.print();">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="6 9 6 2 18 2 18 9"></polyline>
                        <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path>
                        <rect x="6" y="14" width="12" height="8"></rect>
                    </svg>
                    <span>Print Receipt</span>
                </button>
                <a href="<%= ResolveUrl("~/Pages/Shop.aspx") %>" class="btn btn--primary">
                    <span>Continue Shopping</span>
                    <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="7" y1="17" x2="17" y2="7"></line>
                        <polyline points="7 7 17 7 17 17"></polyline>
                    </svg>
                </a>
            </div>
        </div>
    </div>

    <!-- Client Script: Step Progression & State Engine -->
    <script type="module">
        import { ApiClient } from '<%= ResolveUrl("~/Scripts/api.js") %>';
        import { CartManager } from '<%= ResolveUrl("~/Scripts/cart.js") %>';
        import { RealtimeManager } from '<%= ResolveUrl("~/Scripts/realtime.js") %>';

        let currentStep = 1;
        let selectedShippingCost = 0;
        let selectedShippingName = "In-Store Pickup (FREE)";
        let selectedPaymentMethod = "HitPay Online Checkout (GCash / Maya / QR PH)";

        // Determine Checkout Items
        function getCheckoutItems() {
            return CartManager.getSelectedItems();
        }

        function calculateTotals() {
            const items = getCheckoutItems();
            const subtotal = items.reduce((sum, i) => sum + (i.price * i.quantity), 0);
            const total = subtotal + selectedShippingCost;
            const estimatedTax = Math.round(subtotal * 0.12);

            return { subtotal, total, estimatedTax };
        }

        function renderSidebar() {
            const items = getCheckoutItems();
            if (items.length === 0 && currentStep < 4) {
                RealtimeManager.showToast('Your cart is empty. Redirecting to Shop...', 'alert');
                setTimeout(() => window.location.href = '<%= ResolveUrl("~/Pages/Shop.aspx") %>', 1500);
                return;
            }

            const { subtotal, total, estimatedTax } = calculateTotals();

            document.getElementById('sidebar-subtotal').innerHTML = `&#8369;${subtotal.toLocaleString()}`;
            document.getElementById('sidebar-shipping').innerHTML = selectedShippingCost === 0 ? 'FREE' : `&#8369;${selectedShippingCost.toLocaleString()}`;
            document.getElementById('sidebar-tax').innerHTML = `&#8369;${estimatedTax.toLocaleString()}`;
            document.getElementById('sidebar-total').innerHTML = `&#8369;${total.toLocaleString()}`;

        }

        function renderReviewItems() {
            const items = getCheckoutItems();
            const container = document.getElementById('review-items-list');
            if (!container) return;

            container.innerHTML = items.map(item => `
                <div class="review-item-row">
                    <img src="${escapeHtml(item.imageUrl)}" alt="${escapeHtml(item.name)}" class="review-item-img" />
                    <div class="review-item-info">
                        <h4 class="review-item-name">${escapeHtml(item.name)}</h4>
                        <div class="review-item-meta">${escapeHtml(item.size)} &bull; ${escapeHtml(item.color)} &bull; Qty: ${Number(item.quantity)}</div>
                    </div>
                    <div class="review-item-price">&#8369;${(Number(item.price) * Number(item.quantity)).toLocaleString()}</div>
                </div>
            `).join('');

            // Also update review summary text blocks
            const firstName = document.getElementById('ship-first-name')?.value.trim() || '';
            const lastName = document.getElementById('ship-last-name')?.value.trim() || '';
            const fullName = `${firstName} ${lastName}`.trim();
            const phone = document.getElementById('ship-phone')?.value.trim() || '';
            const email = document.getElementById('ship-email')?.value.trim() || '';

            document.getElementById('review-shipping-summary').innerHTML = `
                ${escapeHtml(fullName)} &bull; ${escapeHtml(phone)} ${email ? `&bull; ${escapeHtml(email)}` : ''}<br />
                <strong>Pickup Hub:</strong> Helmet Cartel Flagship Hub &bull; 128 Commonwealth Ave, QC &bull; <strong>FREE</strong>
            `;

            document.getElementById('review-payment-summary').innerHTML = escapeHtml(selectedPaymentMethod);
        }

        // Inline Field Error Management
        function setFieldError(fieldId, errorMsg) {
            const input = document.getElementById(fieldId);
            const errSpan = document.getElementById(`err-${fieldId}`);
            if (input) {
                if (errorMsg) {
                    input.classList.add('is-invalid');
                    input.setAttribute('aria-invalid', 'true');
                } else {
                    input.classList.remove('is-invalid');
                    input.removeAttribute('aria-invalid');
                }
            }
            if (errSpan) {
                errSpan.textContent = errorMsg || '';
                errSpan.classList.toggle('has-error', !!errorMsg);
            }
        }

        function validateEmail(email) {
            return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
        }

        function validateStep1() {
            let isValid = true;

            const firstName = document.getElementById('ship-first-name').value.trim();
            if (!firstName) {
                setFieldError('ship-first-name', 'First name is required.');
                isValid = false;
            } else {
                setFieldError('ship-first-name', '');
            }

            const lastName = document.getElementById('ship-last-name').value.trim();
            if (!lastName) {
                setFieldError('ship-last-name', 'Last name is required.');
                isValid = false;
            } else {
                setFieldError('ship-last-name', '');
            }

            const email = document.getElementById('ship-email').value.trim();
            if (!email) {
                setFieldError('ship-email', 'Email address is required.');
                isValid = false;
            } else if (!validateEmail(email)) {
                setFieldError('ship-email', 'Please enter a valid email address.');
                isValid = false;
            } else {
                setFieldError('ship-email', '');
            }

            const phone = document.getElementById('ship-phone').value.trim();
            if (!phone) {
                setFieldError('ship-phone', 'Mobile phone is required.');
                isValid = false;
            } else if (phone.length < 7) {
                setFieldError('ship-phone', 'Please enter a valid phone number.');
                isValid = false;
            } else {
                setFieldError('ship-phone', '');
            }

            return isValid;
        }

        function validateStep2() {
            const selectedCard = document.querySelector('.payment-method-card.is-selected');
            const paymentType = selectedCard?.getAttribute('data-payment');

            if (paymentType === 'card') {
                let isValid = true;
                const holder = document.getElementById('card-holder').value.trim();
                const number = document.getElementById('card-number').value.replace(/\s+/g, '');
                const exp = document.getElementById('card-exp').value.trim();
                const cvv = document.getElementById('card-cvv').value.trim();

                if (!holder) {
                    setFieldError('card-holder', 'Cardholder name is required.');
                    isValid = false;
                } else {
                    setFieldError('card-holder', '');
                }

                if (!number || number.length < 13) {
                    setFieldError('card-number', 'Enter a valid 16-digit card number.');
                    isValid = false;
                } else {
                    setFieldError('card-number', '');
                }

                if (!exp || !/^\d{2}\/\d{2}$/.test(exp)) {
                    setFieldError('card-exp', 'Use MM/YY format.');
                    isValid = false;
                } else {
                    setFieldError('card-exp', '');
                }

                if (!cvv || cvv.length < 3) {
                    setFieldError('card-cvv', 'Enter 3 or 4 digits.');
                    isValid = false;
                } else {
                    setFieldError('card-cvv', '');
                }

                return isValid;
            }

            return true;
        }

        // Live input listeners for clearing errors on change
        [
            'ship-first-name', 'ship-last-name', 'ship-email', 'ship-phone',
            'card-holder', 'card-number', 'card-exp', 'card-cvv'
        ].forEach(id => {
            const el = document.getElementById(id);
            if (el) {
                el.addEventListener('input', () => {
                    if (el.classList.contains('is-invalid')) {
                        setFieldError(id, '');
                    }
                });
                el.addEventListener('blur', () => {
                    if (el.hasAttribute('required') && !el.value.trim()) {
                        setFieldError(id, 'This field is required.');
                    } else if (id === 'ship-email' && el.value.trim() && !validateEmail(el.value.trim())) {
                        setFieldError(id, 'Please enter a valid email address.');
                    }
                });
            }
        });

        function setStep(step) {
            currentStep = step;

            // Update Stepper Nodes
            for (let i = 1; i <= 3; i++) {
                const node = document.getElementById(`step-node-${i}`);
                const circle = document.getElementById(`step-circle-${i}`);
                if (!node) continue;

                if (i < step) {
                    node.className = 'step-node is-complete is-clickable';
                    circle.innerHTML = `
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                            <polyline points="20 6 9 17 4 12"></polyline>
                        </svg>
                    `;
                } else if (i === step) {
                    node.className = 'step-node is-active';
                    circle.textContent = i;
                } else {
                    node.className = 'step-node';
                    circle.textContent = i;
                }
            }

            // Update Connectors
            document.getElementById('step-connector-1').classList.toggle('is-filled', step >= 2);
            document.getElementById('step-connector-2').classList.toggle('is-filled', step >= 3);

            // Toggle Panels
            document.getElementById('panel-step-1').classList.toggle('is-active', step === 1);
            document.getElementById('panel-step-2').classList.toggle('is-active', step === 2);
            document.getElementById('panel-step-3').classList.toggle('is-active', step === 3);

            if (step === 3) {
                renderReviewItems();
            }

            window.scrollTo({ top: 120, behavior: 'smooth' });
        }

        // Stepper click delegation for completed steps
        document.querySelectorAll('.step-node').forEach(node => {
            node.addEventListener('click', () => {
                const step = parseInt(node.getAttribute('data-step'), 10);
                if (step < currentStep) {
                    setStep(step);
                }
            });
        });

        // Step 1: Shipping Cards Selection
        document.querySelectorAll('.shipping-card').forEach(card => {
            card.addEventListener('click', () => {
                document.querySelectorAll('.shipping-card').forEach(c => c.classList.remove('is-selected'));
                card.classList.add('is-selected');

                selectedShippingCost = parseInt(card.getAttribute('data-shipping-cost'), 10);
                const title = card.querySelector('.shipping-card__title')?.textContent || 'Courier Delivery';
                const cost = selectedShippingCost === 0 ? 'FREE' : `₱${selectedShippingCost}`;
                selectedShippingName = `${title} (${cost})`;

                renderSidebar();
            });
        });

        // Step 1 Continue Button
        document.getElementById('btn-goto-step-2').addEventListener('click', () => {
            if (!validateStep1()) {
                RealtimeManager.showToast('Please check the highlighted errors above.', 'alert');
                return;
            }

            setStep(2);
            RealtimeManager.showToast('Customer & pickup details saved. Select payment method.', 'info');
        });

        // Step 2: Payment Method Card Selection
        document.querySelectorAll('.payment-method-card').forEach(card => {
            card.addEventListener('click', (e) => {
                // Ignore click if typing in card sub-inputs
                if (e.target.closest('input')) return;

                document.querySelectorAll('.payment-method-card').forEach(c => c.classList.remove('is-selected'));
                card.classList.add('is-selected');

                selectedPaymentMethod = card.querySelector('.shipping-card__title')?.textContent || 'HitPay Online Payment';
            });
        });

        // Step 2 Buttons
        document.getElementById('btn-back-to-step-1').addEventListener('click', () => setStep(1));
        document.getElementById('btn-goto-step-3').addEventListener('click', () => {
            if (!validateStep2()) {
                RealtimeManager.showToast('Please check the highlighted card errors.', 'alert');
                return;
            }
            setStep(3);
            RealtimeManager.showToast('Review your order before final confirmation.', 'info');
        });

        // Step 3 Buttons
        document.getElementById('btn-back-to-step-2').addEventListener('click', () => setStep(2));
        document.getElementById('btn-edit-shipping').addEventListener('click', () => setStep(1));
        document.getElementById('btn-edit-payment').addEventListener('click', () => setStep(2));

        // Place Order via live C# Web API (POST /api/v1/orders)
        document.getElementById('btn-place-order').addEventListener('click', async () => {
            const agreed = document.getElementById('chk-agree-terms').checked;
            if (!agreed) {
                RealtimeManager.showToast('Please agree to the Terms of Sale to proceed.', 'alert');
                return;
            }

            const btn = document.getElementById('btn-place-order');
            const textSpan = document.getElementById('btn-place-order-text');
            btn.classList.add('btn--disabled');
            btn.disabled = true;
            textSpan.textContent = "Processing Transaction...";

            const checkoutItems = getCheckoutItems();
            if (!checkoutItems.length || checkoutItems.some(item =>
                !Number.isSafeInteger(Number(item.variantId)) || Number(item.variantId) <= 0 ||
                Number(item.availableStock) < Number(item.quantity))) {
                RealtimeManager.showToast('Review your cart: an item is unavailable or needs to be added again.', 'alert');
                btn.classList.remove('btn--disabled');
                btn.disabled = false;
                textSpan.textContent = 'Place Order & Pay';
                return;
            }
            const fName = document.getElementById('ship-first-name')?.value.trim() || 'Customer';
            const lName = document.getElementById('ship-last-name')?.value.trim() || '';
            const email = document.getElementById('ship-email')?.value.trim() || 'customer@helmetcartel.com';
            const phone = document.getElementById('ship-phone')?.value.trim() || '+63 917 123 4567';

            const selectedCard = document.querySelector('.payment-method-card.is-selected');
            const paymentKey = selectedCard?.getAttribute('data-payment');
            let paymentMethod = 'Cash';
            if (paymentKey === 'hitpay') paymentMethod = 'HitPay';
            else if (paymentKey === 'card') paymentMethod = 'Card_POS';
            else if (paymentKey === 'cash' || paymentKey === 'bank') paymentMethod = 'Cash';

            const payload = {
                customerName: `${fName} ${lName}`.trim(),
                customerEmail: email,
                customerPhone: phone,
                paymentMethod: paymentMethod,
                notes: 'Store Collection at Flagship Hub (QC)',
                items: checkoutItems.map(item => ({
                    variantId: Number(item.variantId),
                    quantity: Number(item.quantity)
                }))
            };

            try {
                const response = await ApiClient.createOrder(payload);
                const orderData = response?.data || response;
                const orderNo = orderData?.orderNumber || `#HC-${new Date().getFullYear()}-${Math.floor(10000 + Math.random() * 90000)}`;
                const totalPaid = orderData?.totalAmount || calculateTotals().total;

                // Clear selected items from cart
                const allItems = CartManager.getItems();
                const remaining = allItems.filter(item => !checkoutItems.some(c => c.variantId === item.variantId));
                CartManager.saveItems(remaining);
                CartManager.updateCartBadge();

                // Populate Receipt Card
                document.getElementById('receipt-order-no').textContent = orderNo;
                document.getElementById('receipt-date').textContent = new Date().toLocaleDateString('en-US', {
                    month: 'long',
                    day: 'numeric',
                    year: 'numeric'
                }) + ' - ' + new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
                document.getElementById('receipt-payment').textContent = selectedPaymentMethod;
                document.getElementById('receipt-address').textContent = `${fName} ${lName} (${phone}) • Flagship Hub QC`;
                document.getElementById('receipt-total').innerHTML = `&#8369;${totalPaid.toLocaleString()}`;

                // If HitPay checkout URL provided and user selected HitPay, redirect:
                if (paymentMethod === 'HitPay' && orderData?.checkoutUrl) {
                    RealtimeManager.showToast('Redirecting to HitPay secure checkout...', 'info');
                    setTimeout(() => window.location.href = orderData.checkoutUrl, 800);
                    return;
                }

                // Show success view
                document.getElementById('checkout-stepper').style.display = 'none';
                document.getElementById('checkout-interactive-grid').style.display = 'none';
                document.getElementById('checkout-success-panel').classList.add('is-active');

                window.scrollTo({ top: 100, behavior: 'smooth' });
                RealtimeManager.showToast(`Order ${orderNo} confirmed! Inventory reserved.`, 'success');
            } catch (err) {
                console.error('[Checkout Error]', err);
                RealtimeManager.showToast(err.message || 'Error processing order. Please check stock.', 'alert');
                btn.classList.remove('btn--disabled');
                btn.disabled = false;
                textSpan.textContent = "Place Order & Pay";
            }
        });

        function escapeHtml(str) {
            if (!str) return '';
            return str
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;');
        }

        // Initialize view
        renderSidebar();
        CartManager.refreshItems().then(() => {
            renderSidebar();
            renderReviewItems();
        }).catch(() => {});
    </script>
</asp:Content>
