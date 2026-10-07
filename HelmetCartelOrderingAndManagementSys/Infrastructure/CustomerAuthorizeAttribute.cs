using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Infrastructure
{
    public sealed class CustomerAuthorizeAttribute : AuthorizationFilterAttribute
    {
        public override async Task OnAuthorizationAsync(HttpActionContext context, CancellationToken cancellationToken)
        {
            var header = context.Request.Headers.Authorization;
            var cookie = context.Request.Headers.GetCookies(AppConstants.JwtConfiguration.AuthCookieName).FirstOrDefault();
            var token = header != null && string.Equals(header.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase)
                ? header.Parameter : cookie?[AppConstants.JwtConfiguration.AuthCookieName]?.Value;
            var identity = new JwtTokenProvider().ValidateToken(token);
            var user = identity == null ? null : await new UserRepository(new DbConnectionFactory())
                .GetUserByEmailAsync(identity.Email).ConfigureAwait(false);
            if (user == null || !user.IsActive || user.Id != identity.Id)
            {
                context.Response = context.Request.CreateResponse(HttpStatusCode.Unauthorized);
                return;
            }
            context.Request.Properties[StaffAuthorizeAttribute.UserIdKey] = user.Id;
            context.Request.Properties[StaffAuthorizeAttribute.RoleKey] = user.RoleName;
        }
    }
}
