using System;
using System.Threading.Tasks;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using HelmetCartelOrderingAndManagementSys.Services;
using HelmetCartelOrderingAndManagementSys.Hubs;
using System.Data.SqlClient;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/orders")]
    public class OrdersController : ApiController
    {
        private readonly IOrderService _orderService;
        private readonly IOrderRepository _orderRepository;
        private readonly IUserRepository _userRepository;

        public OrdersController()
        {
            var dbFactory = new DbConnectionFactory();
            _orderRepository = new OrderRepository(dbFactory);
            _userRepository = new UserRepository(dbFactory);
            var invRepo = new InventoryRepository(dbFactory);
            var invService = new InventoryService(invRepo);
            var sigValidator = new HitPaySignatureValidator();
            var hitPayService = new HitPayService(sigValidator);

            _orderService = new OrderService(_orderRepository, invService, hitPayService);
        }

        public OrdersController(IOrderService orderService, IOrderRepository orderRepository = null, IUserRepository userRepository = null)
        {
            _orderService = orderService;
            _orderRepository = orderRepository ?? new OrderRepository(new DbConnectionFactory());
            _userRepository = userRepository ?? new UserRepository(new DbConnectionFactory());
        }

        [HttpPost]
        [Route("")]
        public async Task<IHttpActionResult> CreateOnlineOrder([FromBody] CreateOrderRequestDto request)
        {
            if (request == null || request.Items == null || request.Items.Count == 0)
            {
                return BadRequest("Invalid order payload.");
            }

            try
            {
                int? userId = GetAuthenticatedUserId();
                var result = await _orderService.CreateOnlineOrderAsync(request, userId).ConfigureAwait(false);
                if (!result.Success)
                {
                    return Content(System.Net.HttpStatusCode.Conflict, result);
                }

                return Ok(result);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError($"[CreateOnlineOrder] Exception: {ex}");
                return Content(System.Net.HttpStatusCode.InternalServerError,
                    ApiResponse<OrderSummaryDto>.Fail(ex.Message, AppConstants.ErrorCodes.DatabaseError));
            }
        }

        [HttpGet]
        [Route("track/{orderNumber}")]
        public async Task<IHttpActionResult> TrackOrder(string orderNumber)
        {
            if (string.IsNullOrWhiteSpace(orderNumber))
            {
                return BadRequest("Order number is required.");
            }

            var order = await _orderService.GetOrderByOrderNumberAsync(orderNumber.Trim()).ConfigureAwait(false);
            if (order == null)
            {
                return NotFound();
            }

            return Ok(ApiResponse<OrderSummaryDto>.Ok(order));
        }

        [HttpPost]
        [Route("in-store")]
        [StaffAuthorize]
        public async Task<IHttpActionResult> CreateInStorePosOrder([FromBody] CreateOrderRequestDto request)
        {
            if (request == null || request.Items == null || request.Items.Count == 0)
            {
                return BadRequest("Invalid POS order payload.");
            }

            int staffUserId = (int)Request.Properties[StaffAuthorizeAttribute.UserIdKey];

            var result = await _orderService.CreateInStorePosOrderAsync(request, staffUserId).ConfigureAwait(false);
            if (!result.Success)
            {
                return Content(System.Net.HttpStatusCode.Conflict, result);
            }

            return Ok(result);
        }

        [HttpGet]
        [Route("")]
        [StaffAuthorize]
        public async Task<IHttpActionResult> GetRecentOrders([FromUri] int limit = 20, [FromUri] string status = null)
        {
            var list = await _orderService.GetRecentOrdersAsync(limit, status).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<OrderSummaryDto>>.Ok(list));
        }

        [HttpGet]
        [Route("{id:int}")]
        [StaffAuthorize]
        public async Task<IHttpActionResult> GetOrderById(int id)
        {
            var order = await _orderService.GetOrderByIdAsync(id).ConfigureAwait(false);
            if (order == null)
            {
                return NotFound();
            }
            return Ok(ApiResponse<OrderSummaryDto>.Ok(order));
        }

        [HttpPut]
        [Route("{id:int}/status")]
        [StaffAuthorize]
        public async Task<IHttpActionResult> UpdateStatus(int id, [FromBody] UpdateOrderStatusDto dto)
        {
            if (dto == null || string.IsNullOrEmpty(dto.Status))
            {
                return BadRequest("Status is required.");
            }

            try
            {
                var rows = await new AdminDataRepository(new DbConnectionFactory()).QueryAsync("dbo.sp_AdminUpdateOrderStatus",
                    new SqlParameter("@OrderId", id), new SqlParameter("@NewStatus", dto.Status),
                    new SqlParameter("@Notes", (object)dto.Notes ?? System.DBNull.Value)).ConfigureAwait(false);
                var order = await _orderService.GetOrderByIdAsync(id).ConfigureAwait(false);
                if (order != null) OrderHub.NotifyOrderStatusChanged(id, order.OrderNumber, dto.Status);
                return Ok(ApiResponse<object>.Ok(rows));
            }
            catch (SqlException e) { return BadRequest(e.Message); }
        }

        [HttpPost]
        [Route("{id:int}/cancel")]
        public async Task<IHttpActionResult> CancelOrder(int id, [FromBody] CancelOrderRequestDto dto)
        {
            int? userId = GetAuthenticatedUserId();
            string userEmail = null;
            if (userId.HasValue)
            {
                var profile = await _userRepository.GetUserProfileAsync(userId.Value).ConfigureAwait(false);
                userEmail = profile?.Email;
            }

            var result = await _orderRepository.CancelOrderAsync(id, userId, userEmail, dto?.Reason).ConfigureAwait(false);
            if (!result.Success)
            {
                return BadRequest(result.Message ?? "Unable to cancel order.");
            }

            var order = await _orderRepository.GetOrderByIdAsync(id).ConfigureAwait(false);
            if (order != null)
            {
                OrderHub.NotifyOrderStatusChanged(id, order.OrderNumber, AppConstants.OrderStatus.Cancelled);
            }

            return Ok(new { success = true, message = "Order cancelled successfully and reserved stock released." });
        }

        private int? GetAuthenticatedUserId()
        {
            var authHeader = Request.Headers.Authorization;
            if (authHeader != null && string.Equals(authHeader.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase))
            {
                var token = authHeader.Parameter;
                var user = new JwtTokenProvider().ValidateToken(token);
                if (user != null) return user.Id;
            }

            var cookieToken = System.Web.HttpContext.Current?.Request?.Cookies?[AppConstants.JwtConfiguration.AuthCookieName]?.Value;
            if (!string.IsNullOrEmpty(cookieToken))
            {
                var user = new JwtTokenProvider().ValidateToken(cookieToken);
                if (user != null) return user.Id;
            }

            return null;
        }
    }
}
