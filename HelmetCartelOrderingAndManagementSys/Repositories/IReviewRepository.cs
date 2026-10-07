using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public interface IReviewRepository
    {
        Task<List<ProductReviewDto>> GetProductReviewsAsync(int productId, bool includeHidden = false, int? currentUserId = null);
        Task<ReportReviewResultDto> ReportReviewAsync(int reviewId, int? userId, string ipAddress, string reason, string notes);
        Task<int> AddReviewAsync(AddReviewRequestDto request);
        Task<List<AdminReviewDto>> AdminGetReviewsAsync(string filter = "ALL", string search = null);
        Task<bool> ToggleReviewVisibilityAsync(int reviewId);
        Task<bool> DeleteReviewAsync(int reviewId);
        Task<List<ProductReviewDto>> GetTopCustomerReviewsAsync(int limit = 6);
    }
}
