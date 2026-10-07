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

                        decimal shippingFee = request.ShippingFee < 0 ? 0.00m : request.ShippingFee;
                        string shippingMethod = string.IsNullOrWhiteSpace(request.ShippingMethod) ? AppConstants.ShippingMethods.Pickup : request.ShippingMethod;
                        decimal total = subtotal + shippingFee;
                        var initialStatus = orderSource == AppConstants.OrderSources.InStorePos
                            ? AppConstants.OrderStatus.Completed
                            : ((request.PaymentMethod == AppConstants.PaymentGateways.Cash || request.PaymentMethod == AppConstants.PaymentGateways.CashOnDelivery)
                                ? AppConstants.OrderStatus.Processing : AppConstants.OrderStatus.PendingPayment);

                        // 2. Insert Order Header via stored procedure dbo.sp_CreateOrder
                        int orderId;
                        using (var orderCmd = new SqlCommand("dbo.sp_CreateOrder", conn, transaction))
                        {
                            orderCmd.CommandType = CommandType.StoredProcedure;

                            string safeName = string.IsNullOrWhiteSpace(request.CustomerName) ? "Customer" : (request.CustomerName.Length > 100 ? request.CustomerName.Substring(0, 100) : request.CustomerName);
                            string safeEmail = string.IsNullOrWhiteSpace(request.CustomerEmail) ? "store@helmetcartel.com" : (request.CustomerEmail.Length > 256 ? request.CustomerEmail.Substring(0, 256) : request.CustomerEmail);
                            string safePhone = string.IsNullOrWhiteSpace(request.CustomerPhone) ? "N/A" : (request.CustomerPhone.Length > 30 ? request.CustomerPhone.Substring(0, 30) : request.CustomerPhone);
                            string safeAddress = string.IsNullOrWhiteSpace(request.ShippingAddress) ? null : (request.ShippingAddress.Length > 300 ? request.ShippingAddress.Substring(0, 300) : request.ShippingAddress);

                            orderCmd.Parameters.Add(new SqlParameter("@OrderNumber", SqlDbType.NVarChar, 50) { Value = orderNumber });
                            orderCmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = (object)userId ?? DBNull.Value });
                            orderCmd.Parameters.Add(new SqlParameter("@CustomerName", SqlDbType.NVarChar, 100) { Value = safeName });
                            orderCmd.Parameters.Add(new SqlParameter("@CustomerEmail", SqlDbType.NVarChar, 256) { Value = safeEmail });
                            orderCmd.Parameters.Add(new SqlParameter("@CustomerPhone", SqlDbType.NVarChar, 30) { Value = safePhone });
                            orderCmd.Parameters.Add(new SqlParameter("@OrderSource", SqlDbType.NVarChar, 30) { Value = orderSource });
                            orderCmd.Parameters.Add(new SqlParameter("@Status", SqlDbType.NVarChar, 50) { Value = initialStatus });
                            orderCmd.Parameters.Add(new SqlParameter("@Subtotal", SqlDbType.Decimal) { Value = subtotal });
                            orderCmd.Parameters.Add(new SqlParameter("@DiscountAmount", SqlDbType.Decimal) { Value = 0.00m });
                            orderCmd.Parameters.Add(new SqlParameter("@TotalAmount", SqlDbType.Decimal) { Value = total });
                            orderCmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 500) { Value = (object)request.Notes ?? DBNull.Value });
                            orderCmd.Parameters.Add(new SqlParameter("@ShippingMethod", SqlDbType.NVarChar, 50) { Value = shippingMethod });
                            orderCmd.Parameters.Add(new SqlParameter("@ShippingFee", SqlDbType.Decimal) { Value = shippingFee });
                            orderCmd.Parameters.Add(new SqlParameter("@ShippingRegion", SqlDbType.NVarChar, 100) { Value = (object)request.ShippingRegion ?? DBNull.Value });
                            orderCmd.Parameters.Add(new SqlParameter("@ShippingAddress", SqlDbType.NVarChar, 300) { Value = (object)safeAddress ?? DBNull.Value });
                            orderCmd.Parameters.Add(new SqlParameter("@ShippingBarangay", SqlDbType.NVarChar, 100) { Value = (object)request.ShippingBarangay ?? DBNull.Value });
                            orderCmd.Parameters.Add(new SqlParameter("@ShippingCity", SqlDbType.NVarChar, 100) { Value = (object)request.ShippingCity ?? DBNull.Value });
                            orderCmd.Parameters.Add(new SqlParameter("@ShippingProvince", SqlDbType.NVarChar, 100) { Value = (object)request.ShippingProvince ?? DBNull.Value });
                            orderCmd.Parameters.Add(new SqlParameter("@ShippingPostalCode", SqlDbType.NVarChar, 20) { Value = (object)request.ShippingPostalCode ?? DBNull.Value });
                            orderCmd.Parameters.Add(new SqlParameter("@DeliveryNotes", SqlDbType.NVarChar, 500) { Value = (object)request.DeliveryNotes ?? DBNull.Value });

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

                            // Reserve stock atomically within the same transaction
                            using (var reserveCmd = new SqlCommand("dbo.sp_ReserveStockAtomic", conn, transaction))
                            {
                                reserveCmd.CommandType = CommandType.StoredProcedure;
                                reserveCmd.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = item.VariantId });
                                reserveCmd.Parameters.Add(new SqlParameter("@Quantity", SqlDbType.Int) { Value = item.Quantity });
                                reserveCmd.Parameters.Add(new SqlParameter("@OrderNumber", SqlDbType.NVarChar, 50) { Value = orderNumber });
                                var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
                                var errorParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 255) { Direction = ParameterDirection.Output };
                                reserveCmd.Parameters.Add(successParam);
                                reserveCmd.Parameters.Add(errorParam);

                                await reserveCmd.ExecuteNonQueryAsync().ConfigureAwait(false);

                                bool success = (bool)successParam.Value;
                                if (!success)
                                {
                                    string err = errorParam.Value as string ?? "Insufficient stock to complete reservation.";
                                    throw new InvalidOperationException(err);
                                }
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

                        decimal voucherDiscount = 0m;
                        string voucherCode = null;
                        if (!string.IsNullOrWhiteSpace(request.VoucherCode))
                        {
                            var quote = await VoucherRepository.ApplyAsync(conn, transaction, orderId, request.VoucherCode).ConfigureAwait(false);
                            voucherCode = quote.Code;
                            if (quote.DiscountType == AppConstants.Vouchers.FreeShipping)
                            {
                                voucherDiscount = 0.00m;
                                shippingFee = 0.00m;
                                total = subtotal;
                            }
                            else
                            {
                                voucherDiscount = quote.DiscountAmount;
                                total = subtotal - voucherDiscount + shippingFee;
                            }
                        }

                        using (var totalsCmd = new SqlCommand("dbo.sp_ValidateOrderTotals", conn, transaction))
                        {
                            totalsCmd.CommandType = CommandType.StoredProcedure;
                            totalsCmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = orderId });
                            await totalsCmd.ExecuteNonQueryAsync().ConfigureAwait(false);
                        }

                        // 4. Record Pending Payment for COD or Cash
                        if (request.PaymentMethod == AppConstants.PaymentGateways.CashOnDelivery ||
                            (request.PaymentMethod == AppConstants.PaymentGateways.Cash && shippingMethod == AppConstants.ShippingMethods.Pickup))
                        {
                            using (var payCmd = new SqlCommand("dbo.sp_RecordPayment", conn, transaction))
                            {
                                payCmd.CommandType = CommandType.StoredProcedure;
                                payCmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = orderId });
                                payCmd.Parameters.Add(new SqlParameter("@PaymentGateway", SqlDbType.NVarChar, 50) { Value = request.PaymentMethod });
                                payCmd.Parameters.Add(new SqlParameter("@GatewayReference", SqlDbType.NVarChar, 100) { Value = (object)DBNull.Value });
                                payCmd.Parameters.Add(new SqlParameter("@Amount", SqlDbType.Decimal) { Value = total });
                                payCmd.Parameters.Add(new SqlParameter("@Status", SqlDbType.NVarChar, 50) { Value = AppConstants.PaymentStatus.Pending });
                                payCmd.Parameters.Add(new SqlParameter("@PaidAt", SqlDbType.DateTime2) { Value = (object)DBNull.Value });
                                var payIdParam = new SqlParameter("@PaymentId", SqlDbType.Int) { Direction = ParameterDirection.Output };
                                payCmd.Parameters.Add(payIdParam);

                                await payCmd.ExecuteNonQueryAsync().ConfigureAwait(false);
                            }
                        }

                        transaction.Commit();

                        return new OrderSummaryDto
                        {
                            Id = orderId,
                            UserId = userId,
                            OrderNumber = orderNumber,
                            CustomerName = request.CustomerName,
                            CustomerEmail = request.CustomerEmail,
                            CustomerPhone = request.CustomerPhone,
                            OrderSource = orderSource,
                            Status = initialStatus,
                            Subtotal = subtotal,
                            DiscountAmount = voucherDiscount,
                            VoucherCode = voucherCode,
                            TotalAmount = total,
                            ShippingMethod = shippingMethod,
                            ShippingFee = shippingFee,
                            ShippingRegion = request.ShippingRegion,
                            ShippingAddress = request.ShippingAddress,
                            ShippingBarangay = request.ShippingBarangay,
                            ShippingCity = request.ShippingCity,
                            ShippingProvince = request.ShippingProvince,
                            ShippingPostalCode = request.ShippingPostalCode,
                            DeliveryNotes = request.DeliveryNotes,
                            PaymentMethod = request.PaymentMethod,
                            PaymentStatus = AppConstants.PaymentStatus.Pending,
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
                    cmd.Parameters.Add(new SqlParameter("@OrderNumber", SqlDbType.NVarChar, 100) { Value = (object)orderNumber ?? DBNull.Value });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        OrderSummaryDto summary = null;

                        // 1. Order Header
                        if (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            summary = new OrderSummaryDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                UserId = reader.IsDBNull(reader.GetOrdinal("UserId")) ? (int?)null : reader.GetInt32(reader.GetOrdinal("UserId")),
                                OrderNumber = reader.GetString(reader.GetOrdinal("OrderNumber")),
                                CustomerName = reader.GetString(reader.GetOrdinal("CustomerName")),
                                CustomerEmail = reader.GetString(reader.GetOrdinal("CustomerEmail")),
                                CustomerPhone = reader.GetString(reader.GetOrdinal("CustomerPhone")),
                                OrderSource = reader.GetString(reader.GetOrdinal("OrderSource")),
                                Status = reader.GetString(reader.GetOrdinal("Status")),
                                Subtotal = reader.GetDecimal(reader.GetOrdinal("Subtotal")),
                                DiscountAmount = reader.GetDecimal(reader.GetOrdinal("DiscountAmount")),
                                TotalAmount = reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
                                ShippingMethod = reader.IsDBNull(reader.GetOrdinal("ShippingMethod")) ? "Pickup" : reader.GetString(reader.GetOrdinal("ShippingMethod")),
                                VoucherCode = reader.IsDBNull(reader.GetOrdinal("VoucherCode")) ? null : reader.GetString(reader.GetOrdinal("VoucherCode")),
                                CashTendered = reader.IsDBNull(reader.GetOrdinal("CashTendered")) ? (decimal?)null : reader.GetDecimal(reader.GetOrdinal("CashTendered")),
                                ShippingFee = reader.IsDBNull(reader.GetOrdinal("ShippingFee")) ? 0.00m : reader.GetDecimal(reader.GetOrdinal("ShippingFee")),
                                ShippingRegion = reader.IsDBNull(reader.GetOrdinal("ShippingRegion")) ? null : reader.GetString(reader.GetOrdinal("ShippingRegion")),
                                ShippingAddress = reader.IsDBNull(reader.GetOrdinal("ShippingAddress")) ? null : reader.GetString(reader.GetOrdinal("ShippingAddress")),
                                ShippingBarangay = reader.IsDBNull(reader.GetOrdinal("ShippingBarangay")) ? null : reader.GetString(reader.GetOrdinal("ShippingBarangay")),
                                ShippingCity = reader.IsDBNull(reader.GetOrdinal("ShippingCity")) ? null : reader.GetString(reader.GetOrdinal("ShippingCity")),
                                ShippingProvince = reader.IsDBNull(reader.GetOrdinal("ShippingProvince")) ? null : reader.GetString(reader.GetOrdinal("ShippingProvince")),
                                ShippingPostalCode = reader.IsDBNull(reader.GetOrdinal("ShippingPostalCode")) ? null : reader.GetString(reader.GetOrdinal("ShippingPostalCode")),
                                Courier = reader.IsDBNull(reader.GetOrdinal("Courier")) ? null : reader.GetString(reader.GetOrdinal("Courier")),
                                TrackingNumber = reader.IsDBNull(reader.GetOrdinal("TrackingNumber")) ? null : reader.GetString(reader.GetOrdinal("TrackingNumber")),
                                DeliveryNotes = reader.IsDBNull(reader.GetOrdinal("DeliveryNotes")) ? null : reader.GetString(reader.GetOrdinal("DeliveryNotes")),
                                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                                RmaCount = reader.GetInt32(reader.GetOrdinal("RmaCount")),
                                LatestRmaType = reader.IsDBNull(reader.GetOrdinal("LatestRmaType")) ? null : reader.GetString(reader.GetOrdinal("LatestRmaType")),
                                LatestRmaStatus = reader.IsDBNull(reader.GetOrdinal("LatestRmaStatus")) ? null : reader.GetString(reader.GetOrdinal("LatestRmaStatus")),
                                LatestRmaResolution = reader.IsDBNull(reader.GetOrdinal("LatestRmaResolution")) ? null : reader.GetString(reader.GetOrdinal("LatestRmaResolution")),
                                Items = new List<OrderItemSummaryDto>()
                            };
                        }

                        // 2. Order Items
                        if (summary != null && await reader.NextResultAsync().ConfigureAwait(false))
                        {
                            while (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                string mainImg = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? null : reader.GetString(reader.GetOrdinal("MainImageUrl"));
                                int rmaIdOrd = GetOrdinalOrDefault(reader, "RmaId");
                                int rmaNumOrd = GetOrdinalOrDefault(reader, "RmaNumber");
                                int rmaTypeOrd = GetOrdinalOrDefault(reader, "RmaType");
                                int rmaStatusOrd = GetOrdinalOrDefault(reader, "RmaStatus", "LatestRmaStatus");
                                int rmaResOrd = GetOrdinalOrDefault(reader, "RmaResolution");
                                int reviewIdOrd = GetOrdinalOrDefault(reader, "ReviewId");

                                summary.Items.Add(new OrderItemSummaryDto
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                                    ProductId = reader.IsDBNull(reader.GetOrdinal("ProductId")) ? (int?)null : reader.GetInt32(reader.GetOrdinal("ProductId")),
                                    ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                                    SKU = reader.GetString(reader.GetOrdinal("SKU")),
                                    Size = reader.GetString(reader.GetOrdinal("Size")),
                                    Color = reader.GetString(reader.GetOrdinal("Color")),
                                    Quantity = reader.GetInt32(reader.GetOrdinal("Quantity")),
                                    UnitPrice = reader.GetDecimal(reader.GetOrdinal("UnitPrice")),
                                    TotalPrice = reader.GetDecimal(reader.GetOrdinal("TotalPrice")),
                                    MainImageUrl = mainImg,
                                    ImageUrl = mainImg,
                                    RmaId = (rmaIdOrd >= 0 && !reader.IsDBNull(rmaIdOrd)) ? reader.GetInt32(rmaIdOrd) : (int?)null,
                                    RmaNumber = (rmaNumOrd >= 0 && !reader.IsDBNull(rmaNumOrd)) ? reader.GetString(rmaNumOrd) : null,
                                    RmaType = (rmaTypeOrd >= 0 && !reader.IsDBNull(rmaTypeOrd)) ? reader.GetString(rmaTypeOrd) : null,
                                    RmaStatus = (rmaStatusOrd >= 0 && !reader.IsDBNull(rmaStatusOrd)) ? reader.GetString(rmaStatusOrd) : null,
                                    RmaResolution = (rmaResOrd >= 0 && !reader.IsDBNull(rmaResOrd)) ? reader.GetString(rmaResOrd) : null,
                                    ReviewId = (reviewIdOrd >= 0 && !reader.IsDBNull(reviewIdOrd)) ? reader.GetInt32(reviewIdOrd) : (int?)null
                                });
                            }
                        }

                        // 3. Payments
                        if (summary != null && await reader.NextResultAsync().ConfigureAwait(false))
                        {
                            if (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                summary.PaymentMethod = reader.IsDBNull(reader.GetOrdinal("PaymentGateway")) ? null : reader.GetString(reader.GetOrdinal("PaymentGateway"));
                                summary.GatewayReference = reader.IsDBNull(reader.GetOrdinal("GatewayReference")) ? null : reader.GetString(reader.GetOrdinal("GatewayReference"));
                                summary.PaymentStatus = reader.IsDBNull(reader.GetOrdinal("Status")) ? null : reader.GetString(reader.GetOrdinal("Status"));
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

                using (var cmd = new SqlCommand("dbo.sp_AdminUpdateOrderStatus", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = orderId });
                    cmd.Parameters.Add(new SqlParameter("@NewStatus", SqlDbType.NVarChar, 50) { Value = newStatus });

                    cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 500) { Value = (object)notes ?? DBNull.Value });
                    await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);
                    return true;
                }
            }
        }

        public async Task<(bool Success, string Message)> CancelOrderAsync(int orderId, int? userId, string userEmail, string reason)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_CustomerCancelOrder", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = orderId });
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = (object)userId ?? DBNull.Value });
                cmd.Parameters.Add(new SqlParameter("@UserEmail", SqlDbType.NVarChar, 256) { Value = (object)userEmail ?? DBNull.Value });
                cmd.Parameters.Add(new SqlParameter("@Reason", SqlDbType.NVarChar, 255) { Value = string.IsNullOrWhiteSpace(reason) ? "Cancelled by customer" : reason.Trim() });
                var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
                var errorParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 255) { Direction = ParameterDirection.Output };
                cmd.Parameters.Add(successParam);
                cmd.Parameters.Add(errorParam);

                await conn.OpenAsync().ConfigureAwait(false);
                await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);

                bool success = (bool)successParam.Value;
                string err = errorParam.Value as string;
                return (success, err);
            }
        }

        private static int GetOrdinalOrDefault(IDataRecord reader, string primaryName, string fallbackName = null)
        {
            for (int i = 0; i < reader.FieldCount; i++)
            {
                if (string.Equals(reader.GetName(i), primaryName, StringComparison.OrdinalIgnoreCase))
                    return i;
            }
            if (!string.IsNullOrEmpty(fallbackName))
            {
                for (int i = 0; i < reader.FieldCount; i++)
                {
                    if (string.Equals(reader.GetName(i), fallbackName, StringComparison.OrdinalIgnoreCase))
                        return i;
                }
            }
            return -1;
        }
    }
}
