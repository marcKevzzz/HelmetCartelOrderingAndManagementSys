using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using HelmetCartelOrderingAndManagementSys.Services;
using HelmetCartelOrderingAndManagementSys.Constants;
using Newtonsoft.Json;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/payments")]
    public class PaymentsController : ApiController
    {
        private readonly IHitPayService _hitPayService;
        private readonly IOrderService _orderService;
        private readonly AdminDataRepository _adminData;

        public PaymentsController()
        {
            var dbFactory = new DbConnectionFactory();
            var orderRepo = new OrderRepository(dbFactory);
            var invRepo = new InventoryRepository(dbFactory);
            var invService = new InventoryService(invRepo);
            var sigValidator = new HitPaySignatureValidator();
            _hitPayService = new HitPayService(sigValidator);
            _orderService = new OrderService(orderRepo, invService, _hitPayService);
            _adminData = new AdminDataRepository(dbFactory);
        }

        public PaymentsController(IHitPayService hitPayService, IOrderService orderService)
        {
            _hitPayService = hitPayService;
            _orderService = orderService;
            _adminData = new AdminDataRepository(new DbConnectionFactory());
        }

        [HttpPost]
        [Route("hitpay-webhook")]
        public async Task<HttpResponseMessage> HitPayWebhook()
        {
            try
            {
                var formData = await Request.Content.ReadAsFormDataAsync().ConfigureAwait(false);
                var dict = new Dictionary<string, string>();
                foreach (var key in formData.AllKeys)
                {
                    dict[key] = formData[key];
                }

                dict.TryGetValue("status", out var status);
                dict.TryGetValue("reference_number", out var referenceNumber);
                dict.TryGetValue("payment_id", out var paymentId);
                dict.TryGetValue("hmac", out var signature);
                var valid = _hitPayService.VerifyWebhookSignature(dict);
                if (!valid)
                {
                    await LogWebhookAsync(paymentId, referenceNumber, dict, signature, false,
                        AppConstants.WebhookProcessingStatus.Rejected, "Invalid signature").ConfigureAwait(false);
                    System.Diagnostics.Debug.WriteLine("[PaymentsController] Webhook rejected: Invalid HMAC signature.");
                    return Request.CreateResponse(HttpStatusCode.BadRequest, new { message = "Invalid signature" });
                }

                var processingStatus = AppConstants.WebhookProcessingStatus.Processed;
                if (string.Equals(status, "completed", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrEmpty(referenceNumber))
                {
                    var processed = await _orderService.ConfirmOnlinePaymentAsync(referenceNumber, paymentId).ConfigureAwait(false);
                    if (!processed) processingStatus = AppConstants.WebhookProcessingStatus.Duplicate;
                }

                await LogWebhookAsync(paymentId, referenceNumber, dict, signature, true, processingStatus, null).ConfigureAwait(false);

                return Request.CreateResponse(HttpStatusCode.OK, new { message = "Webhook received successfully" });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[PaymentsController] Webhook exception: {ex.Message}");
                return Request.CreateResponse(HttpStatusCode.InternalServerError, new { message = ex.Message });
            }
        }

        private Task LogWebhookAsync(string paymentId, string reference, Dictionary<string, string> payload,
            string signature, bool valid, string status, string error)
        {
            return _adminData.QueryAsync("dbo.sp_LogHitPayWebhook",
                AdminDataRepository.Param("@HitPayPaymentId", paymentId),
                AdminDataRepository.Param("@ReferenceNumber", reference),
                AdminDataRepository.Param("@RawPayload", JsonConvert.SerializeObject(payload)),
                AdminDataRepository.Param("@SignatureReceived", signature),
                AdminDataRepository.Param("@IsSignatureValid", valid),
                AdminDataRepository.Param("@ProcessingStatus", status),
                AdminDataRepository.Param("@ErrorMessage", error));
        }
    }
}
