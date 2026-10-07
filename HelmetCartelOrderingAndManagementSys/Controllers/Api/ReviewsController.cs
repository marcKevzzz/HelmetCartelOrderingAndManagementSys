using System;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/reviews")]
    public class ReviewsController : ApiController
    {
        private readonly IReviewRepository _reviewRepository;

        public ReviewsController()
        {
            _reviewRepository = new ReviewRepository(new DbConnectionFactory());
        }

        public ReviewsController(IReviewRepository reviewRepository)
        {
            _reviewRepository = reviewRepository;
        }

        [HttpGet]
        [Route("product/{productId:int}")]
        public async Task<IHttpActionResult> GetProductReviews(int productId)
        {
            int? currentUserId = GetAuthenticatedUserId();
            var reviews = await _reviewRepository.GetProductReviewsAsync(productId, includeHidden: false, currentUserId: currentUserId).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<ProductReviewDto>>.Ok(reviews));
        }

        [HttpPost]
        [Route("report")]
        public async Task<IHttpActionResult> ReportReview([FromBody] ReportReviewRequestDto request)
        {
            if (request == null || request.ReviewId <= 0)
            {
                return BadRequest("Invalid report request.");
            }

            string clientIp = GetClientIpAddress();
            int? userId = GetAuthenticatedUserId();

            var result = await _reviewRepository.ReportReviewAsync(
                reviewId: request.ReviewId,
                userId: userId,
                ipAddress: clientIp,
                reason: string.IsNullOrWhiteSpace(request.Reason) ? "SPAM" : request.Reason.ToUpperInvariant(),
                notes: request.Notes
            ).ConfigureAwait(false);

            if (!result.Success)
            {
                return Ok(new
                {
                    success = false,
                    message = result.ErrorMessage ?? "Failed to report review."
                });
            }

            return Ok(new
            {
                success = true,
                message = "Thank you. Your report has been submitted for moderation."
            });
        }

        [HttpPost]
        [Route("")]
        [CustomerAuthorize]
        public async Task<IHttpActionResult> AddReview([FromBody] AddReviewRequestDto request)
        {
            if (request == null || request.ProductId <= 0 || string.IsNullOrWhiteSpace(request.ReviewerName) || string.IsNullOrWhiteSpace(request.Comment))
            {
                return BadRequest("Product ID, Reviewer Name, and Review Comment are required.");
            }

            request.UserId = (int)Request.Properties[StaffAuthorizeAttribute.UserIdKey];

            if (request.Rating < 1 || request.Rating > 5)
            {
                return BadRequest("Rating must be between 1 and 5 stars.");
            }

            try
            {
                int newId = await _reviewRepository.AddReviewAsync(request).ConfigureAwait(false);
                return Ok(new
                {
                    success = true,
                    reviewId = newId,
                    message = "Review submitted successfully."
                });
            }
            catch (Exception ex)
            {
                return InternalServerError(ex);
            }
        }

        [HttpGet]
        [Route("admin")]
        [StaffAuthorize]
        public async Task<IHttpActionResult> AdminGetReviews([FromUri] string filter = "ALL", [FromUri] string search = null)
        {
            var reviews = await _reviewRepository.AdminGetReviewsAsync(filter, search).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<AdminReviewDto>>.Ok(reviews));
        }

        [HttpPost]
        [Route("admin/{id:int}/toggle-visibility")]
        [StaffAuthorize]
        public async Task<IHttpActionResult> ToggleReviewVisibility(int id)
        {
            if (id <= 0) return BadRequest("Invalid review ID.");

            try
            {
                bool isHidden = await _reviewRepository.ToggleReviewVisibilityAsync(id).ConfigureAwait(false);
                return Ok(new
                {
                    success = true,
                    reviewId = id,
                    isHidden = isHidden,
                    message = isHidden ? "Review has been hidden from storefront." : "Review is now visible on storefront."
                });
            }
            catch (Exception ex)
            {
                return Ok(new { success = false, message = ex.Message });
            }
        }

        [HttpDelete]
        [Route("admin/{id:int}")]
        [StaffAuthorize(adminOnly: true)]
        public async Task<IHttpActionResult> AdminDeleteReview(int id)
        {
            if (id <= 0) return BadRequest("Invalid review ID.");

            try
            {
                bool success = await _reviewRepository.DeleteReviewAsync(id).ConfigureAwait(false);
                return Ok(new
                {
                    success = true,
                    reviewId = id,
                    message = "Customer review has been permanently deleted."
                });
            }
            catch (Exception ex)
            {
                return Ok(new { success = false, message = ex.Message });
            }
        }

        private string GetClientIpAddress()
        {
            try
            {
                if (HttpContext.Current != null && HttpContext.Current.Request != null)
                {
                    string forwarded = HttpContext.Current.Request.ServerVariables["HTTP_X_FORWARDED_FOR"];
                    if (!string.IsNullOrEmpty(forwarded))
                    {
                        string[] addresses = forwarded.Split(',');
                        if (addresses.Length > 0)
                        {
                            return addresses[0].Trim();
                        }
                    }
                    return HttpContext.Current.Request.UserHostAddress;
                }
            }
            catch
            {
                // Fallback
            }
            return "127.0.0.1";
        }

        private int? GetAuthenticatedUserId()
        {
            var authHeader = Request?.Headers?.Authorization;
            if (authHeader != null && string.Equals(authHeader.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase))
            {
                var token = authHeader.Parameter;
                var user = new JwtTokenProvider().ValidateToken(token);
                if (user != null) return user.Id;
            }

            var cookieToken = HttpContext.Current?.Request?.Cookies?[AppConstants.JwtConfiguration.AuthCookieName]?.Value;
            if (!string.IsNullOrEmpty(cookieToken))
            {
                var user = new JwtTokenProvider().ValidateToken(cookieToken);
                if (user != null) return user.Id;
            }

            return null;
        }
    }
}
