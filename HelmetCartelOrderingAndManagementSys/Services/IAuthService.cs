using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public interface IAuthService
    {
        Task<AuthResponseDto> AuthenticateAsync(LoginRequestDto request);
        Task<AuthResponseDto> RegisterCustomerAsync(RegisterRequestDto request);
        Task<UserProfileDto> GetProfileAsync(int userId);
        Task<List<UserOrderSummaryDto>> GetUserOrdersAsync(int userId);
    }
}
