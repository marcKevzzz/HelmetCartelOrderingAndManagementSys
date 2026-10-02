<%@ Page Title="Live Order Tracking & Fulfillment" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="TrackOrder.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.TrackOrderPage" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="~/Content/css/storefront/profile.css?v=8" runat="server" />
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="track-order-page-container">
        <!-- 1. Top Breadcrumb & Back Navigation -->
        <div class="track-order-nav-row">
            <nav class="profile-breadcrumb" aria-label="Breadcrumb">
                <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="profile-breadcrumb__link">Home</asp:HyperLink>
                <svg class="profile-breadcrumb__separator" viewBox="0 0 24 24" fill="none" stroke-width="2">
                    <polyline points="9 18 15 12 9 6"></polyline>
                </svg>
                <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Profile/Profile.aspx?tab=orders" CssClass="profile-breadcrumb__link">My Account</asp:HyperLink>
                <svg class="profile-breadcrumb__separator" viewBox="0 0 24 24" fill="none" stroke-width="2">
                    <polyline points="9 18 15 12 9 6"></polyline>
                </svg>
                <span class="profile-breadcrumb__current" id="track-breadcrumb-number">Order Tracking</span>
            </nav>
            <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Profile/Profile.aspx?tab=orders" CssClass="btn btn--outline btn--sm">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                    <line x1="19" y1="12" x2="5" y2="12"></line>
                    <polyline points="12 19 5 12 12 5"></polyline>
                </svg>
                <span>Back to Order History</span>
            </asp:HyperLink>
        </div>

        <!-- Loading State -->
        <div class="order-loading-box" id="track-loading-state">
            <div class="loading-spinner"></div>
            <span>Loading...</span>
        </div>

        <!-- Not Found State -->
        <div class="empty-orders-card" id="track-error-state" style="display: none;">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="empty-orders-icon">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="15" y1="9" x2="9" y2="15"></line>
                <line x1="9" y1="9" x2="15" y2="15"></line>
            </svg>
            <h2 id="track-error-title">Order Not Found</h2>
            <p id="track-error-msg">We could not find an order matching this order number or identifier.</p>
            <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Profile/Profile.aspx?tab=orders" CssClass="btn btn--primary btn--sm">View My Orders</asp:HyperLink>
        </div>

        <!-- 2. Main Order Tracking Content (Row Layout) -->
        <div class="track-order-content" id="track-order-content" style="display: none;">
            <!-- Row A: Order Header Card -->
            <div class="track-header-card">
                <div class="track-header-main">
                    <div class="track-header-info">
                        <h1 class="track-order-number" id="track-order-number">#HC-20261001-13FF96BAF0</h1>
                        <span class="track-order-date" id="track-order-date">Oct 1, 2026, 04:13 AM</span>
                    </div>
                    <div class="track-header-status-wrap">
                        <span class="order-status-badge status-badge--processing" id="track-status-badge">
                            <span class="status-pulse-dot"></span>
                            <span id="track-status-text">PROCESSING</span>
                        </span>
                    </div>
                </div>

                <!-- Row B: Stepper Tracker Row -->
                <div class="track-stepper-container" id="track-stepper-container">
                    <!-- Dynamically populated via JS stepper -->
                </div>
            </div>

            <!-- Row C: 3-Column Info Cards Row -->
            <div class="track-info-row-grid">
                <!-- Col 1: Fulfillment Method -->
                <div class="track-info-card">
                    <div class="track-info-card__header">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                            <rect x="1" y="3" width="15" height="13"></rect>
                            <polygon points="16 8 20 8 23 11 23 16 16 16 16 8"></polygon>
                            <circle cx="5.5" cy="18.5" r="2.5"></circle>
                            <circle cx="18.5" cy="18.5" r="2.5"></circle>
                        </svg>
                        <span class="track-info-card__label">FULFILLMENT METHOD</span>
                    </div>
                    <div class="track-info-card__body">
                        <strong class="track-info-card__value" id="track-fulfillment-method">Door-to-Door Delivery</strong>
                        <div class="track-courier-row" id="track-courier-row" style="display: none;">
                            <span class="track-courier-name" id="track-courier-name">J&amp;T Express</span>
                            <span class="order-tracking-num-tag" id="track-tracking-num">TRK12345678</span>
                            <button type="button" class="btn-copy-tracking" id="btn-track-copy" title="Copy tracking number">
                                <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="14" height="14">
                                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                                    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                                </svg>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Col 2: Payment Gateway -->
                <div class="track-info-card">
                    <div class="track-info-card__header">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                            <rect x="2" y="5" width="20" height="14" rx="2"></rect>
                            <line x1="2" y1="10" x2="22" y2="10"></line>
                        </svg>
                        <span class="track-info-card__label">PAYMENT GATEWAY</span>
                    </div>
                    <div class="track-info-card__body">
                        <div class="track-payment-badges-row">
                            <span class="payment-gateway-pill" id="track-payment-gateway">CashOnDelivery</span>
                            <span class="payment-status-tag payment-status--pending" id="track-payment-status">PENDING</span>
                        </div>
                        <span class="track-info-subtext" id="track-payment-ref">Reference: N/A</span>
                    </div>
                </div>

                <!-- Col 3: Delivery Destination -->
                <div class="track-info-card">
                    <div class="track-info-card__header">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                            <circle cx="12" cy="10" r="3"></circle>
                        </svg>
                        <span class="track-info-card__label">DELIVERY DESTINATION</span>
                    </div>
                    <div class="track-info-card__body">
                        <strong class="track-recipient-name" id="track-recipient-name">Recipient Name</strong>
                        <p class="track-destination-text" id="track-delivery-destination">Emerald street, Nova Proper, Quezon City, Metro Manila</p>
                        <span class="track-landmark-text" id="track-delivery-landmark" style="display: none;"></span>
                    </div>
                </div>
            </div>

            <!-- Row D: Purchased Gear Items & Summary Row -->
            <div class="track-gear-row-layout">
                <!-- Left: Gear Items List Card -->
                <div class="track-gear-card">
                    <div class="track-gear-card__header">
                        <h2 class="track-gear-card__title">PURCHASED GEAR DETAILS</h2>
                        <span class="track-gear-count" id="track-gear-count">(1 item)</span>
                    </div>
                    <div class="track-gear-items-list" id="track-gear-items-list">
                        <!-- Dynamically populated via JS -->
                    </div>
                </div>

                <!-- Right: Financial Breakdown & Actions Card -->
                <div class="track-summary-card">
                    <div class="track-summary-card__header">
                        <h2 class="track-gear-card__title">ORDER SUMMARY</h2>
                    </div>
                    <div class="track-summary-lines">
                        <div class="track-summary-line">
                            <span>Subtotal</span>
                            <span id="track-subtotal">&#8369;0.00</span>
                        </div>
                        <div class="track-summary-line" id="track-discount-row" style="display: none; color: #047857;">
                            <span>Voucher Discount</span>
                            <span id="track-discount">-&#8369;0.00</span>
                        </div>
                        <div class="track-summary-line">
                            <span>Shipping Fee</span>
                            <span id="track-shipping">&#8369;0.00</span>
                        </div>
                        <div class="track-summary-line track-summary-line--total">
                            <span>Total Amount</span>
                            <strong class="track-total-amount" id="track-total-amount">&#8369;19,140.00</strong>
                        </div>
                    </div>

                    <div class="track-actions-stack">
                        <button type="button" class="btn btn--primary btn--block" id="btn-track-view-receipt">
                            <span>View Digital Receipt</span>
                            <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <line x1="7" y1="17" x2="17" y2="7"></line>
                                <polyline points="7 7 17 7 17 17"></polyline>
                            </svg>
                        </button>
                        <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx" CssClass="btn btn--outline btn--block">
                            <span>Shop Additional Gear</span>
                        </asp:HyperLink>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Official Digital Receipt Modal -->
    <div class="receipt-modal-overlay" id="receipt-modal-overlay" role="dialog" aria-modal="true" aria-labelledby="receipt-dialog-title">
        <div class="receipt-modal-container">
            <div class="receipt-modal-header">
                <h3 class="receipt-modal-title" id="receipt-dialog-title">Digital Sales Receipt</h3>
                <button type="button" class="receipt-modal-close" id="btn-receipt-modal-close" aria-label="Close receipt modal">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                        <line x1="18" y1="6" x2="6" y2="18"></line>
                        <line x1="6" y1="6" x2="18" y2="18"></line>
                    </svg>
                </button>
            </div>

            <div class="receipt-modal-body">
                <div class="digital-receipt-doc" id="digital-receipt-doc">
                    <div class="loading-spinner"></div>
                    <span>Formatting receipt...</span>
                </div>
            </div>

            <div class="receipt-modal-footer">
                <button type="button" class="btn btn--outline btn--sm" id="btn-print-receipt">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                        <polyline points="6 9 6 2 18 2 18 9"></polyline>
                        <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path>
                        <rect x="6" y="14" width="12" height="8"></rect>
                    </svg>
                    <span>Print / Save Receipt</span>
                </button>
            </div>
        </div>
    </div>

    <!-- Page Specific Script -->
    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/track-order.js?v=3") %>'></script>
</asp:Content>
