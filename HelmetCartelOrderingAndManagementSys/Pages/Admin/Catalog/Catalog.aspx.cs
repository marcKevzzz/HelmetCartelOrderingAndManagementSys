using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Admin
{
    public partial class CatalogPage : Page
    {
        private readonly AdminDataRepository _adminRepo;
        private readonly IProductRepository _productRepo;

        public string CurrentTab
        {
            get => (ViewState["CurrentTab"] as string) ?? "all";
            set => ViewState["CurrentTab"] = value;
        }

        public string CurrentSearch
        {
            get => (ViewState["CurrentSearch"] as string) ?? "";
            set => ViewState["CurrentSearch"] = value;
        }

        public int? TargetProductId
        {
            get => ViewState["TargetProductId"] as int?;
            set => ViewState["TargetProductId"] = value;
        }

        public CatalogPage()
        {
            var factory = new DbConnectionFactory();
            _adminRepo = new AdminDataRepository(factory);
            _productRepo = new ProductRepository(factory);
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                string q =
                    Request.QueryString["q"]
                    ?? Request.QueryString["search"]
                    ?? Request.QueryString["brand"];
                if (!string.IsNullOrWhiteSpace(q))
                {
                    CurrentSearch = q.Trim();
                }

                string targetIdStr = Request.QueryString["id"] ?? Request.QueryString["editId"];
                if (int.TryParse(targetIdStr, out int targetId) && targetId > 0)
                {
                    TargetProductId = targetId;
                }

                string tab = Request.QueryString["tab"];
                if (!string.IsNullOrWhiteSpace(tab))
                {
                    CurrentTab = tab.ToLowerInvariant();
                }
                else if (Request.QueryString["msg"] == "draft_saved" || Request.QueryString["msg"] == "unpublished_saved")
                {
                    CurrentTab = "drafts";
                }

                string msg = Request.QueryString["msg"];
                if (!string.IsNullOrWhiteSpace(msg))
                {
                    string alertText =
                        (msg == "draft_saved" || msg == "unpublished_saved") ? "Helmet model draft saved successfully."
                        : msg == "published" ? "Helmet model published successfully."
                        : msg == "deleted" ? "Product deleted successfully."
                        : null;
                    if (alertText != null)
                    {
                        string cleanMsg = HttpUtility.JavaScriptStringEncode(alertText);
                        ClientScript.RegisterStartupScript(
                            this.GetType(),
                            "msgToast",
                            $"document.addEventListener('DOMContentLoaded', function() {{ if (typeof showAdminToast === 'function') showAdminToast('{cleanMsg}'); }});",
                            true
                        );
                    }
                }

                RegisterAsyncTask(new PageAsyncTask(LoadCatalogDataAsync));
            }
        }

        public int CurrentPage
        {
            get => ViewState["CurrentPage"] != null ? (int)ViewState["CurrentPage"] : 1;
            set => ViewState["CurrentPage"] = value;
        }

        public const int PageSize = 20;

        private async Task LoadCatalogDataAsync()
        {
            string search = string.IsNullOrWhiteSpace(CurrentSearch) ? null : CurrentSearch;
            var products = await _adminRepo.GetCatalogProductsAsync(search).ConfigureAwait(false);

            if (TargetProductId.HasValue)
            {
                // Bring target product directly to the top if arriving from inventory
                products = products.OrderByDescending(p => p.Id == TargetProductId.Value).ToList();
            }

            if (CurrentTab == "published_active" || CurrentTab == "active")
            {
                products = products.Where(p => string.Equals(p.PublicationStatus, "Published", StringComparison.OrdinalIgnoreCase) && p.IsActive).ToList();
            }
            else if (CurrentTab == "published_inactive" || CurrentTab == "inactive")
            {
                products = products.Where(p => string.Equals(p.PublicationStatus, "Published", StringComparison.OrdinalIgnoreCase) && !p.IsActive).ToList();
            }
            else if (CurrentTab == "drafts" || CurrentTab == "unpublished")
            {
                products = products.Where(p => string.Equals(p.PublicationStatus, "Unpublished", StringComparison.OrdinalIgnoreCase) ||
                                               string.Equals(p.PublicationStatus, "Draft", StringComparison.OrdinalIgnoreCase)).ToList();
            }

            int totalCount = products.Count;
            int totalPages = Math.Max(1, (int)Math.Ceiling((double)totalCount / PageSize));

            if (CurrentPage < 1)
                CurrentPage = 1;
            if (CurrentPage > totalPages)
                CurrentPage = totalPages;

            var pagedProducts = products.Skip((CurrentPage - 1) * PageSize).Take(PageSize).ToList();

            rptCatalog.DataSource = pagedProducts;
            rptCatalog.DataBind();

            litTotalTop.Text = totalCount.ToString();
            litShowingTop.Text =
                totalCount == 0
                    ? "0"
                    : $"{((CurrentPage - 1) * PageSize) + 1}–{Math.Min(CurrentPage * PageSize, totalCount)}";

            // Centered pagination
            pnlCatalogPagination.Visible = totalPages > 1;
            if (totalPages > 1)
            {
                lnkCatalogPrev.CssClass =
                    "admin-pagination-btn" + (CurrentPage <= 1 ? " disabled" : "");
                lnkCatalogNext.CssClass =
                    "admin-pagination-btn" + (CurrentPage >= totalPages ? " disabled" : "");

                var pageLinks = PaginationHelper.BuildPageLinks(
                    CurrentPage,
                    totalPages,
                    i => i.ToString()
                );
                rptCatalogPages.DataSource = pageLinks;
                rptCatalogPages.DataBind();
            }

            UpdateTabButtonStyles();
        }

        protected void CatalogPage_Change(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                string arg = btn.CommandArgument;
                if (arg == "prev")
                {
                    CurrentPage = Math.Max(1, CurrentPage - 1);
                }
                else if (arg == "next")
                {
                    CurrentPage++;
                }
                else if (int.TryParse(arg, out int p))
                {
                    CurrentPage = p;
                }
                RegisterAsyncTask(new PageAsyncTask(LoadCatalogDataAsync));
            }
        }

        protected void btnConfirmDeleteProduct_Click(object sender, EventArgs e)
        {
            if (int.TryParse(hfDeleteProductId.Value, out int productId) && productId > 0)
            {
                RegisterAsyncTask(
                    new PageAsyncTask(async () =>
                    {
                        try
                        {
                            var res = await _adminRepo
                                .DeleteProductAsync(productId)
                                .ConfigureAwait(false);
                            if (res.Success)
                            {
                                string msg =
                                    res.Status == "SoftDeleted"
                                        ? "Product has historical order transactions. It has been deactivated and archived."
                                        : "Product and its variants were successfully deleted from catalog.";
                                string toastScript =
                                    $"if(window.showAdminToast){{window.showAdminToast({Newtonsoft.Json.JsonConvert.SerializeObject(msg)},'success','Product Deleted');}}";
                                ScriptManager.RegisterStartupScript(
                                    this,
                                    GetType(),
                                    "deleteSuccessToast",
                                    toastScript,
                                    true
                                );
                            }
                            else
                            {
                                string toastScript =
                                    $"if(window.showAdminToast){{window.showAdminToast({Newtonsoft.Json.JsonConvert.SerializeObject(res.Message)},'error','Delete Failed');}}";
                                ScriptManager.RegisterStartupScript(
                                    this,
                                    GetType(),
                                    "deleteFailToast",
                                    toastScript,
                                    true
                                );
                            }
                        }
                        catch (Exception ex)
                        {
                            string toastScript =
                                $"if(window.showAdminToast){{window.showAdminToast({Newtonsoft.Json.JsonConvert.SerializeObject(ex.Message)},'error','Delete Error');}}";
                            ScriptManager.RegisterStartupScript(
                                this,
                                GetType(),
                                "deleteErrToast",
                                toastScript,
                                true
                            );
                        }
                        await LoadCatalogDataAsync().ConfigureAwait(false);
                    })
                );
            }
        }

        protected void FilterTab_Click(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                CurrentTab = btn.CommandArgument;
                CurrentPage = 1;
                RegisterAsyncTask(new PageAsyncTask(LoadCatalogDataAsync));
            }
        }

        private void UpdateTabButtonStyles()
        {
            btnTabAll.CssClass = "admin-tab-btn" + (CurrentTab == "all" ? " active" : "");
            btnTabActive.CssClass = "admin-tab-btn" + (CurrentTab == "published_active" || CurrentTab == "active" ? " active" : "");
            btnTabPublishedInactive.CssClass = "admin-tab-btn" + (CurrentTab == "published_inactive" || CurrentTab == "inactive" ? " active" : "");
            btnTabDrafts.CssClass = "admin-tab-btn" + (CurrentTab == "drafts" || CurrentTab == "unpublished" ? " active" : "");
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
    }
}
