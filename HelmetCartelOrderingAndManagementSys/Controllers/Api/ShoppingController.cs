using System;
using System.Net;
using System.Data.SqlClient;
using System.Threading.Tasks;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/shopping")]
    public sealed class ShoppingController : ApiController
    {
        private readonly ShoppingRepository _shopping = new ShoppingRepository(new DbConnectionFactory());

        // Require explicit bearer credentials: cookie-only mutations would allow CSRF.
        private async Task<int?> UserIdAsync()
        {
            var header = Request.Headers.Authorization;
            if (header == null || !string.Equals(header.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase)) return null;
            var tokenUser = new JwtTokenProvider().ValidateToken(header.Parameter);
            if (tokenUser == null || tokenUser.Id <= 0) return null;
            var user = await new UserRepository(new DbConnectionFactory()).GetUserByEmailAsync(tokenUser.Email).ConfigureAwait(false);
            return user != null && user.IsActive && user.Id == tokenUser.Id ? (int?)user.Id : null;
        }

        [HttpGet, Route("")]
        public async Task<IHttpActionResult> Get()
        {
            var userId = await UserIdAsync().ConfigureAwait(false);
            if (!userId.HasValue) return Unauthorized();
            return Ok(ApiResponse<ShoppingStateDto>.Ok(await _shopping.GetAsync(userId.Value).ConfigureAwait(false)));
        }

        [HttpPost, Route("cart")]
        public Task<IHttpActionResult> Add(CartChangeDto request)
        {
            if (request == null || !request.Quantity.HasValue || request.Quantity <= 0 || !ModelState.IsValid)
                return Task.FromResult<IHttpActionResult>(BadRequest("Valid variant and quantity are required."));
            return Change(AppConstants.Shopping.AddCart, request.VariantId, request.Quantity, true);
        }

        [HttpPost, Route("import")]
        public async Task<IHttpActionResult> Import(ShoppingImportDto request)
        {
            if (request == null || request.Cart == null || request.Favorites == null ||
                request.Cart.Count > 500 || request.Favorites.Count > 500 || !ModelState.IsValid)
                return BadRequest("Invalid saved shopping items.");
            var userId = await UserIdAsync().ConfigureAwait(false);
            if (!userId.HasValue) return Unauthorized();
            return Ok(ApiResponse<ShoppingStateDto>.Ok(await _shopping.ImportAsync(userId.Value, request).ConfigureAwait(false)));
        }

        [HttpPut, Route("cart")]
        public Task<IHttpActionResult> Set(CartChangeDto request)
        {
            if (request == null || !ModelState.IsValid || (!request.Quantity.HasValue && !request.IsSelected.HasValue))
                return Task.FromResult<IHttpActionResult>(BadRequest("Valid cart change is required."));
            return Change(AppConstants.Shopping.SetCart, request.VariantId, request.Quantity, request.IsSelected);
        }

        [HttpDelete, Route("cart/{id:int}")]
        public Task<IHttpActionResult> Remove(int id) { return Change(AppConstants.Shopping.RemoveCart, id); }
        [HttpDelete, Route("cart")]
        public Task<IHttpActionResult> ClearCart() { return Change(AppConstants.Shopping.ClearCart); }
        [HttpPut, Route("cart/selection/{selected:bool}")]
        public Task<IHttpActionResult> SelectAll(bool selected) { return Change(AppConstants.Shopping.SelectCart, selected: selected); }
        [HttpPut, Route("favorites/{id:int}")]
        public Task<IHttpActionResult> SaveFavorite(int id) { return Change(AppConstants.Shopping.SaveFavorite, id); }
        [HttpDelete, Route("favorites/{id:int}")]
        public Task<IHttpActionResult> RemoveFavorite(int id) { return Change(AppConstants.Shopping.RemoveFavorite, id); }
        [HttpDelete, Route("favorites")]
        public Task<IHttpActionResult> ClearFavorites() { return Change(AppConstants.Shopping.ClearFavorites); }

        private async Task<IHttpActionResult> Change(string operation, int? id = null, int? quantity = null, bool? selected = null)
        {
            if (id.HasValue && id <= 0) return BadRequest("Invalid item identifier.");
            var userId = await UserIdAsync().ConfigureAwait(false);
            if (!userId.HasValue) return Unauthorized();
            try
            {
                var state = await _shopping.ChangeAsync(userId.Value, operation, id, quantity, selected).ConfigureAwait(false);
                return Ok(ApiResponse<ShoppingStateDto>.Ok(state));
            }
            catch (SqlException ex) when (ex.Number == 53048)
            {
                return Content(HttpStatusCode.Conflict, ApiResponse<ShoppingStateDto>.Fail(ex.Message, AppConstants.ErrorCodes.InsufficientStock));
            }
        }
    }
}
