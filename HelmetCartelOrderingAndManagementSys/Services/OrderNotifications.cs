using System;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Hubs;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public static class OrderNotifications
    {
        public static async Task PublishAsync(int orderId, string changeType)
        {
            try
            {
                var order = await new OrderRepository(new DbConnectionFactory()).GetOrderByIdAsync(orderId).ConfigureAwait(false);
                await PublishAsync(order, changeType).ConfigureAwait(false);
            }
            catch (Exception ex) { System.Diagnostics.Trace.TraceWarning("Committed order notification failed: {0}", ex); }
        }

        public static async Task PublishAsync(OrderSummaryDto order, string changeType)
        {
            if (order == null) return;
            try
            {
                await new AdminDataRepository(new DbConnectionFactory()).QueryAsync("dbo.sp_RefreshOrderStockAlerts",
                    AdminDataRepository.Param("@OrderId", order.Id)).ConfigureAwait(false);
                var inventory = new InventoryService(new InventoryRepository(new DbConnectionFactory()));
                foreach (var item in order.Items)
                {
                    var stock = await inventory.GetStockByVariantAsync(item.VariantId).ConfigureAwait(false);
                    if (stock == null) continue;
                    InventoryHub.BroadcastStockUpdate(item.VariantId, stock.SKU, stock.AvailableStock, stock.IsLowStock, changeType);
                    if (stock.IsLowStock)
                        InventoryHub.BroadcastLowStockAlert(stock.InventoryId, stock.SKU, stock.AvailableStock,
                            stock.AvailableStock == 0 ? AppConstants.StockAlertSeverity.Critical : AppConstants.StockAlertSeverity.Low);
                }
                OrderHub.NotifyOrderStatusChanged(order.Id, order.OrderNumber, order.Status, order.UserId);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceWarning("Committed order notification failed: {0}", ex);
            }
        }
    }
}
