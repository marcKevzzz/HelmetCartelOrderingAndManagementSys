<%@ Page Title="Secure Checkout" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Checkout.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.CheckoutPage" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href='<%= ResolveUrl("~/Content/css/storefront/checkout.css?v=20261004-3") %>' />
    <link rel="stylesheet" href="/Content/css/receipts.css?v=2" />
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="container checkout-container">
        <!-- Breadcrumb Navigation -->
        <nav class="shop-breadcrumb" aria-label="Breadcrumb">
            <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="shop-breadcrumb__link">Home</asp:HyperLink>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2">
                <polyline points="9 18 15 12 9 6"></polyline>
            </svg>
            <asp:HyperLink runat="server" ID="breadcrumbCartLink" ClientIDMode="Static" NavigateUrl="~/Pages/Storefront/Cart/Cart.aspx" CssClass="shop-breadcrumb__link">Cart</asp:HyperLink>
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
                    <span class="step-title">Customer &amp; Delivery</span>
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
                <!-- STEP 1: Customer Contact & Delivery Method -->
                <div class="checkout-panel is-active" id="panel-step-1">
                    <h2 class="checkout-panel__title">Customer &amp; Delivery Details</h2>
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
                            Delivery Method
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
                                <div class="shipping-card__price" id="card-delivery-price-text"><span class="status-badge status--pending">Add Address</span></div>
                            </div>
                        </div>
                    </div>

                    <div class="checkout-panel-actions">
                        <asp:HyperLink runat="server" ID="btnCheckoutBack" ClientIDMode="Static" NavigateUrl="~/Pages/Storefront/Cart/Cart.aspx" CssClass="btn btn--outline">
                            <svg class="shop-breadcrumb__icon icon--back" viewBox="0 0 24 24" fill="none" stroke-width="2">
                                <polyline points="9 18 15 12 9 6"></polyline>
                            </svg>
                            <span id="btn-checkout-back-text">Back to Cart</span>
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
                    <p class="checkout-panel__subtitle">Choose QRPh or an available pay-on-collection option.</p>

                    <div class="payment-methods-grid">
                        <!-- Option 1: HitPay Online Checkout (QR Ph) -->
                        <div class="payment-method-card is-selected" data-payment="hitpay">
                            <div class="payment-method-header">
                                <div class="payment-method-title-wrap">
                                    <div class="shipping-card__radio"></div>
                                    <div>
                                        <div class="shipping-card__title">QRPh</div>
                                        <div class="shipping-card__desc">QRPh payment with an academic demo confirmation</div>
                                    </div>
                                </div>
                            </div>
                            <div class="payment-method-details">
                                <p class="shipping-card__desc">The QRPh demo screen lets you complete a sample payment without a real charge.</p>
                                <div class="payment-icons payment-icons--checkout">
                                    <span class="payment-icon-pill payment-icon-pill--qrph">QR Ph</span>
                                    <span class="payment-icon-pill">InstaPay P2M</span>
                                    <span class="payment-icon-pill">Zero Convenience Fee</span>
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
                            <span>Back to Customer &amp; Delivery</span>
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
                            <asp:HyperLink runat="server" ID="linkReviewEdit" ClientIDMode="Static" NavigateUrl="~/Pages/Storefront/Cart/Cart.aspx" CssClass="review-block__edit">Edit Cart</asp:HyperLink>
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
                        <button type="button" class="btn btn--primary" id="btn-place-order" aria-describedby="checkout-order-error">
                            <span class="btn-spinner" aria-hidden="true"></span>
                            <span id="btn-place-order-text">Place Order &amp; Pay</span>
                            <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <line x1="7" y1="17" x2="17" y2="7"></line>
                                <polyline points="7 7 17 7 17 17"></polyline>
                            </svg>
                        </button>
                    </div>
                    <span id="checkout-order-error" class="inline-error-msg" role="alert"></span>
                </div>
            </div>

            <!-- Right Column: Sticky Order Summary Sidebar -->
            <aside class="checkout-sidebar">
                <h3 class="checkout-sidebar__title">Order Summary</h3>

                <div class="summary-rows-list">
                    <div class="summary-calc-row">
                        <span>Subtotal</span>
                        <span id="sidebar-subtotal">&#8369;0</span>
                    </div>
                    <div class="summary-calc-row" id="sidebar-voucher-row" hidden>
                        <span id="sidebar-voucher-label">Discount</span>
                        <span id="sidebar-voucher-discount" class="summary-calc-discount">&#8369;0</span>
                    </div>
                    <div class="summary-calc-row">
                        <span>Delivery Fee</span>
                        <span id="sidebar-shipping">FREE (In-Store Pickup)</span>
                    </div>
                </div>

                <hr class="summary-divider" />

                <div class="summary-total-row">
                    <span>Total</span>
                    <span class="summary-total-price" id="sidebar-total">&#8369;0</span>
                </div>

                <!-- Promo / Voucher Code Input matching Image 3 -->
                <div class="checkout-voucher-control">
                    <div class="checkout-promo-row">
                        <div class="checkout-promo-input-wrap">
                            <svg class="checkout-promo-tag-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"></path>
                                <line x1="7" y1="7" x2="7.01" y2="7"></line>
                            </svg>
                            <input type="text" id="checkout-voucher" class="checkout-promo-input" placeholder="Add promo code" maxlength="30" autocomplete="off" aria-describedby="checkout-voucher-error checkout-voucher-status" />
                            <button type="button" id="checkout-voucher-remove" class="checkout-promo-remove" title="Remove promo code" hidden aria-label="Remove promo code">&times;</button>
                        </div>
                        <button type="button" id="checkout-voucher-apply" class="btn-checkout-promo-apply">Apply</button>
                    </div>
                    <span id="checkout-voucher-error" class="inline-error-msg" role="alert"></span>
                    <span id="checkout-voucher-status" class="checkout-promo-status" role="status" aria-live="polite"></span>
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
            <h1 class="success-title" tabindex="-1">ORDER CONFIRMED!</h1>
            <p class="success-subtitle">Thank you for riding with Helmet Cartel. Your order has been placed and inventory is reserved.</p>

            <!-- Order Receipt Card (Collapsible) -->
            <div class="checkout-receipt-wrapper">
                <div class="checkout-receipt-document is-collapsed" id="checkout-receipt-doc"></div>
                <div class="checkout-receipt-toggle-wrap" id="checkout-receipt-toggle-wrap">
                    <button type="button" class="btn-receipt-toggle" id="btn-toggle-receipt" aria-expanded="false" aria-controls="checkout-receipt-doc">
                        <span id="btn-toggle-receipt-text">View Full Receipt</span>
                        <svg class="receipt-caret-icon" viewBox="0 0 24 24" fill="none" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="6 9 12 15 18 9"></polyline>
                        </svg>
                    </button>
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
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="2"></circle></svg>
                    </div>
                    <span class="tracker-text" id="tracker-step-4-text">Collected</span>
                </div>
            </div>

            <div class="success-actions">
                <button type="button" class="btn btn--outline" id="checkout-print-receipt">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                        <polyline points="7 10 12 15 17 10"></polyline>
                        <line x1="12" y1="15" x2="12" y2="3"></line>
                    </svg>
                    <span>Download Receipt</span>
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

    <!-- HitPay Interactive Payment Simulation Modal -->
    <div id="payment-simulation-modal" class="modal-backdrop is-hidden" role="dialog" aria-modal="true" aria-labelledby="sim-order-amount">
        <div class="modal-dialog modal-dialog--sm sim-qr-dialog">
            <div class="sim-modal-header">
                <button type="button" class="modal-close-btn" id="btn-close-sim-modal" aria-label="Close dialog">&times;</button>
            </div>
            <div class="modal-body sim-qr-body">
                <!-- Amount Display -->
                <div class="sim-amount-container">
                    <span class="sim-amount-caption">Total Amount to Pay</span>
                    <div class="sim-order-val sim-order-amount" id="sim-order-amount">&#8369;0.00</div>
                </div>

                <!-- QR Ph Dynamic Code Frame -->
                <div class="sim-qr-wrapper">
                    <div class="sim-qr-frame">
                        <div class="sim-qr-scan-beam" id="sim-qr-scan-beam"></div>
                        <svg class="sim-qr-svg" viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <rect width="200" height="200" rx="12" fill="#FFFFFF"/>
                            
                            <rect x="16" y="16" width="44" height="44" rx="4" fill="#0A0A0A"/>
                            <rect x="22" y="22" width="32" height="32" rx="2" fill="#FFFFFF"/>
                            <rect x="28" y="28" width="20" height="20" rx="2" fill="#0A0A0A"/>
                            
                            <rect x="140" y="16" width="44" height="44" rx="4" fill="#0A0A0A"/>
                            <rect x="146" y="22" width="32" height="32" rx="2" fill="#FFFFFF"/>
                            <rect x="152" y="28" width="20" height="20" rx="2" fill="#0A0A0A"/>
                            
                            <rect x="16" y="140" width="44" height="44" rx="4" fill="#0A0A0A"/>
                            <rect x="22" y="146" width="32" height="32" rx="2" fill="#FFFFFF"/>
                            <rect x="28" y="152" width="20" height="20" rx="2" fill="#0A0A0A"/>
                            
                            <rect x="68" y="20" width="8" height="8" fill="#171717"/>
                            <rect x="84" y="20" width="8" height="8" fill="#171717"/>
                            <rect x="100" y="20" width="8" height="8" fill="#171717"/>
                            <rect x="116" y="20" width="8" height="8" fill="#171717"/>
                            <rect x="68" y="36" width="16" height="8" fill="#171717"/>
                            <rect x="92" y="36" width="8" height="8" fill="#171717"/>
                            <rect x="108" y="36" width="16" height="8" fill="#171717"/>

                            <rect x="20" y="68" width="8" height="8" fill="#171717"/>
                            <rect x="36" y="68" width="8" height="8" fill="#171717"/>
                            <rect x="20" y="84" width="8" height="8" fill="#171717"/>
                            <rect x="20" y="100" width="8" height="8" fill="#171717"/>
                            <rect x="20" y="116" width="8" height="8" fill="#171717"/>

                            <rect x="68" y="68" width="12" height="12" fill="#171717"/>
                            <rect x="120" y="68" width="12" height="12" fill="#171717"/>
                            <rect x="140" y="68" width="16" height="8" fill="#171717"/>
                            <rect x="164" y="68" width="16" height="8" fill="#171717"/>

                            <rect x="140" y="84" width="8" height="16" fill="#171717"/>
                            <rect x="156" y="84" width="16" height="8" fill="#171717"/>
                            <rect x="140" y="108" width="12" height="12" fill="#171717"/>
                            <rect x="160" y="108" width="16" height="16" fill="#171717"/>

                            <rect x="68" y="120" width="16" height="8" fill="#171717"/>
                            <rect x="92" y="120" width="8" height="16" fill="#171717"/>
                            <rect x="108" y="120" width="16" height="8" fill="#171717"/>
                            <rect x="68" y="144" width="12" height="12" fill="#171717"/>
                            <rect x="88" y="144" width="16" height="8" fill="#171717"/>
                            <rect x="112" y="144" width="12" height="12" fill="#171717"/>

                            <rect x="136" y="140" width="16" height="16" rx="2" fill="#171717"/>
                            <rect x="160" y="140" width="16" height="8" fill="#171717"/>
                            <rect x="140" y="164" width="12" height="16" fill="#171717"/>
                            <rect x="160" y="160" width="16" height="20" fill="#171717"/>
                            <rect x="68" y="168" width="16" height="12" fill="#171717"/>
                            <rect x="92" y="168" width="12" height="12" fill="#171717"/>
                            <rect x="112" y="168" width="16" height="12" fill="#171717"/>

                            <rect x="78" y="78" width="44" height="44" rx="8" fill="#FFFFFF" stroke="#E5E5E5" stroke-width="2"/>
                            <rect x="82" y="82" width="36" height="36" rx="6" fill="#0A0A0A"/>
                            <text x="100" y="104" font-family="system-ui, -apple-system, sans-serif" font-size="11" font-weight="900" fill="#FFFFFF" text-anchor="middle" letter-spacing="0.5">QRPh</text>
                        </svg>
                    </div>
                </div>

                <!-- Simulated Process Controls -->
                <div class="sim-process-container">
                    <p class="sim-demo-note">Academic payment demo. Use the button below to complete payment; no real charge is made.</p>
                    <div class="sim-status-banner is-waiting" id="sim-status-banner" hidden role="status" aria-live="polite">
                        <span id="sim-status-banner-text"></span>
                    </div>

                    <div id="sim-status-alert" class="modal-alert modal-alert--danger is-hidden" role="alert">
                        <span id="sim-status-message"></span>
                    </div>

                    <div class="sim-actions-grid">
                        <button type="button" class="btn btn--primary btn-success-sim" id="btn-success-sim">
                            <span class="btn-spinner"></span>
                            <span>Complete Demo Payment</span>
                        </button>
                        <button type="button" class="btn btn--outline btn-cancel-sim" id="btn-cancel-sim">
                            <span>Cancel Payment</span>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- External Storefront Checkout Script -->
    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/checkout.js?v=20261007_return1") %>'></script>
</asp:Content>
