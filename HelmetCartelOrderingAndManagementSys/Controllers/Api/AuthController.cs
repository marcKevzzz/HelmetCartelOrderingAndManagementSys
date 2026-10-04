using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using System.Web.Http;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using HelmetCartelOrderingAndManagementSys.Services;

namespace HelmetCartelOrderingAndManagementSys.Controllers.Api
{
    [RoutePrefix("api/v1/auth")]
    public class AuthController : ApiController
    {
        private readonly IAuthService _authService;
        private readonly IJwtTokenProvider _jwtTokenProvider;

        public AuthController()
        {
            var dbFactory = new DbConnectionFactory();
            var userRepository = new UserRepository(dbFactory);
            _jwtTokenProvider = new JwtTokenProvider();
            _authService = new AuthService(userRepository, _jwtTokenProvider);
        }

        public AuthController(IAuthService authService, IJwtTokenProvider jwtTokenProvider)
        {
            _authService = authService ?? throw new ArgumentNullException(nameof(authService));
            _jwtTokenProvider = jwtTokenProvider ?? throw new ArgumentNullException(nameof(jwtTokenProvider));
        }

        [HttpPost]
        [Route("login")]
        public async Task<IHttpActionResult> Login([FromBody] LoginRequestDto request)
        {
            var httpContext = System.Web.HttpContext.Current;
            if (request == null || string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
            {
                return Ok(ApiResponse<AuthResponseDto>.Fail("Email and password are required.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            try
            {
                var authResult = await _authService.AuthenticateAsync(request).ConfigureAwait(false);
                if (authResult == null)
                {
                    return Ok(ApiResponse<AuthResponseDto>.Fail("Invalid email or password.", AppConstants.ErrorCodes.UnauthorizedAccess));
                }

                SetAuthenticationCookie(authResult, httpContext);
                return Ok(ApiResponse<AuthResponseDto>.Ok(authResult, "Login successful."));
            }
            catch (Exception ex)
            {
                return Ok(ApiResponse<AuthResponseDto>.Fail(ex.Message, "AUTH_ERROR"));
            }
        }

        [HttpPost]
        [Route("register")]
        public async Task<IHttpActionResult> Register([FromBody] RegisterRequestDto request)
        {
            var httpContext = System.Web.HttpContext.Current;
            if (request == null)
            {
                return Ok(ApiResponse<AuthResponseDto>.Fail("Invalid registration data.", "INVALID_INPUT"));
            }

            try
            {
                var authResult = await _authService.RegisterCustomerAsync(request).ConfigureAwait(false);
                SetAuthenticationCookie(authResult, httpContext);
                return Ok(ApiResponse<AuthResponseDto>.Ok(authResult, "Registration successful. Welcome to Helmet Cartel!"));
            }
            catch (ArgumentException aex)
            {
                return Ok(ApiResponse<AuthResponseDto>.Fail(aex.Message, "VALIDATION_FAILED"));
            }
            catch (InvalidOperationException ioex)
            {
                return Ok(ApiResponse<AuthResponseDto>.Fail(ioex.Message, "REGISTRATION_FAILED"));
            }
            catch (Exception ex)
            {
                return Ok(ApiResponse<AuthResponseDto>.Fail(ex.Message, "INTERNAL_ERROR"));
            }
        }

        [HttpPost]
        [Route("logout")]
        public IHttpActionResult Logout()
        {
            var context = System.Web.HttpContext.Current;
            if (context != null)
                context.Response.Cookies.Add(new System.Web.HttpCookie(AppConstants.JwtConfiguration.AuthCookieName, "")
                {
                    HttpOnly = true, Secure = context.Request.IsSecureConnection,
                    SameSite = System.Web.SameSiteMode.Lax, Path = "/", Expires = DateTime.UtcNow.AddDays(-1)
                });
            return Ok();
        }

        [HttpGet]
        [Route("me")]
        public async Task<IHttpActionResult> GetCurrentUser()
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<UserProfileDto>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            var freshProfile = await _authService.GetProfileAsync(user.Id).ConfigureAwait(false);
            if (freshProfile == null)
            {
                return Ok(ApiResponse<UserProfileDto>.Fail("User record not found.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            return Ok(ApiResponse<UserProfileDto>.Ok(freshProfile));
        }

        [HttpGet]
        [Route("my-orders")]
        public async Task<IHttpActionResult> GetUserOrders()
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<List<UserOrderSummaryDto>>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            var orders = await _authService.GetUserOrdersAsync(user.Id).ConfigureAwait(false);
            return Ok(ApiResponse<List<UserOrderSummaryDto>>.Ok(orders));
        }

        [HttpGet]
        [Route("my-orders/{id:int}")]
        public async Task<IHttpActionResult> GetUserOrderDetails(int id)
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<OrderSummaryDto>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            var order = await _authService.GetUserOrderDetailsAsync(user.Id, id, null).ConfigureAwait(false);
            if (order == null)
            {
                return Ok(ApiResponse<OrderSummaryDto>.Fail("Order not found or unauthorized.", AppConstants.ErrorCodes.OrderNotFound));
            }

            return Ok(ApiResponse<OrderSummaryDto>.Ok(order));
        }

        [HttpGet]
        [Route("my-orders/by-number/{orderNumber}")]
        public async Task<IHttpActionResult> GetUserOrderByNumber(string orderNumber)
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<OrderSummaryDto>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            var order = await _authService.GetUserOrderDetailsAsync(user.Id, null, orderNumber).ConfigureAwait(false);
            if (order == null)
            {
                return Ok(ApiResponse<OrderSummaryDto>.Fail("Order not found or unauthorized.", AppConstants.ErrorCodes.OrderNotFound));
            }

            return Ok(ApiResponse<OrderSummaryDto>.Ok(order));
        }

        [HttpGet]
        [Route("my-payments")]
        public async Task<IHttpActionResult> GetUserPayments()
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<List<UserPaymentHistoryDto>>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            var payments = await _authService.GetUserPaymentsAsync(user.Id).ConfigureAwait(false);
            return Ok(ApiResponse<List<UserPaymentHistoryDto>>.Ok(payments));
        }

        [HttpPut]
        [Route("profile")]
        public async Task<IHttpActionResult> UpdateProfile([FromBody] UpdateProfileRequestDto request)
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<UserProfileDto>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            if (request == null)
            {
                return Ok(ApiResponse<UserProfileDto>.Fail("Invalid profile data.", "INVALID_INPUT"));
            }

            try
            {
                var updated = await _authService.UpdateProfileAsync(user.Id, request).ConfigureAwait(false);
                return Ok(ApiResponse<UserProfileDto>.Ok(updated, "Profile updated successfully."));
            }
            catch (ArgumentException aex)
            {
                return Ok(ApiResponse<UserProfileDto>.Fail(aex.Message, "VALIDATION_FAILED"));
            }
            catch (Exception ex)
            {
                return Ok(ApiResponse<UserProfileDto>.Fail(ex.Message, "UPDATE_FAILED"));
            }
        }

        [HttpPut]
        [Route("change-password")]
        public async Task<IHttpActionResult> ChangePassword([FromBody] ChangePasswordRequestDto request)
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<bool>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            if (request == null)
            {
                return Ok(ApiResponse<bool>.Fail("Invalid password change request.", "INVALID_INPUT"));
            }

            try
            {
                var success = await _authService.ChangePasswordAsync(user.Id, request).ConfigureAwait(false);
                return Ok(ApiResponse<bool>.Ok(success, "Password changed successfully."));
            }
            catch (ArgumentException aex)
            {
                return Ok(ApiResponse<bool>.Fail(aex.Message, "VALIDATION_FAILED"));
            }
            catch (Exception ex)
            {
                return Ok(ApiResponse<bool>.Fail(ex.Message, "PASSWORD_CHANGE_FAILED"));
            }
        }

        [HttpGet]
        [Route("addresses")]
        public async Task<IHttpActionResult> GetAddresses()
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<List<UserAddressDto>>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            var addresses = await _authService.GetUserAddressesAsync(user.Id).ConfigureAwait(false);
            return Ok(ApiResponse<List<UserAddressDto>>.Ok(addresses));
        }

        [HttpPost]
        [Route("addresses")]
        public async Task<IHttpActionResult> SaveAddress([FromBody] SaveUserAddressRequestDto request)
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<UserAddressDto>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            if (request == null)
            {
                return Ok(ApiResponse<UserAddressDto>.Fail("Address data is required.", "INVALID_INPUT"));
            }

            try
            {
                var saved = await _authService.SaveUserAddressAsync(user.Id, request).ConfigureAwait(false);
                return Ok(ApiResponse<UserAddressDto>.Ok(saved, "Address saved successfully."));
            }
            catch (ArgumentException aex)
            {
                return Ok(ApiResponse<UserAddressDto>.Fail(aex.Message, "VALIDATION_FAILED"));
            }
            catch (Exception ex)
            {
                return Ok(ApiResponse<UserAddressDto>.Fail(ex.Message, "SAVE_ADDRESS_FAILED"));
            }
        }

        [HttpDelete]
        [Route("addresses/{id:int}")]
        public async Task<IHttpActionResult> DeleteAddress(int id)
        {
            var user = GetAuthenticatedUser();
            if (user == null)
            {
                return Ok(ApiResponse<bool>.Fail("Unauthorized or expired session.", AppConstants.ErrorCodes.UnauthorizedAccess));
            }

            try
            {
                var success = await _authService.DeleteUserAddressAsync(user.Id, id).ConfigureAwait(false);
                return Ok(ApiResponse<bool>.Ok(success, "Address deleted successfully."));
            }
            catch (Exception ex)
            {
                return Ok(ApiResponse<bool>.Fail(ex.Message, "DELETE_ADDRESS_FAILED"));
            }
        }

        private static void SetAuthenticationCookie(AuthResponseDto result, System.Web.HttpContext context)
        {
            if (context == null) return;
            context.Response.Cookies.Add(new System.Web.HttpCookie(AppConstants.JwtConfiguration.AuthCookieName, result.Token)
            {
                HttpOnly = true,
                Secure = context.Request.IsSecureConnection,
                SameSite = System.Web.SameSiteMode.Lax,
                Path = "/",
                Expires = DateTime.UtcNow.AddSeconds(result.ExpiresIn)
            });
        }

        private UserProfileDto GetAuthenticatedUser()
        {
            var authHeader = Request.Headers.Authorization;
            if (authHeader != null && string.Equals(authHeader.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase))
            {
                var token = authHeader.Parameter;
                var user = _jwtTokenProvider.ValidateToken(token);
                if (user != null) return user;
            }

            var cookieToken = System.Web.HttpContext.Current?.Request?.Cookies?[AppConstants.JwtConfiguration.AuthCookieName]?.Value;
            if (string.IsNullOrEmpty(cookieToken))
            {
                var cookieHeader = System.Linq.Enumerable.FirstOrDefault(Request.Headers.GetCookies(AppConstants.JwtConfiguration.AuthCookieName));
                if (cookieHeader != null)
                {
                    cookieToken = cookieHeader[AppConstants.JwtConfiguration.AuthCookieName]?.Value;
                }
            }

            if (!string.IsNullOrEmpty(cookieToken))
            {
                return _jwtTokenProvider.ValidateToken(cookieToken);
            }

            return null;
        }
    }
}
