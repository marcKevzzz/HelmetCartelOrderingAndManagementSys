using System;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http;
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
            var reviews = await _reviewRepository.GetProductReviewsAsync(productId).ConfigureAwait(false);
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
            int? userId = null; // Can be extracted from User.Identity if authenticated

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
        public async Task<IHttpActionResult> AddReview([FromBody] AddReviewRequestDto request)
        {
            if (request == null || request.ProductId <= 0 || string.IsNullOrWhiteSpace(request.ReviewerName) || string.IsNullOrWhiteSpace(request.Comment))
            {
                return BadRequest("Product ID, Reviewer Name, and Review Comment are required.");
            }

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
    }
}
