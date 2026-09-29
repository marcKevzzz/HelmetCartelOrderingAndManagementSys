using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

namespace HelmetCartelOrderingAndManagementSys.Infrastructure
{
    public interface IHitPaySignatureValidator
    {
        bool ValidateSignature(IDictionary<string, string> payloadValues, string receivedSignature, string salt);
    }

    public class HitPaySignatureValidator : IHitPaySignatureValidator
    {
        /// <summary>
        /// Validates HitPay HMAC-SHA256 signature using constant-time comparison.
        /// </summary>
        public bool ValidateSignature(IDictionary<string, string> payloadValues, string receivedSignature, string salt)
        {
            if (string.IsNullOrEmpty(receivedSignature) || string.IsNullOrEmpty(salt))
                return false;

            // 1. Sort dictionary keys alphabetically, excluding 'hmac'
            var sortedValues = payloadValues
                .Where(kvp => !kvp.Key.Equals("hmac", StringComparison.OrdinalIgnoreCase))
                .OrderBy(kvp => kvp.Key, StringComparer.Ordinal)
                .Select(kvp => $"{kvp.Key}={kvp.Value}");

            var rawSignatureString = string.Join("&", sortedValues);

            // 2. Compute HMAC-SHA256
            using (var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(salt)))
            {
                var hashBytes = hmac.ComputeHash(Encoding.UTF8.GetBytes(rawSignatureString));
                var computedHex = BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant();

                // 3. Constant-time comparison to prevent timing attacks
                return CryptographicEquals(computedHex, receivedSignature.ToLowerInvariant());
            }
        }

        private static bool CryptographicEquals(string a, string b)
        {
            if (a == null || b == null || a.Length != b.Length)
                return false;

            int diff = 0;
            for (int i = 0; i < a.Length; i++)
            {
                diff |= a[i] ^ b[i];
            }
            return diff == 0;
        }
    }
}
