using System;
using System.Linq;
using System.Net.Mail;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public static class CheckoutPolicy
    {
        public static void ValidateAndPrice(CreateOrderRequestDto request)
        {
            if (request == null) throw new ArgumentException("Order details are required.");
            Require(request.CustomerName, 100, "Customer name");
            Require(request.CustomerEmail, 256, "Email");
            Require(request.CustomerPhone, 30, "Phone number");
            try { if (new MailAddress(request.CustomerEmail).Address != request.CustomerEmail.Trim()) throw new FormatException(); }
            catch (FormatException) { throw new ArgumentException("Enter a valid email address."); }
            if (request.ShippingMethod != AppConstants.ShippingMethods.Pickup && request.ShippingMethod != AppConstants.ShippingMethods.Delivery)
                throw new ArgumentException("Choose pickup or delivery.");
            if (request.PaymentMethod != AppConstants.PaymentGateways.HitPay &&
                request.PaymentMethod != AppConstants.PaymentGateways.Cash && request.PaymentMethod != AppConstants.PaymentGateways.CashOnDelivery)
                throw new ArgumentException("Choose a supported online payment method.");
            if (request.PaymentMethod == AppConstants.PaymentGateways.Cash && request.ShippingMethod != AppConstants.ShippingMethods.Pickup ||
                request.PaymentMethod == AppConstants.PaymentGateways.CashOnDelivery && request.ShippingMethod != AppConstants.ShippingMethods.Delivery)
                throw new ArgumentException("Cash requires pickup. Cash on delivery requires delivery.");

            request.ShippingFee = AppConstants.ShippingTiers.FeePickup;
            request.ShippingRegion = AppConstants.ShippingMethods.Pickup;
            if (request.ShippingMethod == AppConstants.ShippingMethods.Pickup) return;
            Require(request.ShippingAddress, 300, "Delivery address");
            Require(request.ShippingCity, 100, "City");
            Require(request.ShippingProvince, 100, "Province");
            var province = Normalize(request.ShippingProvince);
            if (province == "metro manila" || province == "ncr")
                SetShipping(request, AppConstants.ShippingTiers.MetroManila, AppConstants.ShippingTiers.FeeMetroManila);
            else if (Matches(province, AppConstants.ShippingLocations.GreaterManila))
                SetShipping(request, AppConstants.ShippingTiers.GreaterManila, AppConstants.ShippingTiers.FeeGreaterManila);
            else if (Matches(province, AppConstants.ShippingLocations.Luzon))
                SetShipping(request, AppConstants.ShippingTiers.RestOfLuzon, AppConstants.ShippingTiers.FeeRestOfLuzon);
            else if (Matches(province, AppConstants.ShippingLocations.Visayas))
                SetShipping(request, AppConstants.ShippingTiers.Visayas, AppConstants.ShippingTiers.FeeVisayas);
            else if (Matches(province, AppConstants.ShippingLocations.Mindanao))
                SetShipping(request, AppConstants.ShippingTiers.Mindanao, AppConstants.ShippingTiers.FeeMindanao);
            else throw new ArgumentException("Choose a recognized Philippine province for delivery.");
        }

        private static string Normalize(string value) => value.Trim().ToLowerInvariant().Replace("\u00f1", "n");
        private static bool Matches(string province, string[] locations) => locations.Any(province.Contains);
        private static void SetShipping(CreateOrderRequestDto request, string region, decimal fee)
        { request.ShippingRegion = region; request.ShippingFee = fee; }
        private static void Require(string value, int limit, string label)
        { if (string.IsNullOrWhiteSpace(value) || value.Length > limit) throw new ArgumentException(label + " is required and must be at most " + limit + " characters."); }
    }
}
