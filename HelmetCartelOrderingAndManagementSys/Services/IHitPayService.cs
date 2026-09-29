using System.Collections.Generic;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public interface IHitPayService
    {
        Task<HitPayPaymentResponse> CreatePaymentRequestAsync(OrderSummaryDto order);
        bool VerifyWebhookSignature(IDictionary<string, string> payload);
        Task<bool> ProcessWebhookNotificationAsync(HitPayWebhookPayload payload);
    }
}
