using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
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
                // 1. Core KPIs
                var stats = await _adminRepo.GetDashboardStatsAsync().ConfigureAwait(false);
                int onHandQty = GetInt32(stats, "onHandStock");
                litOnHandStock.Text = onHandQty.ToString("N0");
                litOnHandStockTrend.Text = TrendHelper.RenderTrend(onHandQty, GetNullableInt32(stats, "yesterdayOnHandStock"), "previous day");

                int availQty = GetInt32(stats, "availableStock");
                litAvailableStock.Text = availQty.ToString("N0");
                litAvailableStockTrend.Text = TrendHelper.RenderTrend(availQty, GetNullableInt32(stats, "yesterdayAvailableStock"), "previous day");

                int lowStockCount = GetInt32(stats, "lowStockCount");
                litLowStock.Text = lowStockCount.ToString("N0");
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

                // 2. Sales Trend (Past 7 Days)
                DateTime now = DateTime.UtcNow;
                var sales = await _adminRepo.GetDailySalesAsync(now.AddDays(-7), now.AddDays(1)).ConfigureAwait(false);
                var salesMap = sales.ToDictionary(s => s.SalesDate.ToString("yyyy-MM-dd"), s => s.Revenue);

                var labels = new List<string>();
                var revenueValues = new List<decimal>();

                for (int i = 6; i >= 0; i--)
                {
                    DateTime d = now.AddDays(-i);
                    string key = d.ToString("yyyy-MM-dd");
                    labels.Add($"\"{d:MMM dd}\"");
                    revenueValues.Add(salesMap.TryGetValue(key, out var val) ? val : 0m);
                }

                SalesChartLabelsJson = "[" + string.Join(", ", labels) + "]";
                SalesChartDataJson = "[" + string.Join(", ", revenueValues) + "]";

                // 3. Brand Distribution
                var brands = await _adminRepo.GetInventoryReportAsync().ConfigureAwait(false);
                var brandLabels = brands.Select(b => $"\"{b.Brand}\"").ToList();
                var brandStock = brands.Select(b => b.AvailableStock).ToList();

                BrandChartLabelsJson = "[" + string.Join(", ", brandLabels) + "]";
                BrandChartDataJson = "[" + string.Join(", ", brandStock) + "]";

                // 4. Recent Operations Activity
                var activity = await _adminRepo.GetRecentActivityAsync(8).ConfigureAwait(false);
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

        protected string FormatActivityTime(object dateObj)
        {
            if (dateObj == null || dateObj == DBNull.Value) return "";
            if (DateTime.TryParse(Convert.ToString(dateObj), out var dt))
            {
                var diff = DateTime.UtcNow - dt.ToUniversalTime();
                if (diff.TotalMinutes < 60) return $"{(int)Math.Max(1, diff.TotalMinutes)}m ago";
                if (diff.TotalHours < 24) return $"{(int)diff.TotalHours}h ago";
                return dt.ToString("MMM dd, HH:mm");
            }
            return "";
        }
    }
}
