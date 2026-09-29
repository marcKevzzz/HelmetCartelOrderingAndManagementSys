using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public class OrderRepository : IOrderRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OrderRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory ?? throw new ArgumentNullException(nameof(dbFactory));
        }

        public async Task<OrderSummaryDto> CreatePhysicalSaleAsync(CreateOrderRequestDto request, string orderNumber,
            string source, string status, string paymentStatus, int? actorUserId)
        {
            var lines = new DataTable();
            lines.Columns.Add("VariantId", typeof(int));
            lines.Columns.Add("Quantity", typeof(int));
            foreach (var item in request.Items)
                lines.Rows.Add(item.VariantId, item.Quantity);
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_CreatePhysicalSale", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@OrderNumber", SqlDbType.NVarChar, 50) { Value = orderNumber });
                cmd.Parameters.Add(new SqlParameter("@ActorUserId", SqlDbType.Int) { Value = (object)actorUserId ?? DBNull.Value });
                cmd.Parameters.Add(new SqlParameter("@CustomerName", SqlDbType.NVarChar, 100) { Value = request.CustomerName ?? "Walk-in Retail Customer" });
                cmd.Parameters.Add(new SqlParameter("@CustomerEmail", SqlDbType.NVarChar, 256) { Value = request.CustomerEmail ?? "store@helmetcartel.com" });
                cmd.Parameters.Add(new SqlParameter("@CustomerPhone", SqlDbType.NVarChar, 30) { Value = request.CustomerPhone ?? "N/A" });
                cmd.Parameters.Add(new SqlParameter("@OrderSource", SqlDbType.NVarChar, 30) { Value = source });
                cmd.Parameters.Add(new SqlParameter("@OrderStatus", SqlDbType.NVarChar, 50) { Value = status });
                cmd.Parameters.Add(new SqlParameter("@PaymentMethod", SqlDbType.NVarChar, 50) { Value = request.PaymentMethod });
                cmd.Parameters.Add(new SqlParameter("@PaymentStatus", SqlDbType.NVarChar, 50) { Value = paymentStatus });
                cmd.Parameters.Add(new SqlParameter("@CashTendered", SqlDbType.Decimal) { Precision = 18, Scale = 2, Value = (object)request.CashTendered ?? DBNull.Value });
                cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 500) { Value = (object)request.Notes ?? DBNull.Value });
                cmd.Parameters.Add(new SqlParameter("@Items", SqlDbType.Structured) { TypeName = "dbo.SaleLineInput", Value = lines });
                await conn.OpenAsync().ConfigureAwait(false);
                var id = Convert.ToInt32(await cmd.ExecuteScalarAsync().ConfigureAwait(false));
                return await GetOrderByIdAsync(id).ConfigureAwait(false);
            }
        }

        public async Task<bool> ConfirmHitPayOrderAsync(string orderNumber, string gatewayReference)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_ConfirmHitPayOrder", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@OrderNumber", SqlDbType.NVarChar, 50) { Value = orderNumber });
                cmd.Parameters.Add(new SqlParameter("@GatewayReference", SqlDbType.NVarChar, 100) { Value = gatewayReference });
                await conn.OpenAsync().ConfigureAwait(false);
                using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    return await reader.ReadAsync().ConfigureAwait(false) && reader.GetBoolean(reader.GetOrdinal("Processed"));
            }
        }

        public async Task<OrderSummaryDto> CreateOrderAsync(CreateOrderRequestDto request, string orderNumber, string orderSource, int? userId = null)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var transaction = conn.BeginTransaction(IsolationLevel.ReadCommitted))
                {
                    try
                    {
                        decimal subtotal = 0;
                        var itemsToInsert = new List<(int VariantId, int Quantity, decimal UnitPrice, decimal TotalPrice, string ProductName, string Sku, string Size, string Color)>();

                        // 1. Verify item prices and variants via stored procedure dbo.sp_GetVariantPriceInfo
                        foreach (var item in request.Items)
                        {
                            using (var priceCmd = new SqlCommand("dbo.sp_GetVariantPriceInfo", conn, transaction))
                            {
                                priceCmd.CommandType = CommandType.StoredProcedure;
                                priceCmd.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = item.VariantId });

                                using (var reader = await priceCmd.ExecuteReaderAsync().ConfigureAwait(false))
                                {
                                    if (await reader.ReadAsync().ConfigureAwait(false))
                                    {
                                        var unitPrice = reader.GetDecimal(reader.GetOrdinal("UnitPrice"));
                                        var itemTotal = unitPrice * item.Quantity;
                                        subtotal += itemTotal;

                                        itemsToInsert.Add((
                                            item.VariantId,
                                            item.Quantity,
                                            unitPrice,
                                            itemTotal,
                                            reader.GetString(reader.GetOrdinal("ProductName")),
                                            reader.GetString(reader.GetOrdinal("SKU")),
                                            reader.GetString(reader.GetOrdinal("Size")),
                                            reader.GetString(reader.GetOrdinal("Color"))
                                        ));
                                    }
                                    else
                                    {
                                        throw new InvalidOperationException($"Product variant ID {item.VariantId} was not found.");
                                    }
                                }
                            }
                        }

                        decimal total = subtotal;
                        var initialStatus = orderSource == AppConstants.OrderSources.InStorePos
                            ? AppConstants.OrderStatus.Completed
                            : (request.PaymentMethod == AppConstants.PaymentGateways.Cash
                                ? AppConstants.OrderStatus.Processing : AppConstants.OrderStatus.PendingPayment);

                        // 2. Insert Order Header via stored procedure dbo.sp_CreateOrder
                        int orderId;
                        using (var orderCmd = new SqlCommand("dbo.sp_CreateOrder", conn, transaction))
                        {
                            orderCmd.CommandType = CommandType.StoredProcedure;

                            orderCmd.Parameters.Add(new SqlParameter("@OrderNumber", SqlDbType.NVarChar, 50) { Value = orderNumber });
                            orderCmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = (object)userId ?? DBNull.Value });
                            orderCmd.Parameters.Add(new SqlParameter("@CustomerName", SqlDbType.NVarChar, 100) { Value = request.CustomerName ?? "Customer" });
                            orderCmd.Parameters.Add(new SqlParameter("@CustomerEmail", SqlDbType.NVarChar, 256) { Value = request.CustomerEmail ?? "store@helmetcartel.com" });
                            orderCmd.Parameters.Add(new SqlParameter("@CustomerPhone", SqlDbType.NVarChar, 30) { Value = request.CustomerPhone ?? "N/A" });
                            orderCmd.Parameters.Add(new SqlParameter("@OrderSource", SqlDbType.NVarChar, 30) { Value = orderSource });
                            orderCmd.Parameters.Add(new SqlParameter("@Status", SqlDbType.NVarChar, 50) { Value = initialStatus });
                            orderCmd.Parameters.Add(new SqlParameter("@Subtotal", SqlDbType.Decimal) { Value = subtotal });
                            orderCmd.Parameters.Add(new SqlParameter("@DiscountAmount", SqlDbType.Decimal) { Value = 0.00m });
                            orderCmd.Parameters.Add(new SqlParameter("@TotalAmount", SqlDbType.Decimal) { Value = total });
                            orderCmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 500) { Value = (object)request.Notes ?? DBNull.Value });

                            var newOrderIdParam = new SqlParameter("@NewOrderId", SqlDbType.Int)
                            {
                                Direction = ParameterDirection.Output
                            };
                            orderCmd.Parameters.Add(newOrderIdParam);

                            await orderCmd.ExecuteNonQueryAsync().ConfigureAwait(false);
                            orderId = Convert.ToInt32(newOrderIdParam.Value);
                        }

                        // 3. Insert Order Items via stored procedure dbo.sp_AddOrderItem
                        var summaryItems = new List<OrderItemSummaryDto>();

                        foreach (var item in itemsToInsert)
                        {
                            using (var itemCmd = new SqlCommand("dbo.sp_AddOrderItem", conn, transaction))
                            {
                                itemCmd.CommandType = CommandType.StoredProcedure;

                                itemCmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = orderId });
                                itemCmd.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = item.VariantId });
                                itemCmd.Parameters.Add(new SqlParameter("@Quantity", SqlDbType.Int) { Value = item.Quantity });
                                itemCmd.Parameters.Add(new SqlParameter("@UnitPrice", SqlDbType.Decimal) { Value = item.UnitPrice });
                                itemCmd.Parameters.Add(new SqlParameter("@TotalPrice", SqlDbType.Decimal) { Value = item.TotalPrice });

                                await itemCmd.ExecuteNonQueryAsync().ConfigureAwait(false);
                            }

                            summaryItems.Add(new OrderItemSummaryDto
                            {
                                VariantId = item.VariantId,
                                ProductName = item.ProductName,
                                SKU = item.Sku,
                                Size = item.Size,
                                Color = item.Color,
                                Quantity = item.Quantity,
                                UnitPrice = item.UnitPrice,
                                TotalPrice = item.TotalPrice
                            });
                        }

                        using (var totalsCmd = new SqlCommand("dbo.sp_ValidateOrderTotals", conn, transaction))
                        {
                            totalsCmd.CommandType = CommandType.StoredProcedure;
                            totalsCmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = orderId });
                            await totalsCmd.ExecuteNonQueryAsync().ConfigureAwait(false);
                        }

                        transaction.Commit();

                        return new OrderSummaryDto
                        {
                            Id = orderId,
                            OrderNumber = orderNumber,
                            CustomerName = request.CustomerName,
                            CustomerEmail = request.CustomerEmail,
                            CustomerPhone = request.CustomerPhone,
                            OrderSource = orderSource,
                            Status = initialStatus,
                            Subtotal = subtotal,
                            TotalAmount = total,
                            CreatedAt = DateTime.UtcNow,
                            Items = summaryItems
                        };
                    }
                    catch
                    {
                        transaction.Rollback();
                        throw;
                    }
                }
            }
        }

        public async Task<OrderSummaryDto> GetOrderByOrderNumberAsync(string orderNumber)
        {
            return await GetOrderDetailsInternalAsync(null, orderNumber).ConfigureAwait(false);
        }

        public async Task<OrderSummaryDto> GetOrderByIdAsync(int orderId)
        {
            return await GetOrderDetailsInternalAsync(orderId, null).ConfigureAwait(false);
        }

        private async Task<OrderSummaryDto> GetOrderDetailsInternalAsync(int? orderId, string orderNumber)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetOrderDetails", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = (object)orderId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@OrderNumber", SqlDbType.NVarChar, 50) { Value = (object)orderNumber ?? DBNull.Value });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        OrderSummaryDto summary = null;

                        // 1. Order Header
                        if (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            summary = new OrderSummaryDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                OrderNumber = reader.GetString(reader.GetOrdinal("OrderNumber")),
                                CustomerName = reader.GetString(reader.GetOrdinal("CustomerName")),
                                CustomerEmail = reader.GetString(reader.GetOrdinal("CustomerEmail")),
                                CustomerPhone = reader.GetString(reader.GetOrdinal("CustomerPhone")),
                                OrderSource = reader.GetString(reader.GetOrdinal("OrderSource")),
                                Status = reader.GetString(reader.GetOrdinal("Status")),
                                Subtotal = reader.GetDecimal(reader.GetOrdinal("Subtotal")),
                                DiscountAmount = reader.GetDecimal(reader.GetOrdinal("DiscountAmount")),
                                TotalAmount = reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
                                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                                Items = new List<OrderItemSummaryDto>()
                            };
                        }

                        // 2. Order Items
                        if (summary != null && await reader.NextResultAsync().ConfigureAwait(false))
                        {
                            while (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                summary.Items.Add(new OrderItemSummaryDto
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                                    ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                                    SKU = reader.GetString(reader.GetOrdinal("SKU")),
                                    Size = reader.GetString(reader.GetOrdinal("Size")),
                                    Color = reader.GetString(reader.GetOrdinal("Color")),
                                    Quantity = reader.GetInt32(reader.GetOrdinal("Quantity")),
                                    UnitPrice = reader.GetDecimal(reader.GetOrdinal("UnitPrice")),
                                    TotalPrice = reader.GetDecimal(reader.GetOrdinal("TotalPrice"))
                                });
                            }
                        }

                        return summary;
                    }
                }
            }
        }

        public async Task<List<OrderSummaryDto>> GetRecentOrdersAsync(int limit = 20, string status = null)
        {
            var list = new List<OrderSummaryDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetRecentOrders", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@Limit", SqlDbType.Int) { Value = limit });
                    cmd.Parameters.Add(new SqlParameter("@Status", SqlDbType.NVarChar, 50) { Value = string.IsNullOrWhiteSpace(status) ? (object)DBNull.Value : status });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            list.Add(new OrderSummaryDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                OrderNumber = reader.GetString(reader.GetOrdinal("OrderNumber")),
                                CustomerName = reader.GetString(reader.GetOrdinal("CustomerName")),
                                CustomerEmail = reader.GetString(reader.GetOrdinal("CustomerEmail")),
                                CustomerPhone = reader.GetString(reader.GetOrdinal("CustomerPhone")),
                                OrderSource = reader.GetString(reader.GetOrdinal("OrderSource")),
                                Status = reader.GetString(reader.GetOrdinal("Status")),
                                Subtotal = reader.GetDecimal(reader.GetOrdinal("Subtotal")),
                                DiscountAmount = reader.GetDecimal(reader.GetOrdinal("DiscountAmount")),
                                TotalAmount = reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
                                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
                            });
                        }
                    }
                }
            }

            return list;
        }

        public async Task<bool> UpdateOrderStatusAsync(int orderId, string newStatus, string notes = null)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_UpdateOrderStatus", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = orderId });
                    cmd.Parameters.Add(new SqlParameter("@NewStatus", SqlDbType.NVarChar, 50) { Value = newStatus });

                    var rows = await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);
                    return rows > 0;
                }
            }
        }
    }
}
