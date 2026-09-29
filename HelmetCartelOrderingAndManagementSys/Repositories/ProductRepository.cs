using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public class ProductRepository : IProductRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public ProductRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory ?? throw new ArgumentNullException(nameof(dbFactory));
        }

        public async Task<PagedResult<ProductListDto>> GetProductsAsync(ProductFilterParams filter)
        {
            var result = new PagedResult<ProductListDto>
            {
                Page = filter.Page,
                PageSize = filter.PageSize
            };

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetProductsPaged", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.Add(new SqlParameter("@CategoryId", SqlDbType.Int) { Value = (object)filter.CategoryId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@BrandId", SqlDbType.Int) { Value = (object)filter.BrandId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@Brand", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(filter.Brand) ? (object)DBNull.Value : filter.Brand });
                    cmd.Parameters.Add(new SqlParameter("@Category", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(filter.Category) ? (object)DBNull.Value : filter.Category });
                    cmd.Parameters.Add(new SqlParameter("@RidingStyle", SqlDbType.NVarChar, 50) { Value = string.IsNullOrWhiteSpace(filter.RidingStyle) ? (object)DBNull.Value : filter.RidingStyle });
                    cmd.Parameters.Add(new SqlParameter("@Search", SqlDbType.NVarChar, 200) { Value = string.IsNullOrWhiteSpace(filter.Search) ? (object)DBNull.Value : filter.Search });
                    if (filter.OnSale)
                        cmd.Parameters.Add(new SqlParameter("@OnSale", SqlDbType.Bit) { Value = true });
                    cmd.Parameters.Add(new SqlParameter("@MinPrice", SqlDbType.Decimal) { Value = (object)filter.MinPrice ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@MaxPrice", SqlDbType.Decimal) { Value = (object)filter.MaxPrice ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@Colors", SqlDbType.NVarChar, 200) { Value = string.IsNullOrWhiteSpace(filter.Colors) ? (object)DBNull.Value : filter.Colors });
                    cmd.Parameters.Add(new SqlParameter("@Sizes", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(filter.Sizes) ? (object)DBNull.Value : filter.Sizes });
                    cmd.Parameters.Add(new SqlParameter("@SortBy", SqlDbType.NVarChar, 50) { Value = string.IsNullOrWhiteSpace(filter.SortBy) ? "popular" : filter.SortBy });
                    cmd.Parameters.Add(new SqlParameter("@PageNumber", SqlDbType.Int) { Value = filter.Page });
                    cmd.Parameters.Add(new SqlParameter("@PageSize", SqlDbType.Int) { Value = filter.PageSize });

                    var totalCountParam = new SqlParameter("@TotalCount", SqlDbType.Int)
                    {
                        Direction = ParameterDirection.Output
                    };
                    cmd.Parameters.Add(totalCountParam);

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            result.Items.Add(new ProductListDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                Slug = reader.GetString(reader.GetOrdinal("Slug")),
                                Brand = reader.GetString(reader.GetOrdinal("Brand")),
                                Category = reader.GetString(reader.GetOrdinal("Category")),
                                RidingStyle = reader.GetString(reader.GetOrdinal("RidingStyle")),
                                BasePrice = reader.GetDecimal(reader.GetOrdinal("BasePrice")),
                                DiscountPercentage = reader.GetInt32(reader.GetOrdinal("DiscountPercentage")),
                                CalculatedEffectivePrice = HasColumn(reader, "EffectivePrice") && !reader.IsDBNull(reader.GetOrdinal("EffectivePrice")) ? reader.GetDecimal(reader.GetOrdinal("EffectivePrice")) : 0m,
                                DiscountType = HasColumn(reader, "DiscountType") && !reader.IsDBNull(reader.GetOrdinal("DiscountType")) ? reader.GetString(reader.GetOrdinal("DiscountType")) : "Percentage",
                                DiscountAmount = HasColumn(reader, "DiscountAmount") && !reader.IsDBNull(reader.GetOrdinal("DiscountAmount")) ? reader.GetDecimal(reader.GetOrdinal("DiscountAmount")) : 0m,
                                DiscountStartDate = HasColumn(reader, "DiscountStartDate") && !reader.IsDBNull(reader.GetOrdinal("DiscountStartDate")) ? (DateTime?)reader.GetDateTime(reader.GetOrdinal("DiscountStartDate")) : null,
                                DiscountEndDate = HasColumn(reader, "DiscountEndDate") && !reader.IsDBNull(reader.GetOrdinal("DiscountEndDate")) ? (DateTime?)reader.GetDateTime(reader.GetOrdinal("DiscountEndDate")) : null,
                                DiscountIsActive = HasColumn(reader, "DiscountIsActive") && !reader.IsDBNull(reader.GetOrdinal("DiscountIsActive")) && reader.GetBoolean(reader.GetOrdinal("DiscountIsActive")),
                                HasActiveDiscount = HasColumn(reader, "HasActiveDiscount") && !reader.IsDBNull(reader.GetOrdinal("HasActiveDiscount")) && reader.GetBoolean(reader.GetOrdinal("HasActiveDiscount")),
                                Rating = reader.GetDecimal(reader.GetOrdinal("Rating")),
                                ReviewCount = reader.GetInt32(reader.GetOrdinal("ReviewCount")),
                                MainImageUrl = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? string.Empty : NormalizeImageUrl(reader.GetString(reader.GetOrdinal("MainImageUrl"))),
                                Description = reader.IsDBNull(reader.GetOrdinal("Description")) ? string.Empty : reader.GetString(reader.GetOrdinal("Description")),
                                IsFeatured = reader.GetBoolean(reader.GetOrdinal("IsFeatured"))
                            });
                        }
                    }

                    if (totalCountParam.Value != null && totalCountParam.Value != DBNull.Value)
                    {
                        result.TotalCount = Convert.ToInt32(totalCountParam.Value);
                    }
                }
            }

            return result;
        }

        public async Task<ProductListDto> GetProductByIdAsync(int id)
        {
            ProductListDto product = null;

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetProductById", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = id });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        // 1. Product Header
                        if (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            product = new ProductListDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                Slug = reader.GetString(reader.GetOrdinal("Slug")),
                                Brand = reader.GetString(reader.GetOrdinal("Brand")),
                                Category = reader.GetString(reader.GetOrdinal("Category")),
                                RidingStyle = reader.GetString(reader.GetOrdinal("RidingStyle")),
                                BasePrice = reader.GetDecimal(reader.GetOrdinal("BasePrice")),
                                DiscountPercentage = reader.GetInt32(reader.GetOrdinal("DiscountPercentage")),
                                CalculatedEffectivePrice = HasColumn(reader, "EffectivePrice") && !reader.IsDBNull(reader.GetOrdinal("EffectivePrice")) ? reader.GetDecimal(reader.GetOrdinal("EffectivePrice")) : 0m,
                                DiscountType = HasColumn(reader, "DiscountType") && !reader.IsDBNull(reader.GetOrdinal("DiscountType")) ? reader.GetString(reader.GetOrdinal("DiscountType")) : "Percentage",
                                DiscountAmount = HasColumn(reader, "DiscountAmount") && !reader.IsDBNull(reader.GetOrdinal("DiscountAmount")) ? reader.GetDecimal(reader.GetOrdinal("DiscountAmount")) : 0m,
                                DiscountStartDate = HasColumn(reader, "DiscountStartDate") && !reader.IsDBNull(reader.GetOrdinal("DiscountStartDate")) ? (DateTime?)reader.GetDateTime(reader.GetOrdinal("DiscountStartDate")) : null,
                                DiscountEndDate = HasColumn(reader, "DiscountEndDate") && !reader.IsDBNull(reader.GetOrdinal("DiscountEndDate")) ? (DateTime?)reader.GetDateTime(reader.GetOrdinal("DiscountEndDate")) : null,
                                DiscountIsActive = HasColumn(reader, "DiscountIsActive") && !reader.IsDBNull(reader.GetOrdinal("DiscountIsActive")) && reader.GetBoolean(reader.GetOrdinal("DiscountIsActive")),
                                HasActiveDiscount = HasColumn(reader, "HasActiveDiscount") && !reader.IsDBNull(reader.GetOrdinal("HasActiveDiscount")) && reader.GetBoolean(reader.GetOrdinal("HasActiveDiscount")),
                                Rating = reader.GetDecimal(reader.GetOrdinal("Rating")),
                                ReviewCount = reader.GetInt32(reader.GetOrdinal("ReviewCount")),
                                OrderCount = reader.GetInt32(reader.GetOrdinal("OrderCount")),
                                MainImageUrl = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? string.Empty : NormalizeImageUrl(reader.GetString(reader.GetOrdinal("MainImageUrl"))),
                                Description = reader.IsDBNull(reader.GetOrdinal("Description")) ? string.Empty : reader.GetString(reader.GetOrdinal("Description")),
                                IsFeatured = reader.GetBoolean(reader.GetOrdinal("IsFeatured"))
                            };
                        }

                        // 2. Product Variants & Inventory
                        if (product != null && await reader.NextResultAsync().ConfigureAwait(false))
                        {
                            while (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                product.Variants.Add(new ProductVariantDto
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    ProductId = reader.GetInt32(reader.GetOrdinal("ProductId")),
                                    SKU = reader.GetString(reader.GetOrdinal("SKU")),
                                    Size = reader.GetString(reader.GetOrdinal("Size")),
                                    Color = reader.GetString(reader.GetOrdinal("Color")),
                                    ColorHex = reader.GetString(reader.GetOrdinal("ColorHex")),
                                    PriceAdjustment = reader.GetDecimal(reader.GetOrdinal("PriceAdjustment")),
                                    EffectivePrice = HasColumn(reader, "EffectivePrice") && !reader.IsDBNull(reader.GetOrdinal("EffectivePrice")) ? reader.GetDecimal(reader.GetOrdinal("EffectivePrice")) : 0m,
                                    CurrentStock = reader.GetInt32(reader.GetOrdinal("CurrentStock")),
                                    IsLowStock = Convert.ToBoolean(reader["IsLowStock"]),
                                    DiscountType = HasColumn(reader, "DiscountType") && !reader.IsDBNull(reader.GetOrdinal("DiscountType")) ? reader.GetString(reader.GetOrdinal("DiscountType")) : null,
                                    DiscountAmount = HasColumn(reader, "DiscountAmount") && !reader.IsDBNull(reader.GetOrdinal("DiscountAmount")) ? reader.GetDecimal(reader.GetOrdinal("DiscountAmount")) : 0m,
                                    DiscountStartDate = HasColumn(reader, "DiscountStartDate") && !reader.IsDBNull(reader.GetOrdinal("DiscountStartDate")) ? (DateTime?)reader.GetDateTime(reader.GetOrdinal("DiscountStartDate")) : null,
                                    DiscountEndDate = HasColumn(reader, "DiscountEndDate") && !reader.IsDBNull(reader.GetOrdinal("DiscountEndDate")) ? (DateTime?)reader.GetDateTime(reader.GetOrdinal("DiscountEndDate")) : null,
                                    HasActiveDiscount = HasColumn(reader, "HasActiveDiscount") && !reader.IsDBNull(reader.GetOrdinal("HasActiveDiscount")) && reader.GetBoolean(reader.GetOrdinal("HasActiveDiscount"))
                                });
                            }
                        }

                        // 3. Additional product gallery images (main image is rendered separately).
                        if (product != null && await reader.NextResultAsync().ConfigureAwait(false))
                        {
                            while (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                product.GalleryImages.Add(new ProductGalleryImageDto
                                {
                                    ImageUrl = reader.IsDBNull(reader.GetOrdinal("ImageUrl")) ? string.Empty : NormalizeImageUrl(reader.GetString(reader.GetOrdinal("ImageUrl"))),
                                    AltText = reader.IsDBNull(reader.GetOrdinal("AltText")) ? product.Name : reader.GetString(reader.GetOrdinal("AltText")),
                                    DisplayOrder = reader.GetInt32(reader.GetOrdinal("DisplayOrder"))
                                });
                            }
                        }
                    }
                }
            }

            return product;
        }

        public async Task<List<ProductSpecificationDto>> GetProductSpecificationsAsync(int productId)
        {
            var specifications = new List<ProductSpecificationDto>();
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);
                using (var cmd = new SqlCommand("dbo.sp_GetProductSpecifications", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });
                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            specifications.Add(new ProductSpecificationDto
                            {
                                SpecificationKey = reader.GetString(reader.GetOrdinal("SpecificationKey")),
                                DisplayName = reader.GetString(reader.GetOrdinal("DisplayName")),
                                SpecificationValue = reader.GetString(reader.GetOrdinal("SpecificationValue")),
                                DisplayOrder = reader.GetInt32(reader.GetOrdinal("DisplayOrder"))
                            });
                        }
                    }
                }
            }
            return specifications;
        }

        public async Task<List<ProductListDto>> GetRelatedProductsAsync(int productId)
        {
            var relatedProducts = new List<ProductListDto>();
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);
                using (var cmd = new SqlCommand("dbo.sp_GetRelatedProducts", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });
                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            relatedProducts.Add(new ProductListDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                Slug = reader.GetString(reader.GetOrdinal("Slug")),
                                Brand = reader.GetString(reader.GetOrdinal("Brand")),
                                Category = reader.GetString(reader.GetOrdinal("Category")),
                                RidingStyle = reader.GetString(reader.GetOrdinal("RidingStyle")),
                                BasePrice = reader.GetDecimal(reader.GetOrdinal("BasePrice")),
                                DiscountPercentage = reader.GetInt32(reader.GetOrdinal("DiscountPercentage")),
                                Rating = reader.GetDecimal(reader.GetOrdinal("Rating")),
                                ReviewCount = reader.GetInt32(reader.GetOrdinal("ReviewCount")),
                                MainImageUrl = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? string.Empty : NormalizeImageUrl(reader.GetString(reader.GetOrdinal("MainImageUrl"))),
                                Description = reader.IsDBNull(reader.GetOrdinal("Description")) ? string.Empty : reader.GetString(reader.GetOrdinal("Description")),
                                IsFeatured = reader.GetBoolean(reader.GetOrdinal("IsFeatured"))
                            });
                        }
                    }
                }
            }
            return relatedProducts;
        }

        public async Task<List<ProductListDto>> GetFeaturedProductsAsync()
        {
            var filter = new ProductFilterParams { Page = 1, PageSize = 8, SortBy = "popular" };
            var result = await GetProductsAsync(filter).ConfigureAwait(false);
            return result.Items;
        }

        public async Task<List<ProductListDto>> GetNewArrivalsAsync(int count = 4)
        {
            var filter = new ProductFilterParams { Page = 1, PageSize = count, SortBy = "newest" };
            var result = await GetProductsAsync(filter).ConfigureAwait(false);
            return result.Items;
        }

        public async Task<List<ProductListDto>> GetTopSellingAsync(int count = 4)
        {
            var filter = new ProductFilterParams { Page = 1, PageSize = count, SortBy = "rating" };
            var result = await GetProductsAsync(filter).ConfigureAwait(false);
            return result.Items;
        }

        public async Task<List<CategoryDto>> GetCategoriesAsync()
        {
            var list = new List<CategoryDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetCategories", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            list.Add(new CategoryDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                Slug = reader.GetString(reader.GetOrdinal("Slug")),
                                Description = reader.IsDBNull(reader.GetOrdinal("Description")) ? string.Empty : reader.GetString(reader.GetOrdinal("Description")),
                                DisplayOrder = reader.GetInt32(reader.GetOrdinal("DisplayOrder")),
                                ProductCount = reader.GetInt32(reader.GetOrdinal("ProductCount"))
                            });
                        }
                    }
                }
            }

            return list;
        }

        public async Task<List<BrandDto>> GetBrandsAsync()
        {
            var list = new List<BrandDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetBrands", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            list.Add(new BrandDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                LogoUrl = reader.IsDBNull(reader.GetOrdinal("LogoUrl")) ? string.Empty : reader.GetString(reader.GetOrdinal("LogoUrl")),
                                Website = reader.IsDBNull(reader.GetOrdinal("Website")) ? string.Empty : reader.GetString(reader.GetOrdinal("Website")),
                                ProductCount = reader.GetInt32(reader.GetOrdinal("ProductCount"))
                            });
                        }
                    }
                }
            }

            return list;
        }

        public async Task<ProductColorDto> AddProductColorAsync(int productId, string color, string colorHex)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);
                using (var cmd = new SqlCommand("dbo.sp_AddProductColor", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });
                    cmd.Parameters.Add(new SqlParameter("@Color", SqlDbType.NVarChar, 50) { Value = color });
                    cmd.Parameters.Add(new SqlParameter("@ColorHex", SqlDbType.NVarChar, 255) { Value = colorHex });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        if (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            return new ProductColorDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                ProductId = reader.GetInt32(reader.GetOrdinal("ProductId")),
                                Color = reader.GetString(reader.GetOrdinal("Color")),
                                ColorHex = reader.GetString(reader.GetOrdinal("ColorHex")),
                                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
                            };
                        }
                    }
                }
            }

            return null;
        }

        private static string NormalizeImageUrl(string url)
        {
            if (string.IsNullOrWhiteSpace(url)) return string.Empty;
            return url.Replace("/Content/images/helmets/", "/Content/images/products/helmets/");
        }

        private static bool HasColumn(System.Data.IDataRecord reader, string columnName)
        {
            for (int i = 0; i < reader.FieldCount; i++)
            {
                if (reader.GetName(i).Equals(columnName, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }
    }
}
