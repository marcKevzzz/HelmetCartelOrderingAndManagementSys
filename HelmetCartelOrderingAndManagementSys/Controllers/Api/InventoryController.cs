using System.Threading.Tasks;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using HelmetCartelOrderingAndManagementSys.Services;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/inventory")]
    [StaffAuthorize]
    public class InventoryController : ApiController
    {
        private readonly IInventoryService _inventoryService;

        public InventoryController()
        {
            var dbFactory = new DbConnectionFactory();
            var repo = new InventoryRepository(dbFactory);
            _inventoryService = new InventoryService(repo);
        }

        public InventoryController(IInventoryService inventoryService)
        {
            _inventoryService = inventoryService;
        }

        [HttpGet]
        [Route("")]
        public async Task<IHttpActionResult> GetInventory([FromUri] bool lowStockOnly = false, [FromUri] string search = null)
        {
            var list = await _inventoryService.GetCurrentStockLevelsAsync(lowStockOnly, search).ConfigureAwait(false);
            return Ok(ApiResponse<System.Collections.Generic.List<InventoryStatusDto>>.Ok(list));
        }

        [HttpGet]
        [Route("variant/{variantId:int}")]
        public async Task<IHttpActionResult> GetStockByVariant(int variantId)
        {
            var status = await _inventoryService.GetStockByVariantAsync(variantId).ConfigureAwait(false);
            if (status == null)
            {
                return NotFound();
            }
            return Ok(ApiResponse<InventoryStatusDto>.Ok(status));
        }

        [HttpPost]
        [Route("restock")]
        public async Task<IHttpActionResult> Restock([FromBody] RestockRequestDto request)
        {
            if (request == null)
            {
                return BadRequest("Invalid restock payload.");
            }

            int staffUserId = (int)Request.Properties[StaffAuthorizeAttribute.UserIdKey];

            var response = await _inventoryService.RestockInventoryAsync(request, staffUserId).ConfigureAwait(false);
            if (!response.Success)
            {
                return BadRequest(response.Message);
            }

            return Ok(response);
        }
    }
}
