<%@ Page Title="Order Details" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" CodeBehind="OrderDetail.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.Admin.Orders.OrderDetail" ResponseEncoding="utf-8" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <style>
        .order-detail-workspace {
            display: grid;
            grid-template-columns: minmax(0, 1.8fr) minmax(320px, 1.2fr);
            gap: var(--space-6);
            align-items: start;
            margin-top: var(--space-6);
        }
        @media (max-width: 1024px) {
            .order-detail-workspace {
                grid-template-columns: 1fr;
            }
        }
        .order-detail-thumb {
            width: 44px;
            height: 44px;
            border-radius: var(--radius-md);
            object-fit: cover;
            background: var(--color-surface-subtle);
            border: 1px solid var(--color-border);
            flex-shrink: 0;
        }
        .order-detail-meta-list {
            display: flex;
            flex-direction: column;
            gap: var(--space-3);
        }
        .order-detail-meta-row {
            display: flex;
            flex-direction: column;
            gap: 3px;
        }
        .order-detail-meta-label {
            font-size: 0.72rem;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: var(--color-text-subtle);
            font-weight: 600;
        }
        .order-detail-meta-value {
            font-size: 0.9375rem;
            color: var(--color-text);
            word-break: break-word;
        }
        .order-detail-summary-line {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: var(--space-2) 0;
            font-size: 0.9375rem;
            color: var(--color-text-subtle);
            border-bottom: 1px dashed var(--color-border);
        }
        .order-detail-summary-line--total {
            font-size: 1.125rem;
            font-weight: 700;
            color: var(--color-text);
            padding-top: var(--space-3);
            margin-top: var(--space-2);
            border-top: 2px solid var(--color-border);
            border-bottom: none;
        }
        .order-detail-address-box {
            padding: var(--space-3) var(--space-4);
            border-radius: var(--radius-md);
            background: var(--color-surface-subtle);
            border: 1px solid var(--color-border);
            font-size: 0.875rem;
            line-height: 1.5;
            color: var(--color-text);
        }
    </style>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- 1. Top Header & Breadcrumb Navigation -->
        <div class="admin-page-header">
            <div>
                <a href="Orders.aspx" class="btn-pill btn-pill--outline order-detail-back-link">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="15 18 9 12 15 6"></polyline>
                    </svg>
                    <span>Back to Orders</span>
                </a>
                <div class="admin-page-title-row">
                    <h1 class="admin-page-title order-detail-header-title">Order <asp:Literal ID="litOrderNumberTitle" runat="server" /></h1>
                    <asp:Literal ID="litHeaderBadges" runat="server" />
                </div>
                <div class="admin-page-subtitle">
                    Placed on <asp:Literal ID="litCreatedAt" runat="server" /> &bull; Channel: <asp:Literal ID="litOrderSource" runat="server" />
                </div>
            </div>
            <div class="admin-header-actions">
                <asp:Literal ID="litActionButtons" runat="server" />
            </div>
        </div>

        <asp:Panel ID="pnlNotFound" runat="server" Visible="false">
            <div class="admin-empty-state">
                <div class="admin-empty-title">Order Not Found</div>
                <p>The requested order could not be located in the database.</p>
                <a href="Orders.aspx" class="btn-pill btn-pill--primary">Return to Orders List</a>
            </div>
        </asp:Panel>

        <asp:Panel ID="pnlOrderContent" runat="server">
            <!-- 2. High-Level KPI Summary Strip: Delivery, Payment, Order Status, Date -->
            <div class="admin-kpi-grid">
                <div class="admin-kpi-card">
                    <div class="admin-kpi-label">Delivery</div>
                    <div class="admin-kpi-value order-detail-kpi-status-val">
                        <asp:Literal ID="litKpiDeliveryMethod" runat="server">-</asp:Literal>
                    </div>
                    <div class="admin-kpi-desc"><asp:Literal ID="litKpiDeliveryCity" runat="server">Fulfillment method</asp:Literal></div>
                </div>

                <div class="admin-kpi-card">
                    <div class="admin-kpi-label">Payment</div>
                    <div class="admin-kpi-value order-detail-kpi-status-val">
                        <asp:Literal ID="litKpiPaymentStatus" runat="server">-</asp:Literal>
                    </div>
                    <div class="admin-kpi-desc"><asp:Literal ID="litKpiPaymentMethod" runat="server">Payment Gateway</asp:Literal></div>
                </div>

                <div class="admin-kpi-card">
                    <div class="admin-kpi-label">Order Status</div>
                    <div class="admin-kpi-value order-detail-kpi-status-val">
                        <asp:Literal ID="litKpiOrderStatus" runat="server">-</asp:Literal>
                    </div>
                    <div class="admin-kpi-desc">Current fulfillment stage</div>
                </div>

                <div class="admin-kpi-card">
                    <div class="admin-kpi-label">Date</div>
                    <div class="admin-kpi-value order-detail-kpi-status-val">
                        <asp:Literal ID="litKpiOrderDate" runat="server">-</asp:Literal>
                    </div>
                    <div class="admin-kpi-desc"><asp:Literal ID="litKpiOrderTime" runat="server">Placed timestamp</asp:Literal></div>
                </div>
            </div>

            <!-- 3. Primary Workspace Grid (Left: Items & Pricing, Right: Customer & Delivery Details) -->
            <div class="order-detail-workspace">
                <!-- Left Column: Items Purchased & Financial Breakdown -->
                <div class="order-detail-column-stack">
                    <!-- Items Purchased Table Card -->
                    <div class="admin-card">
                        <div class="admin-panel-header order-detail-table-card-header">
                            <h2 class="admin-panel-title">Items Ordered (<asp:Literal ID="litItemCount" runat="server" />)</h2>
                        </div>
                        <div class="admin-table-wrapper">
                            <table class="admin-table order-detail">
                                <thead>
                                    <tr>
                                        <th>Item</th>
                                        <th>Variant</th>
                                        <th>SKU</th>
                                        <th class="admin-table-align-right">Unit Price</th>
                                        <th class="admin-table-align-center">Qty</th>
                                        <th class="admin-table-align-right">Line Total</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <asp:Repeater ID="rptOrderItems" runat="server">
                                        <ItemTemplate>
                                            <tr>
                                                <td>
                                                    <div class="order-detail-product-cell">
                                                        <img src='<%# ResolveItemImage(Eval("MainImageUrl")) %>' alt='<%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %>' class="order-detail-thumb" />
                                                        <span class="admin-cell-name"><%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %></span>
                                                    </div>
                                                </td>
                                                <td>
                                                    <div class="admin-variant-cell">
                                                        <span><%# Server.HtmlEncode(Convert.ToString(Eval("Color"))) %></span>
                                                        <span class="admin-size-badge"><%# Server.HtmlEncode(Convert.ToString(Eval("Size"))) %></span>
                                                    </div>
                                                </td>
                                                <td>
                                                    <span class="admin-cell-sku"><%# Server.HtmlEncode(Convert.ToString(Eval("SKU"))) %></span>
                                                </td>
                                                <td class="admin-table-align-right">
                                                    &#8369;<%# Convert.ToDecimal(Eval("UnitPrice")).ToString("N2") %>
                                                </td>
                                                <td class="admin-table-align-center">
                                                    <span class="admin-size-badge"><%# Eval("Quantity") %></span>
                                                </td>
                                                <td class="admin-table-align-right">
                                                    <strong class="admin-cell-price">&#8369;<%# Convert.ToDecimal(Eval("TotalPrice")).ToString("N2") %></strong>
                                                </td>
                                            </tr>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Financial Summary Card -->
                    <div class="admin-card order-detail-card-panel">
                        <h3 class="admin-panel-title order-detail-card-title">Financial Summary</h3>
                        <div class="order-detail-summary-line">
                            <span>Items Subtotal</span>
                            <span>&#8369;<asp:Literal ID="litSubtotal" runat="server" /></span>
                        </div>
                        <div class="order-detail-summary-line">
                            <span>Delivery Fee</span>
                            <span>&#8369;<asp:Literal ID="litDeliveryFee" runat="server" /></span>
                        </div>
                        <asp:PlaceHolder ID="phDiscount" runat="server" Visible="false">
                            <div class="order-detail-summary-line order-detail-discount-text">
                                <span>Applied Discount</span>
                                <span>-&#8369;<asp:Literal ID="litDiscount" runat="server" /></span>
                            </div>
                        </asp:PlaceHolder>
                        <div class="order-detail-summary-line order-detail-summary-line--total">
                            <span>Total Settlement</span>
                            <span class="admin-cell-price order-detail-total-price">&#8369;<asp:Literal ID="litTotalAmount" runat="server" /></span>
                        </div>
                    </div>

                    <!-- Delivery Instructions Card -->
                    <asp:PlaceHolder ID="phNotes" runat="server" Visible="false">
                        <div class="admin-card order-detail-card-panel">
                            <h3 class="admin-panel-title order-detail-card-title">Special Instructions &amp; Delivery Notes</h3>
                            <div class="order-detail-address-box">
                                <asp:Literal ID="litDeliveryNotes" runat="server" />
                            </div>
                        </div>
                    </asp:PlaceHolder>
                </div>

                <!-- Right Column: Customer Details, Delivery Info, Payment Info & Action Center -->
                <div class="order-detail-column-stack">
                    <!-- Customer Information Card -->
                    <div class="admin-card order-detail-card-panel">
                        <div class="admin-panel-header order-detail-card-header-clean">
                            <h3 class="admin-panel-title">Customer Information</h3>
                        </div>
                        <div class="order-detail-meta-list">
                            <div class="order-detail-meta-row">
                                <span class="order-detail-meta-label">Full Name</span>
                                <span class="order-detail-meta-value admin-cell-bold"><asp:Literal ID="litCustomerName" runat="server" /></span>
                            </div>
                            <div class="order-detail-meta-row">
                                <span class="order-detail-meta-label">Email Address</span>
                                <span class="order-detail-meta-value">
                                     <asp:Literal ID="litCustomerEmail" runat="server" />
                                </span>
                            </div>
                            <div class="order-detail-meta-row">
                                <span class="order-detail-meta-label">Phone Number</span>
                                <span class="order-detail-meta-value">
                                    <asp:Literal ID="litCustomerPhone" runat="server" />
                                </span>
                            </div>
                        </div>
                    </div>

                    <!-- Delivery & Logistics Card -->
                    <div class="admin-card order-detail-card-panel">
                        <div class="admin-panel-header order-detail-card-header-clean">
                            <h3 class="admin-panel-title">Delivery &amp; Logistics</h3>
                        </div>
                        <div class="order-detail-meta-list">
                            <div class="order-detail-meta-row">
                                <span class="order-detail-meta-label">Method</span>
                                <span class="order-detail-meta-value"><asp:Literal ID="litDeliveryMethod" runat="server" /></span>
                            </div>
                            <asp:PlaceHolder ID="phDeliveryAddress" runat="server">
                                <div class="order-detail-meta-row">
                                    <span class="order-detail-meta-label">Destination Address</span>
                                    <div class="order-detail-address-box">
                                        <asp:Literal ID="litFullAddress" runat="server" />
                                    </div>
                                </div>
                                <div class="order-detail-meta-row">
                                    <span class="order-detail-meta-label">Shipping Region</span>
                                    <span class="order-detail-meta-value"><asp:Literal ID="litDeliveryRegion" runat="server" /></span>
                                </div>
                            </asp:PlaceHolder>
                            <asp:PlaceHolder ID="phCourierInfo" runat="server" Visible="false">
                                <div class="order-detail-meta-row">
                                    <span class="order-detail-meta-label">Courier Partner</span>
                                    <span class="order-detail-meta-value admin-cell-bold"><asp:Literal ID="litCourier" runat="server" /></span>
                                </div>
                                <div class="order-detail-meta-row">
                                    <span class="order-detail-meta-label">Tracking Number</span>
                                    <span class="order-detail-meta-value"><span class="admin-cell-sku"><asp:Literal ID="litTrackingNumber" runat="server" /></span></span>
                                </div>
                            </asp:PlaceHolder>
                        </div>
                    </div>

                    <!-- Payment Information Card -->
                    <div class="admin-card order-detail-card-panel">
                        <div class="admin-panel-header order-detail-card-header-clean">
                            <h3 class="admin-panel-title">Payment Record</h3>
                        </div>
                        <div class="order-detail-meta-list">
                            <div class="order-detail-meta-row">
                                <span class="order-detail-meta-label">Payment Gateway / Method</span>
                                <span class="order-detail-meta-value"><asp:Literal ID="litPaymentMethod" runat="server" /></span>
                            </div>
                            <div class="order-detail-meta-row">
                                <span class="order-detail-meta-label">Payment Status</span>
                                <span class="order-detail-meta-value"><asp:Literal ID="litPaymentStatus" runat="server" /></span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </asp:Panel>
    </div>

    <!-- Dispatch Courier Modal -->
    <div id="dispatchModal" class="admin-modal-backdrop is-hidden" hidden>
        <div class="admin-modal admin-modal--confirm" role="dialog" aria-modal="true" aria-labelledby="dispatchModalTitle">
            <h3 class="admin-modal-title" id="dispatchModalTitle">Dispatch Order</h3>
            <p class="admin-modal-desc-subtle">Enter courier delivery details for shipment dispatch.</p>
            <div class="order-detail-modal-body-stack">
                <div>
                    <label class="order-detail-meta-label">Courier Name</label>
                    <asp:TextBox ID="txtCourier" runat="server" CssClass="admin-input" placeholder="e.g. J&amp;T Express, LBC, Flash Express" />
                </div>
                <div>
                    <label class="order-detail-meta-label">Tracking Number</label>
                    <asp:TextBox ID="txtTrackingNumber" runat="server" CssClass="admin-input" placeholder="e.g. JT123456789PH" />
                </div>
            </div>
            <div class="admin-modal-footer order-detail-modal-footer-gap">
                <button type="button" class="btn-pill btn-pill--outline" onclick="closeDispatchModal();">Cancel</button>
                <asp:Button ID="btnConfirmDispatch" runat="server" CssClass="btn-pill btn-pill--primary" Text="Confirm Dispatch" OnClick="btnConfirmDispatch_Click" />
            </div>
        </div>
    </div>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script>
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
