using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web;
using System.Web.UI;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Admin
{
    public partial class DashboardPage : Page
    {
        private readonly AdminDataRepository _adminRepo;

        public string SalesChartLabelsJson { get; set; } = "[]";
        public string SalesChartDataJson { get; set; } = "[]";
        public string DaySalesChartLabelsJson { get; set; } = "[]";
        public string DaySalesChartDataJson { get; set; } = "[]";
        public string WeekSalesChartLabelsJson { get; set; } = "[]";
        public string WeekSalesChartDataJson { get; set; } = "[]";
        public string MonthSalesChartLabelsJson { get; set; } = "[]";
        public string MonthSalesChartDataJson { get; set; } = "[]";
        public string BrandChartLabelsJson { get; set; } = "[]";
        public string BrandChartDataJson { get; set; } = "[]";

        public DashboardPage()
        {
            _adminRepo = new AdminDataRepository(new DbConnectionFactory());
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                RegisterAsyncTask(new PageAsyncTask(LoadDashboardDataAsync));
            }
        }

        private async Task LoadDashboardDataAsync()
        {
            try
            {
                DateTime now = DateTime.UtcNow;
                var statsTask = _adminRepo.GetDashboardStatsAsync();
                var hourlyTask = _adminRepo.GetHourlySalesAsync(now.Date);
                var dailyTask = _adminRepo.GetDailySalesAsync(now.AddDays(-30), now.AddDays(1));
                var brandsTask = _adminRepo.GetInventoryReportAsync();
                var activityTask = _adminRepo.GetRecentActivityAsync(8);
                await Task.WhenAll(statsTask, hourlyTask, dailyTask, brandsTask, activityTask).ConfigureAwait(false);
                var stats = await statsTask.ConfigureAwait(false);
                int onHandQty = GetInt32(stats, "onHandStock");
                litOnHandStock.Text = onHandQty.ToString("N0");
                litOnHandStockTrend.Text = TrendHelper.RenderTrend(onHandQty, GetNullableInt32(stats, "yesterdayOnHandStock"), "previous day");

                int availQty = GetInt32(stats, "availableStock");
                litAvailableStock.Text = availQty.ToString("N0");
                litAvailableStockTrend.Text = TrendHelper.RenderTrend(availQty, GetNullableInt32(stats, "yesterdayAvailableStock"), "previous day");

                int lowStockCount = GetInt32(stats, "lowStockCount");
                litLowStock.Text = lowStockCount > 0 ? $"<span class=\"admin-kpi-value--critical\">{lowStockCount:N0}</span>" : "0";
                litLowStockTrend.Text = TrendHelper.RenderTrend(
                    lowStockCount,
                    GetNullableInt32(stats, "yesterdayLowStockCount"),
                    "previous day",
                    invertSentiment: true);

                int activeOrders = GetInt32(stats, "activeOrders");
                litActiveOrders.Text = activeOrders.ToString("N0");
                litActiveOrdersTrend.Text = TrendHelper.RenderTrend(activeOrders, GetNullableInt32(stats, "yesterdayOrdersCount"), "yesterday");

                decimal todayRev = GetDecimal(stats, "todayRevenue");
                litTodayRevenue.Text = todayRev.ToString("N2");
                litTodayRevenueTrend.Text = TrendHelper.RenderTrend(todayRev, GetNullableDecimal(stats, "yesterdayRevenue"), "yesterday", isCurrency: true);

                // 2. Sales Trend (Day, Week, Month)
                // 2A. Day (Hourly breakdown for today)
                var hourlySales = await hourlyTask.ConfigureAwait(false);
                var hourlyMap = hourlySales.ToDictionary(h => h.SaleHour, h => h.Revenue);
                var dayLabels = new List<string>();
                var dayValues = new List<decimal>();
                for (int h = 0; h < 24; h++)
                {
                    DateTime time = DateTime.Today.AddHours(h);
                    dayLabels.Add($"\"{time:h tt}\"");
                    dayValues.Add(hourlyMap.TryGetValue(h, out var val) ? val : 0m);
                }
                DaySalesChartLabelsJson = "[" + string.Join(", ", dayLabels) + "]";
                DaySalesChartDataJson = "[" + string.Join(", ", dayValues) + "]";

                // 2B. Week (Past 7 Days)
                var weekSales = await dailyTask.ConfigureAwait(false);
                var weekSalesMap = weekSales.ToDictionary(s => s.SalesDate.ToString("yyyy-MM-dd"), s => s.Revenue);
                var weekLabels = new List<string>();
                var weekValues = new List<decimal>();
                for (int i = 6; i >= 0; i--)
                {
                    DateTime d = now.AddDays(-i);
                    string key = d.ToString("yyyy-MM-dd");
                    weekLabels.Add($"\"{d:MMM dd}\"");
                    weekValues.Add(weekSalesMap.TryGetValue(key, out var val) ? val : 0m);
                }
                SalesChartLabelsJson = "[" + string.Join(", ", weekLabels) + "]";
                SalesChartDataJson = "[" + string.Join(", ", weekValues) + "]";
                WeekSalesChartLabelsJson = SalesChartLabelsJson;
                WeekSalesChartDataJson = SalesChartDataJson;

                // 2C. Month (Past 30 Days)
                var monthSales = await dailyTask.ConfigureAwait(false);
                var monthSalesMap = monthSales.ToDictionary(s => s.SalesDate.ToString("yyyy-MM-dd"), s => s.Revenue);
                var monthLabels = new List<string>();
                var monthValues = new List<decimal>();
                for (int i = 29; i >= 0; i--)
                {
                    DateTime d = now.AddDays(-i);
                    string key = d.ToString("yyyy-MM-dd");
                    monthLabels.Add($"\"{d:MMM dd}\"");
                    monthValues.Add(monthSalesMap.TryGetValue(key, out var val) ? val : 0m);
                }
                MonthSalesChartLabelsJson = "[" + string.Join(", ", monthLabels) + "]";
                MonthSalesChartDataJson = "[" + string.Join(", ", monthValues) + "]";

                // 3. Brand Distribution
                var brands = await brandsTask.ConfigureAwait(false);
                var brandLabels = brands.Select(b => $"\"{b.Brand}\"").ToList();
                var brandStock = brands.Select(b => b.AvailableStock).ToList();

                BrandChartLabelsJson = "[" + string.Join(", ", brandLabels) + "]";
                BrandChartDataJson = "[" + string.Join(", ", brandStock) + "]";

                // 4. Recent Operations Activity
                var activity = await activityTask.ConfigureAwait(false);
                rptRecentActivity.DataSource = activity;
                rptRecentActivity.DataBind();
            }
            catch (Exception)
            {
                litOnHandStock.Text = "0";
                litOnHandStockTrend.Text = string.Empty;
                litAvailableStock.Text = "0";
                litAvailableStockTrend.Text = string.Empty;
                litLowStock.Text = "0";
                litLowStockTrend.Text = string.Empty;
                litActiveOrders.Text = "0";
                litActiveOrdersTrend.Text = string.Empty;
                litTodayRevenue.Text = "0.00";
                litTodayRevenueTrend.Text = string.Empty;
                SalesChartLabelsJson = "[]";
                SalesChartDataJson = "[]";
                BrandChartLabelsJson = "[]";
                BrandChartDataJson = "[]";
                rptRecentActivity.DataSource = Array.Empty<object>();
                rptRecentActivity.DataBind();
            }
        }

        private static int GetInt32(IReadOnlyDictionary<string, object> values, string key)
        {
            return GetNullableInt32(values, key) ?? 0;
        }

        private static int? GetNullableInt32(IReadOnlyDictionary<string, object> values, string key)
        {
            return values.TryGetValue(key, out var value) && value != null && value != DBNull.Value
                ? (int?)Convert.ToInt32(value)
                : null;
        }

        private static decimal GetDecimal(IReadOnlyDictionary<string, object> values, string key)
        {
            return GetNullableDecimal(values, key) ?? 0m;
        }

        private static decimal? GetNullableDecimal(IReadOnlyDictionary<string, object> values, string key)
        {
            return values.TryGetValue(key, out var value) && value != null && value != DBNull.Value
                ? (decimal?)Convert.ToDecimal(value)
                : null;
        }

        protected object GetActivityValue(object dataItem, string key)
        {
            if (dataItem is IReadOnlyDictionary<string, object> values && values.TryGetValue(key, out var value))
            {
                return value;
            }

            return null;
        }

        protected string FormatActivityDetail(object detail)
        {
            string text = Convert.ToString(detail) ?? string.Empty;
            return Server.HtmlEncode(text)
                .Replace("PHP ", "&#8369;")
                .Replace("â€¢", "&bull;")
                .Replace("•", "&bull;")
                .Replace("&amp;bull;", "&bull;");
        }

        protected string GetActivityIconMarkup(object activityType)
        {
            string type = Convert.ToString(activityType) ?? string.Empty;

            if (type.IndexOf("stock", StringComparison.OrdinalIgnoreCase) >= 0 ||
                type.IndexOf("inventory", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "<path d=\"M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z\"></path>" +
                       "<polyline points=\"3.27 6.96 12 12.01 20.73 6.96\"></polyline>" +
                       "<line x1=\"12\" y1=\"22.08\" x2=\"12\" y2=\"12\"></line>";
            }

            if (type.IndexOf("order", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "<path d=\"M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z\"></path>" +
                       "<line x1=\"3\" y1=\"6\" x2=\"21\" y2=\"6\"></line>" +
                       "<path d=\"M16 10a4 4 0 0 1-8 0\"></path>";
            }

            if (type.IndexOf("rma", StringComparison.OrdinalIgnoreCase) >= 0 ||
                type.IndexOf("return", StringComparison.OrdinalIgnoreCase) >= 0 ||
                type.IndexOf("exchange", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "<polyline points=\"1 4 1 10 7 10\"></polyline>" +
                       "<polyline points=\"23 20 23 14 17 14\"></polyline>" +
                       "<path d=\"M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15\"></path>";
            }

            if (type.IndexOf("review", StringComparison.OrdinalIgnoreCase) >= 0 ||
                type.IndexOf("rating", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "<polygon points=\"12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2\"></polygon>";
            }

            if (type.IndexOf("payment", StringComparison.OrdinalIgnoreCase) >= 0 ||
                type.IndexOf("refund", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "<rect x=\"1\" y=\"4\" width=\"22\" height=\"16\" rx=\"2\" ry=\"2\"></rect>" +
                       "<line x1=\"1\" y1=\"10\" x2=\"23\" y2=\"10\"></line>";
            }

            return "<polygon points=\"12 2 2 7 12 12 22 7 12 2\"></polygon>" +
                   "<polyline points=\"2 17 12 22 22 17\"></polyline>" +
                   "<polyline points=\"2 12 12 17 22 12\"></polyline>";
        }

        protected string FormatActivityTime(object dateObj)
        {
            if (dateObj == null || dateObj == DBNull.Value) return "";
            if (DateTime.TryParse(Convert.ToString(dateObj), out var dt))
            {
                DateTime utcDt = DateTime.SpecifyKind(dt, DateTimeKind.Utc);
                var diff = DateTime.UtcNow - utcDt;
                if (diff.TotalSeconds < 0) diff = TimeSpan.Zero;

                string relative;
                if (diff.TotalSeconds < 60)
                {
                    relative = "just now";
                }
                else if (diff.TotalMinutes < 60)
                {
                    relative = $"{(int)diff.TotalMinutes}m ago";
                }
                else if (diff.TotalHours < 24)
                {
                    relative = $"{(int)diff.TotalHours}h ago";
                }
                else
                {
                    relative = $"{(int)diff.TotalDays}d ago";
                }

                return $"{relative} &middot; {utcDt.ToLocalTime():MMM d, yyyy, h:mm tt}";
            }
            return "";
        }

        protected string GetActivityInspectUrl(object activityType, object reference)
        {
            string type = Convert.ToString(activityType) ?? string.Empty;
            string refVal = Convert.ToString(reference) ?? string.Empty;

            if (type.IndexOf("stock", StringComparison.OrdinalIgnoreCase) >= 0 ||
                type.IndexOf("inventory", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                if (string.IsNullOrWhiteSpace(refVal))
                    return "/Pages/Admin/Inventory/Inventory.aspx";

                if (refVal.StartsWith("PO-", StringComparison.OrdinalIgnoreCase) ||
                    refVal.IndexOf("RESTOCK", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return $"/Pages/Admin/Inventory/Inventory.aspx?view=audit&search={HttpUtility.UrlEncode(refVal)}";
                }

                return $"/Pages/Admin/Inventory/Inventory.aspx?search={HttpUtility.UrlEncode(refVal)}";
            }

            if (type.IndexOf("payment", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return string.IsNullOrWhiteSpace(refVal) 
                    ? "/Pages/Admin/Orders/Orders.aspx" 
                    : $"/Pages/Admin/Orders/OrderDetail.aspx?paymentRef={HttpUtility.UrlEncode(refVal)}";
            }

            if (type.IndexOf("order", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return string.IsNullOrWhiteSpace(refVal) 
                    ? "/Pages/Admin/Orders/Orders.aspx" 
                    : $"/Pages/Admin/Orders/OrderDetail.aspx?orderNumber={HttpUtility.UrlEncode(refVal)}";
            }

            if (type.IndexOf("rma", StringComparison.OrdinalIgnoreCase) >= 0 ||
                type.IndexOf("return", StringComparison.OrdinalIgnoreCase) >= 0 ||
                type.IndexOf("exchange", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return string.IsNullOrWhiteSpace(refVal) ? "/Pages/Admin/Returns/Returns.aspx" : $"/Pages/Admin/Returns/Returns.aspx?search={HttpUtility.UrlEncode(refVal)}";
            }

            if (type.IndexOf("review", StringComparison.OrdinalIgnoreCase) >= 0 ||
                type.IndexOf("rating", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                var match = System.Text.RegularExpressions.Regex.Match(refVal, @"\d+");
                return match.Success 
                    ? $"/Pages/Admin/Reviews/Reviews.aspx?reviewId={match.Value}" 
                    : "/Pages/Admin/Reviews/Reviews.aspx";
            }

            return string.IsNullOrWhiteSpace(refVal) ? "/Pages/Admin/Orders/Orders.aspx" : $"/Pages/Admin/Orders/Orders.aspx?search={HttpUtility.UrlEncode(refVal)}";
        }
    }
}
