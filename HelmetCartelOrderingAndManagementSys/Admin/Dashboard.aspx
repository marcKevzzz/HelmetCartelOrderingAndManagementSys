<%@ Page Title="Dashboard" Language="C#" MasterPageFile="~/Admin/Portal.master" AutoEventWireup="true" CodeBehind="Dashboard.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.DashboardPage" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.2/dist/chart.umd.min.js"></script>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Dashboard Title & Actions -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Operations Dashboard</h1>
            </div>
            <div class="admin-header-actions">
                <a href="/Admin/Inventory.aspx" class="btn-pill btn-pill--primary">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
                    </svg>
                    <span>Manage Inventory</span>
                </a>
                <a href="/Admin/Orders.aspx" class="btn-pill btn-pill--outline">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path>
                    </svg>
                    <span>View Orders</span>
                </a>
            </div>
        </div>

        <!-- Metric KPI Cards (Semantic CSS, Zero Inline Styles) -->
        <div class="admin-kpi-grid">
            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Total Stock</div>
                <div class="admin-kpi-value">
                    <asp:Literal ID="litOnHandStock" runat="server">0</asp:Literal>
                </div>
                <asp:Literal ID="litOnHandStockTrend" runat="server" />
                <div class="admin-kpi-desc">Physical units in warehouse</div>
            </div>

            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Available Stock</div>
                <div class="admin-kpi-value">
                    <asp:Literal ID="litAvailableStock" runat="server">0</asp:Literal>
                </div>
                <asp:Literal ID="litAvailableStockTrend" runat="server" />
                <div class="admin-kpi-desc">Ready for online & in-store sale</div>
            </div>

            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Low Stock Alerts</div>
                <div class="admin-kpi-value">
                    <asp:Literal ID="litLowStock" runat="server">0</asp:Literal>
                </div>
                <asp:Literal ID="litLowStockTrend" runat="server" />
                <div class="admin-kpi-desc">Variants at or below reorder threshold</div>
            </div>

            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Active Orders</div>
                <div class="admin-kpi-value">
                    <asp:Literal ID="litActiveOrders" runat="server">0</asp:Literal>
                </div>
                <asp:Literal ID="litActiveOrdersTrend" runat="server" />
                <div class="admin-kpi-desc">Pending fulfillment / ready for pickup</div>
            </div>

            <div class="admin-kpi-card">
                <div class="admin-kpi-label">Today's Revenue</div>
                <div class="admin-kpi-value">
                    &#8369;<asp:Literal ID="litTodayRevenue" runat="server">0.00</asp:Literal>
                </div>
                <asp:Literal ID="litTodayRevenueTrend" runat="server" />
                <div class="admin-kpi-desc">Online & POS completed sales today</div>
            </div>
        </div>

        <!-- Charts & Graphs Section -->
        <div class="admin-charts-grid">
            <!-- 1. Revenue & Sales Trend Line Chart -->
            <div class="admin-chart-card">
                <div class="admin-chart-header">
                    <div>
                        <h2 class="admin-chart-title">Revenue & Sales Velocity</h2>
                        <span class="admin-chart-subtitle">7-day performance across online and POS transactions</span>
                    </div>
                    <span class="admin-badge admin-badge--in-stock">Daily Aggregation</span>
                </div>
                <div class="admin-chart-body">
                    <canvas id="salesVelocityChart" height="230" data-labels='<%= Server.HtmlEncode(SalesChartLabelsJson) %>' data-values='<%= Server.HtmlEncode(SalesChartDataJson) %>'></canvas>
                </div>
            </div>

            <!-- 2. Stock Distribution Doughnut Chart -->
            <div class="admin-chart-card">
                <div class="admin-chart-header">
                    <div>
                        <h2 class="admin-chart-title">Inventory by Brand</h2>
                        <span class="admin-chart-subtitle">Stock allocation across certified helmet makers</span>
                    </div>
                </div>
                <div class="admin-chart-body">
                    <canvas id="brandDistributionChart" height="230" data-labels='<%= Server.HtmlEncode(BrandChartLabelsJson) %>' data-values='<%= Server.HtmlEncode(BrandChartDataJson) %>'></canvas>
                </div>
            </div>
        </div>

        <!-- Operations Activity Feed -->
        <div class="admin-chart-card">
            <div class="admin-chart-header">
                <div>
                    <h2 class="admin-chart-title">Recent Activity Feed</h2>
                    <span class="admin-chart-subtitle">Live audit logs of orders placed, status updates, and inventory movements</span>
                </div>
                <a href="/Admin/Orders.aspx" class="admin-nav-link admin-nav-link--inline">All Orders &rarr;</a>
            </div>
            <ul class="admin-activity-list">
                <asp:Repeater ID="rptRecentActivity" runat="server">
                    <ItemTemplate>
                        <li class="admin-activity-item">
                            <div class="admin-activity-meta">
                                <span class="admin-activity-ref"><%# Server.HtmlEncode(Convert.ToString(GetActivityValue(Container.DataItem, "reference"))) %></span>
                                <span class="admin-activity-detail"><%# Server.HtmlEncode(Convert.ToString(GetActivityValue(Container.DataItem, "detail"))) %></span>
                            </div>
                            <div class="admin-activity-side">
                                <span class="admin-badge admin-badge--low-stock"><%# Server.HtmlEncode(Convert.ToString(GetActivityValue(Container.DataItem, "activityType"))) %></span>
                                <span class="admin-activity-actor"><%# Server.HtmlEncode(Convert.ToString(GetActivityValue(Container.DataItem, "actor"))) %></span>
                                <span class="admin-activity-time"><%# FormatActivityTime(GetActivityValue(Container.DataItem, "createdAt")) %></span>
                            </div>
                        </li>
                    </ItemTemplate>
                    <FooterTemplate>
                        <%# rptRecentActivity.Items.Count == 0 ? "<li class='admin-empty-state admin-activity-empty'>No recent operations logged yet.</li>" : "" %>
                    </FooterTemplate>
                </asp:Repeater>
            </ul>
        </div>
    </div>

    <!-- External Dashboard Scripts (Zero Inline JavaScript) -->
    <script src="/Scripts/admin/dashboard.js?v=1"></script>
</asp:Content>
