using System;
using System.Collections.Generic;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public class ProductListDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Slug { get; set; }
        public string Brand { get; set; }
        public string Category { get; set; }
        public string RidingStyle { get; set; }
        public decimal BasePrice { get; set; }
        public int DiscountPercentage { get; set; }
        public decimal CalculatedEffectivePrice { get; set; }
        public string DiscountType { get; set; } = "Percentage";
        public decimal DiscountAmount { get; set; }
        public DateTime? DiscountStartDate { get; set; }
        public DateTime? DiscountEndDate { get; set; }
        public bool DiscountIsActive { get; set; } = true;
        public bool HasActiveDiscount { get; set; }

        public decimal EffectivePrice
        {
            get
            {
                if (CalculatedEffectivePrice > 0)
                {
                    return CalculatedEffectivePrice;
                }
                if (HasActiveDiscount || DiscountPercentage > 0)
                {
                    if (string.Equals(DiscountType, "FixedAmount", StringComparison.OrdinalIgnoreCase))
                    {
                        return Math.Max(0, BasePrice - DiscountAmount);
                    }
                    decimal pct = DiscountAmount > 0 ? DiscountAmount : DiscountPercentage;
                    return Math.Round(BasePrice * (1.0m - (pct / 100.0m)), 2);
                }
                return BasePrice;
            }
            set => CalculatedEffectivePrice = value;
        }

        public string DiscountBadgeText
        {
            get
            {
                if (!HasActiveDiscount && DiscountPercentage <= 0) return string.Empty;
                if (string.Equals(DiscountType, "FixedAmount", StringComparison.OrdinalIgnoreCase))
                {
                    return $"-&#8369;{DiscountAmount:N0}";
                }
                decimal pct = DiscountAmount > 0 ? DiscountAmount : DiscountPercentage;
                return $"-{pct:0}%";
            }
        }
        public decimal Rating { get; set; }
        public int ReviewCount { get; set; }
        public int OrderCount { get; set; }
        public string MainImageUrl { get; set; }
        public string Description { get; set; }
        public bool IsFeatured { get; set; }
        public List<ProductVariantDto> Variants { get; set; } = new List<ProductVariantDto>();
        public List<ProductGalleryImageDto> GalleryImages { get; set; } = new List<ProductGalleryImageDto>();
    }

    public class ProductGalleryImageDto
    {
        public string ImageUrl { get; set; }
        public string AltText { get; set; }
        public int DisplayOrder { get; set; }
    }

    public class ProductSpecificationDto
    {
        public string SpecificationKey { get; set; }
        public string DisplayName { get; set; }
        public string SpecificationValue { get; set; }
        public int DisplayOrder { get; set; }
    }

    public class ProductVariantDto
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string SKU { get; set; }
        public string Size { get; set; }
        public string Color { get; set; }
        public string ColorHex { get; set; }
        public decimal PriceAdjustment { get; set; }
        public decimal EffectivePrice { get; set; }
        public int CurrentStock { get; set; }
        public bool IsLowStock { get; set; }
        public string DiscountType { get; set; }
        public decimal DiscountAmount { get; set; }
        public DateTime? DiscountStartDate { get; set; }
        public DateTime? DiscountEndDate { get; set; }
        public bool HasActiveDiscount { get; set; }
    }

    public class ProductFilterParams
    {
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 12;
        public int? CategoryId { get; set; }
        public int? BrandId { get; set; }
        public string Brand { get; set; }
        public string Category { get; set; }
        public string RidingStyle { get; set; }
        public string Search { get; set; }
        public bool OnSale { get; set; }
        public decimal? MinPrice { get; set; }
        public decimal? MaxPrice { get; set; }
        public string Colors { get; set; }
        public string Sizes { get; set; }
        public string SortBy { get; set; } // "price_asc", "price_desc", "rating", "newest"
    }

    public class PagedResult<T>
    {
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalPages => (int)System.Math.Ceiling((double)TotalCount / PageSize);
        public List<T> Items { get; set; } = new List<T>();
    }

    public class CategoryDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Slug { get; set; }
        public string Description { get; set; }
        public int DisplayOrder { get; set; }
        public int ProductCount { get; set; }
    }

    public class BrandDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string LogoUrl { get; set; }
        public string Website { get; set; }
        public int ProductCount { get; set; }
    }

    public class ProductColorDto
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string Color { get; set; }
        public string ColorHex { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class AddProductColorDto
    {
        public string Color { get; set; }
        public string ColorHex { get; set; }
    }
}
