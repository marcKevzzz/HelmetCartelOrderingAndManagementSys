using System;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Repositories;
using Microsoft.AspNet.SignalR;
using Microsoft.AspNet.SignalR.Hubs;

namespace HelmetCartelOrderingAndManagementSys.Infrastructure
{
    [AttributeUsage(AttributeTargets.Class)]
    public sealed class StaffHubAuthorizeAttribute : AuthorizeAttribute
    {
        public override bool AuthorizeHubConnection(HubDescriptor hubDescriptor, IRequest request)
        {
            var token = request.QueryString["token"];
            var identity = new JwtTokenProvider().ValidateToken(token);
            if (identity == null || identity.Id <= 0 || string.IsNullOrWhiteSpace(identity.Email)) return false;

            var user = new UserRepository(new DbConnectionFactory()).GetUserByEmailAsync(identity.Email).GetAwaiter().GetResult();
            return user != null && user.IsActive && user.Id == identity.Id &&
                (user.RoleName == AppConstants.Roles.Admin || user.RoleName == AppConstants.Roles.Staff);
        }
    }
}
