using System;
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
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
    public sealed class StaffAuthorizeAttribute : AuthorizationFilterAttribute
    {
        public const string UserIdKey = "HelmetCartelAuthenticatedUserId";
        public const string RoleKey = "HelmetCartelAuthenticatedRole";
        private readonly bool _adminOnly;

        public StaffAuthorizeAttribute(bool adminOnly = false)
        {
            _adminOnly = adminOnly;
        }

        public override async Task OnAuthorizationAsync(HttpActionContext context, CancellationToken cancellationToken)
        {
            if (context.ActionDescriptor.GetCustomAttributes<System.Web.Http.AllowAnonymousAttribute>().Count > 0 ||
                context.ActionDescriptor.ControllerDescriptor.GetCustomAttributes<System.Web.Http.AllowAnonymousAttribute>().Count > 0)
            {
                return;
            }

            var header = context.Request.Headers.Authorization;
            if (header == null || !string.Equals(header.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase))
            {
                context.Response = context.Request.CreateResponse(HttpStatusCode.Unauthorized);
                return;
            }

            var tokenUser = new JwtTokenProvider().ValidateToken(header.Parameter);
            if (tokenUser == null || tokenUser.Id <= 0 || string.IsNullOrWhiteSpace(tokenUser.Email))
            {
                context.Response = context.Request.CreateResponse(HttpStatusCode.Unauthorized);
                return;
            }

            var user = await new UserRepository(new DbConnectionFactory()).GetUserByEmailAsync(tokenUser.Email).ConfigureAwait(false);
            if (user == null || !user.IsActive || user.Id != tokenUser.Id)
            {
                context.Response = context.Request.CreateResponse(HttpStatusCode.Unauthorized);
                return;
            }

            if (!string.Equals(user.RoleName, AppConstants.Roles.Admin, StringComparison.Ordinal) &&
                (!string.Equals(user.RoleName, AppConstants.Roles.Staff, StringComparison.Ordinal) || _adminOnly))
            {
                context.Response = context.Request.CreateResponse(HttpStatusCode.Forbidden);
                return;
            }

            context.Request.Properties[UserIdKey] = user.Id;
            context.Request.Properties[RoleKey] = user.RoleName;
        }

        public static int UserId(HttpActionContext context)
        {
            return (int)context.Request.Properties[UserIdKey];
        }
    }
}
