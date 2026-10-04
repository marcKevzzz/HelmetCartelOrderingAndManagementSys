using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Admin
{
    public partial class InventoryPage : Page
    {
        private readonly AdminDataRepository _adminRepo;
        private readonly IProductRepository _productRepo;

        public const int PageSize = 20;
        public const int AuditPageSize = 20;

        public int CurrentPageNumber
        {
            get => (ViewState["CurrentPageNumber"] as int?) ?? 1;
            set => ViewState["CurrentPageNumber"] = value;
        }

        public int CurrentAuditPageNumber
        {
            get => (ViewState["CurrentAuditPageNumber"] as int?) ?? 1;
            set => ViewState["CurrentAuditPageNumber"] = value;
        }

        public string CurrentStatus
        {
            get => (ViewState["CurrentStatus"] as string) ?? "active";
            set => ViewState["CurrentStatus"] = value;
        }

        public string CurrentBrand
        {
            get => (ViewState["CurrentBrand"] as string) ?? "";
            set => ViewState["CurrentBrand"] = value;
        }

        public int? CurrentProductId
        {
            get => ViewState["CurrentProductId"] as int?;
            set => ViewState["CurrentProductId"] = value;
        }

        public int? CurrentVariantId
        {
            get => ViewState["CurrentVariantId"] as int?;
            set => ViewState["CurrentVariantId"] = value;
        }

        public string CurrentSearch
        {
            get => (ViewState["CurrentSearch"] as string) ?? "";
            set => ViewState["CurrentSearch"] = value;
        }

        public string CurrentViewMode
        {
            get => (ViewState["CurrentViewMode"] as string) ?? "stock";
            set => ViewState["CurrentViewMode"] = value;
        }

        public string CurrentAuditType
        {
            get => (ViewState["CurrentAuditType"] as string) ?? "all";
            set => ViewState["CurrentAuditType"] = value;
        }

        public string CurrentAuditBrand
        {
            get => (ViewState["CurrentAuditBrand"] as string) ?? "all";
            set => ViewState["CurrentAuditBrand"] = value;
        }

        public InventoryPage()
        {
            var factory = new DbConnectionFactory();
            _adminRepo = new AdminDataRepository(factory);
            _productRepo = new ProductRepository(factory);
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                string q = Request.QueryString["q"] ?? Request.QueryString["search"];
                if (!string.IsNullOrWhiteSpace(q))
                {
                    CurrentSearch = q.Trim();
                }

                if (!string.IsNullOrEmpty(Request.QueryString["view"]))
                {
                    CurrentViewMode = Request.QueryString["view"].ToLowerInvariant() == "audit" ? "audit" : "stock";
                }

                if (!string.IsNullOrEmpty(Request.QueryString["brand"]))
                {
                    CurrentBrand = Request.QueryString["brand"];
                }
                if (int.TryParse(Request.QueryString["productId"], out int productId) && productId > 0)
                    CurrentProductId = productId;
                if (int.TryParse(Request.QueryString["variantId"], out int variantId) && variantId > 0)
                    CurrentVariantId = variantId;

                if (!string.IsNullOrEmpty(Request.QueryString["status"]))
                {
                    CurrentStatus = Request.QueryString["status"].ToLowerInvariant();
                }

                if (int.TryParse(Request.QueryString["page"], out int p) && p > 0)
                {
                    CurrentPageNumber = p;
                }

                RegisterAsyncTask(new PageAsyncTask(InitializeFiltersAndDataAsync));
            }
        }

        private async Task InitializeFiltersAndDataAsync()
        {
            await Task.WhenAll(PopulateBrandsAsync(), PopulateCategoriesAsync()).ConfigureAwait(false);
            await LoadInventoryDataAsync().ConfigureAwait(false);
        }

        private async Task PopulateBrandsAsync()
        {
            ddlBrandFilter.Items.Clear();
            ddlAuditBrandFilter.Items.Clear();
            ddlBrandFilter.Items.Add(new ListItem("All Brands", "all"));
            ddlAuditBrandFilter.Items.Add(new ListItem("All Brands", "all"));
            try
            {
                var brands = await _productRepo.GetBrandsAsync().ConfigureAwait(false);
                foreach (var item in brands)
                {
                    ddlBrandFilter.Items.Add(new ListItem(item.Name, item.Name));
                    ddlAuditBrandFilter.Items.Add(new ListItem(item.Name, item.Name));
                }
                var selected = ddlBrandFilter.Items.FindByValue(CurrentBrand);
                if (selected != null) ddlBrandFilter.SelectedValue = selected.Value;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceWarning("Inventory brand filters failed to load: " + ex.Message);
            }
        }

        private async Task PopulateCategoriesAsync()
        {
            try
            {
                var categories = await _productRepo.GetCategoriesAsync().ConfigureAwait(false);
                ddlCategoryFilter.Items.Clear();
                ddlCategoryFilter.Items.Add(new ListItem("All Categories", "all"));

                foreach (var cat in categories)
                {
                    ddlCategoryFilter.Items.Add(new ListItem(cat.Name, cat.Name));
                }

                string requestedCat = Request.QueryString["category"];
                if (!string.IsNullOrEmpty(requestedCat))
                {
                    var match = ddlCategoryFilter.Items.FindByValue(requestedCat) ?? ddlCategoryFilter.Items.FindByText(requestedCat);
                    if (match != null)
                    {
                        ddlCategoryFilter.SelectedValue = match.Value;
                    }
                }
            }
            catch
            {
                if (ddlCategoryFilter.Items.Count == 0)
                {
                    ddlCategoryFilter.Items.Add(new ListItem("All Categories", "all"));
                }
            }
        }

        private async Task LoadInventoryDataAsync()
        {
            if (CurrentViewMode == "audit")
            {
                pnlActiveStock.Visible = false;
                pnlAuditHistory.Visible = true;
                btnViewActiveStock.CssClass = "admin-tab-btn";
                btnViewAuditHistory.CssClass = "admin-tab-btn active";
                string search = string.IsNullOrWhiteSpace(CurrentSearch) ? null : CurrentSearch;
                var auditLogs = await _adminRepo.GetStockAuditLogsAsync(search: search, limit: 500).ConfigureAwait(false);

                // Exclude sales decrements from Stock In History
                auditLogs = auditLogs.Where(l =>
                    !string.Equals(l.ChangeType, "ONLINE_SALE", StringComparison.OrdinalIgnoreCase) &&
                    !string.Equals(l.ChangeType, "INSTORE_SALE", StringComparison.OrdinalIgnoreCase) &&
                    !string.Equals(l.ChangeType, "Sale", StringComparison.OrdinalIgnoreCase)
                ).ToList();

                // Functional Filter: Change Type
                if (CurrentAuditType == "restock")
                {
                    auditLogs = auditLogs.Where(l => (l.ChangeType ?? "").IndexOf("Restock", StringComparison.OrdinalIgnoreCase) >= 0 || (l.ChangeType ?? "").IndexOf("In", StringComparison.OrdinalIgnoreCase) >= 0 || l.QuantityChanged > 0).ToList();
                }
                else if (CurrentAuditType == "adjustment")
                {
                    auditLogs = auditLogs.Where(l => (l.ChangeType ?? "").IndexOf("Adjust", StringComparison.OrdinalIgnoreCase) >= 0 || (l.ChangeType ?? "").IndexOf("Count", StringComparison.OrdinalIgnoreCase) >= 0).ToList();
                }

                // Functional Filter: Brand
                if (!string.IsNullOrWhiteSpace(CurrentAuditBrand) && CurrentAuditBrand != "all")
                {
                    auditLogs = auditLogs.Where(l => string.Equals(l.BrandName, CurrentAuditBrand, StringComparison.OrdinalIgnoreCase)).ToList();
                }

                int auditTotalCount = auditLogs.Count;
                int auditTotalPages = Math.Max(1, (int)Math.Ceiling((double)auditTotalCount / AuditPageSize));
                if (CurrentAuditPageNumber < 1) CurrentAuditPageNumber = 1;
                if (CurrentAuditPageNumber > auditTotalPages) CurrentAuditPageNumber = auditTotalPages;

                var pagedAuditLogs = auditLogs
                    .Skip((CurrentAuditPageNumber - 1) * AuditPageSize)
                    .Take(AuditPageSize)
                    .ToList();

                rptAuditHistory.DataSource = pagedAuditLogs;
                rptAuditHistory.DataBind();
                litAuditCount.Text = auditTotalCount.ToString("N0");

                int totalAdded = auditLogs.Where(l => l.QuantityChanged > 0).Sum(l => l.QuantityChanged);
                litAuditUnitsAdded.Text = totalAdded.ToString("N0");

                pnlAuditPagination.Visible = auditTotalPages > 1;
                BindAuditPagination(CurrentAuditPageNumber, auditTotalPages);
                UpdateAuditFilterStyles();
                return;
            }

            pnlActiveStock.Visible = true;
            pnlAuditHistory.Visible = false;
            btnViewActiveStock.CssClass = "admin-tab-btn active";
            btnViewAuditHistory.CssClass = "admin-tab-btn";

            string querySearch = string.IsNullOrWhiteSpace(CurrentSearch) ? null : CurrentSearch;
            string category = ddlCategoryFilter.SelectedValue == "all" ? null : ddlCategoryFilter.SelectedValue;
            CurrentBrand = ddlBrandFilter.SelectedValue;
            string brand = string.IsNullOrWhiteSpace(CurrentBrand) || CurrentBrand == "all" ? null : CurrentBrand;

            var allItems = await _adminRepo.GetInventoryVariantsAsync(querySearch, brand, category, CurrentStatus,
                CurrentProductId, CurrentVariantId).ConfigureAwait(false);

            int totalCount = allItems.Count;
            int totalPages = (int)Math.Ceiling((double)totalCount / PageSize);
            if (totalPages < 1) totalPages = 1;

            if (CurrentPageNumber > totalPages) CurrentPageNumber = totalPages;
            if (CurrentPageNumber < 1) CurrentPageNumber = 1;

            var pagedItems = allItems.Skip((CurrentPageNumber - 1) * PageSize).Take(PageSize).ToList();

            rptInventory.DataSource = pagedItems;
            rptInventory.DataBind();

            litAvailableCount.Text = allItems.Sum(x => x.AvailableStock).ToString("N0");
            int startItem = totalCount == 0 ? 0 : (CurrentPageNumber - 1) * PageSize + 1;
            int endItem = Math.Min(CurrentPageNumber * PageSize, totalCount);
            litShowingRange.Text = totalCount == 0 ? "0" : $"{startItem}-{endItem}";
            litTotalCount.Text = totalCount.ToString("N0");

            pnlInventoryPagination.Visible = totalPages > 1;
            BindPagination(CurrentPageNumber, totalPages);
            UpdateTabButtonStyles();
        }

        private void BindPagination(int currentPage, int totalPages)
        {
            btnPrevPage.Enabled = currentPage > 1;
            btnPrevPage.CssClass = "admin-pagination-btn" + (currentPage <= 1 ? " disabled" : "");
            btnNextPage.Enabled = currentPage < totalPages;
            btnNextPage.CssClass = "admin-pagination-btn" + (currentPage >= totalPages ? " disabled" : "");

            var pageLinks = HelmetCartelOrderingAndManagementSys.Infrastructure.PaginationHelper.BuildPageLinks(
                currentPage, 
                totalPages, 
                p => p.ToString()
            );

            rptPaginationPages.DataSource = pageLinks.Select(p => new PaginationPageItem
            {
                PageNumber = p.PageNumber,
                IsActive = p.IsCurrent,
                IsEllipsis = p.IsEllipsis
            }).ToList();
            rptPaginationPages.DataBind();
        }

        private void BindAuditPagination(int currentPage, int totalPages)
        {
            btnAuditPrevPage.Enabled = currentPage > 1;
            btnAuditPrevPage.CssClass = "admin-pagination-btn" + (currentPage <= 1 ? " disabled" : "");
            btnAuditNextPage.Enabled = currentPage < totalPages;
            btnAuditNextPage.CssClass = "admin-pagination-btn" + (currentPage >= totalPages ? " disabled" : "");

            var pageLinks = HelmetCartelOrderingAndManagementSys.Infrastructure.PaginationHelper.BuildPageLinks(
                currentPage,
                totalPages,
                p => p.ToString()
            );

            rptAuditPaginationPages.DataSource = pageLinks.Select(p => new PaginationPageItem
            {
                PageNumber = p.PageNumber,
                IsActive = p.IsCurrent,
                IsEllipsis = p.IsEllipsis
            }).ToList();
            rptAuditPaginationPages.DataBind();
        }

        protected void btnViewMode_Click(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                CurrentViewMode = btn.CommandArgument;
                CurrentPageNumber = 1;
                CurrentAuditPageNumber = 1;
                RegisterAsyncTask(new PageAsyncTask(LoadInventoryDataAsync));
            }
        }

        protected void FilterTab_Click(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                CurrentProductId = null;
                CurrentVariantId = null;
                CurrentStatus = btn.CommandArgument;
                CurrentPageNumber = 1;
                RegisterAsyncTask(new PageAsyncTask(LoadInventoryDataAsync));
            }
        }

        protected void FilterDropdown_Changed(object sender, EventArgs e)
        {
            CurrentProductId = null;
            CurrentVariantId = null;
            CurrentBrand = ddlBrandFilter.SelectedValue;
            CurrentPageNumber = 1;
            RegisterAsyncTask(new PageAsyncTask(LoadInventoryDataAsync));
        }

        protected void btnPrevPage_Click(object sender, EventArgs e)
        {
            if (CurrentPageNumber > 1)
            {
                CurrentPageNumber--;
                RegisterAsyncTask(new PageAsyncTask(LoadInventoryDataAsync));
            }
        }

        protected void btnNextPage_Click(object sender, EventArgs e)
        {
            CurrentPageNumber++;
            RegisterAsyncTask(new PageAsyncTask(LoadInventoryDataAsync));
        }

        protected void rptPaginationPages_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName == "GoToPage" && int.TryParse(e.CommandArgument.ToString(), out int targetPage))
            {
                CurrentPageNumber = targetPage;
                RegisterAsyncTask(new PageAsyncTask(LoadInventoryDataAsync));
            }
        }

        protected void btnSubmitStockAdjust_Click(object sender, EventArgs e)
        {
            if (!int.TryParse(hdnAdjustVariantId.Value, out int variantId) || variantId <= 0) return;
            if (!int.TryParse(txtAdjustQuantity.Value, out int qty) || qty <= 0)
            {
                ScriptManager.RegisterStartupScript(this, GetType(), "StockErr", "window.showAdminToast('Please specify a positive unit quantity to add.', 'warning', 'Invalid Quantity');", true);
                return;
            }

            int delta = Math.Max(1, qty); // Strictly positive stock increase
            string reason = ddlAdjustReason.SelectedValue;
            string reference = string.IsNullOrWhiteSpace(txtAdjustReference.Value) ? "STOCK-IN" : txtAdjustReference.Value.Trim();
            string notes = $"Stock In ({reason}): {reference}";

            // Server-side duplicate submission / double-click protection (3.5s window)
            string adjustFingerprint = $"StockIn_{variantId}_{delta}_{reason}_{reference}";
            if (HttpContext.Current?.Cache != null)
            {
                if (HttpContext.Current.Cache[adjustFingerprint] != null)
                {
                    System.Diagnostics.Trace.TraceWarning($"Ignoring duplicate stock-in request for variant {variantId} within debounce window.");
                    return;
                }
                HttpContext.Current.Cache.Insert(adjustFingerprint, true, null, DateTime.UtcNow.AddSeconds(3.5), System.Web.Caching.Cache.NoSlidingExpiration);
            }

            RegisterAsyncTask(new PageAsyncTask(async () =>
            {
                try
                {
                    int newStock = await _adminRepo.AdjustStockAsync(variantId, delta, null, reference, notes).ConfigureAwait(false);
                    try
                    {
                        var hubContext = Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<HelmetCartelOrderingAndManagementSys.Hubs.InventoryHub>();
                        hubContext?.Clients?.All?.stockUpdated(new { variantId, currentStock = newStock });
                    }
                    catch { }

                    await LoadInventoryDataAsync().ConfigureAwait(false);

                    ScriptManager.RegisterStartupScript(this, GetType(), "StockToast", $"window.showAdminToast('Successfully added {delta} unit(s). Updated stock: {newStock:D3}.', 'success', 'Stock In Confirmed');", true);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Stock adjust error: " + ex.Message);
                    ScriptManager.RegisterStartupScript(this, GetType(), "StockToastErr", $"window.showAdminToast('Failed to complete stock-in: {HttpUtility.JavaScriptStringEncode(ex.Message)}', 'error', 'Stock In Error');", true);
                }
            }));
        }

        private void UpdateTabButtonStyles()
        {
            btnTabAll.CssClass = "admin-tab-btn" + (CurrentStatus == "all" ? " active" : "");
            btnTabActive.CssClass = "admin-tab-btn" + (CurrentStatus == "active" ? " active" : "");
            btnTabInactive.CssClass = "admin-tab-btn" + (CurrentStatus == "inactive" ? " active" : "");
            btnTabInStock.CssClass = "admin-tab-btn" + (CurrentStatus == "in_stock" ? " active" : "");
            btnTabLowStock.CssClass = "admin-tab-btn" + (CurrentStatus == "low_stock" ? " active" : "");
            btnTabOutOfStock.CssClass = "admin-tab-btn" + (CurrentStatus == "out_of_stock" ? " active" : "");
        }

        [System.Web.Services.WebMethod]
        public static object ToggleVariantStatus(int variantId)
        {
            var factory = new DbConnectionFactory();
            var repo = new AdminDataRepository(factory);
            bool newStatus = repo.ToggleVariantActiveAsync(variantId).GetAwaiter().GetResult();
            try
            {
                var hubContext = Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<HelmetCartelOrderingAndManagementSys.Hubs.InventoryHub>();
                hubContext?.Clients?.All?.variantStatusChanged(new { variantId = variantId, isActive = newStatus });
            }
            catch { }
            return new { success = true, variantId = variantId, isActive = newStatus };
        }

        protected string ResolveImageUrl(object urlObj)
        {
            string url = Convert.ToString(urlObj);
            if (string.IsNullOrWhiteSpace(url))
            {
                return "/Content/images/placeholder-helmet.png";
            }
            return url;
        }

        /// <summary>
        /// Formats stock as 3-digit number (e.g. 002, 020, 450)
        /// </summary>
        protected string FormatStockNumber(object stockObj)
        {
            int stock = Convert.ToInt32(stockObj ?? 0);
            return stock < 1000 ? stock.ToString("D3") : stock.ToString("N0");
        }

        protected string RenderStatusBadge(string status, int availableStock)
        {
            if (availableStock <= 0 || status == "out_of_stock")
            {
                return "<span class=\"admin-badge admin-badge--out-of-stock\">Out of Stock</span>";
            }
            if (status == "low_stock")
            {
                return "<span class=\"admin-badge admin-badge--low-stock\">Low Stock</span>";
            }
            return "<span class=\"admin-badge admin-badge--in-stock\">In Stock</span>";
        }

        protected string GetColorSwatchStyle(object colorHexObj)
        {
            string hex = Convert.ToString(colorHexObj ?? "").Trim();
            if (string.IsNullOrWhiteSpace(hex)) return "background-color: #18181B;";
            if (hex.StartsWith("linear-gradient", StringComparison.OrdinalIgnoreCase))
            {
                return $"background: {hex};";
            }
            return $"background-color: {hex};";
        }

        protected string RenderColorSwatch(object colorHexObj)
        {
            string style = GetColorSwatchStyle(colorHexObj);
            return $"<span class=\"admin-color-swatch\" style=\"{HttpUtility.HtmlAttributeEncode(style)}\"></span>";
        }

        protected void AuditTypeTab_Click(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                CurrentAuditType = btn.CommandArgument;
                CurrentAuditPageNumber = 1;
                RegisterAsyncTask(new PageAsyncTask(LoadInventoryDataAsync));
            }
        }

        protected void AuditFilterDropdown_Changed(object sender, EventArgs e)
        {
            CurrentAuditBrand = ddlAuditBrandFilter.SelectedValue;
            CurrentAuditPageNumber = 1;
            RegisterAsyncTask(new PageAsyncTask(LoadInventoryDataAsync));
        }

        protected void AuditPage_Change(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                string arg = btn.CommandArgument;
                if (arg == "prev")
                {
                    CurrentAuditPageNumber = Math.Max(1, CurrentAuditPageNumber - 1);
                }
                else if (arg == "next")
                {
                    CurrentAuditPageNumber++;
                }
                else if (int.TryParse(arg, out int page))
                {
                    CurrentAuditPageNumber = page;
                }

                RegisterAsyncTask(new PageAsyncTask(LoadInventoryDataAsync));
            }
        }

        private void UpdateAuditFilterStyles()
        {
            btnAuditTypeAll.CssClass = CurrentAuditType == "all" ? "admin-tab-btn active" : "admin-tab-btn";
            btnAuditTypeRestock.CssClass = CurrentAuditType == "restock" ? "admin-tab-btn active" : "admin-tab-btn";
            btnAuditTypeAdjustment.CssClass = CurrentAuditType == "adjustment" ? "admin-tab-btn active" : "admin-tab-btn";

            if (ddlAuditBrandFilter.Items.FindByValue(CurrentAuditBrand) != null)
            {
                ddlAuditBrandFilter.SelectedValue = CurrentAuditBrand;
            }
        }

        /// <summary>
        /// Displays positive formatted quantity added without confusing signs (e.g. +1 unit, +10 units).
        /// </summary>
        protected string FormatQuantityAdded(object qtyObj)
        {
            if (qtyObj == null || qtyObj == DBNull.Value) return "+0 units";
            if (int.TryParse(Convert.ToString(qtyObj), out int qty))
            {
                if (qty >= 0)
                {
                    return $"+{qty} {(qty == 1 ? "unit" : "units")}";
                }
                return $"{qty} {(Math.Abs(qty) == 1 ? "unit" : "units")}";
            }
            return "+0 units";
        }

        public class PaginationPageItem
        {
            public int PageNumber { get; set; }
            public bool IsActive { get; set; }
            public bool IsEllipsis { get; set; }
        }
    }
}
