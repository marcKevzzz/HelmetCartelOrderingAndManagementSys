using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public class InventoryRepository : IInventoryRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public InventoryRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory ?? throw new ArgumentNullException(nameof(dbFactory));
        }

        public async Task<List<InventoryStatusDto>> GetInventoryListAsync(bool lowStockOnly = false, string search = null)
        {
            var list = new List<InventoryStatusDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetInventoryList", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@LowStockOnly", SqlDbType.Bit) { Value = lowStockOnly });
                    cmd.Parameters.Add(new SqlParameter("@Search", SqlDbType.NVarChar, 200) { Value = string.IsNullOrWhiteSpace(search) ? (object)DBNull.Value : search });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            list.Add(new InventoryStatusDto
                            {
                                InventoryId = reader.GetInt32(reader.GetOrdinal("InventoryId")),
                                VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                                ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                                Brand = reader.GetString(reader.GetOrdinal("Brand")),
                                SKU = reader.GetString(reader.GetOrdinal("SKU")),
                                Size = reader.GetString(reader.GetOrdinal("Size")),
                                Color = reader.GetString(reader.GetOrdinal("Color")),
                                CurrentStock = reader.GetInt32(reader.GetOrdinal("CurrentStock")),
                                ReservedStock = reader.GetInt32(reader.GetOrdinal("ReservedStock")),
                                ReorderPoint = reader.GetInt32(reader.GetOrdinal("ReorderPoint")),
                                IsLowStock = Convert.ToBoolean(reader["IsLowStock"]),
                                LastRestockedAt = reader.IsDBNull(reader.GetOrdinal("LastRestockedAt"))
                                    ? (DateTime?)null
                                    : reader.GetDateTime(reader.GetOrdinal("LastRestockedAt"))
                            });
                        }
                    }
                }
            }

            return list;
        }

        public async Task<InventoryStatusDto> GetInventoryByVariantIdAsync(int variantId)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetInventoryStatusByVariantId", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = variantId });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        if (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            return new InventoryStatusDto
                            {
                                InventoryId = reader.GetInt32(reader.GetOrdinal("InventoryId")),
                                VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                                ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                                Brand = reader.GetString(reader.GetOrdinal("Brand")),
                                SKU = reader.GetString(reader.GetOrdinal("SKU")),
                                Size = reader.GetString(reader.GetOrdinal("Size")),
                                Color = reader.GetString(reader.GetOrdinal("Color")),
                                CurrentStock = reader.GetInt32(reader.GetOrdinal("CurrentStock")),
                                ReservedStock = reader.GetInt32(reader.GetOrdinal("ReservedStock")),
                                ReorderPoint = reader.GetInt32(reader.GetOrdinal("ReorderPoint")),
                                IsLowStock = Convert.ToBoolean(reader["IsLowStock"]),
                                LastRestockedAt = reader.IsDBNull(reader.GetOrdinal("LastRestockedAt"))
                                    ? (DateTime?)null
                                    : reader.GetDateTime(reader.GetOrdinal("LastRestockedAt"))
                            };
                        }
                    }
                }
            }

            return null;
        }

        public async Task<(bool Success, int RemainingStock, string ErrorMessage)> DeductStockAtomicAsync(
            int variantId, int quantity, int? userId, string changeType, string orderNumber)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_DeductStockAtomic", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = variantId });
                    cmd.Parameters.Add(new SqlParameter("@Quantity", SqlDbType.Int) { Value = quantity });
                    cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = (object)userId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@ChangeType", SqlDbType.NVarChar, 50) { Value = changeType });
                    cmd.Parameters.Add(new SqlParameter("@OrderNumber", SqlDbType.NVarChar, 100) { Value = orderNumber });

                    var pRemainingStock = new SqlParameter("@RemainingStock", SqlDbType.Int) { Direction = ParameterDirection.Output };
                    var pSuccess = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
                    var pErrorMessage = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 255) { Direction = ParameterDirection.Output };

                    cmd.Parameters.Add(pRemainingStock);
                    cmd.Parameters.Add(pSuccess);
                    cmd.Parameters.Add(pErrorMessage);

                    await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);

                    var success = (bool)(pSuccess.Value ?? false);
                    var remaining = pRemainingStock.Value != DBNull.Value ? (int)pRemainingStock.Value : 0;
                    var error = pErrorMessage.Value != DBNull.Value ? (string)pErrorMessage.Value : null;

                    return (success, remaining, error);
                }
            }
        }

        public async Task<int> RestockVariantAsync(
            int variantId, int quantity, int userId, string supplierInvoice, string notes)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_RestockInventory", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = variantId });
                    cmd.Parameters.Add(new SqlParameter("@RestockQuantity", SqlDbType.Int) { Value = quantity });
                    cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
                    cmd.Parameters.Add(new SqlParameter("@SupplierInvoice", SqlDbType.NVarChar, 100) { Value = supplierInvoice ?? "" });
                    cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 500) { Value = notes ?? "" });

                    var pNewStock = new SqlParameter("@NewStock", SqlDbType.Int) { Direction = ParameterDirection.Output };
                    cmd.Parameters.Add(pNewStock);

                    await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);

                    return (int)pNewStock.Value;
                }
            }
        }
    }
}
