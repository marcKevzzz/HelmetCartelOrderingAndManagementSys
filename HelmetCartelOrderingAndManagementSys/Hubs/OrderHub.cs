using System;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using Microsoft.AspNet.SignalR;

namespace HelmetCartelOrderingAndManagementSys.Hubs
{
    /// <summary>
    /// Real-time SignalR hub for publishing incoming orders and status updates
    /// to staff operations dashboards.
    /// </summary>
    [StaffHubAuthorize]
    public class OrderHub : Hub
    {
        public static void NotifyNewOrder(OrderSummaryDto order)
        {
            GlobalHost.ConnectionManager.GetHubContext<OrderHub>().Clients.All.newOrderReceived(order);
        }

        public static void NotifyOrderStatusChanged(int orderId, string orderNumber, string newStatus, int? userId = null)
        {
            CustomerOrderHub.NotifyStatus(userId, orderId, orderNumber, newStatus);
            GlobalHost.ConnectionManager.GetHubContext<OrderHub>().Clients.All.orderStatusChanged(new
            {
                orderId,
                orderNumber,
                newStatus
            });
        }
    }
}
