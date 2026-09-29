using System;
using System.Collections.Generic;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public class CreateOrderRequestDto
    {
        public string CustomerName { get; set; }
        public string CustomerEmail { get; set; }
        public string CustomerPhone { get; set; }
        public string PaymentMethod { get; set; } // "HitPay", "Cash", "Card_POS"
        public string Notes { get; set; }
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
        public string CustomerName { get; set; }
        public string CustomerEmail { get; set; }
        public string CustomerPhone { get; set; }
        public string OrderSource { get; set; }
        public string Status { get; set; }
        public decimal Subtotal { get; set; }
        public decimal DiscountAmount { get; set; }
        public decimal TotalAmount { get; set; }
        public string CheckoutUrl { get; set; }
        public DateTime CreatedAt { get; set; }
        public List<OrderItemSummaryDto> Items { get; set; } = new List<OrderItemSummaryDto>();
    }

    public class OrderItemSummaryDto
    {
        public int Id { get; set; }
        public int VariantId { get; set; }
        public string ProductName { get; set; }
        public string SKU { get; set; }
        public string Size { get; set; }
        public string Color { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
    }

    public class UpdateOrderStatusDto
    {
        public string Status { get; set; }
        public string Notes { get; set; }
    }
}
