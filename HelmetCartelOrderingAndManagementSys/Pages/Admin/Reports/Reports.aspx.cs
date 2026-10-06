using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using Newtonsoft.Json;

namespace HelmetCartelOrderingAndManagementSys.Admin
{
    public partial class ReportsPage : Page
    {
        public const int PageSize = 20;

        private readonly AdminDataRepository _adminRepo;
        private Dictionary<string, List<AdminBrandInventoryDetailDto>> _brandDetails =
            new Dictionary<string, List<AdminBrandInventoryDetailDto>>(StringComparer.OrdinalIgnoreCase);

        public string ActivePreset
        {
            get => (string)(ViewState["ActivePreset"] ?? "30days");
            set => ViewState["ActivePreset"] = value;
        }

        public string ChartLabelsJson { get; set; } = "[]";
        public string ChartRevenueJson { get; set; } = "[]";
        public string ChartOrdersJson { get; set; } = "[]";
        public string SalesPerformanceJson { get; set; } = "[]";
        public string BrandInventoryDetailsJson { get; set; } = "[]";
        public string DailySalesDetailsJson { get; set; } = "[]";
        public string BrandHealthReportJson { get; set; } = "[]";

        public static double GetHealthyPercent(int onHand, int available, int lowStock)
        {
            if (onHand <= 0) return 0.0;
            int healthy = Math.Max(0, available - lowStock);
            return Math.Min(100.0, Math.Max(0.0, ((double)healthy / onHand) * 100.0));
        }

        public static double GetLowStockPercent(int onHand, int lowStock)
        {
            if (onHand <= 0) return 0.0;
            return Math.Min(100.0, Math.Max(0.0, ((double)lowStock / onHand) * 100.0));
        }

        public static double GetReservedPercent(int onHand, int available)
        {
            if (onHand <= 0) return 0.0;
            int reserved = Math.Max(0, onHand - available);
            return Math.Min(100.0, Math.Max(0.0, ((double)reserved / onHand) * 100.0));
        }

        public int CurrentDailySalesPage
        {
            get => (ViewState["CurrentDailySalesPage"] as int?) ?? 1;
            set => ViewState["CurrentDailySalesPage"] = value;
        }

        public int CurrentBrandReportPage
        {
            get => (ViewState["CurrentBrandReportPage"] as int?) ?? 1;
            set => ViewState["CurrentBrandReportPage"] = value;
        }

        public ReportsPage()
        {
            _adminRepo = new AdminDataRepository(new DbConnectionFactory());
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                DateTime today = DateTime.Today;
                DateTime start = today.AddDays(-29);
                DateTime end = today;

                ActivePreset = "30days";
                txtStartDate.Text = start.ToString("yyyy-MM-dd");
                txtEndDate.Text = end.ToString("yyyy-MM-dd");

                RegisterAsyncTask(new PageAsyncTask(() => LoadReportsDataAsync(start, end)));
            }
        }

        protected void btnPreset_Click(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                string preset = btn.CommandArgument?.ToLowerInvariant() ?? "30days";
                DateTime today = DateTime.Today;
                DateTime start;
                DateTime end = today;

                switch (preset)
                {
                    case "today":
                        start = today;
                        end = today;
                        break;

                    case "week":
                        int diff = (7 + (today.DayOfWeek - DayOfWeek.Monday)) % 7;
                        start = today.AddDays(-1 * diff).Date;
                        break;

                    case "month":
                        start = new DateTime(today.Year, today.Month, 1);
                        break;

                    case "custom":
                ActivePreset = "custom";
                ResetTablePages();
                UpdatePresetButtons();
                return;

                    case "30days":
                    default:
                        preset = "30days";
                        start = today.AddDays(-29);
                        break;
                }

                ActivePreset = preset;
                ResetTablePages();
                txtStartDate.Text = start.ToString("yyyy-MM-dd");
                txtEndDate.Text = end.ToString("yyyy-MM-dd");
                pnlDateError.Visible = false;

                RegisterAsyncTask(new PageAsyncTask(() => LoadReportsDataAsync(start, end)));
            }
        }

        protected void btnApplyDateFilter_Click(object sender, EventArgs e)
        {
            string startStr = txtStartDate.Text?.Trim();
            string endStr = txtEndDate.Text?.Trim();

            if (string.IsNullOrEmpty(startStr) || string.IsNullOrEmpty(endStr))
            {
                ShowDateError("Please provide both start and end dates.");
                return;
            }

            if (!DateTime.TryParse(startStr, CultureInfo.InvariantCulture, DateTimeStyles.None, out DateTime startDate) ||
                !DateTime.TryParse(endStr, CultureInfo.InvariantCulture, DateTimeStyles.None, out DateTime endDate))
            {
                ShowDateError("Invalid date format. Please select valid calendar dates.");
                return;
            }

            if (startDate > endDate)
            {
                ShowDateError("Invalid date range: Start date must be on or before end date.");
                return;
            }

            ActivePreset = "custom";
            ResetTablePages();
            pnlDateError.Visible = false;

            RegisterAsyncTask(new PageAsyncTask(() => LoadReportsDataAsync(startDate, endDate)));
        }

        private void ShowDateError(string errorMessage)
        {
            pnlDateError.Visible = true;
            litDateErrorMessage.Text = Server.HtmlEncode(errorMessage);
            UpdatePresetButtons();

            string toastScript = $"if(window.showAdminToast){{window.showAdminToast({JsonConvert.SerializeObject(errorMessage)},'error','Date Range Error');}}";
            ScriptManager.RegisterStartupScript(this, GetType(), "dateFilterToastErr", toastScript, true);
        }

        private async Task LoadReportsDataAsync(DateTime startDate, DateTime endDate)
        {
            try
            {
                var brandTask = _adminRepo.GetInventoryReportAsync();
                var detailsTask = _adminRepo.GetBrandInventoryDetailsAsync();
                var trendTask = _adminRepo.GetInventoryTrendAsync(startDate, endDate);
                var salesTask = _adminRepo.GetDailySalesAsync(startDate.Date, endDate.Date.AddDays(1));
                var performanceTask = _adminRepo.GetSalesPerformanceAsync(startDate.Date, endDate.Date.AddDays(1));
                await Task.WhenAll(brandTask, detailsTask, trendTask, salesTask, performanceTask).ConfigureAwait(false);
                // 1. Load brand inventory health report
                var brandReport = await brandTask.ConfigureAwait(false);
                var details = await detailsTask.ConfigureAwait(false);
                _brandDetails = details.GroupBy(item => item.Brand, StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(group => group.Key, group => group.ToList(), StringComparer.OrdinalIgnoreCase);
                BrandHealthReportJson = JsonConvert.SerializeObject(brandReport);
                BrandInventoryDetailsJson = JsonConvert.SerializeObject(details);
                int brandTotalPages = Math.Max(1, (int)System.Math.Ceiling((double)brandReport.Count / PageSize));
                CurrentBrandReportPage = ClampPage(CurrentBrandReportPage, brandTotalPages);
                var pagedBrandReport = brandReport
                    .Skip((CurrentBrandReportPage - 1) * PageSize)
                    .Take(PageSize)
                    .ToList();

                rptBrandReport.DataSource = pagedBrandReport;
                rptBrandReport.DataBind();
                pnlBrandReportPagination.Visible = brandTotalPages > 1;
                BindReportPagination(
                    rptBrandReportPages,
                    lnkBrandReportPrev,
                    lnkBrandReportNext,
                    CurrentBrandReportPage,
                    brandTotalPages);

                var inventoryTrend = await trendTask.ConfigureAwait(false);
                string inventoryComparisonLabel = $"{startDate:MMM dd, yyyy} to {endDate:MMM dd, yyyy}";
                litTotalUnits.Text = inventoryTrend.EndTotalUnits.ToString("N0");
                litTotalUnitsTrend.Text = TrendHelper.RenderTrend(
                    inventoryTrend.EndTotalUnits,
                    inventoryTrend.StartTotalUnits,
                    inventoryComparisonLabel);
                litTotalVariants.Text = inventoryTrend.EndActiveSkus.ToString("N0");
                litTotalVariantsTrend.Text = TrendHelper.RenderTrend(
                    inventoryTrend.EndActiveSkus,
                    inventoryTrend.StartActiveSkus,
                    inventoryComparisonLabel);

                // 2. Load daily sales report for requested period
                // Adding 1 day to endDate because SQL sp_AdminSalesDaily uses: PaidAt < @EndDate
                var sales = await salesTask.ConfigureAwait(false);


                // Load item-level sales performance data
                var performanceItems = await performanceTask.ConfigureAwait(false);
                SalesPerformanceJson = JsonConvert.SerializeObject(performanceItems);



                decimal periodRevenue = sales.Sum(s => s.Revenue);
                int periodOrders = sales.Sum(s => s.PaymentCount);
                decimal aov = periodOrders > 0 ? (periodRevenue / periodOrders) : 0m;

                litTotalRevenue.Text = periodRevenue.ToString("N2");
                litTotalOrders.Text = periodOrders.ToString("N0");
                litAverageOrderValue.Text = aov.ToString("N2");

                // Calculate comparison period metrics for trend indicators
                DateTime prevStart;
                DateTime prevEnd;
                string compLabel;

                if (ActivePreset == "today")
                {
                    prevStart = startDate.Date.AddDays(-1);
                    prevEnd = startDate.Date.AddDays(-1);
                    compLabel = "yesterday";
                }
                else if (ActivePreset == "week")
                {
                    prevStart = startDate.Date.AddDays(-7);
                    prevEnd = startDate.Date.AddDays(-1);
                    compLabel = "prior week";
                }
                else if (ActivePreset == "month")
                {
                    prevStart = startDate.Date.AddMonths(-1);
                    prevEnd = startDate.Date.AddDays(-1);
                    compLabel = "prior month";
                }
                else if (ActivePreset == "30days")
                {
                    prevStart = startDate.Date.AddDays(-30);
                    prevEnd = startDate.Date.AddDays(-1);
                    compLabel = "prior 30 days";
                }
                else
                {
                    int spanDays = (endDate.Date - startDate.Date).Days + 1;
                    prevStart = startDate.Date.AddDays(-spanDays);
                    prevEnd = startDate.Date.AddDays(-1);
                    compLabel = $"prior {spanDays}d";
                }

                try
                {
                    var prevSales = await _adminRepo.GetDailySalesAsync(prevStart, prevEnd.AddDays(1)).ConfigureAwait(false);
                    decimal prevRevenue = prevSales.Sum(s => s.Revenue);
                    int prevOrders = prevSales.Sum(s => s.PaymentCount);
                    decimal prevAov = prevOrders > 0 ? (prevRevenue / prevOrders) : 0m;

                    litTotalRevenueTrend.Text = TrendHelper.RenderTrend(periodRevenue, prevRevenue, compLabel, isCurrency: true);
                    litTotalOrdersTrend.Text = TrendHelper.RenderTrend(periodOrders, prevOrders, compLabel);
                    litAovTrend.Text = TrendHelper.RenderTrend(aov, prevAov, compLabel, isCurrency: true);
                }
                catch
                {
                    litTotalRevenueTrend.Text = string.Empty;
                    litTotalOrdersTrend.Text = string.Empty;
                    litAovTrend.Text = string.Empty;
                }

                // 3. Prepare Chart.js data (ordered chronologically)
                var chronSales = sales.OrderBy(s => s.SalesDate).ToList();
                var labels = chronSales.Select(s => s.SalesDate.ToString("MMM dd")).ToArray();
                var revenues = chronSales.Select(s => s.Revenue).ToArray();
                var orderCounts = chronSales.Select(s => s.PaymentCount).ToArray();

                ChartLabelsJson = JsonConvert.SerializeObject(labels);
                ChartRevenueJson = JsonConvert.SerializeObject(revenues);
                ChartOrdersJson = JsonConvert.SerializeObject(orderCounts);

                // 4. Bind Daily Sales table (ordered descending)
                var descSales = sales.OrderByDescending(s => s.SalesDate).ToList();
                DailySalesDetailsJson = JsonConvert.SerializeObject(descSales.Select(s => new {
                    salesDate = s.SalesDate.ToString("yyyy-MM-dd"),
                    displayDate = s.SalesDate.ToString("MMMM dd, yyyy (dddd)"),
                    shortDate = s.SalesDate.ToString("MMM dd, yyyy"),
                    paymentCount = s.PaymentCount,
                    revenue = s.Revenue,
                    averageOrderValue = s.PaymentCount > 0 ? (s.Revenue / s.PaymentCount) : 0m
                }));
                int dailySalesTotalPages = Math.Max(1, (int)System.Math.Ceiling((double)descSales.Count / PageSize));
                CurrentDailySalesPage = ClampPage(CurrentDailySalesPage, dailySalesTotalPages);
                var pagedDailySales = descSales
                    .Skip((CurrentDailySalesPage - 1) * PageSize)
                    .Take(PageSize)
                    .ToList();

                rptDailySales.DataSource = pagedDailySales;
                rptDailySales.DataBind();
                pnlDailySalesPagination.Visible = dailySalesTotalPages > 1;
                BindReportPagination(
                    rptDailySalesPages,
                    lnkDailySalesPrev,
                    lnkDailySalesNext,
                    CurrentDailySalesPage,
                    dailySalesTotalPages);

                // 5. Update UI labels
                litRevenueSubtitle.Text = Server.HtmlEncode($"Settled revenue ({startDate:MMM dd} - {endDate:MMM dd})");

                UpdatePresetButtons();
            }
            catch (Exception)
            {
                litTotalUnits.Text = "0";
                litTotalUnitsTrend.Text = string.Empty;
                litTotalVariants.Text = "0";
                litTotalVariantsTrend.Text = string.Empty;
                litTotalRevenue.Text = "0.00";
                litTotalOrders.Text = "0";
                litAverageOrderValue.Text = "0.00";
                litTotalRevenueTrend.Text = string.Empty;
                litTotalOrdersTrend.Text = string.Empty;
                litAovTrend.Text = string.Empty;
                ChartLabelsJson = "[]";
                ChartRevenueJson = "[]";
                ChartOrdersJson = "[]";
                SalesPerformanceJson = "[]";
                BrandInventoryDetailsJson = "[]";
                BrandHealthReportJson = "[]";
                DailySalesDetailsJson = "[]";
            }
        }

        private static List<AdminSalesDimensionReportDto> PrepareSalesDimensionReport(
            IEnumerable<AdminSalesDimensionReportDto> reports)
        {
            var list = reports?.ToList() ?? new List<AdminSalesDimensionReportDto>();
            int topUnits = list.Count == 0 ? 0 : list.Max(report => report.UnitsSold);
            decimal topRevenue = list.Count == 0 ? 0m : list.Max(report => report.Revenue);

            foreach (var report in list)
            {
                report.IsTopSeller = topUnits > 0 && report.UnitsSold == topUnits;
                report.IsTopRevenue = topRevenue > 0m && report.Revenue == topRevenue;
            }

            return list
                .OrderByDescending(report => report.UnitsSold)
                .ThenByDescending(report => report.Revenue)
                .ThenBy(report => report.DimensionName)
                .ToList();
        }

        private static string BuildSalesWinnerSummary(string dimensionLabel, IEnumerable<AdminSalesDimensionReportDto> reports)
        {
            var list = reports?.ToList() ?? new List<AdminSalesDimensionReportDto>();
            if (list.Count == 0) return "No completed sales in the selected period.";

            var topSeller = list.FirstOrDefault(report => report.IsTopSeller);
            var topRevenue = list.FirstOrDefault(report => report.IsTopRevenue);
            if (topSeller == null) return "No completed sales in the selected period.";
            string label = HttpUtility.HtmlEncode(dimensionLabel);
            string summary = $"Top {label} by units: <strong>{HttpUtility.HtmlEncode(topSeller.DimensionName)}</strong> &mdash; {topSeller.UnitsSold:N0} units sold";

            if (topRevenue != null && !string.Equals(topRevenue.DimensionName, topSeller.DimensionName, StringComparison.OrdinalIgnoreCase))
            {
                summary += $" <span class=\"admin-sales-winner-secondary\">Top revenue: <strong>{HttpUtility.HtmlEncode(topRevenue.DimensionName)}</strong> &mdash; &#8369;{topRevenue.Revenue:N2}</span>";
            }

            return summary;
        }

        private void UpdatePresetButtons()
        {
            btnPresetToday.CssClass = ActivePreset == "today" ? "admin-tab-btn active" : "admin-tab-btn";
            btnPresetWeek.CssClass = ActivePreset == "week" ? "admin-tab-btn active" : "admin-tab-btn";
            btnPresetMonth.CssClass = ActivePreset == "month" ? "admin-tab-btn active" : "admin-tab-btn";
            btnPreset30Days.CssClass = ActivePreset == "30days" ? "admin-tab-btn active" : "admin-tab-btn";
            btnPresetCustom.CssClass = ActivePreset == "custom" ? "admin-tab-btn active" : "admin-tab-btn";
        }

        private void ResetTablePages()
        {
            CurrentDailySalesPage = 1;
            CurrentBrandReportPage = 1;
        }

        private static int ClampPage(int page, int totalPages)
        {
            return Math.Max(1, Math.Min(page, totalPages));
        }

        private void BindReportPagination(
            Repeater pagesRepeater,
            LinkButton previousButton,
            LinkButton nextButton,
            int currentPage,
            int totalPages)
        {
            previousButton.Enabled = currentPage > 1;
            previousButton.CssClass = "admin-pagination-btn" + (currentPage <= 1 ? " disabled" : "");
            nextButton.Enabled = currentPage < totalPages;
            nextButton.CssClass = "admin-pagination-btn" + (currentPage >= totalPages ? " disabled" : "");
            pagesRepeater.DataSource = PaginationHelper.BuildPageLinks(currentPage, totalPages, p => p.ToString());
            pagesRepeater.DataBind();
        }

        private bool TryGetSelectedReportDates(out DateTime startDate, out DateTime endDate)
        {
            bool validStart = DateTime.TryParse(txtStartDate.Text, CultureInfo.InvariantCulture, DateTimeStyles.None, out startDate);
            bool validEnd = DateTime.TryParse(txtEndDate.Text, CultureInfo.InvariantCulture, DateTimeStyles.None, out endDate);
            if (!validStart || !validEnd || startDate > endDate)
            {
                startDate = DateTime.Today.AddDays(-29);
                endDate = DateTime.Today;
                return false;
            }

            return true;
        }

        protected void DailySalesPage_Change(object sender, EventArgs e)
        {
            if (sender is LinkButton button)
            {
                CurrentDailySalesPage = GetTargetPage(button.CommandArgument, CurrentDailySalesPage);
                if (TryGetSelectedReportDates(out DateTime startDate, out DateTime endDate))
                {
                    RegisterAsyncTask(new PageAsyncTask(() => LoadReportsDataAsync(startDate, endDate)));
                }
            }
        }

        protected void BrandReportPage_Change(object sender, EventArgs e)
        {
            if (sender is LinkButton button)
            {
                CurrentBrandReportPage = GetTargetPage(button.CommandArgument, CurrentBrandReportPage);
                if (TryGetSelectedReportDates(out DateTime startDate, out DateTime endDate))
                {
                    RegisterAsyncTask(new PageAsyncTask(() => LoadReportsDataAsync(startDate, endDate)));
                }
            }
        }

        private static int GetTargetPage(string commandArgument, int currentPage)
        {
            if (string.Equals(commandArgument, "prev", StringComparison.OrdinalIgnoreCase))
            {
                return Math.Max(1, currentPage - 1);
            }
            if (string.Equals(commandArgument, "next", StringComparison.OrdinalIgnoreCase))
            {
                return currentPage + 1;
            }
            return int.TryParse(commandArgument, out int page) && page > 0 ? page : currentPage;
        }

        protected void rptBrandReport_ItemDataBound(object sender, RepeaterItemEventArgs e)
        {
            if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem) return;
            var report = e.Item.DataItem as AdminBrandReportDto;
            var target = e.Item.FindControl("litBrandDetails") as Literal;
            if (report == null || target == null) return;
            if (report.LowStockCount <= 0) return;
            if (!_brandDetails.TryGetValue(report.Brand, out var variants) || variants.Count == 0)
            {
                target.Text = "<div class=\"admin-brand-details-empty\">No inventory items found for this brand.</div>";
                return;
            }

            var html = new StringBuilder();
            html.Append("<div class=\"admin-brand-details\">");
            foreach (var product in variants.Where(item => item.AvailableStock <= item.ReorderPoint).GroupBy(item => item.ProductId))
            {
                var first = product.First();
                var image = first.MainImageUrl;
                if (string.IsNullOrWhiteSpace(image) ||
                    (!image.StartsWith("/", StringComparison.Ordinal) && !image.StartsWith("https://", StringComparison.OrdinalIgnoreCase)))
                    image = "/Content/images/placeholder-helmet.png";
                html.Append("<section class=\"admin-brand-product\"><div class=\"admin-brand-product-head\">")
                    .Append("<img src=\"").Append(HttpUtility.HtmlAttributeEncode(image)).Append("\" alt=\"")
                    .Append(HttpUtility.HtmlAttributeEncode(first.ProductName)).Append("\" loading=\"lazy\" />")
                    .Append("<div><strong>").Append(HttpUtility.HtmlEncode(first.ProductName)).Append("</strong><span>")
                    .Append(HttpUtility.HtmlEncode(first.CategoryName)).Append("</span></div></div>")
                    .Append("<div class=\"admin-brand-variant-list\">");

                foreach (var item in product)
                {
                    var status = item.AvailableStock <= 0 ? "Out of Stock" :
                        item.AvailableStock <= item.ReorderPoint ? "Low Stock" : "In Stock";
                    var statusClass = item.AvailableStock <= 0 ? "admin-brand-variant-status admin-brand-variant-status--out-of-stock" :
                        item.AvailableStock <= item.ReorderPoint ? "admin-brand-variant-status admin-brand-variant-status--low-stock" : "admin-brand-variant-status";
                    var stockClass = item.AvailableStock <= 0 ? "admin-cell-stock--critical" :
                        item.AvailableStock <= item.ReorderPoint ? "admin-cell-stock--low-stock" : "";

                    html.Append("<div class=\"admin-brand-variant\">")
                        .Append("<div><strong>").Append(HttpUtility.HtmlEncode(item.Color)).Append(" / ")
                        .Append(HttpUtility.HtmlEncode(item.Size)).Append("</strong><span>")
                        .Append(HttpUtility.HtmlEncode(item.SKU)).Append("</span></div>")
                        .Append("<span>On hand <strong>").Append(item.OnHandStock.ToString("N0"))
                        .Append("</strong></span><span>Available <strong class=\"").Append(stockClass).Append("\">").Append(item.AvailableStock.ToString("N0"))
                        .Append("</strong></span><span>Reorder at <strong>").Append(item.ReorderPoint.ToString("N0"))
                        .Append("</strong></span><span class=\"").Append(statusClass).Append("\">")
                        .Append(status).Append("</span><a href=\"/Admin/Inventory.aspx?productId=")
                        .Append(item.ProductId).Append("&amp;variantId=").Append(item.VariantId)
                        .Append("\" class=\"admin-row-action-btn\">Open item &rarr;</a></div>");
                }
                html.Append("</div></section>");
            }
            html.Append("</div>");
            target.Text = html.ToString();
        }

        protected void btnExportExcel_Click(object sender, EventArgs e)
        {
            RegisterAsyncTask(new PageAsyncTask(async () =>
            {
                TryGetSelectedReportDates(out DateTime startDate, out DateTime endDate);
                var brandTask = _adminRepo.GetInventoryReportAsync();
                var detailsTask = _adminRepo.GetBrandInventoryDetailsAsync();
                var salesTask = _adminRepo.GetDailySalesAsync(startDate.Date, endDate.Date.AddDays(1));
                var trendTask = _adminRepo.GetInventoryTrendAsync(startDate, endDate);
                var dashboardStatsTask = _adminRepo.GetDashboardStatsAsync();
                var salesBreakdownTask = _adminRepo.GetSalesByBrandAndCategoryAsync(startDate.Date, endDate.Date.AddDays(1));
                var performanceTask = _adminRepo.GetSalesPerformanceAsync(startDate.Date, endDate.Date.AddDays(1));

                await Task.WhenAll(brandTask, detailsTask, salesTask, trendTask, dashboardStatsTask, salesBreakdownTask, performanceTask).ConfigureAwait(false);

                var brandReport = await brandTask.ConfigureAwait(false);
                var details = await detailsTask.ConfigureAwait(false);
                var sales = await salesTask.ConfigureAwait(false);
                var inventoryTrend = await trendTask.ConfigureAwait(false);
                var dashboardStats = await dashboardStatsTask.ConfigureAwait(false);
                var salesBreakdown = await salesBreakdownTask.ConfigureAwait(false);
                var performanceItems = await performanceTask.ConfigureAwait(false);

                var brandSales = PrepareSalesDimensionReport(salesBreakdown.Brands);
                var categorySales = PrepareSalesDimensionReport(salesBreakdown.Categories);

                decimal periodRevenue = sales.Sum(s => s.Revenue);
                int periodOrders = sales.Sum(s => s.PaymentCount);
                decimal aov = periodOrders > 0 ? (periodRevenue / periodOrders) : 0m;
                int totalWarehouseUnits = inventoryTrend.EndTotalUnits;
                int activeSkus = inventoryTrend.EndActiveSkus;
                int totalOnHand = brandReport.Sum(b => b.OnHandStock);
                int totalAvailable = brandReport.Sum(b => b.AvailableStock);
                int totalLowStockCount = brandReport.Sum(b => b.LowStockCount);
                int outOfStockVariants = details.Count(d => d.AvailableStock <= 0);

                decimal todayRevenue = dashboardStats != null && dashboardStats.TryGetValue("todayRevenue", out var tr) && tr != null && tr != DBNull.Value ? Convert.ToDecimal(tr) : 0m;
                int activeOrders = dashboardStats != null && dashboardStats.TryGetValue("activeOrders", out var ao) && ao != null && ao != DBNull.Value ? Convert.ToInt32(ao) : 0;

                var sb = new StringBuilder();
                sb.AppendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>");
                sb.AppendLine("<?mso-application progid=\"Excel.Sheet\"?>");
                sb.AppendLine("<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\"");
                sb.AppendLine(" xmlns:o=\"urn:schemas-microsoft-com:office:office\"");
                sb.AppendLine(" xmlns:x=\"urn:schemas-microsoft-com:office:excel\"");
                sb.AppendLine(" xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\"");
                sb.AppendLine(" xmlns:html=\"http://www.w3.org/TR/REC-html40\">");

                // Styles
                sb.AppendLine(" <Styles>");
                sb.AppendLine("  <Style ss:ID=\"Default\" ss:Name=\"Normal\"><Alignment ss:Vertical=\"Center\"/><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Color=\"#18181B\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"Header\"><Alignment ss:Horizontal=\"Left\" ss:Vertical=\"Center\"/><Borders><Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#D4D4D8\"/></Borders><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/><Interior ss:Color=\"#F4F4F5\" ss:Pattern=\"Solid\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"HeaderRight\"><Alignment ss:Horizontal=\"Right\" ss:Vertical=\"Center\"/><Borders><Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#D4D4D8\"/></Borders><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/><Interior ss:Color=\"#F4F4F5\" ss:Pattern=\"Solid\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"HeaderCenter\"><Alignment ss:Horizontal=\"Center\" ss:Vertical=\"Center\"/><Borders><Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#D4D4D8\"/></Borders><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/><Interior ss:Color=\"#F4F4F5\" ss:Pattern=\"Solid\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"Title\"><Font ss:FontName=\"Segoe UI\" ss:Size=\"14\" ss:Bold=\"1\" ss:Color=\"#09090B\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"Subtitle\"><Font ss:FontName=\"Segoe UI\" ss:Size=\"9\" ss:Italic=\"1\" ss:Color=\"#71717A\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"SectionHeader\"><Font ss:FontName=\"Segoe UI\" ss:Size=\"11\" ss:Bold=\"1\" ss:Color=\"#18181B\"/><Interior ss:Color=\"#E4E4E7\" ss:Pattern=\"Solid\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"Bold\"><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"BoldCenter\"><Alignment ss:Horizontal=\"Center\"/><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"Center\"><Alignment ss:Horizontal=\"Center\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"Currency\"><Alignment ss:Horizontal=\"Right\"/><NumberFormat ss:Format=\"&quot;PHP &quot;#,##0.00\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"CurrencyBold\"><Alignment ss:Horizontal=\"Right\"/><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/><NumberFormat ss:Format=\"&quot;PHP &quot;#,##0.00\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"Integer\"><Alignment ss:Horizontal=\"Right\"/><NumberFormat ss:Format=\"#,##0\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"IntegerBold\"><Alignment ss:Horizontal=\"Right\"/><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/><NumberFormat ss:Format=\"#,##0\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"Percent\"><Alignment ss:Horizontal=\"Right\"/><NumberFormat ss:Format=\"0.0%\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"PercentBold\"><Alignment ss:Horizontal=\"Right\"/><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/><NumberFormat ss:Format=\"0.0%\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"DateStyle\"><Alignment ss:Horizontal=\"Center\"/><NumberFormat ss:Format=\"yyyy-mm-dd\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"AlertRed\"><Alignment ss:Horizontal=\"Center\"/><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#DC2626\"/><Interior ss:Color=\"#FEE2E2\" ss:Pattern=\"Solid\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"AlertAmber\"><Alignment ss:Horizontal=\"Center\"/><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#D97706\"/><Interior ss:Color=\"#FEF3C7\" ss:Pattern=\"Solid\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"AlertGreen\"><Alignment ss:Horizontal=\"Center\"/><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#16A34A\"/><Interior ss:Color=\"#DCFCE7\" ss:Pattern=\"Solid\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"BadgeTop\"><Alignment ss:Horizontal=\"Center\"/><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#15803D\"/><Interior ss:Color=\"#DCFCE7\" ss:Pattern=\"Solid\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"TotalRow\"><Borders><Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#A1A1AA\"/><Border ss:Position=\"Bottom\" ss:LineStyle=\"Double\" ss:Weight=\"3\" ss:Color=\"#18181B\"/></Borders><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"TotalRowCurrency\"><Alignment ss:Horizontal=\"Right\"/><Borders><Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#A1A1AA\"/><Border ss:Position=\"Bottom\" ss:LineStyle=\"Double\" ss:Weight=\"3\" ss:Color=\"#18181B\"/></Borders><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/><NumberFormat ss:Format=\"&quot;PHP &quot;#,##0.00\"/></Style>");
                sb.AppendLine("  <Style ss:ID=\"TotalRowInteger\"><Alignment ss:Horizontal=\"Right\"/><Borders><Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#A1A1AA\"/><Border ss:Position=\"Bottom\" ss:LineStyle=\"Double\" ss:Weight=\"3\" ss:Color=\"#18181B\"/></Borders><Font ss:FontName=\"Segoe UI\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#18181B\"/><NumberFormat ss:Format=\"#,##0\"/></Style>");
                sb.AppendLine(" </Styles>");

                // Worksheet 1: Executive Summary & Dashboard KPIs
                sb.AppendLine(" <Worksheet ss:Name=\"Executive &amp; KPIs\">");
                sb.AppendLine("  <Table ss:DefaultRowHeight=\"20\">");
                sb.AppendLine("   <Column ss:Width=\"220\"/>");
                sb.AppendLine("   <Column ss:Width=\"150\"/>");
                sb.AppendLine("   <Column ss:Width=\"280\"/>");
                sb.AppendLine("   <Row ss:Height=\"24\"><Cell ss:StyleID=\"Title\"><Data ss:Type=\"String\">HELMET CARTEL OPERATIONS REPORT</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Subtitle\"><Data ss:Type=\"String\">Reporting Period: {startDate:yyyy-MM-dd} to {endDate:yyyy-MM-dd} (Preset: {XmlVal(ActivePreset)}) | Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}</Data></Cell></Row>");
                sb.AppendLine("   <Row></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Key Performance Indicator</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Value</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Metric Scope / Description</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Period Gross Revenue</Data></Cell><Cell ss:StyleID=\"CurrencyBold\"><Data ss:Type=\"Number\">{periodRevenue:F2}</Data></Cell><Cell><Data ss:Type=\"String\">Aggregated completed sales during reporting window</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Completed Paid Orders</Data></Cell><Cell ss:StyleID=\"IntegerBold\"><Data ss:Type=\"Number\">{periodOrders}</Data></Cell><Cell><Data ss:Type=\"String\">Total customer transactions fulfilled</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Average Order Value (AOV)</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{aov:F2}</Data></Cell><Cell><Data ss:Type=\"String\">Mean revenue generated per order</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Today Live Revenue (POS + Online)</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{todayRevenue:F2}</Data></Cell><Cell><Data ss:Type=\"String\">Current day real-time revenue intake</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Live Active Orders</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{activeOrders}</Data></Cell><Cell><Data ss:Type=\"String\">Orders currently being packed or in transit</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Total Warehouse Stock</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{totalWarehouseUnits}</Data></Cell><Cell><Data ss:Type=\"String\">Physical helmet units across all brands</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Active Product SKUs</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{activeSkus}</Data></Cell><Cell><Data ss:Type=\"String\">Distinct brand/color/size variant combinations</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Total Available Stock</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{totalAvailable}</Data></Cell><Cell><Data ss:Type=\"String\">Unreserved units ready for immediate sale</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Low Stock Alerts</Data></Cell><Cell ss:StyleID=\"{(totalLowStockCount > 0 ? "AlertAmber" : "Integer")}\"><Data ss:Type=\"Number\">{totalLowStockCount}</Data></Cell><Cell><Data ss:Type=\"String\">Variants at or below configured reorder threshold</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">Out of Stock Variants</Data></Cell><Cell ss:StyleID=\"{(outOfStockVariants > 0 ? "AlertRed" : "Integer")}\"><Data ss:Type=\"Number\">{outOfStockVariants}</Data></Cell><Cell><Data ss:Type=\"String\">Variants with zero available inventory units</Data></Cell></Row>");
                sb.AppendLine("  </Table>");
                sb.AppendLine(" </Worksheet>");

                // Worksheet 2: Item Sales Performance (Complete list of products and items included in analytics)
                sb.AppendLine(" <Worksheet ss:Name=\"Item Sales Performance\">");
                sb.AppendLine("  <Table ss:DefaultRowHeight=\"19\">");
                sb.AppendLine("   <Column ss:Width=\"50\"/>");
                sb.AppendLine("   <Column ss:Width=\"240\"/>");
                sb.AppendLine("   <Column ss:Width=\"120\"/>");
                sb.AppendLine("   <Column ss:Width=\"120\"/>");
                sb.AppendLine("   <Column ss:Width=\"90\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Row ss:Height=\"24\"><Cell ss:StyleID=\"Title\"><Data ss:Type=\"String\">HELMET PRODUCT SALES PERFORMANCE (ITEM-LEVEL BREAKDOWN)</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Subtitle\"><Data ss:Type=\"String\">Individual helmet models and items sold during the reporting period ({startDate:yyyy-MM-dd} to {endDate:yyyy-MM-dd})</Data></Cell></Row>");
                sb.AppendLine("   <Row></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Rank</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Product / Model Name</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Manufacturer / Brand</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Category</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Units Sold</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Completed Orders</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Gross Revenue</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Average Selling Price</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Revenue Share</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Top Performer</Data></Cell></Row>");

                var rankedItems = (performanceItems ?? new List<AdminSalesPerformanceItemDto>())
                    .OrderByDescending(p => p.Revenue)
                    .ThenByDescending(p => p.UnitsSold)
                    .ToList();

                decimal totalPerfRevenue = rankedItems.Sum(p => p.Revenue);
                int totalPerfUnits = rankedItems.Sum(p => p.UnitsSold);
                int totalPerfOrders = rankedItems.Sum(p => p.OrderCount);
                int maxUnitsSold = rankedItems.Count > 0 ? rankedItems.Max(p => p.UnitsSold) : 0;
                decimal maxRevSold = rankedItems.Count > 0 ? rankedItems.Max(p => p.Revenue) : 0m;

                int rankNum = 1;
                foreach (var item in rankedItems)
                {
                    double revShare = totalPerfRevenue > 0 ? (double)(item.Revenue / totalPerfRevenue) : 0.0;
                    string topBadge = "";
                    if (maxUnitsSold > 0 && item.UnitsSold == maxUnitsSold && maxRevSold > 0 && item.Revenue == maxRevSold) topBadge = "TOP SELLER &amp; REVENUE";
                    else if (maxUnitsSold > 0 && item.UnitsSold == maxUnitsSold) topBadge = "TOP SELLER";
                    else if (maxRevSold > 0 && item.Revenue == maxRevSold) topBadge = "TOP REVENUE";

                    string badgeStyle = !string.IsNullOrEmpty(topBadge) ? "BadgeTop" : "Center";

                    sb.AppendLine($"   <Row><Cell ss:StyleID=\"Center\"><Data ss:Type=\"String\">#{rankNum++}</Data></Cell><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">{XmlVal(item.ProductName)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.BrandName)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.CategoryName)}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{item.UnitsSold}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{item.OrderCount}</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{item.Revenue:F2}</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{item.AverageSellingPrice:F2}</Data></Cell><Cell ss:StyleID=\"Percent\"><Data ss:Type=\"Number\">{revShare:F4}</Data></Cell><Cell ss:StyleID=\"{badgeStyle}\"><Data ss:Type=\"String\">{topBadge}</Data></Cell></Row>");
                }

                if (rankedItems.Count == 0)
                {
                    sb.AppendLine("   <Row><Cell ss:StyleID=\"Center\"><Data ss:Type=\"String\">-</Data></Cell><Cell><Data ss:Type=\"String\">No items sold in the selected reporting period.</Data></Cell><Cell><Data ss:Type=\"String\">-</Data></Cell><Cell><Data ss:Type=\"String\">-</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">0</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">0</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">0.00</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">0.00</Data></Cell><Cell ss:StyleID=\"Percent\"><Data ss:Type=\"Number\">0.0</Data></Cell><Cell><Data ss:Type=\"String\"></Data></Cell></Row>");
                }

                // Summary Total Row
                decimal overallAov = totalPerfUnits > 0 ? (totalPerfRevenue / totalPerfUnits) : 0m;
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">TOTAL</Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">{rankedItems.Count} Distinct Models</Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{totalPerfUnits}</Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{totalPerfOrders}</Data></Cell><Cell ss:StyleID=\"TotalRowCurrency\"><Data ss:Type=\"Number\">{totalPerfRevenue:F2}</Data></Cell><Cell ss:StyleID=\"TotalRowCurrency\"><Data ss:Type=\"Number\">{overallAov:F2}</Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">100.0%</Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell></Row>");
                sb.AppendLine("  </Table>");
                sb.AppendLine(" </Worksheet>");

                // Worksheet 3: Complete Inventory Master Catalog (All variants and items tracked in analytics)
                sb.AppendLine(" <Worksheet ss:Name=\"Complete Inventory Catalog\">");
                sb.AppendLine("  <Table ss:DefaultRowHeight=\"19\">");
                sb.AppendLine("   <Column ss:Width=\"120\"/>");
                sb.AppendLine("   <Column ss:Width=\"240\"/>");
                sb.AppendLine("   <Column ss:Width=\"120\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"60\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Column ss:Width=\"100\"/>");
                sb.AppendLine("   <Column ss:Width=\"100\"/>");
                sb.AppendLine("   <Column ss:Width=\"100\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Row ss:Height=\"24\"><Cell ss:StyleID=\"Title\"><Data ss:Type=\"String\">COMPLETE HELMET INVENTORY &amp; VARIANT CATALOG</Data></Cell></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"Subtitle\"><Data ss:Type=\"String\">All active helmet SKUs, colorways, and sizes across certified manufacturers</Data></Cell></Row>");
                sb.AppendLine("   <Row></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Manufacturer / Brand</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Product Model Name</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Category</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Colorway</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Size</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">SKU Code</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">On-Hand Units</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Available Units</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Reserved Units</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Reorder Point</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Availability Rate</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Health Status</Data></Cell></Row>");

                var sortedDetails = (details ?? new List<AdminBrandInventoryDetailDto>())
                    .OrderBy(d => d.Brand)
                    .ThenBy(d => d.ProductName)
                    .ThenBy(d => d.Size)
                    .ToList();

                int catOnHand = sortedDetails.Sum(d => d.OnHandStock);
                int catAvail = sortedDetails.Sum(d => d.AvailableStock);
                int catReserved = sortedDetails.Sum(d => Math.Max(0, d.OnHandStock - d.AvailableStock));

                foreach (var item in sortedDetails)
                {
                    int reserved = Math.Max(0, item.OnHandStock - item.AvailableStock);
                    double availRate = item.OnHandStock > 0 ? ((double)item.AvailableStock / item.OnHandStock) : 0.0;
                    string statusStyle = item.AvailableStock <= 0 ? "AlertRed" : (item.AvailableStock <= item.ReorderPoint ? "AlertAmber" : "AlertGreen");
                    string statusText = item.AvailableStock <= 0 ? "OUT OF STOCK" : (item.AvailableStock <= item.ReorderPoint ? "LOW STOCK" : "IN STOCK");

                    sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">{XmlVal(item.Brand)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.ProductName)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.CategoryName)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.Color)}</Data></Cell><Cell ss:StyleID=\"Center\"><Data ss:Type=\"String\">{XmlVal(item.Size)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.SKU)}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{item.OnHandStock}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{item.AvailableStock}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{reserved}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{item.ReorderPoint}</Data></Cell><Cell ss:StyleID=\"Percent\"><Data ss:Type=\"Number\">{availRate:F4}</Data></Cell><Cell ss:StyleID=\"{statusStyle}\"><Data ss:Type=\"String\">{statusText}</Data></Cell></Row>");
                }

                // Summary Total Row
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">TOTAL</Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">{sortedDetails.Count} Active Variants</Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{catOnHand}</Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{catAvail}</Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{catReserved}</Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell></Row>");
                sb.AppendLine("  </Table>");
                sb.AppendLine(" </Worksheet>");

                // Worksheet 4: Daily Sales Performance Log
                sb.AppendLine(" <Worksheet ss:Name=\"Daily Sales Log\">");
                sb.AppendLine("  <Table ss:DefaultRowHeight=\"19\">");
                sb.AppendLine("   <Column ss:Width=\"120\"/>");
                sb.AppendLine("   <Column ss:Width=\"160\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Column ss:Width=\"140\"/>");
                sb.AppendLine("   <Column ss:Width=\"140\"/>");
                sb.AppendLine("   <Row ss:Height=\"24\"><Cell ss:StyleID=\"Title\"><Data ss:Type=\"String\">DAILY SALES PERFORMANCE LOG</Data></Cell></Row>");
                sb.AppendLine($"   <Row><Cell ss:StyleID=\"Subtitle\"><Data ss:Type=\"String\">Itemized daily transaction and revenue records ({startDate:yyyy-MM-dd} to {endDate:yyyy-MM-dd})</Data></Cell></Row>");
                sb.AppendLine("   <Row></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Sales Date</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Day of Week</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Completed Orders</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Gross Revenue</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Average Order Value</Data></Cell></Row>");

                foreach (var day in sales.OrderByDescending(s => s.SalesDate))
                {
                    decimal dayAov = day.PaymentCount > 0 ? (day.Revenue / day.PaymentCount) : 0m;
                    sb.AppendLine($"   <Row><Cell ss:StyleID=\"DateStyle\"><Data ss:Type=\"String\">{day.SalesDate:yyyy-MM-dd}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(day.SalesDate.ToString("dddd, MMMM dd, yyyy"))}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{day.PaymentCount}</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{day.Revenue:F2}</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{dayAov:F2}</Data></Cell></Row>");
                }

                sb.AppendLine($"   <Row><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">TOTAL</Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">{sales.Count} Days Logged</Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{periodOrders}</Data></Cell><Cell ss:StyleID=\"TotalRowCurrency\"><Data ss:Type=\"Number\">{periodRevenue:F2}</Data></Cell><Cell ss:StyleID=\"TotalRowCurrency\"><Data ss:Type=\"Number\">{aov:F2}</Data></Cell></Row>");
                sb.AppendLine("  </Table>");
                sb.AppendLine(" </Worksheet>");

                // Worksheet 5: Brand Inventory Health Breakdown
                sb.AppendLine(" <Worksheet ss:Name=\"Brand Inventory Health\">");
                sb.AppendLine("  <Table ss:DefaultRowHeight=\"19\">");
                sb.AppendLine("   <Column ss:Width=\"140\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"120\"/>");
                sb.AppendLine("   <Column ss:Width=\"110\"/>");
                sb.AppendLine("   <Column ss:Width=\"140\"/>");
                sb.AppendLine("   <Row ss:Height=\"24\"><Cell ss:StyleID=\"Title\"><Data ss:Type=\"String\">BRAND INVENTORY HEALTH BREAKDOWN</Data></Cell></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"Subtitle\"><Data ss:Type=\"String\">Stock depth, variant coverage, and stockout risk by manufacturer</Data></Cell></Row>");
                sb.AppendLine("   <Row></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Brand / Manufacturer</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Variants (SKUs)</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">On-Hand Units</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Available Units</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Reserved Units</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Low Stock Alerts</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Availability Rate</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Health Status</Data></Cell></Row>");

                int totalBOnHand = brandReport.Sum(b => b.OnHandStock);
                int totalBAvail = brandReport.Sum(b => b.AvailableStock);
                int totalBReserved = brandReport.Sum(b => Math.Max(0, b.OnHandStock - b.AvailableStock));
                int totalBLow = brandReport.Sum(b => b.LowStockCount);
                int totalBSkus = brandReport.Sum(b => b.VariantCount);

                foreach (var b in brandReport)
                {
                    int reserved = Math.Max(0, b.OnHandStock - b.AvailableStock);
                    double availRate = b.OnHandStock > 0 ? ((double)b.AvailableStock / b.OnHandStock) : 0.0;
                    string statusStyle = b.AvailableStock <= 0 ? "AlertRed" : (b.LowStockCount > 0 ? "AlertAmber" : "AlertGreen");
                    string statusText = b.AvailableStock <= 0 ? "OUT OF STOCK" : (b.LowStockCount > 0 ? "LOW STOCK" : "HEALTHY");
                    sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">{XmlVal(b.Brand)}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{b.VariantCount}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{b.OnHandStock}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{b.AvailableStock}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{reserved}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{b.LowStockCount}</Data></Cell><Cell ss:StyleID=\"Percent\"><Data ss:Type=\"Number\">{availRate:F4}</Data></Cell><Cell ss:StyleID=\"{statusStyle}\"><Data ss:Type=\"String\">{statusText}</Data></Cell></Row>");
                }

                sb.AppendLine($"   <Row><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">TOTAL</Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{totalBSkus}</Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{totalBOnHand}</Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{totalBAvail}</Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{totalBReserved}</Data></Cell><Cell ss:StyleID=\"TotalRowInteger\"><Data ss:Type=\"Number\">{totalBLow}</Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell><Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell></Row>");
                sb.AppendLine("  </Table>");
                sb.AppendLine(" </Worksheet>");

                // Worksheet 6: Sales Performance by Dimension
                sb.AppendLine(" <Worksheet ss:Name=\"Sales by Dimension\">");
                sb.AppendLine("  <Table ss:DefaultRowHeight=\"19\">");
                sb.AppendLine("   <Column ss:Width=\"150\"/>");
                sb.AppendLine("   <Column ss:Width=\"100\"/>");
                sb.AppendLine("   <Column ss:Width=\"100\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Column ss:Width=\"100\"/>");
                sb.AppendLine("   <Column ss:Width=\"100\"/>");
                sb.AppendLine("   <Row ss:Height=\"22\"><Cell ss:StyleID=\"SectionHeader\"><Data ss:Type=\"String\">SALES BY BRAND</Data></Cell></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Brand</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Units Sold</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Order Count</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Gross Revenue</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Average Unit Price</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Top Seller?</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Top Revenue?</Data></Cell></Row>");
                foreach (var sale in brandSales)
                {
                    sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">{XmlVal(sale.DimensionName)}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{sale.UnitsSold}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{sale.OrderCount}</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{sale.Revenue:F2}</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{sale.AverageUnitPrice:F2}</Data></Cell><Cell ss:StyleID=\"Center\"><Data ss:Type=\"String\">{(sale.IsTopSeller ? "YES" : "No")}</Data></Cell><Cell ss:StyleID=\"Center\"><Data ss:Type=\"String\">{(sale.IsTopRevenue ? "YES" : "No")}</Data></Cell></Row>");
                }
                sb.AppendLine("   <Row></Row>");
                sb.AppendLine("   <Row ss:Height=\"22\"><Cell ss:StyleID=\"SectionHeader\"><Data ss:Type=\"String\">SALES BY CATEGORY</Data></Cell></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Category</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Units Sold</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Order Count</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Gross Revenue</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Average Unit Price</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Top Seller?</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Top Revenue?</Data></Cell></Row>");
                foreach (var sale in categorySales)
                {
                    sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">{XmlVal(sale.DimensionName)}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{sale.UnitsSold}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{sale.OrderCount}</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{sale.Revenue:F2}</Data></Cell><Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">{sale.AverageUnitPrice:F2}</Data></Cell><Cell ss:StyleID=\"Center\"><Data ss:Type=\"String\">{(sale.IsTopSeller ? "YES" : "No")}</Data></Cell><Cell ss:StyleID=\"Center\"><Data ss:Type=\"String\">{(sale.IsTopRevenue ? "YES" : "No")}</Data></Cell></Row>");
                }
                sb.AppendLine("  </Table>");
                sb.AppendLine(" </Worksheet>");

                // Worksheet 7: Critical Restock Audit
                sb.AppendLine(" <Worksheet ss:Name=\"Critical Restock Audit\">");
                sb.AppendLine("  <Table ss:DefaultRowHeight=\"19\">");
                sb.AppendLine("   <Column ss:Width=\"120\"/>");
                sb.AppendLine("   <Column ss:Width=\"220\"/>");
                sb.AppendLine("   <Column ss:Width=\"120\"/>");
                sb.AppendLine("   <Column ss:Width=\"100\"/>");
                sb.AppendLine("   <Column ss:Width=\"70\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Column ss:Width=\"90\"/>");
                sb.AppendLine("   <Column ss:Width=\"90\"/>");
                sb.AppendLine("   <Column ss:Width=\"90\"/>");
                sb.AppendLine("   <Column ss:Width=\"90\"/>");
                sb.AppendLine("   <Column ss:Width=\"130\"/>");
                sb.AppendLine("   <Row ss:Height=\"24\"><Cell ss:StyleID=\"Title\"><Data ss:Type=\"String\">CRITICAL INVENTORY RESTOCK AUDIT</Data></Cell></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"Subtitle\"><Data ss:Type=\"String\">Helmet variants requiring immediate replenishment (Available Stock &lt;= Reorder Threshold)</Data></Cell></Row>");
                sb.AppendLine("   <Row></Row>");
                sb.AppendLine("   <Row><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Brand</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Product Name</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Category</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">Color</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Size</Data></Cell><Cell ss:StyleID=\"Header\"><Data ss:Type=\"String\">SKU</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">On Hand</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Available</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Reorder Point</Data></Cell><Cell ss:StyleID=\"HeaderRight\"><Data ss:Type=\"String\">Units Deficit</Data></Cell><Cell ss:StyleID=\"HeaderCenter\"><Data ss:Type=\"String\">Status</Data></Cell></Row>");

                foreach (var item in details.Where(d => d.AvailableStock <= d.ReorderPoint).OrderBy(d => d.AvailableStock).ThenBy(d => d.Brand))
                {
                    int deficit = Math.Max(0, item.ReorderPoint - item.AvailableStock);
                    string statusStyle = item.AvailableStock <= 0 ? "AlertRed" : "AlertAmber";
                    string statusText = item.AvailableStock <= 0 ? "OUT OF STOCK" : "LOW STOCK";
                    sb.AppendLine($"   <Row><Cell ss:StyleID=\"Bold\"><Data ss:Type=\"String\">{XmlVal(item.Brand)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.ProductName)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.CategoryName)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.Color)}</Data></Cell><Cell ss:StyleID=\"Center\"><Data ss:Type=\"String\">{XmlVal(item.Size)}</Data></Cell><Cell><Data ss:Type=\"String\">{XmlVal(item.SKU)}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{item.OnHandStock}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{item.AvailableStock}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{item.ReorderPoint}</Data></Cell><Cell ss:StyleID=\"Integer\"><Data ss:Type=\"Number\">{deficit}</Data></Cell><Cell ss:StyleID=\"{statusStyle}\"><Data ss:Type=\"String\">{statusText}</Data></Cell></Row>");
                }
                sb.AppendLine("  </Table>");
                sb.AppendLine(" </Worksheet>");

                sb.AppendLine("</Workbook>");

                Response.Clear();
                Response.Buffer = true;
                Response.AddHeader("content-disposition", $"attachment;filename=HelmetCartel_Analytics_Report_{startDate:yyyyMMdd}_{endDate:yyyyMMdd}.xls");
                Response.Charset = "utf-8";
                Response.ContentType = "application/vnd.ms-excel";
                Response.Output.Write(sb.ToString());
                Response.Flush();
                Response.End();
            }));
        }

        private static string XmlVal(string s)
        {
            if (string.IsNullOrEmpty(s)) return string.Empty;
            return s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("\"", "&quot;").Replace("'", "&apos;");
        }
    }
}
