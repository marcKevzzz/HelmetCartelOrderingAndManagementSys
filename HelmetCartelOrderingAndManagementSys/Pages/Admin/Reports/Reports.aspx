<%@ Page Title="Analytics" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" CodeBehind="Reports.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.ReportsPage" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.2/dist/chart.umd.min.js"></script>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Page Heading & Actions -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Analytics &amp; Reports</h1>
            </div>
            <div class="admin-header-actions">
                <asp:Button ID="btnExportExcel" runat="server" Text="Export Excel Report (.xls)" CssClass="btn-pill btn-pill--primary" OnClick="btnExportExcel_Click" />
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
        <!-- 1. Sales Performance Analytics by Brand, Category, and Item -->
        <div class="admin-chart-card" id="salesPerformanceCard">
            <div class="admin-chart-header">
                <div>
                    <h2 class="admin-chart-title">Sales Performance Analytics</h2>
                    <span class="admin-chart-subtitle">Top 5 performers by brand, category, and helmet models</span>
                </div>
                <!-- Filter Controls (Dimension and Metric) -->
                <div class="admin-chart-controls">
                    <!-- View By -->
                    <div class="admin-segmented-tabs" id="viewByTabs" title="Dimension View">
                        <button type="button" class="admin-tab-btn active" data-view="item">Item</button>
                        <button type="button" class="admin-tab-btn" data-view="brand">Brand</button>
                        <button type="button" class="admin-tab-btn" data-view="category">Category</button>
                    </div>

                    <!-- Metric -->
                    <div class="admin-segmented-tabs" id="metricTabs" title="Primary Metric">
                        <button type="button" class="admin-tab-btn active" data-metric="units">Units Sold</button>
                        <button type="button" class="admin-tab-btn" data-metric="revenue">Revenue</button>
                        <button type="button" class="admin-tab-btn" data-metric="orders">Orders</button>
                    </div>
                </div>
            </div>

            <!-- Razor-Sharp Monochrome Vector Graph Container (Top 5) -->
            <div id="top5GraphContainer" class="admin-vector-graph-container"
                 data-items='<%= Server.HtmlEncode(SalesPerformanceJson) %>'>
                <!-- Dynamically rendered by JavaScript -->
            </div>
        </div>

        <!-- 2. Daily Sales Performance Log with Dual-Axis Velocity Chart & Table -->
        <div class="admin-chart-card" id="dailySalesPerformanceCard">
            <div class="admin-chart-header">
                <div>
                    <h2 class="admin-chart-title">Daily Sales Performance Log</h2>
                    <span class="admin-chart-subtitle">Itemized daily settlement records and revenue/order velocity</span>
                </div>
                <!-- View Switcher Tabs -->
                <div class="admin-segmented-tabs" id="dailySalesViewTabs">
                    <button type="button" class="admin-tab-btn active" data-view="chart">Velocity Chart</button>
                    <button type="button" class="admin-tab-btn" data-view="split">Split View</button>
                    <button type="button" class="admin-tab-btn" data-view="table">Table Log</button>
                </div>
            </div>

            <!-- Modern Spline Area + Column Velocity Chart -->
            <div id="dailySalesChartWrapper" class="admin-daily-sales-chart-wrapper"
                 data-labels='<%= Server.HtmlEncode(ChartLabelsJson) %>'
                 data-revenue='<%= Server.HtmlEncode(ChartRevenueJson) %>'
                 data-orders='<%= Server.HtmlEncode(ChartOrdersJson) %>'
                 data-daily-sales='<%= Server.HtmlEncode(DailySalesDetailsJson) %>'>
                <div class="admin-chart-body" style="height: 300px; position: relative;">
                    <canvas id="dailySalesVelocityChart"></canvas>
                </div>
            </div>

            <!-- Historical Breakdown Table Container -->
            <div id="dailySalesTableWrapper" class="admin-table-wrapper admin-table-wrapper--bounded admin-daily-sales-table-wrapper">
                <table class="admin-table">
                    <thead>
                        <tr>
                            <th>Sales Date</th>
                            <th>Completed Transactions</th>
                            <th>Gross Revenue</th>
                            <th class="admin-table-align-right">Average Order Value</th>
                            <th class="admin-table-align-right">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <asp:Repeater ID="rptDailySales" runat="server">
                            <ItemTemplate>
                                <tr class="admin-clickable-row js-daily-sales-row" data-date='<%# Convert.ToDateTime(Eval("SalesDate")).ToString("yyyy-MM-dd") %>' data-display='<%# Convert.ToDateTime(Eval("SalesDate")).ToString("MMMM dd, yyyy (dddd)") %>'>
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
                                    <td class="admin-table-align-right">
                                        <button type="button" class="admin-row-action-btn js-daily-sales-inspect-btn" data-date='<%# Convert.ToDateTime(Eval("SalesDate")).ToString("yyyy-MM-dd") %>' data-display='<%# Convert.ToDateTime(Eval("SalesDate")).ToString("MMMM dd, yyyy (dddd)") %>' title="Inspect itemized orders for this day">
                                            <span>Inspect</span> &rarr;
                                        </button>
                                    </td>
                                </tr>
                            </ItemTemplate>
                            <FooterTemplate>
                                <%# rptDailySales.Items.Count == 0 ? "<tr><td colspan='5'><div class='admin-empty-state'><div class='admin-empty-title'>No Sales Recorded</div><p class='admin-empty-desc'>No transactions found for the selected reporting period.</p></div></td></tr>" : "" %>
                            </FooterTemplate>
                        </asp:Repeater>
                    </tbody>
                </table>
            </div>

            <asp:Panel ID="pnlDailySalesPagination" runat="server" CssClass="admin-pagination-container" Visible="false">
                <div class="admin-pagination">
                    <asp:LinkButton ID="lnkDailySalesPrev" runat="server" CssClass="admin-pagination-btn" CommandArgument="prev" OnClick="DailySalesPage_Change">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="19" y1="12" x2="5" y2="12"></line><polyline points="12 5 5 12 12 19"></polyline></svg>
                        <span>Previous</span>
                    </asp:LinkButton>
                    <div class="admin-pagination-pages">
                        <asp:Repeater ID="rptDailySalesPages" runat="server">
                            <ItemTemplate>
                                <asp:LinkButton ID="btnDailySalesPage" runat="server" CommandArgument='<%# Eval("PageNumber") %>'
                                    CssClass='<%# "admin-pagination-page" + ((bool)Eval("IsCurrent") ? " active" : "") %>'
                                    Visible='<%# !(bool)Eval("IsEllipsis") %>' OnClick="DailySalesPage_Change"><%# Eval("PageNumber") %></asp:LinkButton>
                                <asp:Literal ID="litDailySalesPageEllipsis" runat="server" Text="&hellip;" Visible='<%# (bool)Eval("IsEllipsis") %>' />
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                    <asp:LinkButton ID="lnkDailySalesNext" runat="server" CssClass="admin-pagination-btn" CommandArgument="next" OnClick="DailySalesPage_Change">
                        <span>Next</span>
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
                    </asp:LinkButton>
                </div>
            </asp:Panel>
        </div>

        <!-- 3. Brand Inventory Breakdown Section with Stacked Health Bar -->
        <div class="admin-chart-card">
            <div class="admin-chart-header">
                <div>
                    <h2 class="admin-chart-title">Brand Inventory Health Breakdown</h2>
                    <span class="admin-chart-subtitle">Stock depth, variant coverage, and stockout risk by manufacturer</span>
                </div>
                <!-- Legend for Stock Health Bar -->
                <div class="stock-health-legend">
                    <span class="stock-health-legend__item"><span class="stock-health-legend__dot stock-health-legend__dot--healthy"></span>Healthy Stock</span>
                    <span class="stock-health-legend__item"><span class="stock-health-legend__dot stock-health-legend__dot--low"></span>Low Stock</span>
                    <span class="stock-health-legend__item"><span class="stock-health-legend__dot stock-health-legend__dot--reserved"></span>Reserved</span>
                </div>
            </div>

            <div class="admin-table-wrapper admin-table-wrapper--bounded">
                <table class="admin-table">
                    <thead>
                        <tr>
                            <th>Manufacturer / Brand</th>
                            <th>Variants (SKUs)</th>
                            <th>Total Units</th>
                            <th style="min-width: 240px;">Stock Health Distribution</th>
                            <th>Alert Status</th>
                            <th class="admin-table-align-right">Drilldown</th>
                        </tr>
                    </thead>
                    <tbody>
                        <asp:Repeater ID="rptBrandReport" runat="server" OnItemDataBound="rptBrandReport_ItemDataBound">
                            <ItemTemplate>
                                <tr class="admin-clickable-row js-brand-report-row" data-brand='<%# Server.HtmlEncode(Convert.ToString(Eval("Brand"))) %>'>
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
                                        <!-- Stacked Health Progress Bar (Bullet Chart) -->
                                        <div class="stock-health-bar-container">
                                            <div class="stock-health-bar" title='On-hand: <%# Eval("OnHandStock") %> | Available: <%# Eval("AvailableStock") %> | Low Stock: <%# Eval("LowStockCount") %>'>
                                                <div class="stock-health-bar__segment stock-health-bar__segment--healthy" style='width: <%# GetHealthyPercent(Convert.ToInt32(Eval("OnHandStock")), Convert.ToInt32(Eval("AvailableStock")), Convert.ToInt32(Eval("LowStockCount"))).ToString("F1", System.Globalization.CultureInfo.InvariantCulture) %>%;'></div>
                                                <div class="stock-health-bar__segment stock-health-bar__segment--low" style='width: <%# GetLowStockPercent(Convert.ToInt32(Eval("OnHandStock")), Convert.ToInt32(Eval("LowStockCount"))).ToString("F1", System.Globalization.CultureInfo.InvariantCulture) %>%;'></div>
                                                <div class="stock-health-bar__segment stock-health-bar__segment--reserved" style='width: <%# GetReservedPercent(Convert.ToInt32(Eval("OnHandStock")), Convert.ToInt32(Eval("AvailableStock"))).ToString("F1", System.Globalization.CultureInfo.InvariantCulture) %>%;'></div>
                                            </div>
                                            <div class="stock-health-bar__labels">
                                                <span class="stock-health-bar__stat"><strong class="admin-text-success"><%# Convert.ToInt32(Eval("AvailableStock")).ToString("N0") %></strong> Avail</span>
                                                <span class="stock-health-bar__stat"><strong class="admin-text-amber"><%# Convert.ToInt32(Eval("LowStockCount")).ToString("N0") %></strong> Low</span>
                                                <span class="stock-health-bar__stat"><strong class="admin-text-muted"><%# Math.Max(0, Convert.ToInt32(Eval("OnHandStock")) - Convert.ToInt32(Eval("AvailableStock"))).ToString("N0") %></strong> Rsvd</span>
                                            </div>
                                        </div>
                                    </td>
                                    <td>
                                        <%# Convert.ToInt32(Eval("AvailableStock")) <= 0 ? "<span class=\"admin-badge admin-badge--critical-alert\">Out of Stock</span>" :
                                            Convert.ToInt32(Eval("LowStockCount")) > 0 ? "<span class=\"admin-badge admin-badge--warning-alert\">" + Eval("LowStockCount") + " Low</span>" :
                                            "<span class=\"admin-badge admin-badge--in-stock\">Healthy</span>" %>
                                    </td>
                                    <td class="admin-table-align-right">
                                        <button type="button" class="admin-row-action-btn js-brand-drilldown-btn" data-brand='<%# Server.HtmlEncode(Convert.ToString(Eval("Brand"))) %>' title="Open brand inventory drilldown drawer">
                                            <span>Inspect</span> &rarr;
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

            <asp:Panel ID="pnlBrandReportPagination" runat="server" CssClass="admin-pagination-container" Visible="false">
                <div class="admin-pagination">
                    <asp:LinkButton ID="lnkBrandReportPrev" runat="server" CssClass="admin-pagination-btn" CommandArgument="prev" OnClick="BrandReportPage_Change">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="19" y1="12" x2="5" y2="12"></line><polyline points="12 5 5 12 12 19"></polyline></svg>
                        <span>Previous</span>
                    </asp:LinkButton>
                    <div class="admin-pagination-pages">
                        <asp:Repeater ID="rptBrandReportPages" runat="server">
                            <ItemTemplate>
                                <asp:LinkButton ID="btnBrandReportPage" runat="server" CommandArgument='<%# Eval("PageNumber") %>'
                                    CssClass='<%# "admin-pagination-page" + ((bool)Eval("IsCurrent") ? " active" : "") %>'
                                    Visible='<%# !(bool)Eval("IsEllipsis") %>' OnClick="BrandReportPage_Change"><%# Eval("PageNumber") %></asp:LinkButton>
                                <asp:Literal ID="litBrandReportPageEllipsis" runat="server" Text="&hellip;" Visible='<%# (bool)Eval("IsEllipsis") %>' />
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                    <asp:LinkButton ID="lnkBrandReportNext" runat="server" CssClass="admin-pagination-btn" CommandArgument="next" OnClick="BrandReportPage_Change">
                        <span>Next</span>
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
                    </asp:LinkButton>
                </div>
            </asp:Panel>
        </div>
    </div>

    <!-- Hidden Payload for Instant Client-Side Drilldown -->
    <div id="reportsDataPayload"
         data-brand-details='<%= Server.HtmlEncode(BrandInventoryDetailsJson) %>'
         data-brand-health='<%= Server.HtmlEncode(BrandHealthReportJson) %>'
         data-daily-sales='<%= Server.HtmlEncode(DailySalesDetailsJson) %>' hidden></div>

    <!-- 1. Daily Sales In-Page Inspection Drawer -->
    <div id="dailySalesDrawerBackdrop" class="admin-drawer-backdrop" hidden>
        <div id="dailySalesDrawer" class="admin-drawer admin-drawer--lg" role="dialog" aria-modal="true" aria-labelledby="dailySalesDrawerTitle">
            <div class="admin-drawer-header">
                <div>
                    <span class="admin-drawer-pretitle">Daily Settlement Drilldown</span>
                    <h2 id="dailySalesDrawerTitle" class="admin-drawer-title">Settled Transactions</h2>
                </div>
                <button type="button" class="admin-drawer-close-btn" id="btnDailySalesDrawerClose" aria-label="Close drawer">
                    <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                </button>
            </div>
            <div class="admin-drawer-body">
                <!-- Drawer KPIs -->
                <div class="admin-drawer-kpi-row" id="dailySalesDrawerKpis">
                    <div class="admin-drawer-kpi-pill">
                        <span class="admin-drawer-kpi-label">Gross Revenue</span>
                        <strong class="admin-drawer-kpi-value" id="drawerDailyRevenue">&#8369;0.00</strong>
                    </div>
                    <div class="admin-drawer-kpi-pill">
                        <span class="admin-drawer-kpi-label">Orders Settled</span>
                        <strong class="admin-drawer-kpi-value" id="drawerDailyOrders">0</strong>
                    </div>
                    <div class="admin-drawer-kpi-pill">
                        <span class="admin-drawer-kpi-label">Average Order Value</span>
                        <strong class="admin-drawer-kpi-value" id="drawerDailyAov">&#8369;0.00</strong>
                    </div>
                </div>

                <!-- Search / Filter -->
                <div class="admin-drawer-toolbar">
                    <div class="admin-drawer-search">
                        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
                        <input type="text" id="dailySalesSearchInput" placeholder="Filter orders by order #, customer, or payment..." class="admin-drawer-search-input" />
                    </div>
                </div>

                <!-- Orders Table Container -->
                <div class="admin-drawer-table-wrapper" id="dailySalesOrdersContainer">
                    <!-- Populated dynamically via JS -->
                </div>
            </div>
        </div>
    </div>

    <!-- 2. Brand Inventory In-Page Inspection Drawer -->
    <div id="brandInventoryDrawerBackdrop" class="admin-drawer-backdrop" hidden>
        <div id="brandInventoryDrawer" class="admin-drawer admin-drawer--lg" role="dialog" aria-modal="true" aria-labelledby="brandDrawerTitle">
            <div class="admin-drawer-header">
                <div>
                    <span class="admin-drawer-pretitle">Brand Inventory Health Breakdown</span>
                    <h2 id="brandDrawerTitle" class="admin-drawer-title">Brand Helmets &amp; SKUs</h2>
                </div>
                <button type="button" class="admin-drawer-close-btn" id="btnBrandDrawerClose" aria-label="Close drawer">
                    <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                </button>
            </div>
            <div class="admin-drawer-body">
                <!-- Drawer KPIs -->
                <div class="admin-drawer-kpi-row" id="brandDrawerKpis">
                    <div class="admin-drawer-kpi-pill">
                        <span class="admin-drawer-kpi-label">Active SKUs</span>
                        <strong class="admin-drawer-kpi-value" id="drawerBrandSkus">0</strong>
                    </div>
                    <div class="admin-drawer-kpi-pill">
                        <span class="admin-drawer-kpi-label">On-Hand Stock</span>
                        <strong class="admin-drawer-kpi-value" id="drawerBrandOnHand">0</strong>
                    </div>
                    <div class="admin-drawer-kpi-pill">
                        <span class="admin-drawer-kpi-label">Available Stock</span>
                        <strong class="admin-drawer-kpi-value" id="drawerBrandAvailable">0</strong>
                    </div>
                    <div class="admin-drawer-kpi-pill">
                        <span class="admin-drawer-kpi-label">Low Stock Alerts</span>
                        <strong class="admin-drawer-kpi-value" id="drawerBrandLowStock">0</strong>
                    </div>
                </div>

                <!-- Filters & Search -->
                <div class="admin-drawer-toolbar">
                    <div class="admin-drawer-search">
                        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
                        <input type="text" id="brandInventorySearchInput" placeholder="Filter variants by model, color, size, SKU..." class="admin-drawer-search-input" />
                    </div>
                    <div class="admin-segmented-tabs" id="brandInventoryFilterTabs">
                        <button type="button" class="admin-tab-btn active" data-filter="all">All Variants</button>
                        <button type="button" class="admin-tab-btn" data-filter="alert">At Risk / Low</button>
                        <button type="button" class="admin-tab-btn" data-filter="healthy">Healthy</button>
                    </div>
                </div>

                <!-- Inventory Items Table Container -->
                <div class="admin-drawer-table-wrapper" id="brandInventoryItemsContainer">
                    <!-- Populated dynamically via JS -->
                </div>
            </div>
        </div>
    </div>

    <!-- External Reports Scripts (Zero Inline JavaScript) -->
    <script src="/Scripts/admin/reports.js?v=4"></script>
</asp:Content>
