using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public interface IOrderRepository
    {
        Task<OrderSummaryDto> CreateOrderAsync(CreateOrderRequestDto request, string orderNumber, string orderSource, int? userId = null);
        Task<OrderSummaryDto> CreatePhysicalSaleAsync(CreateOrderRequestDto request, string orderNumber, string source, string status, string paymentStatus, int? actorUserId);
        Task<bool> ConfirmHitPayOrderAsync(string orderNumber, string gatewayReference);
        Task<OrderSummaryDto> GetOrderByOrderNumberAsync(string orderNumber);
        Task<OrderSummaryDto> GetOrderByIdAsync(int orderId);
        Task<List<OrderSummaryDto>> GetRecentOrdersAsync(int limit = 20, string status = null);
        Task<bool> UpdateOrderStatusAsync(int orderId, string newStatus, string notes = null);
    }
}
