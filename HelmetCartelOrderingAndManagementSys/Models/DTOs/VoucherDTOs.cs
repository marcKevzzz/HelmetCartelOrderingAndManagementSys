using System;
using System.Collections.Generic;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public sealed class VoucherRequestDto
    {
        public string Code { get; set; }
        public List<OrderItemRequestDto> Items { get; set; }
    }

    public sealed class VoucherQuoteDto
    {
        public string Code { get; set; }
        public decimal Subtotal { get; set; }
        public decimal DiscountAmount { get; set; }
        public decimal DiscountedSubtotal { get; set; }
        public string DiscountType { get; set; }
    }

    public sealed class SaveVoucherDto
    {
        public string Code { get; set; }
        public string DiscountType { get; set; }
        public decimal DiscountValue { get; set; }
        public decimal MinimumSpend { get; set; }
        public DateTime? ExpiresAt { get; set; }
        public int? UsageLimit { get; set; }
        public bool IsActive { get; set; } = true;
    }
}
