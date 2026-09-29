using System.Threading.Tasks;
using System.Text.RegularExpressions;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/products")]
    public class ProductsController : ApiController
    {
        private readonly IProductRepository _productRepository;

        public ProductsController()
        {
            _productRepository = new ProductRepository(new DbConnectionFactory());
        }

        public ProductsController(IProductRepository productRepository)
        {
            _productRepository = productRepository;
        }

        [HttpGet]
        [Route("")]
        public async Task<IHttpActionResult> GetProducts([FromUri] ProductFilterParams filter)
        {
            filter = filter ?? new ProductFilterParams();
            var result = await _productRepository.GetProductsAsync(filter).ConfigureAwait(false);
            return Ok(ApiResponse<PagedResult<ProductListDto>>.Ok(result));
        }

        [HttpGet]
        [Route("{id:int}")]
        public async Task<IHttpActionResult> GetProductById(int id)
        {
            var product = await _productRepository.GetProductByIdAsync(id).ConfigureAwait(false);
            if (product == null)
            {
                return NotFound();
            }
            return Ok(ApiResponse<ProductListDto>.Ok(product));
        }

        [HttpGet]
        [Route("new-arrivals")]
        public async Task<IHttpActionResult> GetNewArrivals([FromUri] int count = 4)
        {
            var items = await _productRepository.GetNewArrivalsAsync(count).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<ProductListDto>>.Ok(items));
        }

        [HttpGet]
        [Route("top-selling")]
        public async Task<IHttpActionResult> GetTopSelling([FromUri] int count = 4)
        {
            var items = await _productRepository.GetTopSellingAsync(count).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<ProductListDto>>.Ok(items));
        }

        [HttpGet]
        [Route("categories")]
        public async Task<IHttpActionResult> GetCategories()
        {
            var categories = await _productRepository.GetCategoriesAsync().ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<CategoryDto>>.Ok(categories));
        }

        [HttpGet]
        [Route("brands")]
        public async Task<IHttpActionResult> GetBrands()
        {
            var brands = await _productRepository.GetBrandsAsync().ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<BrandDto>>.Ok(brands));
        }

        [HttpPost]
        [Route("{id:int}/colors")]
        [StaffAuthorize(adminOnly: true)]
        public async Task<IHttpActionResult> AddProductColor(int id, [FromBody] AddProductColorDto request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Color) ||
                !Regex.IsMatch(request.ColorHex ?? string.Empty, "^#[0-9A-Fa-f]{6}$"))
            {
                return BadRequest("Color name and six-digit hex are required. Use the admin catalog for gradients.");
            }

            var result = await _productRepository.AddProductColorAsync(id, request.Color.Trim(), request.ColorHex.Trim()).ConfigureAwait(false);
            if (result == null)
            {
                return InternalServerError(new System.Exception("Failed to save product color."));
            }

            return Ok(ApiResponse<ProductColorDto>.Ok(result, "Product color successfully saved."));
        }
    }
}
