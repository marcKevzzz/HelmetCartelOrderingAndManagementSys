using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public interface IReturnRepository
    {
        Task<ReturnOperationResultDto> CreateReturnRequestAsync(CreateReturnRequestDto dto);
        Task<List<ReturnRequestDto>> GetCustomerReturnRequestsAsync(int? orderId = null, int? userId = null);
        Task<List<AdminReturnRequestDto>> AdminGetReturnRequestsAsync(string status = "ALL", string search = null);
        Task<ReturnOperationResultDto> AdminProcessReturnRequestAsync(int rmaId, ProcessReturnRequestDto dto, int? processedBy = null);
    }
}
