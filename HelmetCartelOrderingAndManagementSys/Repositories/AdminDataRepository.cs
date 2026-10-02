using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public sealed class AdminDataRepository
    {
        private readonly IDbConnectionFactory _factory;

        public AdminDataRepository(IDbConnectionFactory factory)
        {
            _factory = factory;
        }

        public async Task<List<Dictionary<string, object>>> QueryAsync(string procedure, params SqlParameter[] parameters)
        {
            var rows = new List<Dictionary<string, object>>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand(procedure, connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddRange(parameters);
                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        var row = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
                        for (var i = 0; i < reader.FieldCount; i++)
                        {
                            var name = reader.GetName(i);
                            var prefix = 1;
                            if (name.Length > 1 && char.IsUpper(name[1]))
                            {
                                while (prefix < name.Length && char.IsUpper(name[prefix])) prefix++;
                                if (prefix < name.Length) prefix--;
                            }
                            var key = name.Substring(0, prefix).ToLowerInvariant() + name.Substring(prefix);
                            row[key] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                        }
                        rows.Add(row);
                    }
                }
            }
            return rows;
        }

        public async Task<int> AdjustStockAsync(int variantId, int delta, int? userId, string reference, string notes)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminAdjustStock", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = variantId });
                command.Parameters.Add(new SqlParameter("@QuantityChanged", SqlDbType.Int) { Value = delta });
                command.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = (object)userId ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@ReferenceNumber", SqlDbType.NVarChar, 100) { Value = (object)reference ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 500) { Value = notes });
                var result = new SqlParameter("@NewStock", SqlDbType.Int) { Direction = ParameterDirection.Output };
                command.Parameters.Add(result);
                await connection.OpenAsync().ConfigureAwait(false);
                await command.ExecuteNonQueryAsync().ConfigureAwait(false);
                return (int)result.Value;
            }
        }

        public async Task<List<AdminInventoryItemDto>> GetInventoryProductsAsync(string search = null, string brand = null, string category = null, string stockStatus = "all")
        {
            var list = new List<AdminInventoryItemDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminInventoryProducts", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@Search", SqlDbType.NVarChar, 200) { Value = (object)search ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Brand", SqlDbType.NVarChar, 100) { Value = (object)brand ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Category", SqlDbType.NVarChar, 100) { Value = (object)category ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@StockStatus", SqlDbType.NVarChar, 50) { Value = (object)stockStatus ?? "all" });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminInventoryItemDto
                        {
                            ProductId = reader.GetInt32(reader.GetOrdinal("ProductId")),
                            ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                            Slug = reader.IsDBNull(reader.GetOrdinal("Slug")) ? null : reader.GetString(reader.GetOrdinal("Slug")),
                            BrandId = reader.GetInt32(reader.GetOrdinal("BrandId")),
                            BrandName = reader.GetString(reader.GetOrdinal("BrandName")),
                            CategoryId = reader.GetInt32(reader.GetOrdinal("CategoryId")),
                            CategoryName = reader.GetString(reader.GetOrdinal("CategoryName")),
                            RidingStyle = reader.IsDBNull(reader.GetOrdinal("RidingStyle")) ? null : reader.GetString(reader.GetOrdinal("RidingStyle")),
                            BasePrice = reader.GetDecimal(reader.GetOrdinal("BasePrice")),
                            DiscountPercentage = reader.GetInt32(reader.GetOrdinal("DiscountPercentage")),
                            EffectivePrice = reader.GetDecimal(reader.GetOrdinal("EffectivePrice")),
                            MainImageUrl = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? null : reader.GetString(reader.GetOrdinal("MainImageUrl")),
                            IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive")),
                            TotalStock = reader.GetInt32(reader.GetOrdinal("TotalStock")),
                            ReservedStock = reader.GetInt32(reader.GetOrdinal("ReservedStock")),
                            AvailableStock = reader.GetInt32(reader.GetOrdinal("AvailableStock")),
                            VariantCount = reader.GetInt32(reader.GetOrdinal("VariantCount")),
                            SampleSKU = reader.IsDBNull(reader.GetOrdinal("SampleSKU")) ? "HC-DEFAULT" : reader.GetString(reader.GetOrdinal("SampleSKU")),
                            StockStatus = reader.GetString(reader.GetOrdinal("StockStatus"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<List<AdminInventoryVariantDto>> GetInventoryVariantsAsync(string search = null, string brand = null, string category = null, string stockStatus = "all", int? productId = null, int? variantId = null)
        {
            var list = new List<AdminInventoryVariantDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminInventoryVariants", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@Search", SqlDbType.NVarChar, 200) { Value = (object)search ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Brand", SqlDbType.NVarChar, 100) { Value = (object)brand ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Category", SqlDbType.NVarChar, 100) { Value = (object)category ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@StockStatus", SqlDbType.NVarChar, 50) { Value = (object)stockStatus ?? "all" });
                command.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = (object)productId ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = (object)variantId ?? DBNull.Value });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminInventoryVariantDto
                        {
                            VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                            ProductId = reader.GetInt32(reader.GetOrdinal("ProductId")),
                            BrandName = reader.GetString(reader.GetOrdinal("BrandName")),
                            ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                            CategoryName = reader.GetString(reader.GetOrdinal("CategoryName")),
                            Color = reader.GetString(reader.GetOrdinal("Color")),
                            ColorHex = reader.IsDBNull(reader.GetOrdinal("ColorHex")) ? "#000000" : reader.GetString(reader.GetOrdinal("ColorHex")),
                            Size = reader.GetString(reader.GetOrdinal("Size")),
                            CurrentStock = reader.GetInt32(reader.GetOrdinal("CurrentStock")),
                            ReservedStock = reader.GetInt32(reader.GetOrdinal("ReservedStock")),
                            AvailableStock = reader.GetInt32(reader.GetOrdinal("AvailableStock")),
                            ReorderPoint = reader.GetInt32(reader.GetOrdinal("ReorderPoint")),
                            EffectivePrice = reader.GetDecimal(reader.GetOrdinal("EffectivePrice")),
                            SKU = reader.GetString(reader.GetOrdinal("SKU")),
                            MainImageUrl = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? null : reader.GetString(reader.GetOrdinal("MainImageUrl")),
                            StockStatus = reader.GetString(reader.GetOrdinal("StockStatus"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<List<AdminOrderListItemDto>> GetOrdersAsync(string search = null, string status = null, string source = null, int limit = 100, DateTime? orderDate = null)
        {
            var list = new List<AdminOrderListItemDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminOrders", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@Search", SqlDbType.NVarChar, 100) { Value = (object)search ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Status", SqlDbType.NVarChar, 50) { Value = (object)status ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Source", SqlDbType.NVarChar, 30) { Value = (object)source ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Limit", SqlDbType.Int) { Value = limit });
                command.Parameters.Add(new SqlParameter("@OrderDate", SqlDbType.Date) { Value = orderDate.HasValue ? (object)orderDate.Value.Date : DBNull.Value });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminOrderListItemDto
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            OrderNumber = reader.GetString(reader.GetOrdinal("OrderNumber")),
                            CustomerName = reader.GetString(reader.GetOrdinal("CustomerName")),
                            CustomerEmail = reader.GetString(reader.GetOrdinal("CustomerEmail")),
                            CustomerPhone = reader.GetString(reader.GetOrdinal("CustomerPhone")),
                            OrderSource = reader.GetString(reader.GetOrdinal("OrderSource")),
                            Status = reader.GetString(reader.GetOrdinal("Status")),
                            TotalAmount = reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                            ItemCount = reader.GetInt32(reader.GetOrdinal("ItemCount")),
                            PaymentStatus = reader.IsDBNull(reader.GetOrdinal("PaymentStatus")) ? "Pending" : reader.GetString(reader.GetOrdinal("PaymentStatus")),
                            PaymentMethod = reader.IsDBNull(reader.GetOrdinal("PaymentMethod")) ? null : reader.GetString(reader.GetOrdinal("PaymentMethod")),
                            ShippingMethod = reader.IsDBNull(reader.GetOrdinal("ShippingMethod")) ? "Pickup" : reader.GetString(reader.GetOrdinal("ShippingMethod")),
                            ShippingFee = reader.IsDBNull(reader.GetOrdinal("ShippingFee")) ? 0.00m : reader.GetDecimal(reader.GetOrdinal("ShippingFee")),
                            ShippingRegion = reader.IsDBNull(reader.GetOrdinal("ShippingRegion")) ? null : reader.GetString(reader.GetOrdinal("ShippingRegion")),
                            ShippingAddress = reader.IsDBNull(reader.GetOrdinal("ShippingAddress")) ? null : reader.GetString(reader.GetOrdinal("ShippingAddress")),
                            ShippingBarangay = reader.IsDBNull(reader.GetOrdinal("ShippingBarangay")) ? null : reader.GetString(reader.GetOrdinal("ShippingBarangay")),
                            ShippingCity = reader.IsDBNull(reader.GetOrdinal("ShippingCity")) ? null : reader.GetString(reader.GetOrdinal("ShippingCity")),
                            ShippingProvince = reader.IsDBNull(reader.GetOrdinal("ShippingProvince")) ? null : reader.GetString(reader.GetOrdinal("ShippingProvince")),
                            ShippingPostalCode = reader.IsDBNull(reader.GetOrdinal("ShippingPostalCode")) ? null : reader.GetString(reader.GetOrdinal("ShippingPostalCode")),
                            Courier = reader.IsDBNull(reader.GetOrdinal("Courier")) ? null : reader.GetString(reader.GetOrdinal("Courier")),
                            TrackingNumber = reader.IsDBNull(reader.GetOrdinal("TrackingNumber")) ? null : reader.GetString(reader.GetOrdinal("TrackingNumber")),
                            DeliveryNotes = reader.IsDBNull(reader.GetOrdinal("DeliveryNotes")) ? null : reader.GetString(reader.GetOrdinal("DeliveryNotes"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<bool> UpdateOrderStatusAsync(int orderId, string newStatus, string notes = null, string courier = null, string trackingNumber = null)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminUpdateOrderStatus", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = orderId });
                command.Parameters.Add(new SqlParameter("@NewStatus", SqlDbType.NVarChar, 50) { Value = newStatus });
                command.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 500) { Value = (object)notes ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Courier", SqlDbType.NVarChar, 50) { Value = (object)courier ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@TrackingNumber", SqlDbType.NVarChar, 100) { Value = (object)trackingNumber ?? DBNull.Value });

                await connection.OpenAsync().ConfigureAwait(false);
                await command.ExecuteNonQueryAsync().ConfigureAwait(false);
                return true;
            }
        }

        public async Task<List<AdminCatalogItemDto>> GetCatalogProductsAsync(string search = null)
        {
            var list = new List<AdminCatalogItemDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminCatalogProducts", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@Search", SqlDbType.NVarChar, 200) { Value = (object)search ?? DBNull.Value });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminCatalogItemDto
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            Name = reader.GetString(reader.GetOrdinal("Name")),
                            Slug = reader.GetString(reader.GetOrdinal("Slug")),
                            Description = reader.IsDBNull(reader.GetOrdinal("Description")) ? "" : reader.GetString(reader.GetOrdinal("Description")),
                            CategoryId = reader.GetInt32(reader.GetOrdinal("CategoryId")),
                            Category = reader.GetString(reader.GetOrdinal("Category")),
                            BrandId = reader.GetInt32(reader.GetOrdinal("BrandId")),
                            Brand = reader.GetString(reader.GetOrdinal("Brand")),
                            RidingStyle = reader.IsDBNull(reader.GetOrdinal("RidingStyle")) ? "" : reader.GetString(reader.GetOrdinal("RidingStyle")),
                            BasePrice = reader.GetDecimal(reader.GetOrdinal("BasePrice")),
                            DiscountPercentage = reader.GetInt32(reader.GetOrdinal("DiscountPercentage")),
                            CalculatedEffectivePrice = HasColumn(reader, "EffectivePrice") && !reader.IsDBNull(reader.GetOrdinal("EffectivePrice")) ? reader.GetDecimal(reader.GetOrdinal("EffectivePrice")) : 0m,
                            DiscountType = HasColumn(reader, "DiscountType") && !reader.IsDBNull(reader.GetOrdinal("DiscountType")) ? reader.GetString(reader.GetOrdinal("DiscountType")) : "Percentage",
                            DiscountAmount = HasColumn(reader, "DiscountAmount") && !reader.IsDBNull(reader.GetOrdinal("DiscountAmount")) ? reader.GetDecimal(reader.GetOrdinal("DiscountAmount")) : 0m,
                            DiscountStartDate = HasColumn(reader, "DiscountStartDate") && !reader.IsDBNull(reader.GetOrdinal("DiscountStartDate")) ? (DateTime?)reader.GetDateTime(reader.GetOrdinal("DiscountStartDate")) : null,
                            DiscountEndDate = HasColumn(reader, "DiscountEndDate") && !reader.IsDBNull(reader.GetOrdinal("DiscountEndDate")) ? (DateTime?)reader.GetDateTime(reader.GetOrdinal("DiscountEndDate")) : null,
                            DiscountIsActive = HasColumn(reader, "DiscountIsActive") && !reader.IsDBNull(reader.GetOrdinal("DiscountIsActive")) && reader.GetBoolean(reader.GetOrdinal("DiscountIsActive")),
                            HasActiveDiscount = HasColumn(reader, "HasActiveDiscount") && !reader.IsDBNull(reader.GetOrdinal("HasActiveDiscount")) && reader.GetBoolean(reader.GetOrdinal("HasActiveDiscount")),
                            MainImageUrl = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? null : reader.GetString(reader.GetOrdinal("MainImageUrl")),
                            IsFeatured = reader.GetBoolean(reader.GetOrdinal("IsFeatured")),
                            IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                            VariantCount = reader.GetInt32(reader.GetOrdinal("VariantCount"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<List<AdminUserListItemDto>> GetUsersAsync(int limit = 200)
        {
            var list = new List<AdminUserListItemDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminUsers", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@Limit", SqlDbType.Int) { Value = limit });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminUserListItemDto
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            FirstName = reader.GetString(reader.GetOrdinal("FirstName")),
                            LastName = reader.GetString(reader.GetOrdinal("LastName")),
                            Email = reader.GetString(reader.GetOrdinal("Email")),
                            PhoneNumber = reader.IsDBNull(reader.GetOrdinal("PhoneNumber")) ? "" : reader.GetString(reader.GetOrdinal("PhoneNumber")),
                            Role = reader.GetString(reader.GetOrdinal("Role")),
                            IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<bool> UpdateUserStatusAsync(int userId, bool isActive, int actorUserId)
        {
            // First fetch user to get name, phone, role
            var users = await GetUsersAsync().ConfigureAwait(false);
            var user = users.Find(u => u.Id == userId);
            if (user == null) return false;

            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminUpdateUser", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
                command.Parameters.Add(new SqlParameter("@FirstName", SqlDbType.NVarChar, 100) { Value = user.FirstName });
                command.Parameters.Add(new SqlParameter("@LastName", SqlDbType.NVarChar, 100) { Value = user.LastName });
                command.Parameters.Add(new SqlParameter("@PhoneNumber", SqlDbType.NVarChar, 30) { Value = (object)user.PhoneNumber ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@RoleName", SqlDbType.NVarChar, 50) { Value = user.Role });
                command.Parameters.Add(new SqlParameter("@IsActive", SqlDbType.Bit) { Value = isActive });
                command.Parameters.Add(new SqlParameter("@ActorUserId", SqlDbType.Int) { Value = actorUserId });

                await connection.OpenAsync().ConfigureAwait(false);
                await command.ExecuteNonQueryAsync().ConfigureAwait(false);
                return true;
            }
        }

        public async Task<(bool Success, string Status, string Message)> DeleteProductAsync(int productId)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminDeleteProduct", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    if (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        string status = reader["Status"]?.ToString() ?? "Success";
                        string message = reader["Message"]?.ToString() ?? "Product deleted.";
                        return (true, status, message);
                    }
                }
                return (false, "Error", "Failed to delete product.");
            }
        }

        public async Task<List<AdminBrandReportDto>> GetInventoryReportAsync()
        {
            var list = new List<AdminBrandReportDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminInventoryReport", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminBrandReportDto
                        {
                            Brand = reader.GetString(reader.GetOrdinal("Brand")),
                            VariantCount = reader.GetInt32(reader.GetOrdinal("VariantCount")),
                            OnHandStock = reader.GetInt32(reader.GetOrdinal("OnHandStock")),
                            AvailableStock = reader.GetInt32(reader.GetOrdinal("AvailableStock")),
                            LowStockCount = reader.GetInt32(reader.GetOrdinal("LowStockCount"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<List<AdminDailySaleDto>> GetDailySalesAsync(DateTime startDate, DateTime endDate)
        {
            var list = new List<AdminDailySaleDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminSalesDaily", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@StartDate", SqlDbType.DateTime2) { Value = startDate });
                command.Parameters.Add(new SqlParameter("@EndDate", SqlDbType.DateTime2) { Value = endDate });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminDailySaleDto
                        {
                            SalesDate = reader.GetDateTime(reader.GetOrdinal("SalesDate")),
                            PaymentCount = reader.GetInt32(reader.GetOrdinal("PaymentCount")),
                            Revenue = reader.GetDecimal(reader.GetOrdinal("Revenue"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<List<AdminHourlySaleDto>> GetHourlySalesAsync(DateTime targetDate)
        {
            var list = new List<AdminHourlySaleDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminSalesHourly", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@TargetDate", SqlDbType.Date) { Value = targetDate.Date });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminHourlySaleDto
                        {
                            SaleHour = reader.GetInt32(reader.GetOrdinal("SaleHour")),
                            OrderCount = reader.GetInt32(reader.GetOrdinal("OrderCount")),
                            Revenue = reader.GetDecimal(reader.GetOrdinal("Revenue"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<List<AdminSalesPerformanceItemDto>> GetSalesPerformanceAsync(DateTime startDate, DateTime endDate)
        {
            var list = new List<AdminSalesPerformanceItemDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminSalesPerformance", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@StartDate", SqlDbType.DateTime2) { Value = startDate });
                command.Parameters.Add(new SqlParameter("@EndDate", SqlDbType.DateTime2) { Value = endDate });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminSalesPerformanceItemDto
                        {
                            ProductId = reader.GetInt32(reader.GetOrdinal("ProductId")),
                            ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                            BrandId = reader.GetInt32(reader.GetOrdinal("BrandId")),
                            BrandName = reader.GetString(reader.GetOrdinal("BrandName")),
                            CategoryId = reader.GetInt32(reader.GetOrdinal("CategoryId")),
                            CategoryName = reader.GetString(reader.GetOrdinal("CategoryName")),
                            UnitsSold = reader.GetInt32(reader.GetOrdinal("UnitsSold")),
                            OrderCount = reader.GetInt32(reader.GetOrdinal("OrderCount")),
                            Revenue = reader.GetDecimal(reader.GetOrdinal("Revenue")),
                            AverageSellingPrice = reader.IsDBNull(reader.GetOrdinal("AverageSellingPrice")) ? 0m : reader.GetDecimal(reader.GetOrdinal("AverageSellingPrice"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<AdminSalesBreakdownDto> GetSalesByBrandAndCategoryAsync(DateTime startDate, DateTime endDate)
        {
            var result = new AdminSalesBreakdownDto();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminSalesByBrandAndCategory", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@StartDate", SqlDbType.DateTime2) { Value = startDate });
                command.Parameters.Add(new SqlParameter("@EndDate", SqlDbType.DateTime2) { Value = endDate });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        result.Brands.Add(ReadSalesDimensionReport(reader));
                    }

                    if (await reader.NextResultAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            result.Categories.Add(ReadSalesDimensionReport(reader));
                        }
                    }
                }
            }

            return result;
        }

        private static AdminSalesDimensionReportDto ReadSalesDimensionReport(SqlDataReader reader)
        {
            return new AdminSalesDimensionReportDto
            {
                DimensionName = reader.GetString(reader.GetOrdinal("DimensionName")),
                UnitsSold = reader.GetInt32(reader.GetOrdinal("UnitsSold")),
                OrderCount = reader.GetInt32(reader.GetOrdinal("OrderCount")),
                Revenue = reader.GetDecimal(reader.GetOrdinal("Revenue")),
                AverageUnitPrice = reader.GetDecimal(reader.GetOrdinal("AverageUnitPrice"))
            };
        }

        public async Task<List<AdminBrandInventoryDetailDto>> GetBrandInventoryDetailsAsync()
        {
            var list = new List<AdminBrandInventoryDetailDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminBrandInventoryDetails", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminBrandInventoryDetailDto
                        {
                            Brand = reader.GetString(reader.GetOrdinal("Brand")),
                            ProductId = reader.GetInt32(reader.GetOrdinal("ProductId")),
                            VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                            ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                            CategoryName = reader.GetString(reader.GetOrdinal("CategoryName")),
                            MainImageUrl = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? null : reader.GetString(reader.GetOrdinal("MainImageUrl")),
                            Color = reader.GetString(reader.GetOrdinal("Color")),
                            Size = reader.GetString(reader.GetOrdinal("Size")),
                            SKU = reader.GetString(reader.GetOrdinal("SKU")),
                            OnHandStock = reader.GetInt32(reader.GetOrdinal("OnHandStock")),
                            AvailableStock = reader.GetInt32(reader.GetOrdinal("AvailableStock")),
                            ReorderPoint = reader.GetInt32(reader.GetOrdinal("ReorderPoint")),
                            StockStatus = reader.GetString(reader.GetOrdinal("StockStatus"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<AdminInventoryTrendDto> GetInventoryTrendAsync(DateTime startDate, DateTime endDate)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminInventoryTrend", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@StartDate", SqlDbType.DateTime2) { Value = startDate.Date });
                command.Parameters.Add(new SqlParameter("@EndDate", SqlDbType.DateTime2) { Value = endDate.Date });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    if (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        return new AdminInventoryTrendDto
                        {
                            StartTotalUnits = reader.GetInt32(reader.GetOrdinal("StartTotalUnits")),
                            EndTotalUnits = reader.GetInt32(reader.GetOrdinal("EndTotalUnits")),
                            StartActiveSkus = reader.GetInt32(reader.GetOrdinal("StartActiveSkus")),
                            EndActiveSkus = reader.GetInt32(reader.GetOrdinal("EndActiveSkus"))
                        };
                    }
                }
            }

            return new AdminInventoryTrendDto();
        }

        public async Task<List<Dictionary<string, object>>> GetRecentActivityAsync(int limit = 6)
        {
            return await QueryAsync("dbo.sp_AdminRecentActivity", Param("@Limit", limit)).ConfigureAwait(false);
        }

        public async Task<Dictionary<string, object>> GetDashboardStatsAsync()
        {
            var rows = await QueryAsync("dbo.sp_AdminDashboard", Param("@IncludeRevenue", true)).ConfigureAwait(false);
            return rows.Count > 0 ? rows[0] : new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        }

        public async Task<List<AdminStockAuditLogDto>> GetStockAuditLogsAsync(int? variantId = null, string search = null, int limit = 100)
        {
            var list = new List<AdminStockAuditLogDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminStockAuditLogs", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = (object)variantId ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Search", SqlDbType.NVarChar, 200) { Value = (object)search ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Limit", SqlDbType.Int) { Value = limit });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new AdminStockAuditLogDto
                        {
                            Id = Convert.ToInt64(reader["Id"]),
                            VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                            BrandName = reader.GetString(reader.GetOrdinal("BrandName")),
                            ProductId = reader.GetInt32(reader.GetOrdinal("ProductId")),
                            ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                            Color = reader.GetString(reader.GetOrdinal("Color")),
                            Size = reader.GetString(reader.GetOrdinal("Size")),
                            SKU = reader.GetString(reader.GetOrdinal("SKU")),
                            ChangeType = reader.GetString(reader.GetOrdinal("ChangeType")),
                            PreviousStock = reader.GetInt32(reader.GetOrdinal("PreviousStock")),
                            QuantityChanged = reader.GetInt32(reader.GetOrdinal("QuantityChanged")),
                            NewStock = reader.GetInt32(reader.GetOrdinal("NewStock")),
                            ReferenceNumber = reader.IsDBNull(reader.GetOrdinal("ReferenceNumber")) ? null : reader.GetString(reader.GetOrdinal("ReferenceNumber")),
                            Notes = reader.IsDBNull(reader.GetOrdinal("Notes")) ? null : reader.GetString(reader.GetOrdinal("Notes")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                            PerformedBy = reader.GetString(reader.GetOrdinal("PerformedBy"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<List<AdminGlobalSearchResultDto>> GlobalSearchAsync(string query, int limit = 8)
        {
            var list = new List<AdminGlobalSearchResultDto>();
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminGlobalSearch", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@Query", SqlDbType.NVarChar, 100) { Value = (object)query ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@Limit", SqlDbType.Int) { Value = limit });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        var subtitle = reader.GetString(reader.GetOrdinal("Subtitle"));
                        if (!string.IsNullOrEmpty(subtitle))
                        {
                            subtitle = System.Text.RegularExpressions.Regex.Replace(subtitle, @"(?<=(?:Base:\s*|^|\s))\?(\d)", "\u20B1$1");
                            subtitle = subtitle.Replace("\uFFFD", "•");
                        }

                        list.Add(new AdminGlobalSearchResultDto
                        {
                            Category = reader.GetString(reader.GetOrdinal("Category")),
                            Title = reader.GetString(reader.GetOrdinal("Title")),
                            Subtitle = subtitle,
                            Url = reader.GetString(reader.GetOrdinal("Url")),
                            Badge = reader.GetString(reader.GetOrdinal("Badge"))
                        });
                    }
                }
            }
            return list;
        }

        public async Task<int> CreateProductWithVariantsAsync(
            int categoryId, 
            int brandId, 
            string name, 
            string slug, 
            string description, 
            string ridingStyle, 
            decimal basePrice, 
            int discountPercentage, 
            string mainImageUrl, 
            string variantsJson,
            string discountType = "Percentage",
            decimal discountAmount = 0m,
            DateTime? discountStartDate = null,
            DateTime? discountEndDate = null)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminCreateProductWithVariants", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@CategoryId", SqlDbType.Int) { Value = categoryId });
                command.Parameters.Add(new SqlParameter("@BrandId", SqlDbType.Int) { Value = brandId });
                command.Parameters.Add(new SqlParameter("@Name", SqlDbType.NVarChar, 200) { Value = name });
                command.Parameters.Add(new SqlParameter("@Slug", SqlDbType.NVarChar, 220) { Value = slug });
                command.Parameters.Add(new SqlParameter("@Description", SqlDbType.NVarChar, -1) { Value = (object)description ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@RidingStyle", SqlDbType.NVarChar, 50) { Value = (object)ridingStyle ?? "Sport/Street" });
                command.Parameters.Add(new SqlParameter("@BasePrice", SqlDbType.Decimal) { Value = basePrice });
                command.Parameters.Add(new SqlParameter("@DiscountPercentage", SqlDbType.Int) { Value = discountPercentage });
                command.Parameters.Add(new SqlParameter("@MainImageUrl", SqlDbType.NVarChar, 500) { Value = (object)mainImageUrl ?? "/Content/images/products/helmets/agv/images.jpg" });
                command.Parameters.Add(new SqlParameter("@VariantsJson", SqlDbType.NVarChar, -1) { Value = variantsJson });
                command.Parameters.Add(new SqlParameter("@DiscountType", SqlDbType.NVarChar, 20) { Value = (object)discountType ?? "Percentage" });
                command.Parameters.Add(new SqlParameter("@DiscountAmount", SqlDbType.Decimal) { Value = discountAmount });
                command.Parameters.Add(new SqlParameter("@DiscountStartDate", SqlDbType.DateTime2) { Value = (object)discountStartDate ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@DiscountEndDate", SqlDbType.DateTime2) { Value = (object)discountEndDate ?? DBNull.Value });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    if (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        return reader.GetInt32(reader.GetOrdinal("Id"));
                    }
                }
            }
            return 0;
        }

        public async Task<bool> UpdateProductAsync(
            int productId,
            int categoryId,
            int brandId,
            string name,
            string slug,
            string description,
            string ridingStyle,
            decimal basePrice,
            int discountPercentage,
            string discountType,
            decimal discountAmount,
            DateTime? discountStartDate,
            DateTime? discountEndDate,
            string mainImageUrl,
            bool isFeatured,
            bool isActive)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminSaveProduct", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = productId });
                command.Parameters.Add(new SqlParameter("@CategoryId", SqlDbType.Int) { Value = categoryId });
                command.Parameters.Add(new SqlParameter("@BrandId", SqlDbType.Int) { Value = brandId });
                command.Parameters.Add(new SqlParameter("@Name", SqlDbType.NVarChar, 200) { Value = name });
                command.Parameters.Add(new SqlParameter("@Slug", SqlDbType.NVarChar, 220) { Value = slug });
                command.Parameters.Add(new SqlParameter("@Description", SqlDbType.NVarChar, -1) { Value = (object)description ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@RidingStyle", SqlDbType.NVarChar, 50) { Value = (object)ridingStyle ?? "Sport/Street" });
                command.Parameters.Add(new SqlParameter("@BasePrice", SqlDbType.Decimal) { Value = basePrice });
                command.Parameters.Add(new SqlParameter("@DiscountPercentage", SqlDbType.Int) { Value = discountPercentage });
                command.Parameters.Add(new SqlParameter("@DiscountType", SqlDbType.NVarChar, 20) { Value = (object)discountType ?? "Percentage" });
                command.Parameters.Add(new SqlParameter("@DiscountAmount", SqlDbType.Decimal) { Value = discountAmount });
                command.Parameters.Add(new SqlParameter("@DiscountStartDate", SqlDbType.DateTime2) { Value = (object)discountStartDate ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@DiscountEndDate", SqlDbType.DateTime2) { Value = (object)discountEndDate ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@MainImageUrl", SqlDbType.NVarChar, 500) { Value = (object)mainImageUrl ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@IsFeatured", SqlDbType.Bit) { Value = isFeatured });
                command.Parameters.Add(new SqlParameter("@IsActive", SqlDbType.Bit) { Value = isActive });

                await connection.OpenAsync().ConfigureAwait(false);
                var result = await command.ExecuteScalarAsync().ConfigureAwait(false);
                return result != null && Convert.ToInt32(result) > 0;
            }
        }

        public async Task<int> AddProductGalleryImageAsync(int productId, string imageUrl, string altText, int displayOrder)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminAddProductGalleryImage", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });
                command.Parameters.Add(new SqlParameter("@ImageUrl", SqlDbType.NVarChar, 500) { Value = imageUrl });
                command.Parameters.Add(new SqlParameter("@AltText", SqlDbType.NVarChar, 200) { Value = (object)altText ?? DBNull.Value });
                command.Parameters.Add(new SqlParameter("@DisplayOrder", SqlDbType.Int) { Value = displayOrder });

                await connection.OpenAsync().ConfigureAwait(false);
                var result = await command.ExecuteScalarAsync().ConfigureAwait(false);
                return result != null ? Convert.ToInt32(result) : 0;
            }
        }

        public async Task SaveProductSpecificationsAsync(int productId, string specsJson)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminSaveProductSpecifications", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });
                command.Parameters.Add(new SqlParameter("@SpecsJson", SqlDbType.NVarChar, -1) { Value = (object)specsJson ?? DBNull.Value });

                await connection.OpenAsync().ConfigureAwait(false);
                await command.ExecuteNonQueryAsync().ConfigureAwait(false);
            }
        }

        public async Task<AdminProductCompleteDto> GetProductCompleteAsync(int productId)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_AdminGetProductComplete", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });

                await connection.OpenAsync().ConfigureAwait(false);
                using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    if (!await reader.ReadAsync().ConfigureAwait(false))
                        return null;

                    var product = new AdminProductCompleteDto
                    {
                        Id = Convert.ToInt32(reader["Id"]),
                        CategoryId = Convert.ToInt32(reader["CategoryId"]),
                        BrandId = Convert.ToInt32(reader["BrandId"]),
                        Name = reader["Name"]?.ToString(),
                        Slug = reader["Slug"]?.ToString(),
                        Description = reader["Description"] != DBNull.Value ? reader["Description"].ToString() : null,
                        RidingStyle = reader["RidingStyle"] != DBNull.Value ? reader["RidingStyle"].ToString() : null,
                        BasePrice = Convert.ToDecimal(reader["BasePrice"]),
                        DiscountPercentage = reader["DiscountPercentage"] != DBNull.Value ? Convert.ToInt32(reader["DiscountPercentage"]) : 0,
                        DiscountType = reader["DiscountType"] != DBNull.Value ? reader["DiscountType"].ToString() : "Percentage",
                        DiscountAmount = reader["DiscountAmount"] != DBNull.Value ? Convert.ToDecimal(reader["DiscountAmount"]) : 0m,
                        DiscountStartDate = reader["DiscountStartDate"] != DBNull.Value ? (DateTime?)Convert.ToDateTime(reader["DiscountStartDate"]) : null,
                        DiscountEndDate = reader["DiscountEndDate"] != DBNull.Value ? (DateTime?)Convert.ToDateTime(reader["DiscountEndDate"]) : null,
                        DiscountIsActive = reader["DiscountIsActive"] != DBNull.Value && Convert.ToBoolean(reader["DiscountIsActive"]),
                        MainImageUrl = reader["MainImageUrl"] != DBNull.Value ? reader["MainImageUrl"].ToString() : null,
                        IsFeatured = reader["IsFeatured"] != DBNull.Value && Convert.ToBoolean(reader["IsFeatured"]),
                        IsActive = reader["IsActive"] != DBNull.Value && Convert.ToBoolean(reader["IsActive"]),
                        BrandName = reader["BrandName"]?.ToString(),
                        CategoryName = reader["CategoryName"]?.ToString()
                    };

                    if (await reader.NextResultAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            product.Specifications.Add(new AdminSpecificationItemDto
                            {
                                SpecificationKey = reader["SpecificationKey"]?.ToString(),
                                DisplayName = reader["DisplayName"]?.ToString(),
                                SpecificationValue = reader["SpecificationValue"]?.ToString(),
                                DisplayOrder = reader["DisplayOrder"] != DBNull.Value ? Convert.ToInt32(reader["DisplayOrder"]) : 0
                            });
                        }
                    }

                    if (await reader.NextResultAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            product.Colors.Add(new AdminColorDto
                            {
                                Id = Convert.ToInt32(reader["Id"]),
                                Color = reader["Color"]?.ToString(),
                                SolidHex = reader["ColorHex"]?.ToString(),
                                ColorType = reader["ColorType"]?.ToString(),
                                GradientAngle = reader["GradientAngle"] != DBNull.Value ? (int?)Convert.ToInt32(reader["GradientAngle"]) : null
                            });
                        }
                    }

                    if (await reader.NextResultAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            product.Variants.Add(new AdminVariantDto
                            {
                                Id = Convert.ToInt32(reader["VariantId"]),
                                ProductColorId = Convert.ToInt32(reader["ProductColorId"]),
                                Color = reader["Color"]?.ToString(),
                                ColorHex = reader["ColorHex"]?.ToString(),
                                Size = reader["Size"]?.ToString(),
                                SKU = reader["SKU"]?.ToString(),
                                PriceAdjustment = reader["PriceAdjustment"] != DBNull.Value ? Convert.ToDecimal(reader["PriceAdjustment"]) : 0m,
                                IsActive = reader["IsActive"] != DBNull.Value && Convert.ToBoolean(reader["IsActive"]),
                                CurrentStock = reader["CurrentStock"] != DBNull.Value ? Convert.ToInt32(reader["CurrentStock"]) : 0,
                                ReorderPoint = reader["ReorderPoint"] != DBNull.Value ? Convert.ToInt32(reader["ReorderPoint"]) : 3
                            });
                        }
                    }

                    if (await reader.NextResultAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            product.GalleryImages.Add(new AdminGalleryDto
                            {
                                Id = Convert.ToInt32(reader["Id"]),
                                ImageUrl = reader["ImageUrl"]?.ToString(),
                                AltText = reader["AltText"] != DBNull.Value ? reader["AltText"].ToString() : null,
                                DisplayOrder = reader["DisplayOrder"] != DBNull.Value ? Convert.ToInt32(reader["DisplayOrder"]) : 0
                            });
                        }
                    }

                    return product;
                }
            }
        }

        private static bool HasColumn(System.Data.IDataRecord reader, string columnName)
        {
            for (int i = 0; i < reader.FieldCount; i++)
            {
                if (reader.GetName(i).Equals(columnName, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }

        public static SqlParameter Param(string name, object value)
        {
            return new SqlParameter(name, value ?? DBNull.Value);
        }
    }
}
