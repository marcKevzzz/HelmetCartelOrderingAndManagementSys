<%@ Page Title="Secure Checkout" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Checkout.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.CheckoutPage" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="<%= ResolveUrl("~/Content/css/storefront.css?v=7") %>" />
    <link rel="stylesheet" href="<%= ResolveUrl("~/Content/css/checkout.css?v=3") %>" />
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
                    <span class="step-title">Customer &amp; Fulfillment</span>
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
                <!-- STEP 1: Customer Contact & Fulfillment Method -->
                <div class="checkout-panel is-active" id="panel-step-1">
                    <h2 class="checkout-panel__title">Customer &amp; Fulfillment Details</h2>
                    <p class="checkout-panel__subtitle">Enter your contact info and choose store pickup or door-to-door courier delivery.</p>

                    <!-- Contact Details -->
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

                    <!-- Fulfillment Method Selection -->
                    <div class="form-section">
                        <h3 class="form-section-title">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <rect x="1" y="3" width="15" height="13"></rect>
                                <polygon points="16 8 20 8 23 11 23 16 16 16 16 8"></polygon>
                                <circle cx="5.5" cy="18.5" r="2.5"></circle>
                                <circle cx="18.5" cy="18.5" r="2.5"></circle>
                            </svg>
                            Fulfillment Method
                        </h3>
                        <div class="shipping-options-list">
                            <!-- In-Store Pickup -->
                            <div class="shipping-card is-selected" id="option-fulfillment-pickup" data-fulfillment="pickup" data-shipping-cost="0">
                                <div class="shipping-card__left">
                                    <div class="shipping-card__radio"></div>
                                    <div>
                                        <div class="shipping-card__title">In-Store Pickup <span class="shipping-card__badge">Flagship Store</span></div>
                                        <div class="shipping-card__desc">Helmet Cartel Flagship Hub &bull; 128 Commonwealth Ave, QC &bull; Free helmet fitting &amp; visor check</div>
                                    </div>
                                </div>
                                <div class="shipping-card__price">FREE</div>
                            </div>

                            <!-- Courier Delivery -->
                            <div class="shipping-card" id="option-fulfillment-delivery" data-fulfillment="delivery" data-shipping-cost="150">
                                <div class="shipping-card__left">
                                    <div class="shipping-card__radio"></div>
                                    <div>
                                        <div class="shipping-card__title">Door-to-Door Courier Delivery <span class="shipping-card__badge">Nationwide</span></div>
                                        <div class="shipping-card__desc">Insured nationwide delivery via J&amp;T Express, Lalamove, or Grab Express</div>
                                    </div>
                                </div>
                                <div class="shipping-card__price" id="card-delivery-price-text">&#8369;150</div>
                            </div>
                        </div>

                        <!-- Delivery Address Form (Visible when Delivery is selected) -->
                        <div class="delivery-address-section is-hidden" id="delivery-address-section">
                            <h4 class="form-section-title">
                                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                                    <circle cx="12" cy="10" r="3"></circle>
                                </svg>
                                Delivery Destination &amp; Philippine Shipping Address
                            </h4>

                            <div class="form-group">
                                <label class="form-label" for="ship-region">Delivery Region / Destination *</label>
                                <select class="form-select" id="ship-region">
                                    <option value="NCR" data-fee="150" data-eta="1-2 Business Days" selected>Metro Manila (NCR) &mdash; &#8369;150 (1&ndash;2 Business Days)</option>
                                    <option value="GMA" data-fee="250" data-eta="2-3 Business Days">Greater Manila Area (Cavite, Laguna, Rizal, Bulacan) &mdash; &#8369;250 (2&ndash;3 Days)</option>
                                    <option value="Luzon" data-fee="350" data-eta="3-5 Business Days">Rest of Luzon &mdash; &#8369;350 (3&ndash;5 Days)</option>
                                    <option value="Visayas" data-fee="450" data-eta="5-7 Business Days">Visayas (Cebu, Iloilo, Bacolod, etc.) &mdash; &#8369;450 (5&ndash;7 Days)</option>
                                    <option value="Mindanao" data-fee="500" data-eta="5-8 Business Days">Mindanao (Davao, CDO, GenSan, etc.) &mdash; &#8369;500 (5&ndash;8 Days)</option>
                                </select>
                                <span class="inline-error-msg" id="err-ship-region"></span>
                            </div>

                            <div class="form-group">
                                <label class="form-label" for="ship-address">Street Address / House / Unit / Building *</label>
                                <input type="text" class="form-input" id="ship-address" placeholder="Unit 4B, Emerald Tower, 15 F. Ortigas Jr. Rd" />
                                <span class="inline-error-msg" id="err-ship-address"></span>
                            </div>

                            <div class="form-row">
                                <div class="form-group">
                                    <label class="form-label" for="ship-barangay">Barangay *</label>
                                    <input type="text" class="form-input" id="ship-barangay" placeholder="San Antonio" />
                                    <span class="inline-error-msg" id="err-ship-barangay"></span>
                                </div>
                                <div class="form-group">
                                    <label class="form-label" for="ship-city">City / Municipality *</label>
                                    <input type="text" class="form-input" id="ship-city" placeholder="Pasig City" />
                                    <span class="inline-error-msg" id="err-ship-city"></span>
                                </div>
                            </div>

                            <div class="form-row">
                                <div class="form-group">
                                    <label class="form-label" for="ship-province">Province *</label>
                                    <input type="text" class="form-input" id="ship-province" placeholder="Metro Manila" />
                                    <span class="inline-error-msg" id="err-ship-province"></span>
                                </div>
                                <div class="form-group">
                                    <label class="form-label" for="ship-postal-code">Postal / ZIP Code *</label>
                                    <input type="text" class="form-input" id="ship-postal-code" placeholder="1600" maxlength="10" />
                                    <span class="inline-error-msg" id="err-ship-postal-code"></span>
                                </div>
                            </div>

                            <div class="form-group">
                                <label class="form-label" for="ship-notes">Delivery Landmarks / Rider Instructions (Optional)</label>
                                <input type="text" class="form-input" id="ship-notes" placeholder="Near Petron station, black gate, leave at guard lobby if not home" />
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
                    <p class="checkout-panel__subtitle">All online payments are encrypted and protected by HitPay escrow security.</p>

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

                        <!-- Option 2: Cash on Delivery (COD) - For Delivery Orders -->
                        <div class="payment-method-card is-hidden" id="payment-cod-card" data-payment="cod">
                            <div class="payment-method-header">
                                <div class="payment-method-title-wrap">
                                    <div class="shipping-card__radio"></div>
                                    <div>
                                        <div class="shipping-card__title">Cash on Delivery (COD)</div>
                                        <div class="shipping-card__desc">Pay exact cash to the courier rider upon parcel handover</div>
                                    </div>
                                </div>
                                <span class="delivery-badge-pill">COD Available</span>
                            </div>
                            <div class="payment-method-details">
                                <p class="shipping-card__desc">Prepare the exact amount in Philippine Peso (&#8369;) including delivery fee. The courier rider will provide a physical delivery waybill receipt upon payment.</p>
                            </div>
                        </div>

                        <!-- Option 3: Cash on In-Store Pickup - For Pickup Orders -->
                        <div class="payment-method-card" id="payment-cash-card" data-payment="cash">
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
                                <p class="shipping-card__desc">Pick up at Helmet Cartel Hub, 128 Commonwealth Ave, QC. Present your order confirmation code to staff.</p>
                            </div>
                        </div>

                        <!-- Option 4: Direct Bank Transfer / OTC -->
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
                    </div>

                    <div class="checkout-panel-actions">
                        <button type="button" class="btn btn--outline" id="btn-back-to-step-1">
                            <svg class="shop-breadcrumb__icon icon--back" viewBox="0 0 24 24" fill="none" stroke-width="2">
                                <polyline points="9 18 15 12 9 6"></polyline>
                            </svg>
                            <span>Back to Customer &amp; Fulfillment</span>
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

                    <!-- Fulfillment Summary Block -->
                    <div class="review-block">
                        <div class="review-block__header">
                            <span class="review-block__title">Customer &amp; Fulfillment</span>
                            <span class="review-block__edit" id="btn-edit-shipping">Edit</span>
                        </div>
                        <div class="review-block__content" id="review-shipping-summary">
                            <!-- Populated dynamically via JS -->
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
                        <span>Fulfillment Fee</span>
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
                    <span id="receipt-address-label">Fulfillment Address</span>
                    <span id="receipt-address">Helmet Cartel Hub &bull; 128 Commonwealth Ave, QC</span>
                </div>
                <div class="receipt-row">
                    <span>Fulfillment Status &amp; ETA</span>
                    <span id="receipt-eta" class="receipt-eta">Ready for Store Pickup in 1-2 Hours</span>
                </div>
                <div class="receipt-row receipt-row--bold">
                    <span>Total Amount</span>
                    <span id="receipt-total">&#8369;34,750</span>
                </div>
            </div>

            <!-- Order Timeline Tracker -->
            <div class="order-tracker" id="order-tracker-container">
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
                <div class="tracker-node" id="tracker-step-3">
                    <div class="tracker-icon">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="2"></circle></svg>
                    </div>
                    <span class="tracker-text" id="tracker-step-3-text">Ready for Pickup</span>
                </div>
                <div class="tracker-node" id="tracker-step-4">
                    <div class="tracker-icon">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                    </div>
                    <span class="tracker-text" id="tracker-step-4-text">Collected</span>
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
        let selectedFulfillment = 'pickup'; // 'pickup' | 'delivery'
        let selectedShippingCost = 0;
        let selectedPaymentMethodName = "HitPay Online Checkout (GCash / Maya / QR PH)";
        let selectedPaymentKey = "hitpay";

        // Regional Tiers Data
        const REGION_TIERS = {
            'NCR': { fee: 150, eta: '1-2 Business Days', name: 'Metro Manila (NCR)' },
            'GMA': { fee: 250, eta: '2-3 Business Days', name: 'Greater Manila Area (Cavite, Laguna, Rizal, Bulacan)' },
            'Luzon': { fee: 350, eta: '3-5 Business Days', name: 'Rest of Luzon' },
            'Visayas': { fee: 450, eta: '5-7 Business Days', name: 'Visayas' },
            'Mindanao': { fee: 500, eta: '5-8 Business Days', name: 'Mindanao' }
        };

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
            if (selectedFulfillment === 'pickup') {
                document.getElementById('sidebar-shipping').innerHTML = 'FREE (Pickup)';
            } else {
                const regKey = document.getElementById('ship-region')?.value || 'NCR';
                const regName = REGION_TIERS[regKey]?.name || 'Delivery';
                document.getElementById('sidebar-shipping').innerHTML = `&#8369;${selectedShippingCost.toLocaleString()} (${regKey})`;
            }
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

            // Update review summary text blocks
            const firstName = document.getElementById('ship-first-name')?.value.trim() || '';
            const lastName = document.getElementById('ship-last-name')?.value.trim() || '';
            const fullName = `${firstName} ${lastName}`.trim();
            const phone = document.getElementById('ship-phone')?.value.trim() || '';
            const email = document.getElementById('ship-email')?.value.trim() || '';

            if (selectedFulfillment === 'pickup') {
                document.getElementById('review-shipping-summary').innerHTML = `
                    <strong>${escapeHtml(fullName)}</strong> &bull; ${escapeHtml(phone)} ${email ? `&bull; ${escapeHtml(email)}` : ''}<br />
                    <strong>Pickup Hub:</strong> Helmet Cartel Flagship Hub &bull; 128 Commonwealth Ave, QC &bull; <strong>FREE</strong>
                `;
            } else {
                const regKey = document.getElementById('ship-region')?.value || 'NCR';
                const regData = REGION_TIERS[regKey] || REGION_TIERS['NCR'];
                const addr = document.getElementById('ship-address')?.value.trim() || '';
                const brgy = document.getElementById('ship-barangay')?.value.trim() || '';
                const city = document.getElementById('ship-city')?.value.trim() || '';
                const prov = document.getElementById('ship-province')?.value.trim() || '';
                const zip = document.getElementById('ship-postal-code')?.value.trim() || '';
                const notes = document.getElementById('ship-notes')?.value.trim() || '';

                document.getElementById('review-shipping-summary').innerHTML = `
                    <strong>${escapeHtml(fullName)}</strong> &bull; ${escapeHtml(phone)} ${email ? `&bull; ${escapeHtml(email)}` : ''}<br />
                    <strong>Delivery Address:</strong> ${escapeHtml(addr)}, Brgy. ${escapeHtml(brgy)}, ${escapeHtml(city)}, ${escapeHtml(prov)} ${escapeHtml(zip)}<br />
                    <strong>Region:</strong> ${escapeHtml(regData.name)} &bull; <strong>Fee:</strong> &#8369;${selectedShippingCost.toLocaleString()} (${escapeHtml(regData.eta)})
                    ${notes ? `<br /><em>Notes: ${escapeHtml(notes)}</em>` : ''}
                `;
            }

            document.getElementById('review-payment-summary').innerHTML = escapeHtml(selectedPaymentMethodName);
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

            if (selectedFulfillment === 'delivery') {
                const addr = document.getElementById('ship-address').value.trim();
                if (!addr) {
                    setFieldError('ship-address', 'Street address is required for delivery.');
                    isValid = false;
                } else {
                    setFieldError('ship-address', '');
                }

                const brgy = document.getElementById('ship-barangay').value.trim();
                if (!brgy) {
                    setFieldError('ship-barangay', 'Barangay is required.');
                    isValid = false;
                } else {
                    setFieldError('ship-barangay', '');
                }

                const city = document.getElementById('ship-city').value.trim();
                if (!city) {
                    setFieldError('ship-city', 'City / Municipality is required.');
                    isValid = false;
                } else {
                    setFieldError('ship-city', '');
                }

                const prov = document.getElementById('ship-province').value.trim();
                if (!prov) {
                    setFieldError('ship-province', 'Province is required.');
                    isValid = false;
                } else {
                    setFieldError('ship-province', '');
                }

                const zip = document.getElementById('ship-postal-code').value.trim();
                if (!zip) {
                    setFieldError('ship-postal-code', 'Postal code is required.');
                    isValid = false;
                } else {
                    setFieldError('ship-postal-code', '');
                }
            }

            return isValid;
        }

        // Live input listeners for clearing errors on change
        [
            'ship-first-name', 'ship-last-name', 'ship-email', 'ship-phone',
            'ship-address', 'ship-barangay', 'ship-city', 'ship-province', 'ship-postal-code'
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

        // Fulfillment Selection Toggle (Pickup vs Delivery)
        function updateFulfillmentUI() {
            const deliverySection = document.getElementById('delivery-address-section');
            const pickupCard = document.getElementById('option-fulfillment-pickup');
            const deliveryCard = document.getElementById('option-fulfillment-delivery');
            const codCard = document.getElementById('payment-cod-card');
            const cashCard = document.getElementById('payment-cash-card');

            if (selectedFulfillment === 'pickup') {
                pickupCard.classList.add('is-selected');
                deliveryCard.classList.remove('is-selected');
                deliverySection.classList.add('is-hidden');
                selectedShippingCost = 0;

                // Adjust Payment Options for Pickup
                if (codCard) codCard.classList.add('is-hidden');
                if (cashCard) cashCard.classList.remove('is-hidden');

                // If COD was selected previously, switch back to HitPay
                if (selectedPaymentKey === 'cod') {
                    selectPaymentCard('hitpay');
                }
            } else {
                pickupCard.classList.remove('is-selected');
                deliveryCard.classList.add('is-selected');
                deliverySection.classList.remove('is-hidden');

                // Read current region fee
                const regKey = document.getElementById('ship-region')?.value || 'NCR';
                selectedShippingCost = REGION_TIERS[regKey]?.fee || 150;
                document.getElementById('card-delivery-price-text').innerHTML = `&#8369;${selectedShippingCost.toLocaleString()}`;

                // Adjust Payment Options for Delivery
                if (cashCard) cashCard.classList.add('is-hidden');
                if (codCard) codCard.classList.remove('is-hidden');

                // If Cash on Pickup was selected previously, switch to COD
                if (selectedPaymentKey === 'cash') {
                    selectPaymentCard('cod');
                }
            }

            renderSidebar();
        }

        document.getElementById('option-fulfillment-pickup').addEventListener('click', () => {
            selectedFulfillment = 'pickup';
            updateFulfillmentUI();
        });

        document.getElementById('option-fulfillment-delivery').addEventListener('click', () => {
            selectedFulfillment = 'delivery';
            updateFulfillmentUI();
        });

        // Region dropdown listener
        document.getElementById('ship-region').addEventListener('change', (e) => {
            const regKey = e.target.value;
            const tier = REGION_TIERS[regKey] || REGION_TIERS['NCR'];
            selectedShippingCost = tier.fee;
            document.getElementById('card-delivery-price-text').innerHTML = `&#8369;${tier.fee.toLocaleString()}`;
            renderSidebar();
        });

        function selectPaymentCard(paymentKey) {
            document.querySelectorAll('.payment-method-card').forEach(c => c.classList.remove('is-selected'));
            const target = document.querySelector(`.payment-method-card[data-payment="${paymentKey}"]`);
            if (target) {
                target.classList.add('is-selected');
                selectedPaymentKey = paymentKey;
                selectedPaymentMethodName = target.querySelector('.shipping-card__title')?.textContent || 'Online Payment';
            }
        }

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

        // Step 1 Continue Button
        document.getElementById('btn-goto-step-2').addEventListener('click', () => {
            if (!validateStep1()) {
                RealtimeManager.showToast('Please complete all required fields.', 'alert');
                return;
            }

            setStep(2);
            RealtimeManager.showToast('Customer & fulfillment details saved. Select payment method.', 'info');
        });

        // Step 2: Payment Method Card Selection
        document.querySelectorAll('.payment-method-card').forEach(card => {
            card.addEventListener('click', () => {
                document.querySelectorAll('.payment-method-card').forEach(c => c.classList.remove('is-selected'));
                card.classList.add('is-selected');

                selectedPaymentKey = card.getAttribute('data-payment');
                selectedPaymentMethodName = card.querySelector('.shipping-card__title')?.textContent || 'Online Payment';
            });
        });

        // Step 2 Buttons
        document.getElementById('btn-back-to-step-1').addEventListener('click', () => setStep(1));
        document.getElementById('btn-goto-step-3').addEventListener('click', () => {
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

            let paymentGateway = 'HitPay';
            if (selectedPaymentKey === 'cod') paymentGateway = 'CashOnDelivery';
            else if (selectedPaymentKey === 'cash' || selectedPaymentKey === 'bank') paymentGateway = 'Cash';

            const isDelivery = selectedFulfillment === 'delivery';
            const regionKey = isDelivery ? (document.getElementById('ship-region')?.value || 'NCR') : null;
            const regionName = regionKey ? (REGION_TIERS[regionKey]?.name || regionKey) : null;
            const addr = isDelivery ? document.getElementById('ship-address')?.value.trim() : null;
            const brgy = isDelivery ? document.getElementById('ship-barangay')?.value.trim() : null;
            const city = isDelivery ? document.getElementById('ship-city')?.value.trim() : null;
            const prov = isDelivery ? document.getElementById('ship-province')?.value.trim() : null;
            const zip = isDelivery ? document.getElementById('ship-postal-code')?.value.trim() : null;
            const notes = isDelivery ? document.getElementById('ship-notes')?.value.trim() : null;

            const payload = {
                customerName: `${fName} ${lName}`.trim(),
                customerEmail: email,
                customerPhone: phone,
                paymentMethod: paymentGateway,
                shippingMethod: isDelivery ? 'Delivery' : 'Pickup',
                shippingFee: isDelivery ? selectedShippingCost : 0,
                shippingRegion: regionName,
                shippingAddress: addr,
                shippingBarangay: brgy,
                shippingCity: city,
                shippingProvince: prov,
                shippingPostalCode: zip,
                deliveryNotes: notes,
                notes: isDelivery ? `Door-to-Door Delivery (${regionKey})` : 'Store Pickup at Flagship Hub (QC)',
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
                document.getElementById('receipt-payment').textContent = selectedPaymentMethodName;
                document.getElementById('receipt-total').innerHTML = `&#8369;${totalPaid.toLocaleString()}`;

                if (isDelivery) {
                    document.getElementById('receipt-address-label').textContent = 'Delivery Address';
                    document.getElementById('receipt-address').textContent = `${addr}, Brgy. ${brgy}, ${city}, ${prov} ${zip}`;
                    const eta = REGION_TIERS[regionKey]?.eta || '2-4 Days';
                    document.getElementById('receipt-eta').textContent = `Dispatched via Courier (Est. ${eta})`;

                    // Update Tracker for Delivery
                    document.getElementById('tracker-step-3-text').textContent = 'In Transit / Dispatched';
                    document.getElementById('tracker-step-4-text').textContent = 'Delivered';
                } else {
                    document.getElementById('receipt-address-label').textContent = 'Pickup Location';
                    document.getElementById('receipt-address').textContent = 'Helmet Cartel Flagship Hub • 128 Commonwealth Ave, QC';
                    document.getElementById('receipt-eta').textContent = 'Ready for Store Pickup in 1-2 Hours';

                    // Update Tracker for Pickup
                    document.getElementById('tracker-step-3-text').textContent = 'Ready for Pickup';
                    document.getElementById('tracker-step-4-text').textContent = 'Collected';
                }

                // If HitPay checkout URL provided and user selected HitPay, redirect:
                if (paymentGateway === 'HitPay' && orderData?.checkoutUrl) {
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
        updateFulfillmentUI();
        renderSidebar();
        CartManager.refreshItems().then(() => {
            renderSidebar();
            renderReviewItems();
        }).catch(() => {});
    </script>
</asp:Content>
