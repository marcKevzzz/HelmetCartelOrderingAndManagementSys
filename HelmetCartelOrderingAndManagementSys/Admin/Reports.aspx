<%@ Page Title="Analytics" Language="C#" MasterPageFile="~/Admin/Portal.master" AutoEventWireup="true" CodeBehind="Reports.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.ReportsPage" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.2/dist/chart.umd.min.js"></script>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Page Heading & Actions -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Analytics &amp; Intelligence</h1>
            </div>
            <div class="admin-header-actions">
                <asp:Button ID="btnExportReport" runat="server" Text="Export CSV" CssClass="btn-pill btn-pill--outline" OnClick="btnExportReport_Click" />
                <a href="/Admin/Dashboard.aspx" class="btn-pill btn-pill--primary">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <rect x="3" y="3" width="7" height="7"></rect>
                        <rect x="14" y="3" width="7" height="7"></rect>
                        <rect x="14" y="14" width="7" height="7"></rect>
                        <rect x="3" y="14" width="7" height="7"></rect>
                    </svg>
                    <span>View Dashboard</span>
                </a>
            </div>
        </div>

        <!-- Analytics Date Filter Bar -->
        <div class="admin-analytics-toolbar">
            <div class="admin-date-presets">
                <div class="admin-segmented-tabs">
                    <asp:LinkButton ID="btnPresetToday" runat="server" CssClass="admin-tab-btn" OnClick="btnPreset_Click" CommandArgument="today">Today</asp:LinkButton>
                    <asp:LinkButton ID="btnPresetWeek" runat="server" CssClass="admin-tab-btn" OnClick="btnPreset_Click" CommandArgument="week">This Week</asp:LinkButton>
                    <asp:LinkButton ID="btnPresetMonth" runat="server" CssClass="admin-tab-btn" OnClick="btnPreset_Click" CommandArgument="month">This Month</asp:LinkButton>
                    <asp:LinkButton ID="btnPreset30Days" runat="server" CssClass="admin-tab-btn" OnClick="btnPreset_Click" CommandArgument="30days">Last 30 Days</asp:LinkButton>
                    <asp:LinkButton ID="btnPresetCustom" runat="server" CssClass="admin-tab-btn" OnClick="btnPreset_Click" CommandArgument="custom">Custom Range</asp:LinkButton>
                </div>
            </div>

            <div class="admin-date-custom-group">
                <div class="admin-date-field">
                    <asp:TextBox ID="txtStartDate" runat="server" TextMode="Date" CssClass="admin-date-input" />
                </div>
                <div class="admin-date-field">
                    <label for="<%= txtEndDate.ClientID %>" class="admin-date-label">—</label>
                    <asp:TextBox ID="txtEndDate" runat="server" TextMode="Date" CssClass="admin-date-input" />
                </div>
                <asp:Button ID="btnApplyDateFilter" runat="server" Text="Apply Filter" CssClass="btn-pill btn-pill--primary" OnClick="btnApplyDateFilter_Click" />
            </div>
        </div>

        <!-- Inline Validation Alert for Date Errors -->
        <asp:Panel ID="pnlDateError" runat="server" Visible="false" CssClass="admin-alert admin-alert--error" role="alert">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="12" y1="8" x2="12" y2="12"></line>
                <line x1="12" y1="16" x2="12.01" y2="16"></line>
            </svg>
            <asp:Literal ID="litDateErrorMessage" runat="server" />
        </asp:Panel>

        <!-- Metric KPI Cards (Preserves selected date filter metrics) -->
        <div class="admin-kpi-grid">
            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Period Gross Revenue</div>
                <div class="admin-kpi-value">
                    &#8369;<asp:Literal ID="litTotalRevenue" runat="server">0.00</asp:Literal>
                </div>
                <asp:Literal ID="litTotalRevenueTrend" runat="server" />
                <div class="admin-kpi-desc">
                    <asp:Literal ID="litRevenueSubtitle" runat="server">Aggregated completed sales</asp:Literal>
                </div>
            </div>

            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Completed Orders</div>
                <div class="admin-kpi-value">
                    <asp:Literal ID="litTotalOrders" runat="server">0</asp:Literal>
                </div>
                <asp:Literal ID="litTotalOrdersTrend" runat="server" />
                <div class="admin-kpi-desc">Paid transactions in period</div>
            </div>

            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Average Order Value</div>
                <div class="admin-kpi-value">
                    &#8369;<asp:Literal ID="litAverageOrderValue" runat="server">0.00</asp:Literal>
                </div>
                <asp:Literal ID="litAovTrend" runat="server" />
                <div class="admin-kpi-desc">Mean revenue per order</div>
            </div>

            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Total Warehouse Units</div>
                <div class="admin-kpi-value">
                    <asp:Literal ID="litTotalUnits" runat="server">0</asp:Literal>
                </div>
                <asp:Literal ID="litTotalUnitsTrend" runat="server" />
                <div class="admin-kpi-desc">Physical inventory across brands</div>
            </div>

            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Active SKUs</div>
                <div class="admin-kpi-value">
                    <asp:Literal ID="litTotalVariants" runat="server">0</asp:Literal>
                </div>
                <asp:Literal ID="litTotalVariantsTrend" runat="server" />
                <div class="admin-kpi-desc">Color and size combinations</div>
            </div>
        </div>

        <!-- 1. Daily Sales & Revenue Trend Chart -->
        <div class="admin-chart-card">
            <div class="admin-chart-header">
                <div>
                    <h2 class="admin-chart-title">Revenue &amp; Order Velocity</h2>
                    <span class="admin-chart-subtitle">
                        <asp:Literal ID="litChartSubtitle" runat="server">Daily transaction trend for the selected period</asp:Literal>
                    </span>
                </div>
                <span class="admin-badge admin-badge--in-stock">
                    <asp:Literal ID="litActiveRangeBadge" runat="server">Last 30 Days</asp:Literal>
                </span>
            </div>
            <div class="admin-chart-body">
                <canvas id="analyticsRevenueChart" height="240" data-labels='<%= Server.HtmlEncode(ChartLabelsJson) %>' data-revenue='<%= Server.HtmlEncode(ChartRevenueJson) %>' data-orders='<%= Server.HtmlEncode(ChartOrdersJson) %>'></canvas>
            </div>
        </div>

        <!-- 2. Daily Sales Historical Breakdown Table -->
        <div class="admin-chart-card">
            <div class="admin-chart-header">
                <div>
                    <h2 class="admin-chart-title">Daily Sales Performance Log</h2>
                    <span class="admin-chart-subtitle">Itemized daily settlement records for the selected period</span>
                </div>
            </div>

            <div class="admin-table-wrapper admin-table-wrapper--bounded">
                <table class="admin-table">
                    <thead>
                        <tr>
                            <th>Sales Date</th>
                            <th>Completed Transactions</th>
                            <th>Gross Revenue</th>
                            <th class="admin-table-align-right">Average Order Value</th>
                        </tr>
                    </thead>
                    <tbody>
                        <asp:Repeater ID="rptDailySales" runat="server">
                            <ItemTemplate>
                                <tr>
                                    <td>
                                        <span class="admin-cell-sku admin-cell-bold">
                                            <%# Convert.ToDateTime(Eval("SalesDate")).ToString("MMMM dd, yyyy (dddd)") %>
                                        </span>
                                    </td>
                                    <td>
                                        <span class="admin-size-badge"><%# Eval("PaymentCount") %> orders</span>
                                    </td>
                                    <td>
                                        <span class="admin-cell-price">&#8369;<%# Convert.ToDecimal(Eval("Revenue")).ToString("N2") %></span>
                                    </td>
                                    <td class="admin-table-align-right">
                                        <span class="admin-cell-mono-muted">
                                            &#8369;<%# (Convert.ToDecimal(Eval("Revenue")) / Math.Max(1, Convert.ToInt32(Eval("PaymentCount")))).ToString("N2") %>
                                        </span>
                                    </td>
                                </tr>
                            </ItemTemplate>
                            <FooterTemplate>
                                <%# rptDailySales.Items.Count == 0 ? "<tr><td colspan='4'><div class='admin-empty-state'><div class='admin-empty-title'>No Sales Recorded</div><p class='admin-empty-desc'>No transactions found for the selected reporting period.</p></div></td></tr>" : "" %>
                            </FooterTemplate>
                        </asp:Repeater>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- 3. Brand Inventory Breakdown Section -->
        <div class="admin-chart-card">
            <div class="admin-chart-header">
                <div>
                    <h2 class="admin-chart-title">Brand Inventory Health Breakdown</h2>
                    <span class="admin-chart-subtitle">Stock depth, variant coverage, and stockout risk by manufacturer</span>
                </div>
            </div>

            <div class="admin-table-wrapper admin-table-wrapper--bounded">
                <table class="admin-table">
                    <thead>
                        <tr>
                            <th>Manufacturer / Brand</th>
                            <th>Variants (SKUs)</th>
                            <th>On-Hand Units</th>
                            <th>Available Units</th>
                            <th>Low Stock Alerts</th>
                            <th class="admin-table-align-right">Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        <asp:Repeater ID="rptBrandReport" runat="server" OnItemDataBound="rptBrandReport_ItemDataBound">
                            <ItemTemplate>
                                <tr>
                                    <td>
                                        <span class="admin-cell-brand admin-cell-brand-bold">
                                            <%# Server.HtmlEncode(Convert.ToString(Eval("Brand"))) %>
                                        </span>
                                    </td>
                                    <td>
                                        <span class="admin-size-badge"><%# Eval("VariantCount") %> SKUs</span>
                                    </td>
                                    <td>
                                        <span class="admin-cell-stock"><%# Convert.ToInt32(Eval("OnHandStock")).ToString("N0") %></span>
                                    </td>
                                    <td>
                                        <span class="admin-cell-stock admin-cell-bold"><%# Convert.ToInt32(Eval("AvailableStock")).ToString("N0") %></span>
                                    </td>
                                    <td>
                                        <%# Convert.ToInt32(Eval("LowStockCount")) > 0 ? "<span class=\"admin-badge admin-badge--low-stock\">" + Eval("LowStockCount") + " Low</span>" : "<span class=\"admin-badge admin-badge--in-stock\">Healthy (0)</span>" %>
                                    </td>
                                    <td class="admin-table-align-right">
                                        <button type="button" class="admin-row-action-btn js-brand-inventory-toggle" aria-expanded="false" aria-controls='brand-details-<%# Container.ItemIndex %>'>
                                            <span>View Inventory &darr;</span>
                                        </button>
                                    </td>
                                </tr>
                                <tr id='brand-details-<%# Container.ItemIndex %>' class="admin-brand-detail-row" hidden>
                                    <td colspan="6"><asp:Literal ID="litBrandDetails" runat="server" /></td>
                                </tr>
                            </ItemTemplate>
                        </asp:Repeater>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- External Reports Scripts (Zero Inline JavaScript) -->
    <script src="/Scripts/admin/reports.js?v=2"></script>
</asp:Content>
