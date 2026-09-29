using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using Microsoft.AspNet.SignalR;

namespace HelmetCartelOrderingAndManagementSys.Hubs
{
    /// <summary>
    /// Real-time SignalR hub for broadcasting live inventory updates,
    /// stock level changes, and low-stock alerts to connected storefronts and staff dashboards.
    /// </summary>
    public class InventoryHub : Hub
    {
        public static void BroadcastStockUpdate(int variantId, string sku, int newStock, bool isLowStock, string changeSource)
        {
            var payload = new StockUpdateBroadcastDto
            {
                VariantId = variantId,
                SKU = sku,
                NewStock = newStock,
                IsLowStock = isLowStock,
                ChangeSource = changeSource
            };

            GlobalHost.ConnectionManager.GetHubContext<InventoryHub>().Clients.All.stockUpdated(payload);
        }

        public static void BroadcastLowStockAlert(int inventoryId, string sku, int currentStock, string severity)
        {
            GlobalHost.ConnectionManager.GetHubContext<InventoryHub>().Clients.All.lowStockAlert(new
            {
                inventoryId,
                sku,
                currentStock,
                severity
            });
        }
    }
}
