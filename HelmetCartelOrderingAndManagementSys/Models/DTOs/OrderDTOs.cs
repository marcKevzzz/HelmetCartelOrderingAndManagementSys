using System;
using System.Collections.Generic;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public class CreateOrderRequestDto
    {
        public string VoucherCode { get; set; }
        public string CustomerName { get; set; }
        public string CustomerEmail { get; set; }
        public string CustomerPhone { get; set; }
        public string PaymentMethod { get; set; } // "HitPay", "Cash", "Card_POS", "CashOnDelivery"
        public decimal? CashTendered { get; set; }
        public bool CardTerminalApproved { get; set; }
        public string Notes { get; set; }
        public string ShippingMethod { get; set; } = "Pickup"; // "Pickup", "Delivery"
        public decimal ShippingFee { get; set; } = 0.00m;
        public string ShippingRegion { get; set; }
        public string ShippingAddress { get; set; }
        public string ShippingBarangay { get; set; }
        public string ShippingCity { get; set; }
        public string ShippingProvince { get; set; }
        public string ShippingPostalCode { get; set; }
        public string DeliveryNotes { get; set; }
        public List<OrderItemRequestDto> Items { get; set; } = new List<OrderItemRequestDto>();
    }

    public class OrderItemRequestDto
    {
        public int VariantId { get; set; }
        public int Quantity { get; set; }
    }

    public class OrderSummaryDto
    {
        public int Id { get; set; }
        public string OrderNumber { get; set; }
        public string VoucherCode { get; set; }
        public string CustomerName { get; set; }
        public string CustomerEmail { get; set; }
        public string CustomerPhone { get; set; }
        public string OrderSource { get; set; }
        public string Status { get; set; }
        public decimal Subtotal { get; set; }
        public decimal DiscountAmount { get; set; }
        public decimal TotalAmount { get; set; }
        public string ShippingMethod { get; set; } = "Pickup";
        public decimal ShippingFee { get; set; } = 0.00m;
        public string ShippingRegion { get; set; }
        public string ShippingAddress { get; set; }
        public string ShippingBarangay { get; set; }
        public string ShippingCity { get; set; }
        public string ShippingProvince { get; set; }
        public string ShippingPostalCode { get; set; }
        public string Courier { get; set; }
        public string TrackingNumber { get; set; }
        public string DeliveryNotes { get; set; }
        public string PaymentMethod { get; set; }
        public string PaymentStatus { get; set; }
        public string GatewayReference { get; set; }
        public decimal? CashTendered { get; set; }
        public string CheckoutUrl { get; set; }
        public DateTime CreatedAt { get; set; }
        public string PreviewImages { get; set; }
        public List<string> PreviewImageList { get; set; } = new List<string>();
        public int RmaCount { get; set; }
        public string LatestRmaType { get; set; }
        public string LatestRmaStatus { get; set; }
        public string LatestRmaResolution { get; set; }
        public List<OrderItemSummaryDto> Items { get; set; } = new List<OrderItemSummaryDto>();
    }

    public class OrderItemSummaryDto
    {
        public int Id { get; set; }
        public int VariantId { get; set; }
        public int? ProductId { get; set; }
        public string ProductName { get; set; }
        public string SKU { get; set; }
        public string Size { get; set; }
        public string Color { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
        public string MainImageUrl { get; set; }
        public string ImageUrl { get; set; }
        public int? RmaId { get; set; }
        public string RmaNumber { get; set; }
        public string RmaType { get; set; }
        public string RmaStatus { get; set; }
        public string RmaResolution { get; set; }
        public int? ReviewId { get; set; }
    }

    public class UpdateOrderStatusDto
    {
        public string Status { get; set; }
        public string Notes { get; set; }
        public string Courier { get; set; }
        public string TrackingNumber { get; set; }
    }

    public class DispatchOrderRequestDto
    {
        public string Courier { get; set; }
        public string TrackingNumber { get; set; }
        public string Notes { get; set; }
    }

    public class CancelOrderRequestDto
    {
        public string Reason { get; set; }
    }
}
