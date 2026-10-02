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
        Task<UserProfileDto> UpdateProfileAsync(int userId, UpdateProfileRequestDto request);
        Task<bool> ChangePasswordAsync(int userId, ChangePasswordRequestDto request);
        Task<List<UserPaymentHistoryDto>> GetUserPaymentsAsync(int userId);
        Task<OrderSummaryDto> GetUserOrderDetailsAsync(int userId, int? orderId, string orderNumber);
        Task<List<UserAddressDto>> GetUserAddressesAsync(int userId);
        Task<UserAddressDto> SaveUserAddressAsync(int userId, SaveUserAddressRequestDto request);
        Task<bool> DeleteUserAddressAsync(int userId, int addressId);
    }
}
