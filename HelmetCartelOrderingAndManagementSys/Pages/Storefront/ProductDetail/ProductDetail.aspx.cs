using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web.UI;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

namespace HelmetCartelOrderingAndManagementSys.Pages
{
    public partial class ProductDetailPage : Page
    {
        private readonly IProductRepository _productRepository;
        private readonly IReviewRepository _reviewRepository;

        public ProductListDto ProductItem { get; set; }
        public string ProductJson { get; set; } = "null";
        public List<string> UniqueSizes { get; set; } = new List<string>();
        public List<ProductVariantDto> UniqueColors { get; set; } = new List<ProductVariantDto>();
        public List<ProductGalleryImageDto> GalleryImages { get; set; } = new List<ProductGalleryImageDto>();
        public List<ProductSpecificationDto> ProductSpecifications { get; set; } = new List<ProductSpecificationDto>();
        public List<ProductListDto> RelatedProducts { get; set; } = new List<ProductListDto>();

        public List<ProductReviewDto> Reviews { get; set; } = new List<ProductReviewDto>();
        public string ReviewsJson { get; set; } = "[]";
        public int ReviewsCount { get; set; } = 0;

        public ProductDetailPage()
        {
            var dbFactory = new DbConnectionFactory();
            _productRepository = new ProductRepository(dbFactory);
            _reviewRepository = new ReviewRepository(dbFactory);
        }

        public ProductDetailPage(IProductRepository productRepository, IReviewRepository reviewRepository)
        {
            _productRepository = productRepository;
            _reviewRepository = reviewRepository;
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            RegisterAsyncTask(new PageAsyncTask(LoadProductAsync));
        }

        private async Task LoadProductAsync()
        {
            string slug = Request.QueryString["slug"];
            int productId = 0;
            if (!string.IsNullOrEmpty(Request.QueryString["id"]) && int.TryParse(Request.QueryString["id"], out int parsedId))
            {
                productId = parsedId;
            }

            try
            {
                if (!string.IsNullOrWhiteSpace(slug))
                {
                    ProductItem = await _productRepository.GetProductBySlugAsync(slug).ConfigureAwait(false);
                }
                else if (productId > 0)
                {
                    ProductItem = await _productRepository.GetProductByIdAsync(productId).ConfigureAwait(false);
                }
                else
                {
                    ProductItem = await _productRepository.GetProductByIdAsync(1).ConfigureAwait(false);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ProductDetail] Error loading product (id: {productId}, slug: {slug}): {ex.Message}");
            }

            if (ProductItem == null)
            {
                Response.StatusCode = 404;
            }

            if (ProductItem != null)
            {
                Title = $"{ProductItem.Name} - Helmet Cartel";

                if (ProductItem.Variants != null && ProductItem.Variants.Count > 0)
                {
                    UniqueSizes = ProductItem.Variants
                        .Select(v => NormalizeDisplaySize(v.Size))
                        .Where(s => !string.IsNullOrEmpty(s))
                        .Distinct(StringComparer.OrdinalIgnoreCase)
                        .OrderBy(GetSizeOrder)
                        .ThenBy(s => s)
                        .ToList();

                    UniqueColors = ProductItem.Variants
                        .GroupBy(v => v.Color)
                        .Select(g => g.First())
                        .ToList();
                }

                GalleryImages = new List<ProductGalleryImageDto>();
                if (!string.IsNullOrWhiteSpace(ProductItem.MainImageUrl))
                {
                    GalleryImages.Add(new ProductGalleryImageDto
                    {
                        ImageUrl = ProductItem.MainImageUrl,
                        AltText = ProductItem.Name + " main view",
                        DisplayOrder = 0
                    });
                }
                GalleryImages.AddRange(ProductItem.GalleryImages
                    .Where(image => !string.IsNullOrWhiteSpace(image.ImageUrl))
                    .OrderBy(image => image.DisplayOrder));
                rptGalleryImages.DataSource = GalleryImages;
                rptGalleryImages.DataBind();

                rptGalleryModalImages.DataSource = GalleryImages;
                rptGalleryModalImages.DataBind();

                try
                {
                    ProductSpecifications = await _productRepository.GetProductSpecificationsAsync(ProductItem.Id);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[ProductDetail] Error loading specifications for product {ProductItem.Id}: {ex.Message}");
                    ProductSpecifications = new List<ProductSpecificationDto>();
                }
                pnlProductSpecifications.Visible = ProductSpecifications.Count > 0;
                pnlSpecToggle.Visible = ProductSpecifications.Count > 3;
                lblNoSpecifications.Visible = ProductSpecifications.Count == 0;
                rptProductSpecifications.DataSource = ProductSpecifications;
                rptProductSpecifications.DataBind();

                try
                {
                    RelatedProducts = await _productRepository.GetRelatedProductsAsync(ProductItem.Id);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[ProductDetail] Error loading related products for {ProductItem.Id}: {ex.Message}");
                    RelatedProducts = new List<ProductListDto>();
                }
                pnlRelatedProducts.Visible = RelatedProducts.Count > 0;
                rptRelatedProducts.DataSource = RelatedProducts;
                rptRelatedProducts.DataBind();

                ProductJson = JsonConvert.SerializeObject(ProductItem, new JsonSerializerSettings
                {
                    ContractResolver = new CamelCasePropertyNamesContractResolver(),
                    StringEscapeHandling = StringEscapeHandling.EscapeHtml
                });
            }

            int targetProductId = ProductItem?.Id ?? productId;
            int? currentUserId = null;
            try
            {
                var cookieToken = Request.Cookies[Constants.AppConstants.JwtConfiguration.AuthCookieName]?.Value;
                if (!string.IsNullOrEmpty(cookieToken))
                {
                    var user = new JwtTokenProvider().ValidateToken(cookieToken);
                    if (user != null) currentUserId = user.Id;
                }
            }
            catch { }

            try
            {
                Reviews = await _reviewRepository.GetProductReviewsAsync(targetProductId, includeHidden: false, currentUserId: currentUserId).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ProductDetail] Error loading reviews for product {targetProductId}: {ex.Message}");
                Reviews = new List<ProductReviewDto>();
            }

            ReviewsCount = Reviews.Count;
            ReviewsJson = JsonConvert.SerializeObject(Reviews);
        }

        public string RenderReviewStars(int rating)
        {
            var sb = new System.Text.StringBuilder();
            for (int i = 1; i <= 5; i++)
            {
                if (i <= rating)
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

        public string GetReviewerInitial(string reviewerName)
        {
            return string.IsNullOrWhiteSpace(reviewerName)
                ? "?"
                : char.ToUpperInvariant(reviewerName.Trim()[0]).ToString();
        }

        public string GetColorSwatchClass(string colorName)
        {
            if (string.IsNullOrWhiteSpace(colorName)) return "swatch--charcoal";
            var lower = colorName.ToLowerInvariant();
            if (lower.Contains("gradient") || lower.Contains("chameleon") || lower.Contains("iridescent") || lower.Contains("rainbow"))
                return "swatch--gradient";
            if (lower.Contains("charcoal") || lower.Contains("carbon")) return "swatch--charcoal";
            if (lower.Contains("black")) return "swatch--black";
            if (lower.Contains("white")) return "swatch--white";
            if (lower.Contains("red")) return "swatch--red";
            if (lower.Contains("olive") || lower.Contains("green")) return "swatch--olive";
            if (lower.Contains("navy") || lower.Contains("blue")) return "swatch--navy";
            if (lower.Contains("yellow")) return "swatch--yellow";
            if (lower.Contains("orange")) return "swatch--orange";
            return "swatch--charcoal";
        }

        public string GetGalleryThumbClass(int itemIndex)
        {
            var classes = new List<string> { "gallery-thumb" };
            if (itemIndex == 0)
            {
                classes.Add("active");
            }
            if (itemIndex >= 5)
            {
                classes.Add("gallery-thumb--hidden");
            }
            else if (itemIndex == 4 && GalleryImages != null && GalleryImages.Count > 5)
            {
                classes.Add("gallery-thumb--has-more");
            }
            return string.Join(" ", classes);
        }

        public bool IsFifthThumbWithMore(int itemIndex)
        {
            return itemIndex == 4 && GalleryImages != null && GalleryImages.Count > 5;
        }

        public int GetExtraImagesCount()
        {
            return GalleryImages != null && GalleryImages.Count > 5 ? GalleryImages.Count - 5 : 0;
        }

        private static readonly Dictionary<string, int> SizeOrderMap = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
        {
            { "XXS", 1 }, { "2XS", 1 },
            { "XS", 2 },  { "Extra Small", 2 },
            { "S", 3 },   { "Small", 3 },
            { "M", 4 },   { "Medium", 4 },
            { "L", 5 },   { "Large", 5 },
            { "XL", 6 },  { "X-Large", 6 }, { "Extra Large", 6 },
            { "2XL", 7 }, { "XXL", 7 },
            { "3XL", 8 }, { "XXXL", 8 },
            { "4XL", 9 }, { "XXXXL", 9 },
            { "5XL", 10 }
        };

        private static int GetSizeOrder(string size)
        {
            if (string.IsNullOrWhiteSpace(size)) return 999;
            string key = size.Trim();
            return SizeOrderMap.TryGetValue(key, out int order) ? order : 100;
        }

        private static string NormalizeDisplaySize(string size)
        {
            if (string.IsNullOrWhiteSpace(size)) return size;
            string trimmed = size.Trim();
            if (string.Equals(trimmed, "XXL", StringComparison.OrdinalIgnoreCase)) return "2XL";
            if (string.Equals(trimmed, "XXXL", StringComparison.OrdinalIgnoreCase)) return "3XL";
            if (string.Equals(trimmed, "XXXXL", StringComparison.OrdinalIgnoreCase)) return "4XL";
            return trimmed;
        }
    }
}

