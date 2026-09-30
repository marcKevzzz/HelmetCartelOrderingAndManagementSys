using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using System.IO;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Hubs;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using HelmetCartelOrderingAndManagementSys.Services;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/admin")]
    [StaffAuthorize]
    public class AdminController : ApiController
    {
        private readonly AdminDataRepository _data;
        private readonly InventoryService _inventory;
        private readonly AuthService _auth;
        private readonly OrderRepository _orders;

        public AdminController()
        {
            var factory = new DbConnectionFactory();
            _data = new AdminDataRepository(factory);
            _inventory = new InventoryService(new InventoryRepository(factory));
            _auth = new AuthService(new UserRepository(factory), new JwtTokenProvider());
            _orders = new OrderRepository(factory);
        }

        private Task<IHttpActionResult> Rows(string procedure, params SqlParameter[] args)
        {
            return Run(procedure, args);
        }

        private async Task<IHttpActionResult> Run(string procedure, SqlParameter[] args)
        {
            try { return Ok(ApiResponse<object>.Ok(await _data.QueryAsync(procedure, args).ConfigureAwait(false))); }
            catch (SqlException e) { return BadRequest(e.Message); }
        }

        private static SqlParameter P(string name, object value) => AdminDataRepository.Param(name, value);
        private int ActorId => (int)Request.Properties[StaffAuthorizeAttribute.UserIdKey];

        [HttpGet, Route("dashboard")]
        public Task<IHttpActionResult> Dashboard() => Rows("dbo.sp_AdminDashboard",
            P("@IncludeRevenue", string.Equals((string)Request.Properties[StaffAuthorizeAttribute.RoleKey],
                AppConstants.Roles.Admin, StringComparison.Ordinal)));

        [HttpGet, Route("dashboard/activity")]
        public Task<IHttpActionResult> RecentActivity() =>
            Rows("dbo.sp_AdminRecentActivity", P("@Limit", 8));

        [HttpGet, Route("global-search"), AllowAnonymous]
        public async Task<IHttpActionResult> GlobalSearch(string q = null)
        {
            if (string.IsNullOrWhiteSpace(q)) return Ok(ApiResponse<object>.Ok(new List<AdminGlobalSearchResultDto>()));
            var results = await _data.GlobalSearchAsync(q, 8).ConfigureAwait(false);
            return Ok(ApiResponse<object>.Ok(results));
        }

        [HttpGet, Route("sellable-variants")]
        public Task<IHttpActionResult> SellableVariants(string search = null, string brand = null, string category = null) =>
            Rows("dbo.sp_AdminSellableVariants", P("@Search", search), P("@Brand", brand), P("@Category", category));

        [HttpGet, Route("orders")]
        public Task<IHttpActionResult> Orders(string search = null, string status = null, string source = null) =>
            Rows("dbo.sp_AdminOrders", P("@Search", search), P("@Status", status), P("@Source", source), P("@Limit", 100));

        [HttpPut, Route("orders/{id:int}/status")]
        public async Task<IHttpActionResult> SetOrderStatus(int id, UpdateOrderStatusDto request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Status)) return BadRequest("Status is required.");
            var result = await Run("dbo.sp_AdminUpdateOrderStatus", new[] {
                P("@OrderId", id),
                P("@NewStatus", request.Status),
                P("@Notes", request.Notes),
                P("@Courier", request.Courier),
                P("@TrackingNumber", request.TrackingNumber)
            }).ConfigureAwait(false);
            if (result is System.Web.Http.Results.OkNegotiatedContentResult<ApiResponse<object>>)
            {
                try
                {
                    var order = await _orders.GetOrderByIdAsync(id).ConfigureAwait(false);
                    if (order != null) OrderHub.NotifyOrderStatusChanged(id, order.OrderNumber, request.Status);
                }
                catch (Exception ex) { System.Diagnostics.Trace.TraceWarning($"Committed order notification failed: {ex}"); }
            }
            return result;
        }

        [HttpPost, Route("orders/{id:int}/dispatch")]
        public async Task<IHttpActionResult> DispatchOrder(int id, DispatchOrderRequestDto request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Courier) || string.IsNullOrWhiteSpace(request.TrackingNumber))
                return BadRequest("Courier and Tracking Number are required for dispatch.");

            var result = await Run("dbo.sp_AdminUpdateOrderStatus", new[] {
                P("@OrderId", id),
                P("@NewStatus", AppConstants.OrderStatus.Shipped),
                P("@Notes", request.Notes),
                P("@Courier", request.Courier),
                P("@TrackingNumber", request.TrackingNumber)
            }).ConfigureAwait(false);

            if (result is System.Web.Http.Results.OkNegotiatedContentResult<ApiResponse<object>>)
            {
                try
                {
                    var order = await _orders.GetOrderByIdAsync(id).ConfigureAwait(false);
                    if (order != null) OrderHub.NotifyOrderStatusChanged(id, order.OrderNumber, AppConstants.OrderStatus.Shipped);
                }
                catch (Exception ex) { System.Diagnostics.Trace.TraceWarning($"Committed order notification failed: {ex}"); }
            }
            return result;
        }

        [HttpGet, Route("inventory/{variantId:int}/history")]
        public Task<IHttpActionResult> StockHistory(int variantId) =>
            Rows("dbo.sp_AdminStockHistory", P("@VariantId", variantId), P("@Limit", 50));

        [HttpPost, Route("inventory/adjust")]
        public async Task<IHttpActionResult> AdjustStock(AdminStockAdjustmentDto request)
        {
            if (request == null || request.VariantId <= 0 || request.QuantityChanged == 0 || string.IsNullOrWhiteSpace(request.Notes))
                return BadRequest("Variant, nonzero change, and reason are required.");
            try
            {
                var stock = await _data.AdjustStockAsync(request.VariantId, request.QuantityChanged, ActorId,
                    request.ReferenceNumber, request.Notes).ConfigureAwait(false);
                try
                {
                    var item = await _inventory.GetStockByVariantAsync(request.VariantId).ConfigureAwait(false);
                    InventoryHub.BroadcastStockUpdate(request.VariantId, item?.SKU ?? string.Empty, stock,
                        item?.IsLowStock ?? false, AppConstants.StockAuditChangeType.Adjustment);
                    if (item?.IsLowStock == true)
                        InventoryHub.BroadcastLowStockAlert(item.InventoryId, item.SKU, stock,
                            stock == 0 ? "CRITICAL_ZERO" : "LOW_STOCK");
                }
                catch (Exception ex) { System.Diagnostics.Trace.TraceWarning($"Committed stock notification failed: {ex}"); }
                return Ok(ApiResponse<object>.Ok(new { newStock = stock }));
            }
            catch (SqlException e) { return BadRequest(e.Message); }
        }

        [HttpGet, Route("catalog/products"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Products(string search = null) => Rows("dbo.sp_AdminCatalogProducts", P("@Search", search));
        [HttpGet, Route("catalog/categories"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Categories() => Rows("dbo.sp_AdminCategories");
        [HttpGet, Route("catalog/brands"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Brands() => Rows("dbo.sp_AdminBrands");
        [HttpGet, Route("catalog/{id:int}/colors"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Colors(int id) => Rows("dbo.sp_AdminColors", P("@ProductId", id));
        [HttpGet, Route("catalog/{id:int}/variants"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Variants(int id) => Rows("dbo.sp_AdminVariants", P("@ProductId", id));
        [HttpGet, Route("catalog/{id:int}/gallery"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Gallery(int id) => Rows("dbo.sp_AdminGallery", P("@ProductId", id));
        [HttpGet, Route("catalog/{id:int}/specifications"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Specifications(int id) => Rows("dbo.sp_AdminSpecifications", P("@ProductId", id));

        [HttpGet, Route("catalog/{id:int}/complete"), StaffAuthorize(adminOnly: true)]
        public async Task<IHttpActionResult> GetProductComplete(int id)
        {
            var p = await _data.GetProductCompleteAsync(id).ConfigureAwait(false);
            if (p == null) return NotFound();
            return Ok(ApiResponse<AdminProductCompleteDto>.Ok(p));
        }

        [HttpPost, Route("catalog/{id:int}/specifications-batch"), StaffAuthorize(adminOnly: true)]
        public async Task<IHttpActionResult> SaveSpecificationsBatch(int id, [FromBody] Newtonsoft.Json.Linq.JToken payload)
        {
            try
            {
                string json = payload != null ? payload.ToString() : "[]";
                await _data.SaveProductSpecificationsAsync(id, json).ConfigureAwait(false);
                return Ok(ApiResponse<object>.Ok(new { success = true }));
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPost, Route("catalog/products"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> SaveProduct(AdminProductDto d)
        {
            if (d == null) return Task.FromResult<IHttpActionResult>(BadRequest("Product is required."));
            return Rows("dbo.sp_AdminSaveProduct", 
                P("@Id", d.Id), 
                P("@CategoryId", d.CategoryId), 
                P("@BrandId", d.BrandId),
                P("@Name", d.Name), 
                P("@Slug", d.Slug), 
                P("@Description", d.Description), 
                P("@RidingStyle", d.RidingStyle),
                P("@BasePrice", d.BasePrice), 
                P("@DiscountPercentage", d.DiscountPercentage),
                P("@DiscountType", d.DiscountType ?? "Percentage"),
                P("@DiscountAmount", d.DiscountAmount),
                P("@DiscountStartDate", (object)d.DiscountStartDate ?? DBNull.Value),
                P("@DiscountEndDate", (object)d.DiscountEndDate ?? DBNull.Value),
                P("@MainImageUrl", d.MainImageUrl), 
                P("@IsFeatured", d.IsFeatured), 
                P("@IsActive", d.IsActive));
        }

        [HttpDelete, Route("catalog/products/{id:int}"), StaffAuthorize(adminOnly: true)]
        public async Task<IHttpActionResult> DeleteProduct(int id)
        {
            var res = await _data.DeleteProductAsync(id).ConfigureAwait(false);
            if (!res.Success) return BadRequest(res.Message);
            return Ok(ApiResponse<object>.Ok(new { status = res.Status, message = res.Message }));
        }

        [HttpPost, Route("catalog/categories"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> SaveCategory(AdminCategoryDto d)
        {
            if (d == null) return Task.FromResult<IHttpActionResult>(BadRequest("Category is required."));
            return Rows("dbo.sp_AdminSaveCategory", P("@Id", d.Id), P("@Name", d.Name), P("@Slug", d.Slug),
                P("@Description", d.Description), P("@DisplayOrder", d.DisplayOrder), P("@IsActive", d.IsActive));
        }

        [HttpPost, Route("catalog/brands"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> SaveBrand(AdminBrandDto d)
        {
            if (d == null) return Task.FromResult<IHttpActionResult>(BadRequest("Brand is required."));
            return Rows("dbo.sp_AdminSaveBrand", P("@Id", d.Id), P("@Name", d.Name), P("@LogoUrl", d.LogoUrl),
                P("@Website", d.Website), P("@IsActive", d.IsActive));
        }

        [HttpPost, Route("catalog/colors"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> SaveColor(AdminColorDto d)
        {
            if (d == null || (d.ColorType == AppConstants.ColorTypes.LinearGradient && (d.Stops == null || d.Stops.Count < 2 || d.Stops.Count > 4)))
                return Task.FromResult<IHttpActionResult>(BadRequest("Gradient needs 2–4 stops."));
            var s = d.Stops ?? new List<string>();
            return Rows("dbo.sp_AdminSaveColor", P("@Id", d.Id), P("@ProductId", d.ProductId), P("@Color", d.Color),
                P("@ColorType", d.ColorType), P("@SolidHex", d.SolidHex), P("@GradientAngle", d.GradientAngle),
                P("@Stop1", s.Count > 0 ? s[0] : null), P("@Stop2", s.Count > 1 ? s[1] : null),
                P("@Stop3", s.Count > 2 ? s[2] : null), P("@Stop4", s.Count > 3 ? s[3] : null));
        }

        [HttpPost, Route("catalog/variants"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> SaveVariant(AdminVariantDto d)
        {
            if (d == null) return Task.FromResult<IHttpActionResult>(BadRequest("Variant is required."));
            return Rows("dbo.sp_AdminSaveVariant", P("@Id", d.Id), P("@ProductColorId", d.ProductColorId), P("@SKU", d.SKU),
                P("@Size", d.Size), P("@PriceAdjustment", d.PriceAdjustment), P("@ReorderPoint", d.ReorderPoint), P("@IsActive", d.IsActive));
        }

        [HttpPost, Route("catalog/gallery"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> SaveGallery(AdminGalleryDto d)
        {
            if (d == null) return Task.FromResult<IHttpActionResult>(BadRequest("Gallery image is required."));
            return Rows("dbo.sp_AdminSaveGallery", P("@Id", d.Id), P("@ProductId", d.ProductId), P("@ImageUrl", d.ImageUrl),
                P("@AltText", d.AltText), P("@DisplayOrder", d.DisplayOrder), P("@IsActive", d.IsActive));
        }

        [HttpPost, Route("catalog/specifications"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> SaveSpecification(AdminSpecificationDto d)
        {
            if (d == null) return Task.FromResult<IHttpActionResult>(BadRequest("Specification is required."));
            return Rows("dbo.sp_UpsertProductSpecificationValue", P("@ProductId", d.ProductId),
                P("@SpecificationKey", d.SpecificationKey), P("@SpecificationValue", d.SpecificationValue));
        }

        [HttpPost, Route("catalog/upload"), StaffAuthorize(adminOnly: true)]
        public async Task<IHttpActionResult> UploadImage()
        {
            var file = HttpContext.Current?.Request.Files["image"];
            if (file == null || file.ContentLength <= 0 || file.ContentLength > 5 * 1024 * 1024)
                return BadRequest("Choose an image up to 5 MB.");
            byte[] bytes;
            using (var buffer = new MemoryStream())
            {
                await file.InputStream.CopyToAsync(buffer).ConfigureAwait(false);
                bytes = buffer.ToArray();
            }
            var saved = ImageUploadHelper.SaveImageBytes(bytes, file.FileName,
                HttpContext.Current.Request.Form["brand"], file.ContentType);
            if (!saved.Success) return BadRequest(saved.ErrorMessage);
            return Ok(ApiResponse<object>.Ok(new { imageUrl = saved.FilePath }));
        }

        [HttpGet, Route("reports/sales"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Sales(DateTime startDate, DateTime endDate) =>
            Rows("dbo.sp_AdminSalesReport", P("@StartDate", startDate), P("@EndDate", endDate));
        [HttpGet, Route("reports/daily"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> SalesDaily(DateTime startDate, DateTime endDate) =>
            Rows("dbo.sp_AdminSalesDaily", P("@StartDate", startDate), P("@EndDate", endDate));
        [HttpGet, Route("reports/inventory"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> InventoryReport() => Rows("dbo.sp_AdminInventoryReport");

        [HttpGet, Route("users"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Users() => Rows("dbo.sp_AdminUsers", P("@Limit", 200));
        [HttpPost, Route("users"), StaffAuthorize(adminOnly: true)]
        public async Task<IHttpActionResult> CreateUser(AdminUserDto d)
        {
            if (d == null || !d.IsActive) return BadRequest("Create an active account, then deactivate it if needed.");
            try { return Ok(ApiResponse<object>.Ok(await _auth.CreateManagedUserAsync(d).ConfigureAwait(false))); }
            catch (Exception e) when (e is ArgumentException || e is InvalidOperationException) { return BadRequest(e.Message); }
        }
        [HttpPut, Route("users/{id:int}"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> UpdateUser(int id, AdminUserDto d)
        {
            if (d == null) return Task.FromResult<IHttpActionResult>(BadRequest("User is required."));
            return Rows("dbo.sp_AdminUpdateUser", P("@UserId", id), P("@FirstName", d.FirstName),
                P("@LastName", d.LastName), P("@PhoneNumber", d.PhoneNumber), P("@RoleName", d.Role),
                P("@IsActive", d.IsActive), P("@ActorUserId", ActorId));
        }

        [HttpGet, Route("reviews"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Reviews() => Rows("dbo.sp_AdminReviews", P("@Limit", 100));
        [HttpPut, Route("reviews/{id:int}/visibility"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> ReviewVisibility(int id, AdminReviewDto d)
        {
            if (d == null) return Task.FromResult<IHttpActionResult>(BadRequest("Visibility is required."));
            return Rows("dbo.sp_AdminModerateReview", P("@ReviewId", id), P("@IsHidden", d.IsHidden));
        }

        [HttpGet, Route("payments"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Payments() => Rows("dbo.sp_AdminPayments", P("@Limit", 100));
        [HttpGet, Route("webhooks"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Webhooks() => Rows("dbo.sp_AdminWebhookEvents", P("@Limit", 100));
    }
}
