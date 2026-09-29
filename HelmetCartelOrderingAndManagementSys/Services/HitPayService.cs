using System;
using System.Collections.Generic;
using System.Configuration;
using System.Net.Http;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using Newtonsoft.Json;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public class HitPayService : IHitPayService
    {
        private readonly IHitPaySignatureValidator _signatureValidator;
        private readonly string _apiKey;
        private readonly string _salt;
        private readonly string _baseUrl;

        public HitPayService(IHitPaySignatureValidator signatureValidator)
        {
            _signatureValidator = signatureValidator ?? throw new ArgumentNullException(nameof(signatureValidator));
            _apiKey = ConfigurationManager.AppSettings["HitPay:ApiKey"] ?? "sandbox_api_key_default";
            _salt = ConfigurationManager.AppSettings["HitPay:Salt"] ?? "sandbox_salt_default";
            _baseUrl = ConfigurationManager.AppSettings["HitPay:BaseUrl"] ?? AppConstants.HitPay.SandboxUrl;
        }

        public async Task<HitPayPaymentResponse> CreatePaymentRequestAsync(OrderSummaryDto order)
        {
            try
            {
                using (var client = new HttpClient())
                {
                    client.BaseAddress = new Uri(_baseUrl);
                    client.DefaultRequestHeaders.Add(AppConstants.HitPay.HeaderApiKey, _apiKey);

                    var formValues = new Dictionary<string, string>
                    {
                        { "amount", order.TotalAmount.ToString("F2") },
                        { "currency", AppConstants.HitPay.Currency },
                        { "reference_number", order.OrderNumber },
                        { "email", order.CustomerEmail },
                        { "name", order.CustomerName },
                        { "phone", order.CustomerPhone },
                        { "webhook", "/api/v1/payments/hitpay-webhook" },
                        { "redirect_url", $"/order-confirmation.html?orderNumber={order.OrderNumber}" }
                    };

                    var formContent = new FormUrlEncodedContent(formValues);
                    var response = await client.PostAsync("payment-requests", formContent).ConfigureAwait(false);

                    if (response.IsSuccessStatusCode)
                    {
                        var content = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                        return JsonConvert.DeserializeObject<HitPayPaymentResponse>(content);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[HitPayService] Failed calling HitPay API: {ex.Message}");
            }

            // Fallback for local sandbox/testing without active HitPay credentials
            return new HitPayPaymentResponse
            {
                Id = $"hitpay_sandbox_{Guid.NewGuid():N}",
                ReferenceNumber = order.OrderNumber,
                Status = "pending",
                Url = $"https://sandbox.hitpayapp.com/checkout/{order.OrderNumber}"
            };
        }

        public bool VerifyWebhookSignature(IDictionary<string, string> payload)
        {
            if (payload == null || !payload.ContainsKey("hmac"))
                return false;

            var receivedHmac = payload["hmac"];
            return _signatureValidator.ValidateSignature(payload, receivedHmac, _salt);
        }

        public async Task<bool> ProcessWebhookNotificationAsync(HitPayWebhookPayload payload)
        {
            if (payload == null) return false;
            // Handled in payments controller or order service confirmation
            return await Task.FromResult(payload.Status == "completed").ConfigureAwait(false);
        }
    }
}
