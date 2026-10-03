<%@ Page Title="Order Details" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" CodeBehind="OrderDetail.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.Admin.Orders.OrderDetail" ResponseEncoding="utf-8" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="/Content/css/receipts.css?v=20261003-2" />
    <style>
        .od-page-container {
            display: flex;
            flex-direction: column;
            gap: var(--space-6);
            width: 100%;
        }

        /* Top Header */
        .od-header {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            gap: var(--space-4);
            flex-wrap: wrap;
        }

        .od-header-left {
            display: flex;
            flex-direction: column;
            gap: 6px;
        }

        .od-header-title-row {
            display: flex;
            align-items: center;
            gap: var(--space-3);
            flex-wrap: wrap;
        }

        .od-order-num {
            font-family: var(--font-heading);
            font-size: 1.75rem;
            font-weight: 900;
            letter-spacing: -0.02em;
            color: var(--color-text-main);
            margin: 0;
            line-height: 1.15;
        }

        .od-status-badges {
            display: inline-flex;
            align-items: center;
            gap: var(--space-2);
        }

        .od-header-date-row {
            display: flex;
            align-items: center;
            gap: var(--space-2);
            font-size: var(--text-body-sm);
            color: var(--color-text-secondary);
        }

        .od-header-actions {
            display: flex;
            align-items: center;
            gap: var(--space-2);
        }

        /* Main Workspace Grid (Left: Order Items & Financial Summary, Right: Customer & Shipping) */
        .od-workspace-grid {
            display: grid;
            grid-template-columns: minmax(0, 1.85fr) minmax(320px, 1.15fr);
            gap: var(--space-6);
            align-items: start;
        }

        @media (max-width: 1024px) {
            .od-workspace-grid {
                grid-template-columns: 1fr;
            }
        }

        /* Collapsible Section Cards */
        .od-card {
            background-color: var(--color-surface-card);
            border: 1px solid var(--color-border-subtle);
            border-radius: var(--radius-lg);
            overflow: hidden;
            box-shadow: var(--shadow-sm);
            margin-bottom: var(--space-6);
        }

        .od-card:last-child {
            margin-bottom: 0;
        }

        .od-card-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: var(--space-5) var(--space-6);
            background-color: var(--color-surface-card);
            cursor: pointer;
            user-select: none;
            border-bottom: 1px solid transparent;
            transition: background-color var(--transition-fast);
        }

        .od-card.is-open .od-card-header {
            border-bottom-color: var(--color-border-subtle);
        }

        .od-card-header:hover {
            background-color: var(--color-surface-subtle);
        }

        .od-card-title-wrap {
            display: flex;
            align-items: center;
            gap: var(--space-3);
        }

        .od-card-title {
            font-size: var(--text-h4);
            font-weight: var(--weight-bold);
            color: var(--color-text-main);
            margin: 0;
        }

        .od-chevron-icon {
            width: 18px;
            height: 18px;
            color: var(--color-text-muted);
            transition: transform var(--transition-fast);
            flex-shrink: 0;
        }

        .od-card.is-open .od-chevron-icon {
            transform: rotate(180deg);
        }

        .od-card-body {
            padding: var(--space-6);
            display: none;
        }

        .od-card.is-open .od-card-body {
            display: block;
        }

        .od-card-desc {
            font-size: var(--text-body-sm);
            color: var(--color-text-secondary);
            margin-bottom: var(--space-4);
        }

        /* Order Item Rows */
        .od-items-list {
            display: flex;
            flex-direction: column;
            gap: var(--space-4);
        }

        .od-item-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: var(--space-4);
            padding-bottom: var(--space-4);
            border-bottom: 1px solid var(--color-border-subtle);
        }

        .od-item-row:last-child {
            border-bottom: none;
            padding-bottom: 0;
        }

        .od-item-left {
            display: flex;
            align-items: center;
            gap: var(--space-4);
            min-width: 0;
        }

        .od-item-thumb-box {
            width: 64px;
            height: 64px;
            border-radius: var(--radius-md);
            background-color: var(--color-surface-subtle);
            border: 1px solid var(--color-border-subtle);
            overflow: hidden;
            flex-shrink: 0;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .od-item-img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            object-position: center;
        }

        .od-item-info {
            display: flex;
            flex-direction: column;
            gap: 4px;
            min-width: 0;
        }

        .od-item-category {
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--color-text-muted);
            font-weight: var(--weight-bold);
        }

        .od-item-name {
            font-size: var(--text-body);
            font-weight: var(--weight-bold);
            color: var(--color-text-main);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .od-item-variant-chips {
            display: flex;
            align-items: center;
            gap: var(--space-2);
            flex-wrap: wrap;
        }

        .od-item-variant-chip {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            font-size: var(--text-caption);
            color: var(--color-text-secondary);
            background-color: var(--color-surface-subtle);
            padding: 2px 8px;
            border-radius: var(--radius-pill);
            border: 1px solid var(--color-border-subtle);
        }

        .od-item-right {
            display: flex;
            align-items: center;
            gap: var(--space-4);
            flex-shrink: 0;
        }

        .od-item-qty-calc {
            display: inline-flex;
            align-items: center;
            padding: 4px 10px;
            background-color: var(--color-surface-subtle);
            border-radius: var(--radius-pill);
            font-size: var(--text-caption);
            font-weight: var(--weight-medium);
            color: var(--color-text-main);
            white-space: nowrap;
        }

        .od-item-total-price {
            font-size: var(--text-body);
            font-weight: var(--weight-bold);
            color: var(--color-text-main);
            min-width: 80px;
            text-align: right;
        }

        /* Financial Breakdown */
        .od-summary-table {
            display: flex;
            flex-direction: column;
            gap: var(--space-3);
        }

        .od-summary-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-size: var(--text-body-sm);
            color: var(--color-text-secondary);
        }

        .od-summary-row.od-summary-row--total {
            font-size: var(--text-body);
            font-weight: var(--weight-bold);
            color: var(--color-text-main);
            padding-top: var(--space-3);
            border-top: 2px solid var(--color-border-subtle);
            margin-top: var(--space-2);
        }

        .od-summary-row--total .od-summary-amount {
            font-size: var(--text-h3);
            font-weight: var(--weight-bold);
        }

        .od-summary-paid-box {
            margin-top: var(--space-4);
            padding-top: var(--space-4);
            border-top: 1px dashed var(--color-border-subtle);
            display: flex;
            flex-direction: column;
            gap: var(--space-2);
        }

        .od-summary-paid-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-size: var(--text-body-sm);
            color: var(--color-text-main);
        }

        .od-summary-paid-subtext {
            font-size: var(--text-caption);
            color: var(--color-text-muted);
        }

        /* Sidebar Panels (Customers, Contact, Shipping Address, Notes) */
        .od-sidebar-stack {
            display: flex;
            flex-direction: column;
            gap: var(--space-4);
        }

        .od-sidebar-card {
            background-color: var(--color-surface-card);
            border: 1px solid var(--color-border-subtle);
            border-radius: var(--radius-lg);
            padding: var(--space-5);
            box-shadow: var(--shadow-sm);
        }

        .od-sidebar-card-title {
            font-size: var(--text-body);
            font-weight: var(--weight-bold);
            color: var(--color-text-main);
            margin-bottom: var(--space-3);
            display: flex;
            align-items: center;
            gap: var(--space-2);
        }

        .od-sidebar-line {
            display: flex;
            align-items: center;
            gap: var(--space-2);
            font-size: var(--text-body-sm);
            color: var(--color-text-main);
            margin-bottom: 6px;
        }

        .od-sidebar-line:last-child {
            margin-bottom: 0;
        }

        .od-sidebar-line svg {
            width: 16px;
            height: 16px;
            color: var(--color-text-muted);
            flex-shrink: 0;
        }

        .od-sidebar-muted {
            font-size: var(--text-caption);
            color: var(--color-text-muted);
            margin-top: var(--space-2);
        }

        .od-address-block {
            font-size: var(--text-body-sm);
            line-height: 1.55;
            color: var(--color-text-secondary);
            margin-top: var(--space-2);
        }

        .od-map-link {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            margin-top: var(--space-3);
            font-size: var(--text-body-sm);
            font-weight: var(--weight-medium);
            color: var(--color-text-main);
            text-decoration: underline;
        }
    </style>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container od-page-container">
        <!-- 1. Top Header Navigation, Statuses & Actions -->
        <header class="od-header">
            <div class="od-header-left">
                <a href="Orders.aspx" class="btn-pill btn-pill--outline" style="width:fit-content;margin-bottom:var(--space-2);">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="15 18 9 12 15 6"></polyline>
                    </svg>
                    <span>Back to Orders</span>
                </a>
                <div class="od-header-title-row">
                    <h1 class="od-order-num"><asp:Literal ID="litOrderNumberTitle" runat="server" /></h1>
                    <div class="od-status-badges">
                        <asp:Literal ID="litHeaderBadges" runat="server" />
                    </div>
                </div>
                <div class="od-header-date-row">
                    <span><asp:Literal ID="litCreatedAt" runat="server" /></span>
                    <span>&bull;</span>
                    <span>Channel: <asp:Literal ID="litOrderSource" runat="server" /></span>
                </div>
            </div>

            <div class="od-header-actions">
                <% if (pnlOrderContent.Visible && OrderId > 0) { %>
                <button type="button" id="btn-view-order-receipt" class="btn-pill btn-pill--outline" data-order-id="<%= OrderId %>" aria-haspopup="dialog" aria-controls="order-receipt-dialog">View Receipt</button>
                <% } %>
                <asp:Literal ID="litActionButtons" runat="server" />
            </div>
        </header>

        <asp:Panel ID="pnlNotFound" runat="server" Visible="false">
            <div class="admin-empty-state">
                <div class="admin-empty-title">Order Not Found</div>
                <p>The requested order could not be located in the database.</p>
                <a href="Orders.aspx" class="btn-pill btn-pill--primary">Return to Orders List</a>
            </div>
        </asp:Panel>

        <asp:Panel ID="pnlOrderContent" runat="server">
            <!-- 2. Primary Layout: Left Stack (Order Items, Financial Summary) vs Right Stack (Customer, Contact, Shipping, Notes) -->
            <div class="od-workspace-grid">
                
                <!-- Left Stack -->
                <div class="od-main-column">
                    
                    <!-- Collapsible Order Item Section -->
                    <div class="od-card is-open" id="secOrderItems">
                        <div class="od-card-header" onclick="toggleCard('secOrderItems')">
                            <div class="od-card-title-wrap">
                                <h2 class="od-card-title">Order Item (<asp:Literal ID="litItemCount" runat="server" />)</h2>
                                <span class="admin-badge "><asp:Literal ID="litKpiOrderStatus" runat="server" /></span>
                            </div>
                            <svg class="od-chevron-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <polyline points="6 9 12 15 18 9"></polyline>
                            </svg>
                        </div>
                        <div class="od-card-body">
                            <div class="od-card-desc">Individual products and variant details included in this transaction.</div>
                            
                            <div class="od-items-list">
                                <asp:Repeater ID="rptOrderItems" runat="server">
                                    <ItemTemplate>
                                        <div class="od-item-row">
                                            <div class="od-item-left">
                                                <div class="od-item-thumb-box">
                                                    <img src='<%# ResolveItemImage(Eval("MainImageUrl")) %>' 
                                                         alt='<%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %>' 
                                                         class="od-item-img"
                                                         onerror="this.src='/Content/images/placeholder-helmet.png';" />
                                                </div>
                                                <div class="od-item-info">
                                                    <span class="od-item-category"><%# Server.HtmlEncode(Convert.ToString(Eval("SKU"))) %></span>
                                                    <span class="od-item-name"><%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %></span>
                                                    <div class="od-item-variant-chips">
                                                        <span class="od-item-variant-chip">Color: <strong><%# Server.HtmlEncode(Convert.ToString(Eval("Color"))) %></strong></span>
                                                        <span class="od-item-variant-chip">Size: <strong><%# Server.HtmlEncode(Convert.ToString(Eval("Size"))) %></strong></span>
                                                    </div>
                                                </div>
                                            </div>

                                            <div class="od-item-right">
                                                <span class="od-item-qty-calc">
                                                    <%# Eval("Quantity") %> &times; &#8369;<%# Convert.ToDecimal(Eval("UnitPrice")).ToString("N2") %>
                                                </span>
                                                <span class="od-item-total-price">
                                                    &#8369;<%# Convert.ToDecimal(Eval("TotalPrice")).ToString("N2") %>
                                                </span>
                                            </div>
                                        </div>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </div>

                        </div>
                    </div>

                    <!-- Collapsible Order Summary Section -->
                    <div class="od-card is-open" id="secOrderSummary">
                        <div class="od-card-header" onclick="toggleCard('secOrderSummary')">
                            <div class="od-card-title-wrap">
                                <h2 class="od-card-title">Order Summary</h2>
                                <span class="admin-badge admin-badge--neutral"><asp:Literal ID="litKpiPaymentStatus" runat="server" /></span>
                            </div>
                            <svg class="od-chevron-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <polyline points="6 9 12 15 18 9"></polyline>
                            </svg>
                        </div>
                        <div class="od-card-body">
                            <div class="od-card-desc">Review payment breakdown, applied discounts, delivery fees, and final balance.</div>
                            
                            <div class="od-summary-table">
                                <div class="od-summary-row">
                                    <span>Subtotal</span>
                                    <span><asp:Literal ID="litSummaryItemCount" runat="server" /> item(s)</span>
                                    <strong class="od-summary-amount">&#8369;<asp:Literal ID="litSubtotal" runat="server" /></strong>
                                </div>

                                <asp:PlaceHolder ID="phDiscount" runat="server" Visible="false">
                                    <div class="od-summary-row" style="color:var(--color-accent-red);">
                                        <span>Discount</span>
                                        <span>Promotional</span>
                                        <strong class="od-summary-amount">-&#8369;<asp:Literal ID="litDiscount" runat="server" /></strong>
                                    </div>
                                </asp:PlaceHolder>

                                <div class="od-summary-row">
                                    <span>Shipping</span>
                                    <span><asp:Literal ID="litKpiDeliveryMethod" runat="server" /></span>
                                    <strong class="od-summary-amount">&#8369;<asp:Literal ID="litDeliveryFee" runat="server" /></strong>
                                </div>

                                <div class="od-summary-row od-summary-row--total">
                                    <span>Total</span>
                                    <span class="od-summary-amount">&#8369;<asp:Literal ID="litTotalAmount" runat="server" /></span>
                                </div>
                            </div>

                            <div class="od-summary-paid-box">
                                <div class="od-summary-paid-row">
                                    <span>Paid by customer</span>
                                    <strong><asp:Literal ID="litPaidAmountText" runat="server">&#8369;0.00</asp:Literal></strong>
                                </div>
                                <div class="od-summary-paid-subtext">
                                    Payment Method: <asp:Literal ID="litPaymentMethod" runat="server" /> &bull; Status: <asp:Literal ID="litPaymentStatus" runat="server" />
                                </div>
                            </div>
                        </div>
                    </div>

                </div>

                <!-- Right Sidebar Stack (Customers, Contact, Shipping Address, Notes) -->
                <aside class="od-sidebar-stack">
                    
                    <!-- Notes Card (if available) -->
                    <asp:PlaceHolder ID="phNotes" runat="server" Visible="false">
                        <div class="od-sidebar-card">
                            <h3 class="od-sidebar-card-title">Notes</h3>
                            <div class="od-address-block">
                                <asp:Literal ID="litDeliveryNotes" runat="server" />
                            </div>
                        </div>
                    </asp:PlaceHolder>

                    <!-- Customers Card -->
                    <div class="od-sidebar-card">
                        <h3 class="od-sidebar-card-title">Customers</h3>
                        <div class="od-sidebar-line">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                                <circle cx="12" cy="7" r="4"></circle>
                            </svg>
                            <strong><asp:Literal ID="litCustomerName" runat="server" /></strong>
                        </div>
                        <div class="od-sidebar-line">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
                                <line x1="16" y1="2" x2="16" y2="6"></line>
                                <line x1="8" y1="2" x2="8" y2="6"></line>
                                <line x1="3" y1="10" x2="21" y2="10"></line>
                            </svg>
                            <span>Channel: <asp:Literal ID="litCustomerChannel" runat="server" /></span>
                        </div>
                        <div class="od-sidebar-muted">
                            Verified Storefront Customer
                        </div>
                    </div>

                    <!-- Contact Information Card -->
                    <div class="od-sidebar-card">
                        <h3 class="od-sidebar-card-title">Contact Information</h3>
                        <div class="od-sidebar-line">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"></path>
                                <polyline points="22,6 12,13 2,6"></polyline>
                            </svg>
                            <span><asp:Literal ID="litCustomerEmail" runat="server" /></span>
                        </div>
                        <div class="od-sidebar-line">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path>
                            </svg>
                            <span><asp:Literal ID="litCustomerPhone" runat="server" /></span>
                        </div>
                    </div>

                    <!-- Shipping / Pickup Address Card -->
                    <div class="od-sidebar-card">
                        <h3 class="od-sidebar-card-title">
                            <asp:Literal ID="litShippingSectionTitle" runat="server">Shipping Address</asp:Literal>
                        </h3>
                        <div class="od-sidebar-line">
                            <span class="admin-badge admin-badge--neutral" style="margin-bottom:var(--space-2);"><asp:Literal ID="litDeliveryMethod" runat="server" /></span>
                        </div>
                        <div class="od-sidebar-line">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                                <circle cx="12" cy="7" r="4"></circle>
                            </svg>
                            <strong><asp:Literal ID="litShippingRecipient" runat="server" /></strong>
                        </div>
                        <div class="od-address-block">
                            <asp:Literal ID="litFullAddress" runat="server" />
                            <asp:Literal ID="litDeliveryRegion" runat="server" Visible="false" />
                        </div>
                        <asp:PlaceHolder ID="phCourierInfo" runat="server" Visible="false">
                            <div class="od-sidebar-muted" style="margin-top:var(--space-3);padding-top:var(--space-2);border-top:1px solid var(--color-border-subtle);">
                                Courier: <strong><asp:Literal ID="litCourier" runat="server" /></strong><br />
                                Tracking: <code style="color:var(--color-text-main);"><asp:Literal ID="litTrackingNumber" runat="server" /></code>
                            </div>
                        </asp:PlaceHolder>
                    </div>

                </aside>

            </div>
        </asp:Panel>
    </div>

    <!-- Dispatch Courier Modal -->
    <div id="order-receipt-overlay" class="admin-modal-backdrop is-hidden" hidden>
        <section id="order-receipt-dialog" class="admin-modal hc-receipt-dialog" role="dialog" aria-modal="true" aria-labelledby="order-receipt-title">
            <header class="hc-receipt-dialog-header">
                <h2 id="order-receipt-title" class="admin-modal-title">Digital Sales Receipt</h2>
                <button type="button" id="btn-close-order-receipt" class="btn-pill btn-pill--outline" aria-label="Close receipt">&times;</button>
            </header>
            <div id="order-receipt-document" class="hc-receipt-dialog-body" aria-live="polite"></div>
            <footer class="hc-receipt-dialog-footer">
                <button type="button" id="btn-print-order-receipt" class="btn-pill btn-pill--outline" disabled>Print / Save Receipt</button>
            </footer>
        </section>
    </div>

    <div id="dispatchModal" class="admin-modal-backdrop is-hidden" hidden>
        <div class="admin-modal admin-modal--confirm" role="dialog" aria-modal="true" aria-labelledby="dispatchModalTitle">
            <h3 class="admin-modal-title" id="dispatchModalTitle">Dispatch Order</h3>
            <p class="admin-modal-desc-subtle">Enter courier delivery details for shipment dispatch.</p>
            <div class="order-detail-modal-body-stack" style="display:flex;flex-direction:column;gap:var(--space-3);margin:var(--space-4) 0;">
                <div>
                    <label class="order-detail-meta-label">Courier Name</label>
                    <asp:TextBox ID="txtCourier" runat="server" CssClass="admin-form-input" placeholder="e.g. J&amp;T Express, LBC, Flash Express" />
                </div>
                <div>
                    <label class="order-detail-meta-label">Tracking Number</label>
                    <asp:TextBox ID="txtTrackingNumber" runat="server" CssClass="admin-form-input" placeholder="e.g. JT123456789PH" />
                </div>
            </div>
            <div class="admin-modal-footer" style="display:flex;justify-content:flex-end;gap:var(--space-2);">
                <button type="button" class="btn-pill btn-pill--outline" onclick="closeDispatchModal();">Cancel</button>
                <asp:Button ID="btnConfirmDispatch" runat="server" CssClass="btn-pill btn-pill--primary" Text="Confirm Dispatch" OnClick="btnConfirmDispatch_Click" />
            </div>
        </div>
    </div>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script type="module" src="/Scripts/admin/order-receipt.js?v=20261003-2"></script>
    <script>
        function toggleCard(cardId) {
            var card = document.getElementById(cardId);
            if (card) {
                card.classList.toggle('is-open');
            }
        }

        function openDispatchModal() {
            var modal = document.getElementById('dispatchModal');
            if (modal) {
                modal.classList.remove('is-hidden');
                modal.removeAttribute('hidden');
            }
        }
        function closeDispatchModal() {
            var modal = document.getElementById('dispatchModal');
            if (modal) {
                modal.classList.add('is-hidden');
                modal.setAttribute('hidden', 'hidden');
            }
        }
    </script>
</asp:Content>
