using System;
using System.Collections.Generic;
using System.Configuration;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public class AuthService : IAuthService
    {
        private readonly IUserRepository _userRepository;
        private readonly IJwtTokenProvider _jwtTokenProvider;

        public AuthService(IUserRepository userRepository, IJwtTokenProvider jwtTokenProvider)
        {
            _userRepository = userRepository ?? throw new ArgumentNullException(nameof(userRepository));
            _jwtTokenProvider = jwtTokenProvider ?? throw new ArgumentNullException(nameof(jwtTokenProvider));

        }

        public async Task<AuthResponseDto> AuthenticateAsync(LoginRequestDto request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
            {
                throw new ArgumentException("Email and password are required.");
            }

            var normalizedEmail = request.Email.Trim().ToLowerInvariant();
            var user = await _userRepository.GetUserByEmailAsync(normalizedEmail).ConfigureAwait(false);

            if (user == null || !user.IsActive)
            {
                return null; // Invalid credentials or inactive account
            }

            if (!VerifyPassword(request.Password, user.PasswordHash, user.Salt))
            {
                return null; // Password mismatch
            }

            var profile = new UserProfileDto
            {
                Id = user.Id,
                Email = user.Email,
                FirstName = user.FirstName,
                LastName = user.LastName,
                FullName = user.FullName,
                PhoneNumber = user.PhoneNumber,
                Role = user.RoleName
            };

            var token = _jwtTokenProvider.GenerateToken(profile, request.RememberMe);

            return new AuthResponseDto
            {
                Token = token,
                ExpiresIn = (request.RememberMe ? AppConstants.JwtConfiguration.RememberMeExpiryMinutes : AppConstants.JwtConfiguration.SessionExpiryMinutes) * 60,
                User = profile
            };
        }

        public async Task<AuthResponseDto> RegisterCustomerAsync(RegisterRequestDto request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (string.IsNullOrWhiteSpace(request.FirstName)) throw new ArgumentException("First name is required.");
            if (string.IsNullOrWhiteSpace(request.LastName)) throw new ArgumentException("Last name is required.");
            if (string.IsNullOrWhiteSpace(request.Email)) throw new ArgumentException("Email is required.");
            if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length < 6)
            {
                throw new ArgumentException("Password must be at least 6 characters.");
            }
            if (string.IsNullOrWhiteSpace(request.PhoneNumber))
            {
                throw new ArgumentException("Mobile phone number is required.");
            }

            var normalizedEmail = request.Email.Trim().ToLowerInvariant();
            var salt = GenerateSalt();
            var passwordHash = HashPassword(request.Password, salt);

            var (success, newUserId, errorMessage) = await _userRepository.RegisterUserAsync(
                request.FirstName.Trim(),
                request.LastName.Trim(),
                normalizedEmail,
                passwordHash,
                salt,
                request.PhoneNumber?.Trim(),
                AppConstants.Roles.Customer
            ).ConfigureAwait(false);

            if (!success)
            {
                throw new InvalidOperationException(errorMessage ?? "Registration failed.");
            }

            var profile = new UserProfileDto
            {
                Id = newUserId,
                Email = normalizedEmail,
                FirstName = request.FirstName.Trim(),
                LastName = request.LastName.Trim(),
                FullName = (request.FirstName.Trim() + " " + request.LastName.Trim()).Trim(),
                PhoneNumber = request.PhoneNumber?.Trim(),
                Role = AppConstants.Roles.Customer
            };

            var token = _jwtTokenProvider.GenerateToken(profile);

            return new AuthResponseDto
            {
                Token = token,
                ExpiresIn = AppConstants.JwtConfiguration.SessionExpiryMinutes * 60,
                User = profile
            };
        }

        public async Task<UserProfileDto> CreateManagedUserAsync(AdminUserDto request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.FirstName) ||
                string.IsNullOrWhiteSpace(request.LastName) || string.IsNullOrWhiteSpace(request.Email) ||
                string.IsNullOrWhiteSpace(request.Password) || request.Password.Length < 6)
                throw new ArgumentException("First name, last name, email, and a six-character password are required.");
            if (request.Role != AppConstants.Roles.Admin && request.Role != AppConstants.Roles.Staff &&
                request.Role != AppConstants.Roles.Customer)
                throw new ArgumentException("Invalid role.");

            var email = request.Email.Trim().ToLowerInvariant();
            var salt = GenerateSalt();
            var passwordHash = HashPassword(request.Password, salt);
            var (success, id, error) = await _userRepository.RegisterUserAsync(
                request.FirstName.Trim(), request.LastName.Trim(), email, passwordHash, salt,
                request.PhoneNumber?.Trim(), request.Role).ConfigureAwait(false);
            if (!success) throw new InvalidOperationException(error ?? "User creation failed.");
            return await _userRepository.GetUserProfileAsync(id).ConfigureAwait(false);
        }

        public async Task<UserProfileDto> GetProfileAsync(int userId)
        {
            return await _userRepository.GetUserProfileAsync(userId).ConfigureAwait(false);
        }

        public async Task<List<UserOrderSummaryDto>> GetUserOrdersAsync(int userId)
        {
            return await _userRepository.GetUserOrdersAsync(userId).ConfigureAwait(false);
        }

        public async Task<UserProfileDto> UpdateProfileAsync(int userId, UpdateProfileRequestDto request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (string.IsNullOrWhiteSpace(request.FirstName)) throw new ArgumentException("First name is required.");
            if (string.IsNullOrWhiteSpace(request.LastName)) throw new ArgumentException("Last name is required.");
            if (string.IsNullOrWhiteSpace(request.PhoneNumber)) throw new ArgumentException("Mobile phone number is required.");

            return await _userRepository.UpdateProfileAsync(
                userId,
                request.FirstName.Trim(),
                request.LastName.Trim(),
                request.PhoneNumber.Trim()
            ).ConfigureAwait(false);
        }

        public async Task<bool> ChangePasswordAsync(int userId, ChangePasswordRequestDto request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (string.IsNullOrWhiteSpace(request.CurrentPassword))
                throw new ArgumentException("Current password is required.");
            if (string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Length < 6)
                throw new ArgumentException("New password must be at least 6 characters.");
            if (!string.Equals(request.NewPassword, request.ConfirmNewPassword, StringComparison.Ordinal))
                throw new ArgumentException("New password and confirmation do not match.");

            var profile = await _userRepository.GetUserProfileAsync(userId).ConfigureAwait(false);
            if (profile == null) throw new InvalidOperationException("User account not found.");

            var userRecord = await _userRepository.GetUserByEmailAsync(profile.Email).ConfigureAwait(false);
            if (userRecord == null) throw new InvalidOperationException("User account record not found.");

            if (!VerifyPassword(request.CurrentPassword, userRecord.PasswordHash, userRecord.Salt))
            {
                throw new ArgumentException("Current password is incorrect.");
            }

            var newSalt = GenerateSalt();
            var newHash = HashPassword(request.NewPassword, newSalt);

            return await _userRepository.ChangePasswordAsync(userId, newHash, newSalt).ConfigureAwait(false);
        }

        public async Task<List<UserPaymentHistoryDto>> GetUserPaymentsAsync(int userId)
        {
            return await _userRepository.GetUserPaymentsAsync(userId).ConfigureAwait(false);
        }

        public async Task<OrderSummaryDto> GetUserOrderDetailsAsync(int userId, int? orderId, string orderNumber)
        {
            return await _userRepository.GetUserOrderDetailsAsync(userId, orderId, orderNumber).ConfigureAwait(false);
        }

        public async Task<List<UserAddressDto>> GetUserAddressesAsync(int userId)
        {
            return await _userRepository.GetUserAddressesAsync(userId).ConfigureAwait(false);
        }

        public async Task<UserAddressDto> SaveUserAddressAsync(int userId, SaveUserAddressRequestDto request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (string.IsNullOrWhiteSpace(request.StreetAddress)) throw new ArgumentException("Street address is required.");
            if (string.IsNullOrWhiteSpace(request.City)) throw new ArgumentException("City / Municipality is required.");
            if (string.IsNullOrWhiteSpace(request.Province)) throw new ArgumentException("Province is required.");

            request.Barangay = request.Barangay?.Trim() ?? string.Empty;
            request.PostalCode = request.PostalCode?.Trim() ?? string.Empty;
            request.AddressLabel = string.IsNullOrWhiteSpace(request.AddressLabel) ? "Home" : request.AddressLabel.Trim();

            return await _userRepository.SaveUserAddressAsync(userId, request).ConfigureAwait(false);
        }

        public async Task<bool> DeleteUserAddressAsync(int userId, int addressId)
        {
            return await _userRepository.DeleteUserAddressAsync(userId, addressId).ConfigureAwait(false);
        }

        private static bool VerifyPassword(string inputPassword, string storedHash, string salt)
        {
            if (string.IsNullOrEmpty(storedHash)) return false;

            // 1. Check salted hash: SHA256(password + salt)
            var computedSalted = HashPassword(inputPassword, salt);
            if (string.Equals(computedSalted, storedHash, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            // 2. Check plain SHA256 (used in database seed data: SHA256('password'))
            var computedPlain = ComputeSha256(inputPassword);
            if (string.Equals(computedPlain, storedHash, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            return false;
        }

        private static string GenerateSalt()
        {
            var bytes = new byte[16];
            using (var rng = new RNGCryptoServiceProvider())
            {
                rng.GetBytes(bytes);
            }
            return BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();
        }

        private static string HashPassword(string password, string salt)
        {
            return ComputeSha256(password + (salt ?? ""));
        }

        private static string ComputeSha256(string raw)
        {
            using (var sha = SHA256.Create())
            {
                var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(raw));
                var sb = new StringBuilder();
                foreach (var b in bytes)
                {
                    sb.Append(b.ToString("x2"));
                }
                return sb.ToString();
            }
        }
    }
}
