using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Hubs;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public class InventoryService : IInventoryService
    {
        private readonly IInventoryRepository _inventoryRepository;

        public InventoryService(IInventoryRepository inventoryRepository)
        {
            _inventoryRepository = inventoryRepository ?? throw new ArgumentNullException(nameof(inventoryRepository));
        }

        public async Task<List<InventoryStatusDto>> GetCurrentStockLevelsAsync(bool lowStockOnly = false, string search = null)
        {
            return await _inventoryRepository.GetInventoryListAsync(lowStockOnly, search).ConfigureAwait(false);
        }

        public async Task<InventoryStatusDto> GetStockByVariantAsync(int variantId)
        {
            return await _inventoryRepository.GetInventoryByVariantIdAsync(variantId).ConfigureAwait(false);
        }

        public async Task<ApiResponse<int>> RestockInventoryAsync(RestockRequestDto request, int userId)
        {
            if (request == null || request.VariantId <= 0 || request.QuantityAdded <= 0)
                return ApiResponse<int>.Fail("Invalid restock parameters.", AppConstants.ErrorCodes.VariantNotFound);

            var newStock = await _inventoryRepository.RestockVariantAsync(
                request.VariantId, request.QuantityAdded, userId, request.SupplierInvoice, request.Notes).ConfigureAwait(false);

            await NotifyCommittedStockAsync(request.VariantId, newStock, AppConstants.StockAuditChangeType.Restock).ConfigureAwait(false);

            return ApiResponse<int>.Ok(newStock, "Inventory successfully restocked.");
        }

        public async Task<ApiResponse<int>> ProcessSaleDeductionAsync(
            int variantId, int quantity, int? userId, string changeType, string orderNumber)
        {
            var result = await _inventoryRepository.DeductStockAtomicAsync(
                variantId, quantity, userId, changeType, orderNumber).ConfigureAwait(false);

            if (!result.Success)
            {
                return ApiResponse<int>.Fail(result.ErrorMessage, AppConstants.ErrorCodes.InsufficientStock);
            }

            await NotifyCommittedStockAsync(variantId, result.RemainingStock, changeType).ConfigureAwait(false);

            return ApiResponse<int>.Ok(result.RemainingStock, "Stock successfully deducted.");
        }

        private async Task NotifyCommittedStockAsync(int variantId, int newStock, string changeType)
        {
            try
            {
                var inv = await _inventoryRepository.GetInventoryByVariantIdAsync(variantId).ConfigureAwait(false);
                InventoryHub.BroadcastStockUpdate(variantId, inv?.SKU ?? "N/A", newStock,
                    inv?.IsLowStock ?? false, changeType);
                if (inv != null && inv.IsLowStock)
                    InventoryHub.BroadcastLowStockAlert(inv.InventoryId, inv.SKU, newStock,
                        newStock == 0 ? "CRITICAL_ZERO" : "LOW_STOCK");
            }
            catch (Exception ex) { System.Diagnostics.Trace.TraceWarning($"Committed stock notification failed: {ex}"); }
        }
    }
}
