using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Repositories;
using Microsoft.AspNet.SignalR;

namespace HelmetCartelOrderingAndManagementSys.Hubs
{
    public class CustomerOrderHub : Hub
    {
        // Public connections may listen to inventory. Only an authenticated owner can join this group.
        public async Task WatchMyOrders()
        {
            var token = Context.Request.Cookies.ContainsKey(AppConstants.JwtConfiguration.AuthCookieName)
                ? Context.Request.Cookies[AppConstants.JwtConfiguration.AuthCookieName].Value : null;
            var identity = new JwtTokenProvider().ValidateToken(token);
            var user = identity == null ? null : await new UserRepository(new DbConnectionFactory())
                .GetUserByEmailAsync(identity.Email).ConfigureAwait(false);
            if (user == null || !user.IsActive || user.Id != identity.Id)
                throw new HubException("Sign in to receive your order updates.");
            await Groups.Add(Context.ConnectionId, Group(user.Id)).ConfigureAwait(false);
        }

        private static string Group(int userId) => "customer-orders-" + userId;

        public static void NotifyStatus(int? userId, int orderId, string orderNumber, string newStatus)
        {
            if (!userId.HasValue) return;
            GlobalHost.ConnectionManager.GetHubContext<CustomerOrderHub>().Clients.Group(Group(userId.Value))
                .orderStatusChanged(new { orderId, orderNumber, newStatus });
        }
    }
}
