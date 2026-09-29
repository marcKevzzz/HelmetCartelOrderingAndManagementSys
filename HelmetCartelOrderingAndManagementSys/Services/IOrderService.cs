using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public interface IOrderService
    {
        Task<ApiResponse<OrderSummaryDto>> CreateOnlineOrderAsync(CreateOrderRequestDto request, int? userId = null);
        Task<ApiResponse<OrderSummaryDto>> CreateInStorePosOrderAsync(CreateOrderRequestDto request, int staffUserId);
        Task<ApiResponse<bool>> UpdateOrderStatusAsync(int orderId, string newStatus, string notes = null);
        Task<OrderSummaryDto> GetOrderByIdAsync(int orderId);
        Task<List<OrderSummaryDto>> GetRecentOrdersAsync(int limit = 20, string status = null);
        Task<bool> ConfirmOnlinePaymentAsync(string orderNumber, string paymentGatewayRef);
    }
}
