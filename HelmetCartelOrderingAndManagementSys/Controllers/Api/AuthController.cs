using System;
using System.Collections.Generic;
using System.Net;
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
            if (authHeader == null || !string.Equals(authHeader.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            var token = authHeader.Parameter;
            return _jwtTokenProvider.ValidateToken(token);
        }
    }
}
