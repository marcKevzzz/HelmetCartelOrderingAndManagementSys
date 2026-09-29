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
        public string SelectedBrand { get; set; } = "all";

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
            SelectedBrand = Request.QueryString["brand"] ?? "all";

            if (!IsPostBack)
            {
                Page.RegisterAsyncTask(new PageAsyncTask(LoadFilterDataAsync));
            }
        }

        private async Task LoadFilterDataAsync()
        {
            try
            {
                var categories = await _productRepository.GetCategoriesAsync().ConfigureAwait(false);
                var brands = await _productRepository.GetBrandsAsync().ConfigureAwait(false);

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
            if (string.Equals(SelectedBrand, brandName, StringComparison.OrdinalIgnoreCase))
                return true;
            return false;
        }
    }
}
