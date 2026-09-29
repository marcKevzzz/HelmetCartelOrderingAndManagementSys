using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public interface IInventoryService
    {
        Task<List<InventoryStatusDto>> GetCurrentStockLevelsAsync(bool lowStockOnly = false, string search = null);
        Task<InventoryStatusDto> GetStockByVariantAsync(int variantId);
        Task<ApiResponse<int>> RestockInventoryAsync(RestockRequestDto request, int userId);
        Task<ApiResponse<int>> ProcessSaleDeductionAsync(int variantId, int quantity, int? userId, string changeType, string orderNumber);
    }
}
