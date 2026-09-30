using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using Newtonsoft.Json;

namespace HelmetCartelOrderingAndManagementSys.Infrastructure
{
    public interface IJwtTokenProvider
    {
        string GenerateToken(UserProfileDto user, bool rememberMe = false);
        UserProfileDto ValidateToken(string token);
    }

    public class JwtTokenProvider : IJwtTokenProvider
    {
        private readonly string _secret;
        private readonly string _issuer;
        private readonly string _audience;

        public JwtTokenProvider()
        {
            _secret = Environment.GetEnvironmentVariable(AppConstants.JwtConfiguration.SecretEnvironmentVariable);
            if (string.IsNullOrWhiteSpace(_secret)) _secret = ConfigurationManager.AppSettings[AppConstants.JwtConfiguration.SecretKey];
            if (string.IsNullOrWhiteSpace(_secret)) _secret = LoadOrCreateLocalSecret();
            if (_secret.Length < 32) throw new ConfigurationErrorsException("JWT secret must contain at least 32 characters.");
            _issuer = ConfigurationManager.AppSettings[AppConstants.JwtConfiguration.IssuerKey] ?? "HelmetCartelApi";
            _audience = ConfigurationManager.AppSettings[AppConstants.JwtConfiguration.AudienceKey] ?? "HelmetCartelClients";

        }

        public string GenerateToken(UserProfileDto user, bool rememberMe = false)
        {
            if (user == null) throw new ArgumentNullException(nameof(user));

            var header = new Dictionary<string, object>
            {
                { "alg", "HS256" },
                { "typ", "JWT" }
            };

            var epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            var expiryMinutes = rememberMe ? AppConstants.JwtConfiguration.RememberMeExpiryMinutes : AppConstants.JwtConfiguration.SessionExpiryMinutes;
            var exp = (long)(DateTime.UtcNow.AddMinutes(expiryMinutes) - epoch).TotalSeconds;

            var payload = new Dictionary<string, object>
            {
                { AppConstants.JwtClaims.UserId, user.Id },
                { AppConstants.JwtClaims.Email, user.Email },
                { AppConstants.JwtClaims.Role, user.Role },
                { AppConstants.JwtClaims.FullName, user.FullName },
                { AppConstants.JwtClaims.FirstName, user.FirstName },
                { AppConstants.JwtClaims.LastName, user.LastName },
                { "iss", _issuer },
                { "aud", _audience },
                { "exp", exp }
            };

            var headerJson = JsonConvert.SerializeObject(header);
            var payloadJson = JsonConvert.SerializeObject(payload);

            var encodedHeader = Base64UrlEncode(Encoding.UTF8.GetBytes(headerJson));
            var encodedPayload = Base64UrlEncode(Encoding.UTF8.GetBytes(payloadJson));

            var stringToSign = $"{encodedHeader}.{encodedPayload}";
            var signature = ComputeHmacSha256(stringToSign, _secret);
            var encodedSignature = Base64UrlEncode(signature);

            return $"{stringToSign}.{encodedSignature}";
        }

        public UserProfileDto ValidateToken(string token)
        {
            if (string.IsNullOrWhiteSpace(token)) return null;

            var parts = token.Split('.');
            if (parts.Length != 3) return null;

            var headerEncoded = parts[0];
            var payloadEncoded = parts[1];
            var signatureEncoded = parts[2];

            var stringToSign = $"{headerEncoded}.{payloadEncoded}";
            var expectedSignature = Base64UrlEncode(ComputeHmacSha256(stringToSign, _secret));

            if (!string.Equals(signatureEncoded, expectedSignature, StringComparison.Ordinal))
            {
                return null; // Invalid signature
            }

            try
            {
                var payloadJson = Encoding.UTF8.GetString(Base64UrlDecode(payloadEncoded));
                var payload = JsonConvert.DeserializeObject<Dictionary<string, object>>(payloadJson);

                if (payload == null) return null;

                if (!payload.TryGetValue("exp", out var expObj) ||
                    !payload.TryGetValue("iss", out var issuer) ||
                    !payload.TryGetValue("aud", out var audience) ||
                    !string.Equals(issuer?.ToString(), _issuer, StringComparison.Ordinal) ||
                    !string.Equals(audience?.ToString(), _audience, StringComparison.Ordinal)) return null;
                var epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
                if (DateTime.UtcNow >= epoch.AddSeconds(Convert.ToInt64(expObj))) return null;

                var user = new UserProfileDto
                {
                    Id = payload.TryGetValue(AppConstants.JwtClaims.UserId, out var idObj) ? Convert.ToInt32(idObj) : 0,
                    Email = payload.TryGetValue(AppConstants.JwtClaims.Email, out var emailObj) ? emailObj?.ToString() : null,
                    Role = payload.TryGetValue(AppConstants.JwtClaims.Role, out var roleObj) ? roleObj?.ToString() : null,
                    FirstName = payload.TryGetValue(AppConstants.JwtClaims.FirstName, out var firstObj) ? firstObj?.ToString() : null,
                    LastName = payload.TryGetValue(AppConstants.JwtClaims.LastName, out var lastObj) ? lastObj?.ToString() : null,
                    FullName = payload.TryGetValue(AppConstants.JwtClaims.FullName, out var nameObj) ? nameObj?.ToString() : null
                };

                return user;
            }
            catch
            {
                return null;
            }
        }

        private static byte[] ComputeHmacSha256(string input, string secret)
        {
            using (var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret)))
            {
                return hmac.ComputeHash(Encoding.UTF8.GetBytes(input));
            }
        }

        private static string LoadOrCreateLocalSecret()
        {
            var folder = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, AppConstants.JwtConfiguration.LocalSecretFolder);
            // An explicitly supplied local key takes precedence over the generated fallback.
            var suppliedPath = Path.Combine(folder, AppConstants.JwtConfiguration.UserSecretFileName);
            if (File.Exists(suppliedPath)) return File.ReadAllText(suppliedPath).Trim();
            var path = Path.Combine(folder, AppConstants.JwtConfiguration.GeneratedSecretFileName);
            Directory.CreateDirectory(folder);
            if (File.Exists(path)) return File.ReadAllText(path).Trim();
            var bytes = new byte[48];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(bytes);
            var secret = Convert.ToBase64String(bytes);
            try
            {
                using (var stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                using (var writer = new StreamWriter(stream)) writer.Write(secret);
            }
            catch (IOException) { return File.ReadAllText(path).Trim(); }
            return secret;
        }

        private static string Base64UrlEncode(byte[] input)
        {
            var output = Convert.ToBase64String(input);
            output = output.Split('=')[0];
            output = output.Replace('+', '-');
            output = output.Replace('/', '_');
            return output;
        }

        private static byte[] Base64UrlDecode(string input)
        {
            var output = input.Replace('-', '+').Replace('_', '/');
            switch (output.Length % 4)
            {
                case 0: break;
                case 2: output += "=="; break;
                case 3: output += "="; break;
                default: throw new FormatException("Illegal base64url string!");
            }
            return Convert.FromBase64String(output);
        }
    }
}
