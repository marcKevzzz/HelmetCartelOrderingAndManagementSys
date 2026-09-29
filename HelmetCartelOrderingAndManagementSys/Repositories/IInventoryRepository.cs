using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public interface IInventoryRepository
    {
        Task<List<InventoryStatusDto>> GetInventoryListAsync(bool lowStockOnly = false, string search = null);
        Task<InventoryStatusDto> GetInventoryByVariantIdAsync(int variantId);
        Task<(bool Success, int RemainingStock, string ErrorMessage)> DeductStockAtomicAsync(
            int variantId, int quantity, int? userId, string changeType, string orderNumber);
        Task<int> RestockVariantAsync(
            int variantId, int quantity, int userId, string supplierInvoice, string notes);
    }
}
