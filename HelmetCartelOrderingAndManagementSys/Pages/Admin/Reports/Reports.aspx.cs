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
                // 1. Load brand inventory health report
                var brandReport = await _adminRepo.GetInventoryReportAsync().ConfigureAwait(false);
                var details = await _adminRepo.GetBrandInventoryDetailsAsync().ConfigureAwait(false);
                _brandDetails = details.GroupBy(item => item.Brand, StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(group => group.Key, group => group.ToList(), StringComparer.OrdinalIgnoreCase);
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

                var inventoryTrend = await _adminRepo.GetInventoryTrendAsync(startDate, endDate).ConfigureAwait(false);
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
                var sales = await _adminRepo.GetDailySalesAsync(startDate.Date, endDate.Date.AddDays(1)).ConfigureAwait(false);

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

                // 5. Update UI labels and active badge
                string rangeSubtitle = $"Performance from {startDate:MMMM dd, yyyy} to {endDate:MMMM dd, yyyy}";
                litChartSubtitle.Text = Server.HtmlEncode(rangeSubtitle);
                litRevenueSubtitle.Text = Server.HtmlEncode($"Settled revenue ({startDate:MMM dd} - {endDate:MMM dd})");

                string badgeText = ActivePreset == "today" ? "Today" :
                                   ActivePreset == "week" ? "This Week" :
                                   ActivePreset == "month" ? "This Month" :
                                   ActivePreset == "30days" ? "Last 30 Days" :
                                   $"{startDate:MMM dd} - {endDate:MMM dd}";
                litActiveRangeBadge.Text = Server.HtmlEncode(badgeText);

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
            }
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
                    image = "/Content/images/products/helmets/agv/images.jpg";
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
                    html.Append("<div class=\"admin-brand-variant\">")
                        .Append("<div><strong>").Append(HttpUtility.HtmlEncode(item.Color)).Append(" / ")
                        .Append(HttpUtility.HtmlEncode(item.Size)).Append("</strong><span>")
                        .Append(HttpUtility.HtmlEncode(item.SKU)).Append("</span></div>")
                        .Append("<span>On hand <strong>").Append(item.OnHandStock.ToString("N0"))
                        .Append("</strong></span><span>Available <strong>").Append(item.AvailableStock.ToString("N0"))
                        .Append("</strong></span><span>Reorder at <strong>").Append(item.ReorderPoint.ToString("N0"))
                        .Append("</strong></span><span class=\"admin-brand-variant-status\">")
                        .Append(status).Append("</span><a href=\"/Admin/Inventory.aspx?productId=")
                        .Append(item.ProductId).Append("&amp;variantId=").Append(item.VariantId)
                        .Append("\" class=\"admin-row-action-btn\">Open item &rarr;</a></div>");
                }
                html.Append("</div></section>");
            }
            html.Append("</div>");
            target.Text = html.ToString();
        }

        protected void btnExportReport_Click(object sender, EventArgs e)
        {
            RegisterAsyncTask(new PageAsyncTask(async () =>
            {
                var brandReport = await _adminRepo.GetInventoryReportAsync().ConfigureAwait(false);
                var sb = new StringBuilder();
                sb.AppendLine("Brand,VariantCount,OnHandStock,AvailableStock,LowStockCount");

                foreach (var b in brandReport)
                {
                    sb.AppendLine($"\"{b.Brand}\",{b.VariantCount},{b.OnHandStock},{b.AvailableStock},{b.LowStockCount}");
                }

                Response.Clear();
                Response.Buffer = true;
                Response.AddHeader("content-disposition", "attachment;filename=HelmetCartel_Brand_Inventory_Report.csv");
                Response.Charset = "utf-8";
                Response.ContentType = "text/csv";
                Response.Output.Write(sb.ToString());
                Response.Flush();
                Response.End();
            }));
        }
    }
}
