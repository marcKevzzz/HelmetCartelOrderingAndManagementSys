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

        [HttpPost]
        [Route("simulate")]
        public async Task<IHttpActionResult> SimulatePayment([FromBody] SimulatePaymentRequestDto request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.OrderNumber))
            {
                return BadRequest("Order number is required for payment simulation.");
            }

            var isSimulation = string.Equals(System.Configuration.ConfigurationManager.AppSettings["HitPay:SimulationMode"], "true", StringComparison.OrdinalIgnoreCase);
            if (!isSimulation)
            {
                return BadRequest("Payment simulation is only enabled when HitPay:SimulationMode is true.");
            }

            try
            {
                string channel = string.IsNullOrWhiteSpace(request.PaymentChannel) ? AppConstants.PaymentChannels.QrPh : request.PaymentChannel.ToUpperInvariant();
                string outcome = string.IsNullOrWhiteSpace(request.Outcome) ? "SUCCESS" : request.Outcome.ToUpperInvariant();

                if (outcome == "SUCCESS")
                {
                    string simGatewayRef = $"SIM-{channel}-{Guid.NewGuid().ToString("N").Substring(0, 8).ToUpperInvariant()}";
                    bool confirmed = await _orderService.ConfirmOnlinePaymentAsync(request.OrderNumber, simGatewayRef).ConfigureAwait(false);

                    if (!confirmed)
                    {
                        return Ok(ApiResponse<object>.Fail("Order has already been processed or cannot accept payment.", AppConstants.ErrorCodes.OrderNotFound));
                    }

                    return Ok(ApiResponse<object>.Ok(new
                    {
                        orderNumber = request.OrderNumber,
                        paymentId = simGatewayRef,
                        channel = channel,
                        status = AppConstants.OrderStatus.Processing,
                        paymentStatus = AppConstants.PaymentStatus.Completed
                    }, "Simulated payment completed successfully."));
                }
                else
                {
                    // Record failed payment attempt in database using stored procedure
                    await _adminData.QueryAsync(
                        "dbo.sp_RecordPaymentFailure",
                        AdminDataRepository.Param("@OrderNumber", request.OrderNumber)
                    ).ConfigureAwait(false);

                    return Ok(ApiResponse<object>.Fail("Payment simulation failed: Insufficient funds or card declined.", "SIMULATED_PAYMENT_DECLINED"));
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError($"[PaymentsController.SimulatePayment] Error simulating payment for {request.OrderNumber}: {ex}");
                return InternalServerError(ex);
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
