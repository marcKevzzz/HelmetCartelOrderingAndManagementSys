using System;
using System.Linq;
using System.Data.SqlClient;
using System.Threading.Tasks;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using HelmetCartelOrderingAndManagementSys.Services;
using HelmetCartelOrderingAndManagementSys.Constants;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/returns")]
    public class ReturnsController : ApiController
    {
        private readonly IReturnRepository _returnRepository;
        private readonly IUserRepository _users = new UserRepository(new DbConnectionFactory());

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
        [CustomerAuthorize]
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
                request.UserId = (int)Request.Properties[StaffAuthorizeAttribute.UserIdKey];
                if (await _users.GetUserOrderDetailsAsync(request.UserId.Value, request.OrderId, null).ConfigureAwait(false) == null)
                    return NotFound();
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
        [CustomerAuthorize]
        public async Task<IHttpActionResult> GetByOrderId(int orderId)
        {
            if (orderId <= 0) return BadRequest("Invalid Order ID.");

            var userId = (int)Request.Properties[StaffAuthorizeAttribute.UserIdKey];
            if (await _users.GetUserOrderDetailsAsync(userId, orderId, null).ConfigureAwait(false) == null)
                return NotFound();

            var items = await _returnRepository.GetCustomerReturnRequestsAsync(orderId: orderId).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<ReturnRequestDto>>.Ok(items));
        }

        [HttpGet]
        [Route("user/{userId:int}")]
        [CustomerAuthorize]
        public async Task<IHttpActionResult> GetByUserId(int userId)
        {
            if (userId <= 0) return BadRequest("Invalid User ID.");
            if (userId != (int)Request.Properties[StaffAuthorizeAttribute.UserIdKey]) return NotFound();

            var items = await _returnRepository.GetCustomerReturnRequestsAsync(userId: userId).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<ReturnRequestDto>>.Ok(items));
        }

        [HttpGet]
        [Route("~/api/v1/admin/returns")]
        [StaffAuthorize]
        public async Task<IHttpActionResult> AdminGetReturns([FromUri] string status = "ALL", [FromUri] string search = null)
        {
            var items = await _returnRepository.AdminGetReturnRequestsAsync(status, search).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<AdminReturnRequestDto>>.Ok(items));
        }

        [HttpPost]
        [Route("~/api/v1/admin/returns/{id:int}/process")]
        [StaffAuthorize]
        public async Task<IHttpActionResult> AdminProcessReturn(int id, [FromBody] ProcessReturnRequestDto request)
        {
            if (id <= 0 || request == null || string.IsNullOrWhiteSpace(request.NewStatus))
            {
                return BadRequest("Valid RMA ID and NewStatus are required.");
            }

            int? processedBy = (int)Request.Properties[StaffAuthorizeAttribute.UserIdKey];

            try
            {
                var snapshot = (await _returnRepository.AdminGetReturnRequestsAsync().ConfigureAwait(false)).FirstOrDefault(x => x.Id == id);
                var result = await _returnRepository.AdminProcessReturnRequestAsync(id, request, processedBy).ConfigureAwait(false);

                if (!result.Success)
                {
                    return Ok(new
                    {
                        success = false,
                        message = result.ErrorMessage ?? "Failed to update return request."
                    });
                }

                if (snapshot != null)
                {
                    var order = await new OrderRepository(new DbConnectionFactory()).GetOrderByIdAsync(snapshot.OrderId).ConfigureAwait(false);
                    var replacement = request.ExchangeVariantId ?? snapshot.ExchangeVariantId;
                    if (replacement.HasValue && order != null && !order.Items.Any(x => x.VariantId == replacement.Value))
                        order.Items.Add(new OrderItemSummaryDto { VariantId = replacement.Value });
                    await OrderNotifications.PublishAsync(order, AppConstants.StockAuditChangeType.Return).ConfigureAwait(false);
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

        [HttpGet]
        [Route("~/api/v1/admin/returns/{id:int}/replacements")]
        [StaffAuthorize]
        public async Task<IHttpActionResult> GetReplacements(int id)
        {
            var rows = await new AdminDataRepository(new DbConnectionFactory()).QueryAsync(
                "dbo.sp_AdminReturnReplacements", new SqlParameter("@RmaId", id)).ConfigureAwait(false);
            return Ok(ApiResponse<object>.Ok(rows));
        }
    }
}
