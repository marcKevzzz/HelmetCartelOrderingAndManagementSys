using System;
using System.Security.Claims;
using System.Threading.Tasks;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/returns")]
    public class ReturnsController : ApiController
    {
        private readonly IReturnRepository _returnRepository;

        public ReturnsController()
        {
            _returnRepository = new ReturnRepository(new DbConnectionFactory());
        }

        public ReturnsController(IReturnRepository returnRepository)
        {
            _returnRepository = returnRepository;
        }

        [HttpPost]
        [Route("")]
        public async Task<IHttpActionResult> CreateReturn([FromBody] CreateReturnRequestDto request)
        {
            if (request == null || request.OrderId <= 0 || request.OrderItemId <= 0)
            {
                return BadRequest("OrderId and OrderItemId are required.");
            }

            if (string.IsNullOrWhiteSpace(request.RequestType) || (request.RequestType != "RETURN" && request.RequestType != "EXCHANGE"))
            {
                return BadRequest("RequestType must be RETURN or EXCHANGE.");
            }

            if (string.IsNullOrWhiteSpace(request.Reason))
            {
                return BadRequest("Reason is required.");
            }

            try
            {
                var result = await _returnRepository.CreateReturnRequestAsync(request).ConfigureAwait(false);

                if (!result.Success)
                {
                    return Ok(new
                    {
                        success = false,
                        message = result.ErrorMessage ?? "Could not submit return/exchange request."
                    });
                }

                return Ok(new
                {
                    success = true,
                    rmaId = result.RmaId,
                    rmaNumber = result.RmaNumber,
                    message = $"RMA Request {result.RmaNumber} submitted successfully. Our support team will review it shortly."
                });
            }
            catch (Exception ex)
            {
                return InternalServerError(ex);
            }
        }

        [HttpGet]
        [Route("order/{orderId:int}")]
        public async Task<IHttpActionResult> GetByOrderId(int orderId)
        {
            if (orderId <= 0) return BadRequest("Invalid Order ID.");

            var items = await _returnRepository.GetCustomerReturnRequestsAsync(orderId: orderId).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<ReturnRequestDto>>.Ok(items));
        }

        [HttpGet]
        [Route("user/{userId:int}")]
        public async Task<IHttpActionResult> GetByUserId(int userId)
        {
            if (userId <= 0) return BadRequest("Invalid User ID.");

            var items = await _returnRepository.GetCustomerReturnRequestsAsync(userId: userId).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<ReturnRequestDto>>.Ok(items));
        }

        [HttpGet]
        [Route("~/api/v1/admin/returns")]
        public async Task<IHttpActionResult> AdminGetReturns([FromUri] string status = "ALL", [FromUri] string search = null)
        {
            var items = await _returnRepository.AdminGetReturnRequestsAsync(status, search).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<AdminReturnRequestDto>>.Ok(items));
        }

        [HttpPost]
        [Route("~/api/v1/admin/returns/{id:int}/process")]
        public async Task<IHttpActionResult> AdminProcessReturn(int id, [FromBody] ProcessReturnRequestDto request)
        {
            if (id <= 0 || request == null || string.IsNullOrWhiteSpace(request.NewStatus))
            {
                return BadRequest("Valid RMA ID and NewStatus are required.");
            }

            int? processedBy = null;
            if (User?.Identity is ClaimsIdentity claimsIdentity)
            {
                var idClaim = claimsIdentity.FindFirst(ClaimTypes.NameIdentifier);
                if (idClaim != null && int.TryParse(idClaim.Value, out int uid))
                {
                    processedBy = uid;
                }
            }

            try
            {
                var result = await _returnRepository.AdminProcessReturnRequestAsync(id, request, processedBy).ConfigureAwait(false);

                if (!result.Success)
                {
                    return Ok(new
                    {
                        success = false,
                        message = result.ErrorMessage ?? "Failed to update return request."
                    });
                }

                return Ok(new
                {
                    success = true,
                    message = $"RMA #{id} updated to status '{request.NewStatus}' successfully."
                });
            }
            catch (Exception ex)
            {
                return InternalServerError(ex);
            }
        }
    }
}
