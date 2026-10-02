<%@ Page Title="Orders" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" CodeBehind="Orders.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.OrdersPage" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Page Heading & Quick Stats -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Orders Management</h1>
            </div>
            <div class="admin-header-actions">
                <a href="/Admin/POS.aspx" class="btn-pill btn-pill--primary">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="5" x2="12" y2="19"></line>
                        <line x1="5" y1="12" x2="19" y2="12"></line>
                    </svg>
                    <span>New Walk-in Order</span>
                </a>
            </div>
        </div>

        <!-- Filter Sub-bar with Top Metadata -->
        <div class="admin-filters-bar">
            <div class="admin-filters-left">
                <!-- Segmented Filter Pills -->
                <div class="admin-segmented-tabs">
                    <asp:LinkButton ID="btnTabAll" runat="server" CssClass="admin-tab-btn" CommandArgument="all" OnClick="FilterTab_Click">All</asp:LinkButton>
                    <asp:LinkButton ID="btnTabProcessing" runat="server" CssClass="admin-tab-btn" CommandArgument="Processing" OnClick="FilterTab_Click">Processing</asp:LinkButton>
                    <asp:LinkButton ID="btnTabReady" runat="server" CssClass="admin-tab-btn" CommandArgument="ReadyForPickup" OnClick="FilterTab_Click">Ready for Pickup</asp:LinkButton>
                    <asp:LinkButton ID="btnTabShipped" runat="server" CssClass="admin-tab-btn" CommandArgument="Shipped" OnClick="FilterTab_Click">Shipped</asp:LinkButton>
                    <asp:LinkButton ID="btnTabCompleted" runat="server" CssClass="admin-tab-btn" CommandArgument="Completed" OnClick="FilterTab_Click">Completed</asp:LinkButton>
                    <asp:LinkButton ID="btnTabPending" runat="server" CssClass="admin-tab-btn" CommandArgument="PendingPayment" OnClick="FilterTab_Click">Pending Payment</asp:LinkButton>
                </div>

                <div class="admin-orders-date-filter">
                    <asp:TextBox ID="txtOrderDate" runat="server" TextMode="Date" CssClass="admin-date-input" aria-label="Filter orders by date" />
                    <asp:Button ID="btnApplyDateFilter" runat="server" Text="Apply Filter" CssClass="btn-pill btn-pill--primary admin-orders-date-filter__button" OnClick="ApplyDateFilter_Click" />
                </div>
            </div>

            <!-- Table Top Metadata -->
            <div class="admin-meta-top">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="admin-meta-top-icon">
                    <circle cx="12" cy="12" r="10"></circle>
                    <polyline points="12 6 12 12 16 14"></polyline>
                </svg>
                <span>Showing <asp:Literal ID="litShowingTop" runat="server">0</asp:Literal> of <asp:Literal ID="litTotalTop" runat="server">0</asp:Literal> orders</span>
            </div>
        </div>

        <!-- Independent Scrollable Responsive Orders Table Component -->
        <div class="admin-table-wrapper">
            <table class="admin-table admin-table-orders">
                <colgroup>
                    <col class="col-order-num" />
                    <col class="col-customer" />
                    <col style="min-width: 120px;" />
                    <col style="min-width: 100px;" />
                    <col style="min-width: 65px; width: 65px;" />
                    <col class="col-price" />
                    <col class="col-status" />
                    <col style="min-width: 130px; width: 150px;" />
                    <col style="min-width: 140px; width: 170px;" />
                    <col class="col-actions orders" />
                </colgroup>
                <thead>
                    <tr>
                        <th>Order #</th>
                        <th>Customer</th>
                        <th>Delivery</th>
                        <th>Source</th>
                        <th>Items</th>
                        <th>Total</th>
                        <th>Payment</th>
                        <th>Order Status</th>
                        <th>Date</th>
                        <th class="admin-table-align-right">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptOrders" runat="server" OnItemCommand="rptOrders_ItemCommand">
                        <ItemTemplate>
                            <tr>
                                <td>
                                    <span class="admin-cell-sku">
                                        <%# Server.HtmlEncode(Convert.ToString(Eval("OrderNumber"))) %>
                                    </span>
                                </td>
                                <td>
                                    <span class="admin-cell-name"><%# Server.HtmlEncode(Convert.ToString(Eval("CustomerName"))) %></span>
                                </td>
                                <td>
                                    <%# RenderDeliveryCell(Convert.ToString(Eval("ShippingMethod")), Convert.ToString(Eval("ShippingRegion")), Convert.ToString(Eval("Courier")), Convert.ToString(Eval("TrackingNumber"))) %>
                                </td>
                                <td>
                                    <%# RenderSourceBadge(Convert.ToString(Eval("OrderSource"))) %>
                                </td>
                                <td>
                                    <span class="admin-size-badge"><%# Eval("ItemCount") %></span>
                                </td>
                                <td>
                                    <span class="admin-cell-price">&#8369;<%# Convert.ToDecimal(Eval("TotalAmount")).ToString("N2") %></span>
                                </td>
                                <td>
                                    <%# RenderPaymentBadge(Convert.ToString(Eval("PaymentStatus")), Convert.ToString(Eval("PaymentMethod"))) %>
                                </td>
                                <td>
                                    <%# RenderStatusBadge(Convert.ToString(Eval("Status"))) %>
                                </td>
                                <td>
                                    <span class="admin-activity-time"><%# Convert.ToDateTime(Eval("CreatedAt")).ToString("MMM dd, yyyy HH:mm") %></span>
                                </td>
                                <td class="admin-table-align-right">
                                    <div class="admin-actions-cell admin-actions-cell--right">
                                        <a href='<%# "OrderDetail.aspx?id=" + Eval("Id") %>' class="btn-pill-sm btn-pill--outline" title="View Full Order Details">
                                            <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>
                                            <span>View</span>
                                        </a>
                                        <%# RenderTransitionButton(Convert.ToInt32(Eval("Id")), Convert.ToString(Eval("Status")), Convert.ToString(Eval("PaymentStatus")), Convert.ToString(Eval("ShippingMethod")), Convert.ToDecimal(Eval("TotalAmount")), Convert.ToString(Eval("PaymentMethod")), Convert.ToString(Eval("OrderNumber")), Convert.ToString(Eval("CustomerName")), Convert.ToString(Eval("ShippingCity"))) %>
                                    </div>
                                </td>
                            </tr>
                        </ItemTemplate>
                        <FooterTemplate>
                            <%# rptOrders.Items.Count == 0 ? "<tr><td colspan='10'><div class='admin-empty-state'><div class='admin-empty-title'>No Orders Found</div><p>No orders match the current status filter or search criteria.</p></div></td></tr>" : "" %>
                        </FooterTemplate>
                    </asp:Repeater>
                </tbody>
            </table>
        </div>

        <!-- Centered Pagination -->
        <asp:Panel ID="pnlOrdersPagination" runat="server" CssClass="admin-pagination-container" Visible="false">
            <div class="admin-pagination">
                <asp:LinkButton ID="lnkOrdersPrev" runat="server" CssClass="admin-pagination-btn" OnClick="OrdersPage_Change" CommandArgument="prev">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6"></polyline></svg>
                    <span>Previous</span>
                </asp:LinkButton>
                <div class="admin-pagination-pages">
                    <asp:Repeater ID="rptOrdersPages" runat="server">
                        <ItemTemplate>
                            <asp:PlaceHolder runat="server" Visible='<%# !(bool)Eval("IsEllipsis") %>'>
                                <asp:LinkButton runat="server" CssClass='<%# "admin-pagination-page " + Eval("CssClass") %>' 
                                    OnClick="OrdersPage_Change" CommandArgument='<%# Eval("Number") %>'>
                                    <%# Eval("Number") %>
                                </asp:LinkButton>
                            </asp:PlaceHolder>
                            <asp:PlaceHolder runat="server" Visible='<%# (bool)Eval("IsEllipsis") %>'>
                                <span class="admin-pagination-ellipsis">&hellip;</span>
                            </asp:PlaceHolder>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
                <asp:LinkButton ID="lnkOrdersNext" runat="server" CssClass="admin-pagination-btn" OnClick="OrdersPage_Change" CommandArgument="next">
                    <span>Next</span>
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
                </asp:LinkButton>
            </div>
        </asp:Panel>
    </div>

    <!-- Admin Order Dispatch Modal -->
    <div class="admin-modal-backdrop" id="dispatchModalBackdrop" style="display: none;">
        <div class="admin-modal admin-modal--sm" role="dialog" aria-modal="true" aria-labelledby="dispatchModalTitle">
            <div class="admin-modal-header">
                <h3 class="admin-modal-title" id="dispatchModalTitle">Dispatch Delivery Order</h3>
                <button type="button" class="admin-modal-close-btn" onclick="closeDispatchModal()" aria-label="Close modal">&times;</button>
            </div>
            <div class="admin-modal-body">
                <input type="hidden" id="dispatchOrderId" />
                <p class="admin-cell-mono-muted" id="dispatchOrderSummaryText">Order Reference</p>

                <div class="admin-form-group" style="margin-top: 12px;">
                    <label class="admin-form-label" for="dispatchCourier">Courier Partner *</label>
                    <select id="dispatchCourier" class="admin-form-select">
                        <option value="J&amp;T Express" selected>J&amp;T Express</option>
                        <option value="Lalamove">Lalamove</option>
                        <option value="Grab Express">Grab Express</option>
                        <option value="Ninjavan">Ninjavan</option>
                        <option value="Flash Express">Flash Express</option>
                        <option value="Other">Other / In-House Courier</option>
                    </select>
                </div>

                <div class="admin-form-group" style="margin-top: 12px;">
                    <label class="admin-form-label" for="dispatchTrackingNumber">Waybill / Tracking Number *</label>
                    <input type="text" id="dispatchTrackingNumber" class="admin-form-input" placeholder="e.g. JT782910482910" />
                    <span class="inline-error-msg" id="err-dispatch-tracking" style="display: none; color: var(--color-accent-red); font-size: 0.8rem; margin-top: 4px;"></span>
                </div>

                <div class="admin-form-group" style="margin-top: 12px;">
                    <label class="admin-form-label" for="dispatchNotes">Dispatch Notes (Optional)</label>
                    <input type="text" id="dispatchNotes" class="admin-form-input" placeholder="e.g. Handed to rider, parcel sealed" />
                </div>
            </div>
            <div class="admin-modal-footer admin-modal-actions-right" style="margin-top: 16px;">
                <button type="button" class="btn-pill btn-pill--outline" onclick="closeDispatchModal()">Cancel</button>
                <button type="button" class="btn-pill btn-pill--primary" id="btnConfirmDispatch" onclick="confirmDispatch()">
                    <span>Confirm Dispatch</span>
                </button>
            </div>
        </div>
    </div>

    <script src='<%= ResolveUrl("~/Scripts/admin/orders.js?v=1") %>'></script>
</asp:Content>
