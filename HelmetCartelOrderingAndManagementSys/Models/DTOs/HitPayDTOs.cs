using Newtonsoft.Json;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public class HitPayCreatePaymentRequest
    {
        public string Amount { get; set; }
        public string Currency { get; set; } = "PHP";
        [JsonProperty("payment_methods")]
        public string[] PaymentMethods { get; set; } = new[] { "qrph" };
        public string Email { get; set; }
        public string Name { get; set; }
        public string Phone { get; set; }
        [JsonProperty("reference_number")]
        public string ReferenceNumber { get; set; }
        [JsonProperty("webhook")]
        public string WebhookUrl { get; set; }
        [JsonProperty("redirect_url")]
        public string RedirectUrl { get; set; }
    }

    public class HitPayPaymentResponse
    {
        public string Id { get; set; }
        public string Url { get; set; }
        public string Status { get; set; }
        [JsonProperty("reference_number")]
        public string ReferenceNumber { get; set; }
    }

    public class HitPayWebhookPayload
    {
        [JsonProperty("payment_id")]
        public string PaymentId { get; set; }
        [JsonProperty("payment_request_id")]
        public string PaymentRequestId { get; set; }
        [JsonProperty("reference_number")]
        public string ReferenceNumber { get; set; }
        public string Status { get; set; } // "completed", "failed"
        public string Amount { get; set; }
        public string Currency { get; set; }
        public string Hmac { get; set; }
    }

    public class SimulatePaymentRequestDto
    {
        public string OrderNumber { get; set; }
        public string PaymentChannel { get; set; } = "QRPH";
        public string Outcome { get; set; } = "SUCCESS";
    }
}
