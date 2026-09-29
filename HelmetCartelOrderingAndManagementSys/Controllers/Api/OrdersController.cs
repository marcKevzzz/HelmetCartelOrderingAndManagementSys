using System.Threading.Tasks;
using System.Web.Http;
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

        public OrdersController()
        {
            var dbFactory = new DbConnectionFactory();
            var orderRepo = new OrderRepository(dbFactory);
            var invRepo = new InventoryRepository(dbFactory);
            var invService = new InventoryService(invRepo);
            var sigValidator = new HitPaySignatureValidator();
            var hitPayService = new HitPayService(sigValidator);

            _orderService = new OrderService(orderRepo, invService, hitPayService);
        }

        public OrdersController(IOrderService orderService)
        {
            _orderService = orderService;
        }

        [HttpPost]
        [Route("")]
        public async Task<IHttpActionResult> CreateOnlineOrder([FromBody] CreateOrderRequestDto request)
        {
            if (request == null || request.Items == null || request.Items.Count == 0)
            {
                return BadRequest("Invalid order payload.");
            }

            var result = await _orderService.CreateOnlineOrderAsync(request).ConfigureAwait(false);
            if (!result.Success)
            {
                return Content(System.Net.HttpStatusCode.Conflict, result);
            }

            return Ok(result);
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
    }
}
