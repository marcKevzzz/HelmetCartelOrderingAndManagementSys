using System;

namespace HelmetCartelOrderingAndManagementSys.Constants
{
    /// <summary>
    /// Centralized application constants used across all layers of the Helmet Cartel system.
    /// Strictly eliminates magic strings and provides a single source of truth.
    /// </summary>
    public static class AppConstants
    {
        public static class Shopping
        {
            public const string AddCart = "AddCart";
            public const string SetCart = "SetCart";
            public const string RemoveCart = "RemoveCart";
            public const string ClearCart = "ClearCart";
            public const string SelectCart = "SelectCart";
            public const string SaveFavorite = "SaveFavorite";
            public const string RemoveFavorite = "RemoveFavorite";
            public const string ClearFavorites = "ClearFavorites";
        }

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
            public const string Shipped = "Shipped";
            public const string Delivered = "Delivered";
            public const string Completed = "Completed";
            public const string Cancelled = "Cancelled";
        }

        public static class OrderSources
        {
            public const string Online = "ONLINE";
            public const string InStorePos = "INSTORE_POS";
        }

        public static class ShippingMethods
        {
            public const string Pickup = "Pickup";
            public const string Delivery = "Delivery";
        }

        public static class Couriers
        {
            public const string JAndT = "J&T Express";
            public const string Lbc = "LBC Express";
            public const string Flash = "Flash Express";
            public const string Lalamove = "Lalamove";
            public const string Grab = "Grab Express";
            public const string Other = "Other Courier";
        }

        public static class ShippingTiers
        {
            public const string MetroManila = "Metro Manila (NCR)";
            public const string GreaterManila = "Greater Manila Area";
            public const string RestOfLuzon = "Rest of Luzon";
            public const string Visayas = "Visayas";
            public const string Mindanao = "Mindanao & Island Provinces";

            public const decimal FeeMetroManila = 150.00m;
            public const decimal FeeGreaterManila = 250.00m;
            public const decimal FeeRestOfLuzon = 350.00m;
            public const decimal FeeVisayas = 450.00m;
            public const decimal FeeMindanao = 500.00m;
            public const decimal FeePickup = 0.00m;
        }

        public static class PaymentGateways
        {
            public const string HitPay = "HitPay";
            public const string Cash = "Cash";
            public const string CardPos = "Card_POS";
            public const string CashOnDelivery = "CashOnDelivery";
        }

        public static class PaymentChannels
        {
            public const string QrPh = "QRPH";
            public const string GCash = "GCASH";
            public const string Maya = "MAYA";
            public const string Card = "CARD";
        }

        public static class ShippingLocations
        {
            public static readonly string[] GreaterManila = { "cavite", "laguna", "batangas", "rizal", "bulacan" };
            public static readonly string[] Luzon = { "pampanga", "nueva ecija", "tarlac", "zambales", "bataan", "pangasinan", "ilocos", "la union", "benguet", "baguio", "cagayan", "isabela", "nueva vizcaya", "quirino", "aurora", "quezon", "albay", "camarines", "sorsogon", "catanduanes", "masbate", "marinduque", "occidental mindoro", "oriental mindoro", "palawan", "romblon", "abra", "apayao", "ifugao", "kalinga", "mountain province" };
            public static readonly string[] Visayas = { "cebu", "bohol", "iloilo", "negros", "leyte", "samar", "panay", "capiz", "aklan", "antique", "guimaras", "biliran", "siquijor" };
            public static readonly string[] Mindanao = { "davao", "misamis", "bukidnon", "south cotabato", "cotabato", "zamboanga", "lanao", "agusan", "surigao", "sultan kudarat", "sarangani", "basilan", "sulu", "tawi-tawi", "maguindanao" };
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

        public static class StockAlertSeverity
        {
            public const string Low = "LOW_STOCK";
            public const string Critical = "CRITICAL_ZERO";
        }

        public static class HitPay
        {
            public const string Currency = "PHP";
            public const string HeaderApiKey = "X-BUSINESS-API-KEY";
            public const string HeaderSignature = "X-Hitpay-Signature";
            public const string SandboxUrl = "https://api.sandbox.hit-pay.com/v1/";
            public const string ProductionUrl = "https://api.hit-pay.com/v1/";
        }

        public static class JwtConfiguration
        {
            public const int SessionExpiryMinutes = 60;
            public const int RememberMeExpiryMinutes = 14 * 24 * 60;
            public const string AuthCookieName = "hc_auth_token";
            public const string SecretEnvironmentVariable = "HELMET_CARTEL_JWT_SECRET";
            public const string SecretKey = "Jwt:Secret";
            public const string IssuerKey = "Jwt:Issuer";
            public const string AudienceKey = "Jwt:Audience";
            public const string ExpiryMinutesKey = "Jwt:ExpiryMinutes";
            public const string LocalSecretFolder = "App_Data";
            public const string UserSecretFileName = "Jwt_Secret";
            public const string GeneratedSecretFileName = "jwt-secret.key";
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

        public static class Receipts
        {
            public const string Brand = "HELMET CARTEL";
            public const string SimulationPrefix = "SIM-";
        }

        public static class Vouchers
        {
            public const string Percentage = "PERCENTAGE";
            public const string FixedAmount = "FIXED_AMOUNT";
            public const string FreeShipping = "FREE_SHIPPING";
            public const int FirstSqlError = 54001;
            public const int LastSqlError = 54020;
        }

        public static class ErrorCodes
        {
            public const string InvalidInput = "INVALID_INPUT";
            public const string InsufficientStock = "INSUFFICIENT_STOCK";
            public const string ProductNotFound = "PRODUCT_NOT_FOUND";
            public const string VariantNotFound = "VARIANT_NOT_FOUND";
            public const string OrderNotFound = "ORDER_NOT_FOUND";
            public const string InvalidPaymentSignature = "INVALID_PAYMENT_SIGNATURE";
            public const string UnauthorizedAccess = "UNAUTHORIZED_ACCESS";
            public const string ConcurrencyConflict = "CONCURRENCY_CONFLICT";
            public const string InvalidVoucher = "INVALID_VOUCHER";
            public const string DatabaseError = "DATABASE_ERROR";
        }
    }
}
