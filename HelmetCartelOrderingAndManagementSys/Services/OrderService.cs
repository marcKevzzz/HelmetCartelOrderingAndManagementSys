using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Hubs;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Services
{
    public class OrderService : IOrderService
    {
        private readonly IOrderRepository _orderRepository;
        private readonly IInventoryService _inventoryService;
        private readonly IHitPayService _hitPayService;

        public OrderService(
            IOrderRepository orderRepository,
            IInventoryService inventoryService,
            IHitPayService hitPayService)
        {
            _orderRepository = orderRepository ?? throw new ArgumentNullException(nameof(orderRepository));
            _inventoryService = inventoryService ?? throw new ArgumentNullException(nameof(inventoryService));
            _hitPayService = hitPayService ?? throw new ArgumentNullException(nameof(hitPayService));
        }

        public async Task<ApiResponse<OrderSummaryDto>> CreateOnlineOrderAsync(CreateOrderRequestDto request, int? userId = null)
        {
            if (request == null || request.Items == null || request.Items.Count == 0)
                return ApiResponse<OrderSummaryDto>.Fail("Order must contain at least one item.", AppConstants.ErrorCodes.OrderNotFound);

            try { VoucherService.NormalizeCode(request.VoucherCode, true); }
            catch (ArgumentException e) { return ApiResponse<OrderSummaryDto>.Fail(e.Message, AppConstants.ErrorCodes.InvalidVoucher); }

            // 1. Check stock availability before initiating order
            foreach (var item in request.Items)
            {
                var stock = await _inventoryService.GetStockByVariantAsync(item.VariantId).ConfigureAwait(false);
                if (item.Quantity <= 0)
                    return ApiResponse<OrderSummaryDto>.Fail("Quantity must be greater than zero.", AppConstants.ErrorCodes.InsufficientStock);

                if (stock == null || stock.CurrentStock - stock.ReservedStock < item.Quantity)
                {
                    return ApiResponse<OrderSummaryDto>.Fail(
                        $"Insufficient stock for {stock?.ProductName ?? "selected item"} ({stock?.Size}/{stock?.Color}). Available: {(stock == null ? 0 : stock.CurrentStock - stock.ReservedStock)}",
                        AppConstants.ErrorCodes.InsufficientStock);
                }
            }

            bool isCashOnPickup = string.Equals(request.PaymentMethod, AppConstants.PaymentGateways.Cash, StringComparison.OrdinalIgnoreCase);
            bool isCod = string.Equals(request.PaymentMethod, AppConstants.PaymentGateways.CashOnDelivery, StringComparison.OrdinalIgnoreCase);
            var orderNumber = GenerateOrderNumber();

            try
            {
                if (request.Items.Any(x => x.Quantity <= 0) || request.Items.Select(x => x.VariantId).Distinct().Count() != request.Items.Count)
                    return ApiResponse<OrderSummaryDto>.Fail("Invalid or duplicate items.", AppConstants.ErrorCodes.VariantNotFound);

                if (isCashOnPickup || isCod)
                {
                    var orderResult = await _orderRepository.CreateOrderAsync(request, orderNumber, AppConstants.OrderSources.Online, userId).ConfigureAwait(false);

                    // CreateOrderAsync reserves the requested quantity atomically. Cash pickup and
                    // COD are not completed sales yet, so do not deduct CurrentStock here. The
                    // reservation is converted to a sale when the order is fulfilled and payment
                    // is recorded by the order-status stored procedure.
                    await NotifySafelyAsync(() => BroadcastCommittedStockAsync(request.Items, AppConstants.StockAuditChangeType.OnlineSale)).ConfigureAwait(false);
                    NotifySafely(() => OrderHub.NotifyNewOrder(orderResult));

                    string msg = isCod
                        ? "Order placed successfully with Cash on Delivery. Preparing for dispatch."
                        : "Order placed for store pickup.";
                    return ApiResponse<OrderSummaryDto>.Ok(orderResult, msg);
                }

                var order = await _orderRepository.CreateOrderAsync(request, orderNumber, AppConstants.OrderSources.Online, userId).ConfigureAwait(false);

                // Check if HitPay simulation mode is enabled
                var isSimulation = string.Equals(System.Configuration.ConfigurationManager.AppSettings["HitPay:SimulationMode"], "true", StringComparison.OrdinalIgnoreCase);

                if (isSimulation)
                {
                    // Interactive simulation mode: Return order as PendingPayment so the customer can interact with the simulation modal
                    order.PaymentStatus = AppConstants.PaymentStatus.Pending;
                    order.Status = AppConstants.OrderStatus.PendingPayment;
                    order.CheckoutUrl = null;
                    NotifySafely(() => OrderHub.NotifyNewOrder(order));
                    return ApiResponse<OrderSummaryDto>.Ok(order, "Order created in Simulation Mode. Ready for simulated payment.");
                }

                // 2. Generate HitPay payment checkout link for online e-wallet / card payments
                try
                {
                    var hitpayResponse = await _hitPayService.CreatePaymentRequestAsync(order).ConfigureAwait(false);
                    order.CheckoutUrl = hitpayResponse?.Url;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[HitPay] Warning: Checkout URL generation error: {ex.Message}");
                }

                // 3. Notify staff dashboard of incoming pending order
                NotifySafely(() => OrderHub.NotifyNewOrder(order));

                return ApiResponse<OrderSummaryDto>.Ok(order, "Order created successfully. Proceed to payment.");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError($"[CreateOnlineOrderAsync] Error: {ex}");
                return ApiResponse<OrderSummaryDto>.Fail(ex.Message, ex is SqlException sql && sql.Number >= AppConstants.Vouchers.FirstSqlError && sql.Number <= AppConstants.Vouchers.LastSqlError
                    ? AppConstants.ErrorCodes.InvalidVoucher : AppConstants.ErrorCodes.InsufficientStock);
            }
        }

        public async Task<ApiResponse<OrderSummaryDto>> CreateInStorePosOrderAsync(CreateOrderRequestDto request, int staffUserId)
        {
            if (request == null || request.Items == null || request.Items.Count == 0)
                return ApiResponse<OrderSummaryDto>.Fail("POS Order must contain at least one item.", AppConstants.ErrorCodes.OrderNotFound);
            if (!string.IsNullOrWhiteSpace(request.VoucherCode)) return ApiResponse<OrderSummaryDto>.Fail("Vouchers apply to online checkout only.", AppConstants.ErrorCodes.InvalidVoucher);
            if (request.PaymentMethod != AppConstants.PaymentGateways.Cash && request.PaymentMethod != AppConstants.PaymentGateways.CardPos)
                return ApiResponse<OrderSummaryDto>.Fail("Choose cash or card POS payment.");
            if (request.PaymentMethod == AppConstants.PaymentGateways.Cash &&
                (!request.CashTendered.HasValue || request.CashTendered.Value < 0))
                return ApiResponse<OrderSummaryDto>.Fail("Enter the cash amount received.");
            if (request.PaymentMethod == AppConstants.PaymentGateways.CardPos && !request.CardTerminalApproved)
                return ApiResponse<OrderSummaryDto>.Fail("Confirm the card terminal payment before completing the sale.");
            if (request.Items.Any(x => x.Quantity <= 0) || request.Items.Select(x => x.VariantId).Distinct().Count() != request.Items.Count)
                return ApiResponse<OrderSummaryDto>.Fail("Invalid or duplicate items.", AppConstants.ErrorCodes.VariantNotFound);
            try
            {
                var order = await _orderRepository.CreatePhysicalSaleAsync(request, GenerateOrderNumber(),
                    AppConstants.OrderSources.InStorePos, AppConstants.OrderStatus.Completed,
                    AppConstants.PaymentStatus.Completed, staffUserId).ConfigureAwait(false);
                await NotifySafelyAsync(() => BroadcastCommittedStockAsync(request.Items, AppConstants.StockAuditChangeType.InStoreSale)).ConfigureAwait(false);
                NotifySafely(() => OrderHub.NotifyNewOrder(order));
                return ApiResponse<OrderSummaryDto>.Ok(order, "In-store sale completed and stock reconciled.");
            }
            catch (Exception e) { return ApiResponse<OrderSummaryDto>.Fail(e.Message, AppConstants.ErrorCodes.InsufficientStock); }
        }

        private async Task BroadcastCommittedStockAsync(IEnumerable<OrderItemRequestDto> items, string source)
        {
            foreach (var item in items)
            {
                var stock = await _inventoryService.GetStockByVariantAsync(item.VariantId).ConfigureAwait(false);
                if (stock != null)
                {
                    InventoryHub.BroadcastStockUpdate(item.VariantId, stock.SKU, stock.AvailableStock, stock.IsLowStock, source);
                    if (stock.IsLowStock)
                        InventoryHub.BroadcastLowStockAlert(stock.InventoryId, stock.SKU, stock.AvailableStock, "Low");
                }
            }
        }

        private static async Task NotifySafelyAsync(Func<Task> notify)
        {
            try { await notify().ConfigureAwait(false); }
            catch (Exception ex) { System.Diagnostics.Trace.TraceWarning($"Committed transaction notification failed: {ex}"); }
        }

        private static void NotifySafely(Action notify)
        {
            try { notify(); }
            catch (Exception ex) { System.Diagnostics.Trace.TraceWarning($"Committed transaction notification failed: {ex}"); }
        }

        public async Task<ApiResponse<bool>> UpdateOrderStatusAsync(int orderId, string newStatus, string notes = null)
        {
            var success = await _orderRepository.UpdateOrderStatusAsync(orderId, newStatus, notes).ConfigureAwait(false);
            if (success)
            {
                await NotifySafelyAsync(async () => {
                    var order = await _orderRepository.GetOrderByIdAsync(orderId).ConfigureAwait(false);
                    if (order != null) OrderHub.NotifyOrderStatusChanged(orderId, order.OrderNumber, newStatus);
                }).ConfigureAwait(false);
                return ApiResponse<bool>.Ok(true, "Order status updated.");
            }
            return ApiResponse<bool>.Fail("Order not found or update failed.", AppConstants.ErrorCodes.OrderNotFound);
        }

        public async Task<OrderSummaryDto> GetOrderByIdAsync(int orderId)
        {
            return await _orderRepository.GetOrderByIdAsync(orderId).ConfigureAwait(false);
        }

        public async Task<OrderSummaryDto> GetOrderByOrderNumberAsync(string orderNumber)
        {
            return await _orderRepository.GetOrderByOrderNumberAsync(orderNumber).ConfigureAwait(false);
        }

        public async Task<List<OrderSummaryDto>> GetRecentOrdersAsync(int limit = 20, string status = null)
        {
            return await _orderRepository.GetRecentOrdersAsync(limit, status).ConfigureAwait(false);
        }

        public async Task<bool> ConfirmOnlinePaymentAsync(string orderNumber, string paymentGatewayRef)
        {
            var order = await _orderRepository.GetOrderByOrderNumberAsync(orderNumber).ConfigureAwait(false);
            if (order == null) return false;
            var processed = await _orderRepository.ConfirmHitPayOrderAsync(orderNumber, paymentGatewayRef).ConfigureAwait(false);
            if (!processed) return false;
            await NotifySafelyAsync(() => BroadcastCommittedStockAsync(order.Items.Select(x => new OrderItemRequestDto { VariantId = x.VariantId, Quantity = x.Quantity }),
                AppConstants.StockAuditChangeType.OnlineSale)).ConfigureAwait(false);
            NotifySafely(() => OrderHub.NotifyOrderStatusChanged(order.Id, orderNumber, AppConstants.OrderStatus.Processing));

            return true;
        }

        private static string GenerateOrderNumber()
        {
            return $"HC-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString("N").Substring(0, 10).ToUpperInvariant()}";
        }
    }
}
