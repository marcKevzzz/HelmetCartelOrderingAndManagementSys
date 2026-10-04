using System;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public sealed class VoucherService
    {
        private readonly VoucherRepository _repository;
        public VoucherService(VoucherRepository repository) { _repository = repository; }

        public static string NormalizeCode(string code, bool optional = false)
        {
            if (optional && string.IsNullOrWhiteSpace(code)) return null;
            code = (code ?? "").Trim().ToUpperInvariant();
            if (!Regex.IsMatch(code, "^[A-Z0-9-]{3,30}$"))
                throw new ArgumentException("Use 3-30 letters, numbers or hyphens for the voucher code.");
            return code;
        }

        public Task<VoucherQuoteDto> PreviewAsync(VoucherRequestDto request)
        {
            if (request == null) throw new ArgumentException("Enter a voucher code.");
            request.Code = NormalizeCode(request.Code);
            if (request.Items == null || request.Items.Count == 0 || request.Items.Count > 100 ||
                request.Items.Any(x => x == null || x.VariantId <= 0 || x.Quantity <= 0 || x.Quantity > 10000) ||
                request.Items.Select(x => x.VariantId).Distinct().Count() != request.Items.Count)
                throw new ArgumentException("Choose valid, distinct merchandise items.");
            return _repository.PreviewAsync(request);
        }

        public static void ValidateSave(SaveVoucherDto request)
        {
            if (request == null) throw new ArgumentException("Voucher details are required.");
            request.Code = NormalizeCode(request.Code);
            if (request.DiscountType != AppConstants.Vouchers.Percentage &&
                request.DiscountType != AppConstants.Vouchers.FixedAmount &&
                request.DiscountType != AppConstants.Vouchers.FreeShipping)
                throw new ArgumentException("Choose percentage, fixed-peso discount, or free delivery.");

            if (request.DiscountType == AppConstants.Vouchers.FreeShipping)
            {
                if (request.DiscountValue < 0) request.DiscountValue = 0m;
                if (request.MinimumSpend < 0 || request.MinimumSpend > 9999999999999999.99m || request.UsageLimit <= 0 ||
                    decimal.Round(request.MinimumSpend, 2) != request.MinimumSpend)
                    throw new ArgumentException("Check the minimum spend and usage limit; amounts allow two decimal places.");
            }
            else
            {
                if (request.DiscountValue <= 0 || request.DiscountValue > 9999999999999999.99m ||
                    (request.DiscountType == AppConstants.Vouchers.Percentage && request.DiscountValue > 100) ||
                    request.MinimumSpend < 0 || request.MinimumSpend > 9999999999999999.99m || request.UsageLimit <= 0 ||
                    decimal.Round(request.DiscountValue, 2) != request.DiscountValue || decimal.Round(request.MinimumSpend, 2) != request.MinimumSpend)
                    throw new ArgumentException("Check the discount, minimum spend and usage limit; amounts allow two decimal places.");
            }
            if (request.ExpiresAt.HasValue) request.ExpiresAt = request.ExpiresAt.Value.ToUniversalTime();
        }
    }
}
