using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Web.UI;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Pages
{
    public partial class ShopPage : Page
    {
        private const int CatalogPageSize = 9;
        private static readonly string[] AllowedColors = { "Green", "Red", "Orange", "Cyan", "Blue", "Purple", "Pink", "White", "Black", "Grey", "Yellow" };
        private static readonly string[] AllowedSizes = { "XS", "S", "M", "L", "XL", "2XL", "XXL", "3XL" };
        private static readonly string[] AllowedSorts = { "popular", "top_selling", "price_asc", "price_desc", "newest", "rating" };
        private readonly IProductRepository _productRepository;
        public string CatalogHeading { get; private set; } = "HELMETS";

        public ShopPage()
        {
            _productRepository = new ProductRepository(new DbConnectionFactory());
        }

        public ShopPage(IProductRepository productRepository)
        {
            _productRepository = productRepository;
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            RegisterAsyncTask(new PageAsyncTask(LoadCatalogProductsAsync));
        }

        private async Task LoadCatalogProductsAsync()
        {
            string category = Request.QueryString["category"];
            string brand = NormalizeCsv(Request.QueryString.GetValues("brand"), null);
            string search = Request.QueryString["q"] ?? Request.QueryString["search"];
            if (search != null && search.Length > 200) search = search.Substring(0, 200);
            string sortBy = Request.QueryString["sortBy"] ?? Request.QueryString["sort"] ?? "popular";
            sortBy = AllowedSorts.FirstOrDefault(option => string.Equals(option, sortBy, StringComparison.OrdinalIgnoreCase)) ?? "popular";
            bool onSale = string.Equals(Request.QueryString["onSale"], "1", StringComparison.Ordinal);
            CatalogHeading = onSale ? "HELMETS ON SALE" : !string.IsNullOrEmpty(brand) ? brand.ToUpperInvariant() + " HELMETS" : !string.IsNullOrEmpty(category) ? category.ToUpperInvariant() + " HELMETS" : sortBy == "newest" ? "NEW ARRIVALS" : "HELMETS";

            int pageNumber = 1;
            if (int.TryParse(Request.QueryString["page"], out int p) && p > 0)
            {
                pageNumber = p;
            }

            decimal? minPrice = ParsePrice(Request.QueryString["minPrice"]);
            decimal? maxPrice = ParsePrice(Request.QueryString["maxPrice"]);
            if (minPrice.HasValue && maxPrice.HasValue && minPrice > maxPrice)
            {
                decimal temp = minPrice.Value;
                minPrice = maxPrice;
                maxPrice = temp;
            }

            try
            {
                var filter = new ProductFilterParams
                {
                    Page = pageNumber,
                    PageSize = CatalogPageSize,
                    Category = category,
                    Brand = brand,
                    Search = search,
                    OnSale = onSale,
                    SortBy = sortBy,
                    MinPrice = minPrice,
                    MaxPrice = maxPrice,
                    Colors = NormalizeCsv(Request.QueryString.GetValues("color"), AllowedColors),
                    Sizes = NormalizeCsv(Request.QueryString.GetValues("size"), AllowedSizes)
                };

                var result = await _productRepository.GetProductsAsync(filter).ConfigureAwait(false);
                if (result != null && result.TotalPages > 0 && pageNumber > result.TotalPages)
                {
                    pageNumber = result.TotalPages;
                    filter.Page = pageNumber;
                    result = await _productRepository.GetProductsAsync(filter).ConfigureAwait(false);
                }

                var products = result?.Items ?? new List<ProductListDto>();
                int totalCount = result?.TotalCount ?? 0;

                if (products.Count > 0)
                {
                    rptCatalog.DataSource = products;
                    rptCatalog.DataBind();
                    rptCatalog.Visible = true;
                    pnlNoProducts.Visible = false;

                    int startItem = (pageNumber - 1) * CatalogPageSize + 1;
                    int endItem = Math.Min(pageNumber * CatalogPageSize, totalCount);
                    litProductsCount.Text = $"Showing {startItem}-{endItem} of {totalCount} Products";
                }
                else
                {
                    rptCatalog.Visible = false;
                    pnlNoProducts.Visible = true;
                    litProductsCount.Text = "Showing 0 Products";
                }

                int totalPages = result?.TotalPages ?? 0;
                pnlPagination.Visible = totalPages > 1;
                if (totalPages > 1)
                {
                    lnkPrev.Visible = pageNumber > 1;
                    lnkNext.Visible = pageNumber < totalPages;
                    if (lnkPrev.Visible) lnkPrev.HRef = BuildShopUrl(pageNumber - 1);
                    if (lnkNext.Visible) lnkNext.HRef = BuildShopUrl(pageNumber + 1);

                    var pageLinks = PaginationHelper.BuildPageLinks(pageNumber, totalPages, i => HttpUtility.HtmlAttributeEncode(BuildShopUrl(i)));
                    rptPages.DataSource = pageLinks;
                    rptPages.DataBind();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ShopPage] Error loading products via C#: {ex.Message}");
                rptCatalog.Visible = false;
                pnlNoProducts.Visible = true;
                pnlPagination.Visible = false;
                litProductsCount.Text = "Catalog unavailable";
            }
        }

        private static decimal? ParsePrice(string value)
        {
            if (decimal.TryParse(value, System.Globalization.NumberStyles.Number,
                System.Globalization.CultureInfo.InvariantCulture, out decimal amount) && amount >= 0 && amount <= 100000)
                return amount;
            return null;
        }

        private static string NormalizeCsv(IEnumerable<string> values, IEnumerable<string> allowed)
        {
            if (values == null) return null;
            var tokens = values.SelectMany(value => (value ?? string.Empty).Split(','))
                .Select(value => value.Trim())
                .Where(value => value.Length > 0 && !string.Equals(value, "all", StringComparison.OrdinalIgnoreCase))
                .Distinct(StringComparer.OrdinalIgnoreCase);
            if (allowed != null)
            {
                tokens = tokens.Where(option => allowed.Contains(option, StringComparer.OrdinalIgnoreCase));
            }
            var list = tokens.ToList();
            if (list.Contains("2XL", StringComparer.OrdinalIgnoreCase) && !list.Contains("XXL", StringComparer.OrdinalIgnoreCase))
                list.Add("XXL");
            else if (list.Contains("XXL", StringComparer.OrdinalIgnoreCase) && !list.Contains("2XL", StringComparer.OrdinalIgnoreCase))
                list.Add("2XL");

            return list.Count == 0 ? null : string.Join(",", list);
        }

        private string BuildShopUrl(int page)
        {
            var query = HttpUtility.ParseQueryString(Request.Url.Query);
            query.Set("page", page.ToString(System.Globalization.CultureInfo.InvariantCulture));
            return ResolveUrl("~/Pages/Shop.aspx") + "?" + query;
        }

        public string RenderPricingHtml(object basePriceObj, object effectivePriceObj, object hasDiscountObj, object discountPercentageObj, object discountBadgeTextObj)
        {
            decimal basePrice = Convert.ToDecimal(basePriceObj ?? 0);
            decimal effectivePrice = Convert.ToDecimal(effectivePriceObj ?? basePrice);
            bool hasDiscount = Convert.ToBoolean(hasDiscountObj ?? false);
            int discountPct = Convert.ToInt32(discountPercentageObj ?? 0);
            string badgeText = Convert.ToString(discountBadgeTextObj ?? "");

            if ((hasDiscount || discountPct > 0) && effectivePrice < basePrice)
            {
                if (string.IsNullOrWhiteSpace(badgeText)) badgeText = $"-{discountPct}%";
                return $"<span class=\"price-current\">&#8369;{effectivePrice:N0}</span><span class=\"price-original\">&#8369;{basePrice:N0}</span><span class=\"discount-badge\">{badgeText}</span>";
            }
            return $"<span class=\"price-current\">&#8369;{effectivePrice:N0}</span>";
        }

        public sealed class CatalogPageLink
        {
            public int Number { get; set; }
            public string Url { get; set; }
            public string CssClass { get; set; }
            public bool IsCurrent { get; set; }
            public bool IsEllipsis { get; set; }
        }

        public string RenderStars(decimal rating)
        {
            var sb = new StringBuilder();
            int fullStars = (int)Math.Floor(rating);
            for (int i = 0; i < 5; i++)
            {
                if (i < fullStars)
                {
                    sb.Append("<svg viewBox=\"0 0 24 24\"><polygon points=\"12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2\"/></svg>");
                }
                else
                {
                    sb.Append("<svg viewBox=\"0 0 24 24\" class=\"star--empty\"><polygon points=\"12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2\"/></svg>");
                }
            }
            return sb.ToString();
        }
    }
}
