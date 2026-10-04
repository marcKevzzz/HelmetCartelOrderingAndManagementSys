using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public sealed class ShoppingStateDto
    {
        public List<CartItemDto> Cart { get; set; } = new List<CartItemDto>();
        public List<FavoriteItemDto> Favorites { get; set; } = new List<FavoriteItemDto>();
    }

    public sealed class CartItemDto
    {
        public int VariantId { get; set; }
        public int ProductId { get; set; }
        public int Quantity { get; set; }
        public bool IsSelected { get; set; }
        public string Name { get; set; }
        public string Brand { get; set; }
        public string Size { get; set; }
        public string Color { get; set; }
        public string ImageUrl { get; set; }
        public decimal Price { get; set; }
        public int AvailableStock { get; set; }
    }

    public sealed class FavoriteItemDto
    {
        public int ProductId { get; set; }
        public string Name { get; set; }
        public string Brand { get; set; }
        public string Category { get; set; }
        public string ImageUrl { get; set; }
        public decimal Price { get; set; }
        public decimal OriginalPrice { get; set; }
        public int DiscountPercentage { get; set; }
        public decimal Rating { get; set; }
        public int ReviewCount { get; set; }
        public bool IsOutOfStock { get; set; }
    }

    public sealed class CartChangeDto
    {
        [Range(1, int.MaxValue)]
        public int VariantId { get; set; }
        [Range(0, 9999)]
        public int? Quantity { get; set; }
        public bool? IsSelected { get; set; }
    }

    public sealed class ShoppingImportDto
    {
        public List<CartChangeDto> Cart { get; set; } = new List<CartChangeDto>();
        public List<int> Favorites { get; set; } = new List<int>();
    }
}
