using System;

namespace HelmetCartelOrderingAndManagementSys.Constants
{
    /// <summary>
    /// Centralized application constants used across all layers of the Helmet Cartel system.
    /// Strictly eliminates magic strings and provides a single source of truth.
    /// </summary>
    public static class AppConstants
    {
        public static class Roles
        {
            public const string Admin = "Admin";
            public const string Staff = "Staff";
            public const string Customer = "Customer";
        }

        public static class OrderStatus
        {
            public const string PendingPayment = "PendingPayment";
            public const string Processing = "Processing";
            public const string ReadyForPickup = "ReadyForPickup";
            public const string Completed = "Completed";
            public const string Cancelled = "Cancelled";
        }

        public static class OrderSources
        {
            public const string Online = "ONLINE";
            public const string InStorePos = "INSTORE_POS";
        }

        public static class PaymentGateways
        {
            public const string HitPay = "HitPay";
            public const string Cash = "Cash";
            public const string CardPos = "Card_POS";
        }

        public static class PaymentStatus
        {
            public const string Pending = "Pending";
            public const string Completed = "Completed";
            public const string Failed = "Failed";
            public const string Refunded = "Refunded";
        }

        public static class ColorTypes
        {
            public const string Solid = "SOLID";
            public const string LinearGradient = "LINEAR_GRADIENT";
        }

        public static class WebhookProcessingStatus
        {
            public const string Processed = "Processed";
            public const string Rejected = "Rejected";
            public const string Duplicate = "Duplicate";
        }

        public static class StockAuditChangeType
        {
            public const string OnlineSale = "ONLINE_SALE";
            public const string InStoreSale = "INSTORE_SALE";
            public const string Restock = "RESTOCK";
            public const string Adjustment = "ADJUSTMENT";
            public const string Return = "RETURN";
        }

        public static class SignalREvents
        {
            // Inventory Hub Events
            public const string StockUpdated = "stockUpdated";
            public const string LowStockAlert = "lowStockAlert";

            // Order Hub Events
            public const string NewOrderReceived = "newOrderReceived";
            public const string OrderStatusChanged = "orderStatusChanged";
        }

        public static class StockAlertThresholds
        {
            public const int DefaultReorderPoint = 3;
            public const int CriticalZero = 0;
        }

        public static class HitPay
        {
            public const string Currency = "PHP";
            public const string HeaderApiKey = "X-BUSINESS-API-KEY";
            public const string HeaderSignature = "X-Hitpay-Signature";
            public const string SandboxUrl = "https://api.sandbox.hit-pay.com/v1/";
            public const string ProductionUrl = "https://api.hit-pay.com/v1/";
        }

        public static class JwtClaims
        {
            public const string UserId = "uid";
            public const string Email = "email";
            public const string Role = "role";
            public const string FullName = "name";
            public const string FirstName = "given_name";
            public const string LastName = "family_name";
        }

        public static class ErrorCodes
        {
            public const string InsufficientStock = "INSUFFICIENT_STOCK";
            public const string ProductNotFound = "PRODUCT_NOT_FOUND";
            public const string VariantNotFound = "VARIANT_NOT_FOUND";
            public const string OrderNotFound = "ORDER_NOT_FOUND";
            public const string InvalidPaymentSignature = "INVALID_PAYMENT_SIGNATURE";
            public const string UnauthorizedAccess = "UNAUTHORIZED_ACCESS";
            public const string ConcurrencyConflict = "CONCURRENCY_CONFLICT";
        }
    }
}
