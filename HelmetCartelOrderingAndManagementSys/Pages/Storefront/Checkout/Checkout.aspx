<%@ Page Title="Secure Checkout" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Checkout.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.CheckoutPage" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="~/Content/css/storefront/storefront.css?v=8" runat="server" />
    <link rel="stylesheet" href="~/Content/css/storefront/checkout.css?v=4" runat="server" />
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="container checkout-container">
        <!-- Breadcrumb Navigation -->
        <nav class="shop-breadcrumb" aria-label="Breadcrumb">
            <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="shop-breadcrumb__link">Home</asp:HyperLink>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2">
                <polyline points="9 18 15 12 9 6"></polyline>
            </svg>
            <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Cart/Cart.aspx" CssClass="shop-breadcrumb__link">Cart</asp:HyperLink>
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

                    <!-- Customer Contact Details & Saved Delivery Address -->
                    <div class="form-section">
                        <h3 class="form-section-title">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                                <circle cx="12" cy="7" r="4"></circle>
                            </svg>
                            Customer Contact Details
                        </h3>

                        <!-- Clickable Address Card Component (matching screenshot) -->
                        <asp:HyperLink runat="server" ID="checkoutAddressComponent" ClientIDMode="Static" NavigateUrl="~/Pages/Storefront/Profile/Profile.aspx?tab=addresses" CssClass="checkout-address-card" ToolTip="Click to manage or select addresses in your profile">
                            <div class="checkout-address-card__icon">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                                    <circle cx="12" cy="10" r="3"></circle>
                                </svg>
                            </div>
                            <div class="checkout-address-card__content">
                                <div class="checkout-address-card__top">
                                    <span class="checkout-address-card__name" id="checkout-card-name">Customer</span>
                                    <span class="checkout-address-card__phone" id="checkout-card-phone">Loading...</span>
                                </div>
                                <div class="checkout-address-card__lines" id="checkout-card-address">
                                    Loading saved delivery address from your profile...
                                </div>
                            </div>
                            <div class="checkout-address-card__arrow">
                                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <polyline points="9 18 15 12 9 6"></polyline>
                                </svg>
                            </div>
                        </asp:HyperLink>
                        <span class="inline-error-msg" id="err-checkout-address"></span>
                    </div>

                    <!-- Fulfillment Method Selection -->
                    <div class="form-section">
                        <h3 class="form-section-title">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <rect x="1" y="3" width="15" height="13"></rect>
                                <polygon points="16 8 20 8 23 11 23 16 16 16 8"></polygon>
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
                                        <div class="shipping-card__desc">Helmet Cartel Flagship Hub &bull; 128 Commonwealth Ave, QC</div>
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
                                        <div class="shipping-card__desc">Simulated door-to-door courier dispatch via J&amp;T Express, Lalamove, or Grab Express</div>
                                    </div>
                                </div>
                                <div class="shipping-card__price" id="card-delivery-price-text">&#8369;150</div>
                            </div>
                        </div>
                    </div>

                    <div class="checkout-panel-actions">
                        <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Cart/Cart.aspx" CssClass="btn btn--outline">
                            <svg class="shop-breadcrumb__icon icon--back" viewBox="0 0 24 24" fill="none" stroke-width="2">
                                <polyline points="9 18 15 12 9 6"></polyline>
                            </svg>
                            <span>Back to Cart</span>
                        </asp:HyperLink>
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
                    <p class="checkout-panel__subtitle">Please review your itemized gear selection before placing your order.</p>

                    <!-- Selected Items Summary List -->
                    <div class="review-block">
                        <div class="review-block__header">
                            <div class="review-block__title-wrap">
                                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path>
                                    <line x1="3" y1="6" x2="21" y2="6"></line>
                                    <path d="M16 10a4 4 0 0 1-8 0"></path>
                                </svg>
                                <span class="review-block__title">Order Items</span>
                            </div>
                            <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Cart/Cart.aspx" CssClass="review-block__edit">Edit Cart</asp:HyperLink>
                        </div>
                        <div class="review-items-list" id="review-items-list">
                            <!-- Populated dynamically via JS -->
                        </div>
                    </div>

                    <!-- Policy Checkbox -->
                    <div class="checkout-terms">
                        <input type="checkbox" id="chk-agree-terms" checked />
                        <label for="chk-agree-terms">
                            I have reviewed my order details and agree to Helmet Cartel's <a href="#">Terms of Sale</a>.
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
                            <span class="btn-spinner" aria-hidden="true"></span>
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
                </div>

                <hr class="summary-divider" />

                <div class="summary-total-row">
                    <span>Total Amount</span>
                    <span class="summary-total-price" id="sidebar-total">&#8369;0</span>
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
                <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx" CssClass="btn btn--primary">
                    <span>Continue Shopping</span>
                    <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="7" y1="17" x2="17" y2="7"></line>
                        <polyline points="7 7 17 7 17 17"></polyline>
                    </svg>
                </asp:HyperLink>
            </div>
        </div>
    </div>

    <!-- External Storefront Checkout Script -->
    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/checkout.js?v=1") %>'></script>
</asp:Content>
