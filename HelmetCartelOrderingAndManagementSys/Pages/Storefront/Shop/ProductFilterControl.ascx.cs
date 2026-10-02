using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web.UI;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Pages.Shop
{
    public partial class ProductFilterControl : UserControl
    {
        private readonly IProductRepository _productRepository;

        public string SelectedCategory { get; set; } = "all";
        public HashSet<string> SelectedBrands { get; private set; } = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        public ProductFilterControl()
        {
            _productRepository = new ProductRepository(new DbConnectionFactory());
        }

        public ProductFilterControl(IProductRepository productRepository)
        {
            _productRepository = productRepository;
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            SelectedCategory = Request.QueryString["category"] ?? "all";
            var brandParams = Request.QueryString.GetValues("brand");
            if (brandParams != null)
            {
                foreach (var b in brandParams)
                {
                    if (string.IsNullOrWhiteSpace(b)) continue;
                    foreach (var item in b.Split(','))
                    {
                        var trimmed = item.Trim();
                        if (!string.IsNullOrEmpty(trimmed) && !string.Equals(trimmed, "all", StringComparison.OrdinalIgnoreCase))
                        {
                            SelectedBrands.Add(trimmed);
                        }
                    }
                }
            }

            if (!IsPostBack)
            {
                Page.RegisterAsyncTask(new PageAsyncTask(LoadFilterDataAsync));
            }
        }

        private async Task LoadFilterDataAsync()
        {
            try
            {
                var categories = System.Web.HttpRuntime.Cache["ShopFilterCategories"] as List<CategoryDto>;
                if (categories == null)
                {
                    categories = await _productRepository.GetCategoriesAsync().ConfigureAwait(false);
                    if (categories != null && categories.Count > 0)
                    {
                        System.Web.HttpRuntime.Cache.Insert("ShopFilterCategories", categories, null, DateTime.UtcNow.AddMinutes(5), System.Web.Caching.Cache.NoSlidingExpiration);
                    }
                }

                var brands = System.Web.HttpRuntime.Cache["ShopFilterBrands"] as List<BrandDto>;
                if (brands == null)
                {
                    brands = await _productRepository.GetBrandsAsync().ConfigureAwait(false);
                    if (brands != null && brands.Count > 0)
                    {
                        System.Web.HttpRuntime.Cache.Insert("ShopFilterBrands", brands, null, DateTime.UtcNow.AddMinutes(5), System.Web.Caching.Cache.NoSlidingExpiration);
                    }
                }

                rptCategoryFilter.DataSource = categories ?? new List<CategoryDto>();
                rptCategoryFilter.DataBind();

                rptBrandFilter.DataSource = brands ?? new List<BrandDto>();
                rptBrandFilter.DataBind();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ProductFilterControl] Error loading filter items: {ex.Message}");
            }
        }

        public bool IsCategoryActive(string categoryName)
        {
            if (string.Equals(SelectedCategory, categoryName, StringComparison.OrdinalIgnoreCase))
                return true;
            return false;
        }

        public bool IsBrandActive(string brandName)
        {
            if (string.IsNullOrEmpty(brandName)) return false;
            return SelectedBrands.Contains(brandName);
        }

        public bool IsAllBrandsActive => SelectedBrands.Count == 0 || SelectedBrands.Contains("all");
    }
}
