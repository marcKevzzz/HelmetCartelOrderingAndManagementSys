using System;
using System.Data.SqlClient;
using System.Net;
using System.Threading.Tasks;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using HelmetCartelOrderingAndManagementSys.Services;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/vouchers")]
    public sealed class VouchersController : ApiController
    {
        private readonly VoucherRepository _repository = new VoucherRepository(new DbConnectionFactory());

        [HttpPost, Route("validate")]
        public async Task<IHttpActionResult> Validate(VoucherRequestDto request)
        {
            try
            {
                if (!ModelState.IsValid) return BadRequest(ModelState);
                return Ok(ApiResponse<VoucherQuoteDto>.Ok(await new VoucherService(_repository).PreviewAsync(request).ConfigureAwait(false)));
            }
            catch (ArgumentException e) { return VoucherError(e.Message); }
            catch (SqlException e) when (IsVoucherError(e)) { return VoucherError(e.Message); }
        }

        [HttpGet, Route("~/api/v1/admin/vouchers"), StaffAuthorize(adminOnly: true)]
        public async Task<IHttpActionResult> List() => Ok(await _repository.ListAsync().ConfigureAwait(false));

        [HttpPost, Route("~/api/v1/admin/vouchers"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Create(SaveVoucherDto request) => Save(0, request);

        [HttpPut, Route("~/api/v1/admin/vouchers/{id:int}"), StaffAuthorize(adminOnly: true)]
        public Task<IHttpActionResult> Update(int id, SaveVoucherDto request) => id <= 0
            ? Task.FromResult(VoucherError("Invalid voucher ID.")) : Save(id, request);

        private async Task<IHttpActionResult> Save(int id, SaveVoucherDto request)
        {
            try
            {
                if (!ModelState.IsValid) return BadRequest(ModelState);
                if (id < 0) throw new ArgumentException("Invalid voucher ID.");
                VoucherService.ValidateSave(request);
                return Ok(await _repository.SaveAsync(id, request).ConfigureAwait(false));
            }
            catch (ArgumentException e) { return VoucherError(e.Message); }
            catch (SqlException e) when (IsVoucherError(e)) { return VoucherError(e.Message); }
            catch (SqlException e) when (e.Number == 2601 || e.Number == 2627) { return VoucherError("This voucher code already exists."); }
        }

        private IHttpActionResult VoucherError(string message) => Content(HttpStatusCode.BadRequest,
            ApiResponse<object>.Fail(message, AppConstants.ErrorCodes.InvalidVoucher));
        private static bool IsVoucherError(SqlException e) => e.Number >= AppConstants.Vouchers.FirstSqlError && e.Number <= AppConstants.Vouchers.LastSqlError;
    }
}
