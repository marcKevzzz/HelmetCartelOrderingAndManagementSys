using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
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
                string q = Request.QueryString["q"] ?? Request.QueryString["search"] ?? Request.QueryString["brand"];
                if (!string.IsNullOrWhiteSpace(q))
                {
                    CurrentSearch = q.Trim();
                }

                string targetIdStr = Request.QueryString["id"] ?? Request.QueryString["editId"];
                if (int.TryParse(targetIdStr, out int targetId) && targetId > 0)
                {
                    TargetProductId = targetId;
                }

                RegisterAsyncTask(new PageAsyncTask(InitializeDataAsync));
            }
        }

        private async Task InitializeDataAsync()
        {
            await PopulateDropdownsAsync().ConfigureAwait(false);
            await LoadCatalogDataAsync().ConfigureAwait(false);
        }

        private async Task PopulateDropdownsAsync()
        {
            try
            {
                var brands = await _productRepo.GetBrandsAsync().ConfigureAwait(false);
                ddlNewBrand.Items.Clear();
                foreach (var b in brands)
                {
                    ddlNewBrand.Items.Add(new ListItem(b.Name, b.Id.ToString()));
                }

                var categories = await _productRepo.GetCategoriesAsync().ConfigureAwait(false);
                ddlNewCategory.Items.Clear();
                foreach (var c in categories)
                {
                    ddlNewCategory.Items.Add(new ListItem(c.Name, c.Id.ToString()));
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("Error populating dropdowns: " + ex.Message);
            }
        }

        public int CurrentPage
        {
            get => ViewState["CurrentPage"] != null ? (int)ViewState["CurrentPage"] : 1;
            set => ViewState["CurrentPage"] = value;
        }

        public const int PageSize = 8;

        private async Task LoadCatalogDataAsync()
        {
            string search = string.IsNullOrWhiteSpace(CurrentSearch) ? null : CurrentSearch;
            var products = await _adminRepo.GetCatalogProductsAsync(search).ConfigureAwait(false);

            if (TargetProductId.HasValue)
            {
                // Bring target product directly to the top if arriving from inventory
                products = products.OrderByDescending(p => p.Id == TargetProductId.Value).ToList();
            }

            if (CurrentTab == "active")
            {
                products = products.Where(p => p.IsActive).ToList();
            }
            else if (CurrentTab == "featured")
            {
                products = products.Where(p => p.IsFeatured).ToList();
            }

            int totalCount = products.Count;
            int totalPages = Math.Max(1, (int)Math.Ceiling((double)totalCount / PageSize));

            if (CurrentPage < 1) CurrentPage = 1;
            if (CurrentPage > totalPages) CurrentPage = totalPages;

            var pagedProducts = products.Skip((CurrentPage - 1) * PageSize).Take(PageSize).ToList();

            rptCatalog.DataSource = pagedProducts;
            rptCatalog.DataBind();

            litTotalTop.Text = totalCount.ToString();
            litShowingTop.Text = totalCount == 0 ? "0" : $"{((CurrentPage - 1) * PageSize) + 1}–{Math.Min(CurrentPage * PageSize, totalCount)}";

            // Centered pagination
            pnlCatalogPagination.Visible = totalPages > 1;
            if (totalPages > 1)
            {
                lnkCatalogPrev.CssClass = "admin-pagination-btn" + (CurrentPage <= 1 ? " disabled" : "");
                lnkCatalogNext.CssClass = "admin-pagination-btn" + (CurrentPage >= totalPages ? " disabled" : "");

                var pageLinks = PaginationHelper.BuildPageLinks(CurrentPage, totalPages, i => i.ToString());
                rptCatalogPages.DataSource = pageLinks;
                rptCatalogPages.DataBind();
            }

            UpdateTabButtonStyles();

            // Auto-open edit modal if editId was explicitly provided
            if (TargetProductId.HasValue && !IsPostBack && !string.IsNullOrEmpty(Request.QueryString["editId"]))
            {
                var target = products.FirstOrDefault(p => p.Id == TargetProductId.Value);
                if (target != null)
                {
                    string editScript = $"window.addEventListener('DOMContentLoaded', function() {{ openEditProductModal({target.Id}, '{HttpUtility.JavaScriptStringEncode(target.Name)}', {target.BrandId}, {target.CategoryId}, '{HttpUtility.JavaScriptStringEncode(target.RidingStyle)}', {target.BasePrice}, '{HttpUtility.JavaScriptStringEncode(target.DiscountType)}', {target.DiscountAmount}, '{HttpUtility.JavaScriptStringEncode(target.MainImageUrl)}', '{HttpUtility.JavaScriptStringEncode(target.Description)}'); }});";
                    ScriptManager.RegisterStartupScript(this, GetType(), "AutoOpenEdit", editScript, true);
                }
            }
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
                RegisterAsyncTask(new PageAsyncTask(async () =>
                {
                    try
                    {
                        var res = await _adminRepo.DeleteProductAsync(productId).ConfigureAwait(false);
                        if (res.Success)
                        {
                            string msg = res.Status == "SoftDeleted" 
                                ? "Product has historical order transactions. It has been deactivated and archived." 
                                : "Product and its variants were successfully deleted from catalog.";
                            string toastScript = $"if(window.showAdminToast){{window.showAdminToast({Newtonsoft.Json.JsonConvert.SerializeObject(msg)},'success','Product Deleted');}}";
                            ScriptManager.RegisterStartupScript(this, GetType(), "deleteSuccessToast", toastScript, true);
                        }
                        else
                        {
                            string toastScript = $"if(window.showAdminToast){{window.showAdminToast({Newtonsoft.Json.JsonConvert.SerializeObject(res.Message)},'error','Delete Failed');}}";
                            ScriptManager.RegisterStartupScript(this, GetType(), "deleteFailToast", toastScript, true);
                        }
                    }
                    catch (Exception ex)
                    {
                        string toastScript = $"if(window.showAdminToast){{window.showAdminToast({Newtonsoft.Json.JsonConvert.SerializeObject(ex.Message)},'error','Delete Error');}}";
                        ScriptManager.RegisterStartupScript(this, GetType(), "deleteErrToast", toastScript, true);
                    }
                    await LoadCatalogDataAsync().ConfigureAwait(false);
                }));
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

        protected void btnSubmitNewProduct_Click(object sender, EventArgs e)
        {
            string name = txtNewName.Value?.Trim();
            if (string.IsNullOrWhiteSpace(name))
            {
                ScriptManager.RegisterStartupScript(this, GetType(), "ValErrName", "window.showAdminToast('Helmet model name is required.', 'warning', 'Validation');", true);
                return;
            }

            if (!int.TryParse(ddlNewBrand.SelectedValue, out int brandId) || brandId <= 0) return;
            if (!int.TryParse(ddlNewCategory.SelectedValue, out int categoryId) || categoryId <= 0) return;

            if (!decimal.TryParse(txtNewBasePrice.Value, out decimal basePrice) || basePrice <= 0) basePrice = 30000;

            string discountType = ddlNewDiscountType.SelectedValue ?? "Percentage";
            decimal.TryParse(txtNewDiscountValue.Value, out decimal discountVal);
            if (discountVal < 0) discountVal = 0;

            DateTime? startDate = null;
            if (DateTime.TryParse(txtNewDiscountStartDate.Value, out DateTime sDate)) startDate = sDate;

            DateTime? endDate = null;
            if (DateTime.TryParse(txtNewDiscountEndDate.Value, out DateTime eDate)) endDate = eDate;

            int discountPct = 0;
            if (discountType == "Percentage")
            {
                discountPct = (int)Math.Min(90, Math.Max(0, discountVal));
            }

            string style = ddlNewStyle.SelectedValue ?? "Sport/Street";
            string description = txtNewDescription.Value?.Trim() ?? "";

            string slug = Regex.Replace(name.ToLowerInvariant(), @"[^a-z0-9\s-]", "").Replace(" ", "-").Trim('-');
            if (string.IsNullOrWhiteSpace(slug)) slug = "helmet-" + Guid.NewGuid().ToString().Substring(0, 8);

            // 1. Process Multi-Image Uploads & Organize inside Brand Folder
            string brandText = ddlNewBrand.SelectedItem?.Text?.ToLowerInvariant() ?? "helmets";
            string brandSlug = Regex.Replace(brandText, @"[^a-z0-9]", "");
            if (string.IsNullOrWhiteSpace(brandSlug)) brandSlug = "helmets";
            string brandPhysicalDir = Server.MapPath($"~/Content/images/products/helmets/{brandSlug}");
            if (!Directory.Exists(brandPhysicalDir))
            {
                Directory.CreateDirectory(brandPhysicalDir);
            }

            var uploadedImageUrls = new List<string>();
            if (fileUploadImages.HasFiles)
            {
                int imgIdx = 1;
                foreach (var file in fileUploadImages.PostedFiles)
                {
                    if (file.ContentLength <= 0) continue;
                    if (file.ContentLength > 5 * 1024 * 1024) continue; // 5MB limit
                    string ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                    if (ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp") continue;

                    string safeFileName = $"{slug}-{DateTime.UtcNow.Ticks}-{imgIdx}{ext}";
                    string savePath = Path.Combine(brandPhysicalDir, safeFileName);
                    file.SaveAs(savePath);
                    uploadedImageUrls.Add($"/Content/images/products/helmets/{brandSlug}/{safeFileName}");
                    imgIdx++;
                }
            }

            string imageUrl = uploadedImageUrls.Count > 0 
                ? uploadedImageUrls[0] 
                : (string.IsNullOrWhiteSpace(txtNewImageUrl.Value) ? "/Content/images/products/helmets/agv/images.jpg" : txtNewImageUrl.Value.Trim());

            int.TryParse(hdnEditProductId.Value, out int editProductId);

            string variantsJson = hdnVariantsJson.Value;
            if (string.IsNullOrWhiteSpace(variantsJson))
            {
                variantsJson = "[{\"color\":\"Standard Black\",\"colorHex\":\"#18181B\",\"size\":\"M\",\"sku\":\"" + slug + "-BLK-M\",\"priceAdj\":0,\"stock\":10,\"reorder\":3}]";
            }

            RegisterAsyncTask(new PageAsyncTask(async () =>
            {
                try
                {
                    if (editProductId > 0)
                    {
                        // Update existing product
                        bool updated = await _adminRepo.UpdateProductAsync(
                            editProductId,
                            categoryId,
                            brandId,
                            name,
                            slug,
                            description,
                            style,
                            basePrice,
                            discountPct,
                            discountType,
                            discountVal,
                            startDate,
                            endDate,
                            imageUrl,
                            isFeatured: false,
                            isActive: true
                        ).ConfigureAwait(false);

                        // Save extra uploaded gallery images
                        for (int i = 1; i < uploadedImageUrls.Count; i++)
                        {
                            await _adminRepo.AddProductGalleryImageAsync(editProductId, uploadedImageUrls[i], name, i + 1).ConfigureAwait(false);
                        }

                        await LoadCatalogDataAsync().ConfigureAwait(false);
                        ScriptManager.RegisterStartupScript(this, GetType(), "ProdUpdated", $"window.showAdminToast('Updated helmet \"{HttpUtility.JavaScriptStringEncode(name)}\" successfully.', 'success', 'Product Updated');", true);
                    }
                    else
                    {
                        // Create brand new product with variants
                        int newId = await _adminRepo.CreateProductWithVariantsAsync(
                            categoryId,
                            brandId,
                            name,
                            slug,
                            description,
                            style,
                            basePrice,
                            discountPct,
                            imageUrl,
                            variantsJson,
                            discountType,
                            discountVal,
                            startDate,
                            endDate
                        ).ConfigureAwait(false);

                        // Save extra uploaded gallery images
                        for (int i = 1; i < uploadedImageUrls.Count; i++)
                        {
                            await _adminRepo.AddProductGalleryImageAsync(newId, uploadedImageUrls[i], name, i + 1).ConfigureAwait(false);
                        }

                        await LoadCatalogDataAsync().ConfigureAwait(false);
                        ScriptManager.RegisterStartupScript(this, GetType(), "ProdCreated", $"window.showAdminToast('Created helmet \"{HttpUtility.JavaScriptStringEncode(name)}\" with variants successfully.', 'success', 'Product Created');", true);
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error saving product: " + ex.Message);
                    ScriptManager.RegisterStartupScript(this, GetType(), "ProdErr", $"window.showAdminToast('Failed to save helmet: {HttpUtility.JavaScriptStringEncode(ex.Message)}', 'error', 'Save Error');", true);
                }
            }));
        }

        private void UpdateTabButtonStyles()
        {
            btnTabAll.CssClass = "admin-tab-btn" + (CurrentTab == "all" ? " active" : "");
            btnTabActive.CssClass = "admin-tab-btn" + (CurrentTab == "active" ? " active" : "");
            btnTabFeatured.CssClass = "admin-tab-btn" + (CurrentTab == "featured" ? " active" : "");
        }

        protected string ResolveImageUrl(object urlObj)
        {
            string url = Convert.ToString(urlObj);
            if (string.IsNullOrWhiteSpace(url))
            {
                return "/Content/images/products/helmets/agv/images.jpg";
            }
            return url;
        }
    }
}
