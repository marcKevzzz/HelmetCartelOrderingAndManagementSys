using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public interface IProductRepository
    {
        Task<PagedResult<ProductListDto>> GetProductsAsync(ProductFilterParams filter);
        Task<ProductListDto> GetProductByIdAsync(int id);
        Task<ProductListDto> GetProductBySlugAsync(string slug);
        Task<List<ProductListDto>> GetRelatedProductsAsync(int productId);
        Task<List<ProductSpecificationDto>> GetProductSpecificationsAsync(int productId);
        Task<List<ProductListDto>> GetFeaturedProductsAsync();
        Task<List<ProductListDto>> GetNewArrivalsAsync(int count = 4);
        Task<List<ProductListDto>> GetTopSellingAsync(int count = 4);
        Task<List<CategoryDto>> GetCategoriesAsync();
        Task<List<BrandDto>> GetBrandsAsync();
        Task<ProductColorDto> AddProductColorAsync(int productId, string color, string colorHex);
    }
}
