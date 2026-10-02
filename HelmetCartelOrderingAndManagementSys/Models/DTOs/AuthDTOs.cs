using System;
using System.Collections.Generic;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public class LoginRequestDto
    {
        public bool RememberMe { get; set; }
        public string Email { get; set; }
        public string Password { get; set; }
    }

    public class RegisterRequestDto
    {
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Email { get; set; }
        public string Password { get; set; }
        public string PhoneNumber { get; set; }
    }

    public class AuthResponseDto
    {
        public string Token { get; set; }
        public int ExpiresIn { get; set; }
        public UserProfileDto User { get; set; }
    }

    public class UserProfileDto
    {
        public int Id { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string FullName { get; set; }
        public string Email { get; set; }
        public string PhoneNumber { get; set; }
        public string Role { get; set; }
        public DateTime? CreatedAt { get; set; }
    }

    public class UpdateProfileRequestDto
    {
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string PhoneNumber { get; set; }
    }

    public class ChangePasswordRequestDto
    {
        public string CurrentPassword { get; set; }
        public string NewPassword { get; set; }
        public string ConfirmNewPassword { get; set; }
    }

    public class UserRecordDto
    {
        public int Id { get; set; }
        public int RoleId { get; set; }
        public string RoleName { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string FullName { get; set; }
        public string Email { get; set; }
        public string PasswordHash { get; set; }
        public string Salt { get; set; }
        public string PhoneNumber { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class UserOrderSummaryDto
    {
        public int Id { get; set; }
        public string OrderNumber { get; set; }
        public string CustomerName { get; set; }
        public string CustomerEmail { get; set; }
        public string CustomerPhone { get; set; }
        public decimal Subtotal { get; set; }
        public decimal DiscountAmount { get; set; }
        public decimal ShippingFee { get; set; }
        public decimal TotalAmount { get; set; }
        public string OrderStatus { get; set; }
        public string OrderSource { get; set; }
        public string ShippingMethod { get; set; }
        public string ShippingRegion { get; set; }
        public string ShippingAddress { get; set; }
        public string ShippingBarangay { get; set; }
        public string ShippingCity { get; set; }
        public string ShippingProvince { get; set; }
        public string ShippingPostalCode { get; set; }
        public string Courier { get; set; }
        public string TrackingNumber { get; set; }
        public string DeliveryNotes { get; set; }
        public string Notes { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public string PaymentGateway { get; set; }
        public string PaymentStatus { get; set; }
        public string GatewayReference { get; set; }
        public int ItemCount { get; set; }
    }

    public class UserPaymentHistoryDto
    {
        public int PaymentId { get; set; }
        public int OrderId { get; set; }
        public string OrderNumber { get; set; }
        public string PaymentGateway { get; set; }
        public string GatewayReference { get; set; }
        public decimal Amount { get; set; }
        public string PaymentStatus { get; set; }
        public DateTime? PaidAt { get; set; }
        public DateTime PaymentCreatedAt { get; set; }
        public string CustomerName { get; set; }
        public string CustomerEmail { get; set; }
        public string ShippingMethod { get; set; }
        public decimal OrderTotalAmount { get; set; }
        public int ItemCount { get; set; }
    }

    public class UserAddressDto
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string AddressLabel { get; set; }
        public string RecipientName { get; set; }
        public string PhoneNumber { get; set; }
        public string StreetAddress { get; set; }
        public string Barangay { get; set; }
        public string City { get; set; }
        public string Province { get; set; }
        public string PostalCode { get; set; }
        public string DeliveryLandmark { get; set; }
        public bool IsDefault { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class SaveUserAddressRequestDto
    {
        public int? Id { get; set; }
        public string AddressLabel { get; set; }
        public string RecipientName { get; set; }
        public string PhoneNumber { get; set; }
        public string StreetAddress { get; set; }
        public string Barangay { get; set; }
        public string City { get; set; }
        public string Province { get; set; }
        public string PostalCode { get; set; }
        public string DeliveryLandmark { get; set; }
        public bool IsDefault { get; set; }
    }
}
