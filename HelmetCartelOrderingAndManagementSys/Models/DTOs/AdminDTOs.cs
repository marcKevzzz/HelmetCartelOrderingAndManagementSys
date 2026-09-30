using System.Collections.Generic;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public sealed class AdminStockAdjustmentDto
    {
        public int VariantId { get; set; }
        public int QuantityChanged { get; set; }
        public string ReferenceNumber { get; set; }
        public string Notes { get; set; }
    }

    public sealed class AdminProductDto
    {
        public int Id { get; set; }
        public int CategoryId { get; set; }
        public int BrandId { get; set; }
        public string Name { get; set; }
        public string Slug { get; set; }
        public string Description { get; set; }
        public string RidingStyle { get; set; }
        public decimal BasePrice { get; set; }
        public int DiscountPercentage { get; set; }
        public string DiscountType { get; set; } = "Percentage";
        public decimal DiscountAmount { get; set; }
        public System.DateTime? DiscountStartDate { get; set; }
        public System.DateTime? DiscountEndDate { get; set; }
        public bool DiscountIsActive { get; set; } = true;
        public string MainImageUrl { get; set; }
        public bool IsFeatured { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public sealed class AdminCategoryDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Slug { get; set; }
        public string Description { get; set; }
        public int DisplayOrder { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public sealed class AdminBrandDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string LogoUrl { get; set; }
        public string Website { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public sealed class AdminColorDto
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string Color { get; set; }
        public string ColorType { get; set; }
        public string SolidHex { get; set; }
        public int? GradientAngle { get; set; }
        public List<string> Stops { get; set; } = new List<string>();
    }

    public sealed class AdminVariantDto
    {
        public int Id { get; set; }
        public int ProductColorId { get; set; }
        public string SKU { get; set; }
        public string Size { get; set; }
        public decimal PriceAdjustment { get; set; }
        public int ReorderPoint { get; set; }
        public bool IsActive { get; set; } = true;
        public int CurrentStock { get; set; }
        public string Color { get; set; }
        public string ColorHex { get; set; }
    }

    public sealed class AdminGalleryDto
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string ImageUrl { get; set; }
        public string AltText { get; set; }
        public int DisplayOrder { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public sealed class AdminUserDto
    {
        public int Id { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Email { get; set; }
        public string Password { get; set; }
        public string PhoneNumber { get; set; }
        public string Role { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public sealed class AdminReviewDto
    {
        public bool IsHidden { get; set; }
    }

    public sealed class AdminSpecificationDto
    {
        public int ProductId { get; set; }
        public string SpecificationKey { get; set; }
        public string SpecificationValue { get; set; }
    }

    public sealed class AdminInventoryItemDto
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public string Slug { get; set; }
        public int BrandId { get; set; }
        public string BrandName { get; set; }
        public int CategoryId { get; set; }
        public string CategoryName { get; set; }
        public string RidingStyle { get; set; }
        public decimal BasePrice { get; set; }
        public int DiscountPercentage { get; set; }
        public decimal EffectivePrice { get; set; }
        public string MainImageUrl { get; set; }
        public bool IsActive { get; set; }
        public int TotalStock { get; set; }
        public int ReservedStock { get; set; }
        public int AvailableStock { get; set; }
        public int VariantCount { get; set; }
        public string SampleSKU { get; set; }
        public string StockStatus { get; set; }
    }

    public sealed class AdminInventoryVariantDto
    {
        public int VariantId { get; set; }
        public int ProductId { get; set; }
        public string BrandName { get; set; }
        public string ProductName { get; set; }
        public string CategoryName { get; set; }
        public string Color { get; set; }
        public string ColorHex { get; set; }
        public string Size { get; set; }
        public int CurrentStock { get; set; }
        public int ReservedStock { get; set; }
        public int AvailableStock { get; set; }
        public int ReorderPoint { get; set; }
        public decimal EffectivePrice { get; set; }
        public string SKU { get; set; }
        public string MainImageUrl { get; set; }
        public string StockStatus { get; set; }
    }

    public sealed class AdminOrderListItemDto
    {
        public int Id { get; set; }
        public string OrderNumber { get; set; }
        public string CustomerName { get; set; }
        public string CustomerEmail { get; set; }
        public string CustomerPhone { get; set; }
        public string OrderSource { get; set; }
        public string Status { get; set; }
        public decimal TotalAmount { get; set; }
        public System.DateTime CreatedAt { get; set; }
        public int ItemCount { get; set; }
        public string PaymentStatus { get; set; }
        public string PaymentMethod { get; set; }
        public string ShippingMethod { get; set; } = "Pickup";
        public decimal ShippingFee { get; set; }
        public string ShippingRegion { get; set; }
        public string ShippingAddress { get; set; }
        public string ShippingBarangay { get; set; }
        public string ShippingCity { get; set; }
        public string ShippingProvince { get; set; }
        public string ShippingPostalCode { get; set; }
        public string Courier { get; set; }
        public string TrackingNumber { get; set; }
        public string DeliveryNotes { get; set; }
    }

    public sealed class AdminCatalogItemDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Slug { get; set; }
        public string Description { get; set; }
        public int CategoryId { get; set; }
        public string Category { get; set; }
        public int BrandId { get; set; }
        public string Brand { get; set; }
        public string RidingStyle { get; set; }
        public decimal BasePrice { get; set; }
        public int DiscountPercentage { get; set; }
        public decimal CalculatedEffectivePrice { get; set; }
        public string DiscountType { get; set; } = "Percentage";
        public decimal DiscountAmount { get; set; }
        public System.DateTime? DiscountStartDate { get; set; }
        public System.DateTime? DiscountEndDate { get; set; }
        public bool DiscountIsActive { get; set; } = true;
        public bool HasActiveDiscount { get; set; }

        public decimal EffectivePrice
        {
            get
            {
                if (CalculatedEffectivePrice > 0) return CalculatedEffectivePrice;
                if (HasActiveDiscount || DiscountPercentage > 0)
                {
                    if (string.Equals(DiscountType, "FixedAmount", System.StringComparison.OrdinalIgnoreCase))
                    {
                        return System.Math.Max(0, BasePrice - DiscountAmount);
                    }
                    decimal pct = DiscountAmount > 0 ? DiscountAmount : DiscountPercentage;
                    return System.Math.Round(BasePrice * (1.0m - (pct / 100.0m)), 2);
                }
                return BasePrice;
            }
            set => CalculatedEffectivePrice = value;
        }

        public string DiscountBadgeText
        {
            get
            {
                if (!HasActiveDiscount && DiscountPercentage <= 0) return "0%";
                if (string.Equals(DiscountType, "FixedAmount", System.StringComparison.OrdinalIgnoreCase))
                {
                    return $"-&#8369;{DiscountAmount:N0}";
                }
                decimal pct = DiscountAmount > 0 ? DiscountAmount : DiscountPercentage;
                return $"-{pct:0}%";
            }
        }
        public string MainImageUrl { get; set; }
        public bool IsFeatured { get; set; }
        public bool IsActive { get; set; }
        public System.DateTime CreatedAt { get; set; }
        public int VariantCount { get; set; }
    }

    public sealed class AdminUserListItemDto
    {
        public int Id { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string FullName => $"{FirstName} {LastName}".Trim();
        public string Email { get; set; }
        public string PhoneNumber { get; set; }
        public string Role { get; set; }
        public bool IsActive { get; set; }
        public System.DateTime CreatedAt { get; set; }
    }

    public sealed class AdminBrandReportDto
    {
        public string Brand { get; set; }
        public int VariantCount { get; set; }
        public int OnHandStock { get; set; }
        public int AvailableStock { get; set; }
        public int LowStockCount { get; set; }
    }

    public sealed class AdminBrandInventoryDetailDto
    {
        public string Brand { get; set; }
        public int ProductId { get; set; }
        public int VariantId { get; set; }
        public string ProductName { get; set; }
        public string CategoryName { get; set; }
        public string MainImageUrl { get; set; }
        public string Color { get; set; }
        public string Size { get; set; }
        public string SKU { get; set; }
        public int OnHandStock { get; set; }
        public int AvailableStock { get; set; }
        public int ReorderPoint { get; set; }
        public string StockStatus { get; set; }
    }

    public sealed class AdminInventoryTrendDto
    {
        public int StartTotalUnits { get; set; }
        public int EndTotalUnits { get; set; }
        public int StartActiveSkus { get; set; }
        public int EndActiveSkus { get; set; }
    }

    public sealed class AdminDailySaleDto
    {
        public System.DateTime SalesDate { get; set; }
        public int PaymentCount { get; set; }
        public decimal Revenue { get; set; }
    }

    public sealed class AdminGlobalSearchResultDto
    {
        public string Category { get; set; }
        public string Title { get; set; }
        public string Subtitle { get; set; }
        public string Url { get; set; }
        public string Badge { get; set; }
    }

    public sealed class AdminStockAuditLogDto
    {
        public long Id { get; set; }
        public int VariantId { get; set; }
        public string BrandName { get; set; }
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public string Color { get; set; }
        public string Size { get; set; }
        public string SKU { get; set; }
        public string ChangeType { get; set; }
        public int PreviousStock { get; set; }
        public int QuantityChanged { get; set; }
        public int NewStock { get; set; }
        public string ReferenceNumber { get; set; }
        public string Notes { get; set; }
        public System.DateTime CreatedAt { get; set; }
        public string PerformedBy { get; set; }
    }

    public sealed class AdminSpecificationItemDto
    {
        public string SpecificationKey { get; set; }
        public string DisplayName { get; set; }
        public string SpecificationValue { get; set; }
        public int DisplayOrder { get; set; }
    }

    public sealed class AdminProductCompleteDto
    {
        public int Id { get; set; }
        public int CategoryId { get; set; }
        public int BrandId { get; set; }
        public string Name { get; set; }
        public string Slug { get; set; }
        public string Description { get; set; }
        public string RidingStyle { get; set; }
        public decimal BasePrice { get; set; }
        public int DiscountPercentage { get; set; }
        public string DiscountType { get; set; }
        public decimal DiscountAmount { get; set; }
        public System.DateTime? DiscountStartDate { get; set; }
        public System.DateTime? DiscountEndDate { get; set; }
        public bool DiscountIsActive { get; set; }
        public string MainImageUrl { get; set; }
        public bool IsFeatured { get; set; }
        public bool IsActive { get; set; }
        public string BrandName { get; set; }
        public string CategoryName { get; set; }

        public List<AdminSpecificationItemDto> Specifications { get; set; } = new List<AdminSpecificationItemDto>();
        public List<AdminColorDto> Colors { get; set; } = new List<AdminColorDto>();
        public List<AdminVariantDto> Variants { get; set; } = new List<AdminVariantDto>();
        public List<AdminGalleryDto> GalleryImages { get; set; } = new List<AdminGalleryDto>();
    }
}


