using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public interface IUserRepository
    {
        Task<UserRecordDto> GetUserByEmailAsync(string email);
        Task<UserProfileDto> GetUserProfileAsync(int userId);
        Task<(bool Success, int UserId, string ErrorMessage)> RegisterUserAsync(string firstName, string lastName, string email, string passwordHash, string salt, string phoneNumber, string roleName);
        Task<List<UserOrderSummaryDto>> GetUserOrdersAsync(int userId);
        Task<UserProfileDto> UpdateProfileAsync(int userId, string firstName, string lastName, string phoneNumber);
        Task<bool> ChangePasswordAsync(int userId, string newPasswordHash, string newSalt);
        Task<List<UserPaymentHistoryDto>> GetUserPaymentsAsync(int userId);
        Task<OrderSummaryDto> GetUserOrderDetailsAsync(int userId, int? orderId, string orderNumber);
        Task<List<UserAddressDto>> GetUserAddressesAsync(int userId);
        Task<UserAddressDto> SaveUserAddressAsync(int userId, SaveUserAddressRequestDto dto);
        Task<bool> DeleteUserAddressAsync(int userId, int addressId);
    }
}
