using System;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public class InventoryStatusDto
    {
        public int InventoryId { get; set; }
        public int VariantId { get; set; }
        public string ProductName { get; set; }
        public string Brand { get; set; }
        public string SKU { get; set; }
        public string Size { get; set; }
        public string Color { get; set; }
        public int CurrentStock { get; set; }
        public int ReservedStock { get; set; }
        public int AvailableStock => Math.Max(0, CurrentStock - ReservedStock);
        public int ReorderPoint { get; set; }
        public bool IsLowStock { get; set; }
        public DateTime? LastRestockedAt { get; set; }
    }

    public class RestockRequestDto
    {
        public int VariantId { get; set; }
        public int QuantityAdded { get; set; }
        public string SupplierInvoice { get; set; }
        public decimal UnitCost { get; set; }
        public string Notes { get; set; }
    }

    public class StockUpdateBroadcastDto
    {
        public int VariantId { get; set; }
        public string SKU { get; set; }
        public int NewStock { get; set; }
        public bool IsLowStock { get; set; }
        public string ChangeSource { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }
}
