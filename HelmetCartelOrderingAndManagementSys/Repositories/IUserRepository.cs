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
    }
}
