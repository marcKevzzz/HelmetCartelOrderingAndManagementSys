using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public class ReturnRepository : IReturnRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public ReturnRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory ?? throw new ArgumentNullException(nameof(dbFactory));
        }

        public async Task<ReturnOperationResultDto> CreateReturnRequestAsync(CreateReturnRequestDto dto)
        {
            if (dto == null) throw new ArgumentNullException(nameof(dto));

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_CreateReturnRequest", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = dto.OrderId });
                    cmd.Parameters.Add(new SqlParameter("@OrderItemId", SqlDbType.Int) { Value = dto.OrderItemId });
                    cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = (object)dto.UserId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@RequestType", SqlDbType.NVarChar, 20) { Value = dto.RequestType ?? "RETURN" });
                    cmd.Parameters.Add(new SqlParameter("@Reason", SqlDbType.NVarChar, 50) { Value = dto.Reason ?? "DEFECTIVE" });
                    cmd.Parameters.Add(new SqlParameter("@ExchangeVariantId", SqlDbType.Int) { Value = (object)dto.ExchangeVariantId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@CustomerNotes", SqlDbType.NVarChar, 1000) { Value = string.IsNullOrWhiteSpace(dto.CustomerNotes) ? (object)DBNull.Value : dto.CustomerNotes.Trim() });

                    var rmaIdParam = new SqlParameter("@NewRmaId", SqlDbType.Int) { Direction = ParameterDirection.Output };
                    var rmaNumberParam = new SqlParameter("@NewRmaNumber", SqlDbType.NVarChar, 30) { Direction = ParameterDirection.Output };
                    var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
                    var errorParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 255) { Direction = ParameterDirection.Output };

                    cmd.Parameters.Add(rmaIdParam);
                    cmd.Parameters.Add(rmaNumberParam);
                    cmd.Parameters.Add(successParam);
                    cmd.Parameters.Add(errorParam);

                    await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);

                    bool success = successParam.Value != DBNull.Value && (bool)successParam.Value;
                    string error = errorParam.Value != DBNull.Value ? errorParam.Value.ToString() : null;
                    int? rmaId = rmaIdParam.Value != DBNull.Value ? (int?)rmaIdParam.Value : null;
                    string rmaNumber = rmaNumberParam.Value != DBNull.Value ? rmaNumberParam.Value.ToString() : null;

                    return new ReturnOperationResultDto
                    {
                        Success = success,
                        ErrorMessage = error,
                        RmaId = rmaId,
                        RmaNumber = rmaNumber
                    };
                }
            }
        }

        public async Task<List<ReturnRequestDto>> GetCustomerReturnRequestsAsync(int? orderId = null, int? userId = null)
        {
            var list = new List<ReturnRequestDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetCustomerReturnRequests", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = (object)orderId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = (object)userId ?? DBNull.Value });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            list.Add(new ReturnRequestDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                RmaNumber = reader.GetString(reader.GetOrdinal("RmaNumber")),
                                OrderId = reader.GetInt32(reader.GetOrdinal("OrderId")),
                                OrderNumber = reader.GetString(reader.GetOrdinal("OrderNumber")),
                                OrderItemId = reader.GetInt32(reader.GetOrdinal("OrderItemId")),
                                VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                                ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                                ColorName = reader.GetString(reader.GetOrdinal("ColorName")),
                                Size = reader.GetString(reader.GetOrdinal("Size")),
                                Quantity = reader.GetInt32(reader.GetOrdinal("Quantity")),
                                UnitPrice = reader.GetDecimal(reader.GetOrdinal("UnitPrice")),
                                MainImageUrl = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? null : reader.GetString(reader.GetOrdinal("MainImageUrl")),
                                UserId = reader.IsDBNull(reader.GetOrdinal("UserId")) ? (int?)null : reader.GetInt32(reader.GetOrdinal("UserId")),
                                RequestType = reader.GetString(reader.GetOrdinal("RequestType")),
                                Reason = reader.GetString(reader.GetOrdinal("Reason")),
                                ExchangeVariantId = reader.IsDBNull(reader.GetOrdinal("ExchangeVariantId")) ? (int?)null : reader.GetInt32(reader.GetOrdinal("ExchangeVariantId")),
                                CustomerNotes = reader.IsDBNull(reader.GetOrdinal("CustomerNotes")) ? null : reader.GetString(reader.GetOrdinal("CustomerNotes")),
                                Status = reader.GetString(reader.GetOrdinal("Status")),
                                ResolutionType = reader.IsDBNull(reader.GetOrdinal("ResolutionType")) ? null : reader.GetString(reader.GetOrdinal("ResolutionType")),
                                RefundAmount = reader.IsDBNull(reader.GetOrdinal("RefundAmount")) ? (decimal?)null : reader.GetDecimal(reader.GetOrdinal("RefundAmount")),
                                Restocked = reader.GetBoolean(reader.GetOrdinal("Restocked")),
                                AdminNotes = reader.IsDBNull(reader.GetOrdinal("AdminNotes")) ? null : reader.GetString(reader.GetOrdinal("AdminNotes")),
                                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                                UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt"))
                            });
                        }
                    }
                }
            }

            return list;
        }

        public async Task<List<AdminReturnRequestDto>> AdminGetReturnRequestsAsync(string status = "ALL", string search = null)
        {
            var list = new List<AdminReturnRequestDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_AdminGetReturnRequests", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@Status", SqlDbType.NVarChar, 30) { Value = string.IsNullOrWhiteSpace(status) ? "ALL" : status.Trim() });
                    cmd.Parameters.Add(new SqlParameter("@Search", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(search) ? (object)DBNull.Value : search.Trim() });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            list.Add(new AdminReturnRequestDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                RmaNumber = reader.GetString(reader.GetOrdinal("RmaNumber")),
                                OrderId = reader.GetInt32(reader.GetOrdinal("OrderId")),
                                OrderNumber = reader.GetString(reader.GetOrdinal("OrderNumber")),
                                CustomerEmail = reader.GetString(reader.GetOrdinal("CustomerEmail")),
                                CustomerPhone = reader.IsDBNull(reader.GetOrdinal("CustomerPhone")) ? null : reader.GetString(reader.GetOrdinal("CustomerPhone")),
                                CustomerName = reader.GetString(reader.GetOrdinal("CustomerName")),
                                OrderItemId = reader.GetInt32(reader.GetOrdinal("OrderItemId")),
                                VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                                ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                                ColorName = reader.GetString(reader.GetOrdinal("ColorName")),
                                Size = reader.GetString(reader.GetOrdinal("Size")),
                                Quantity = reader.GetInt32(reader.GetOrdinal("Quantity")),
                                UnitPrice = reader.GetDecimal(reader.GetOrdinal("UnitPrice")),
                                RequestType = reader.GetString(reader.GetOrdinal("RequestType")),
                                Reason = reader.GetString(reader.GetOrdinal("Reason")),
                                ExchangeVariantId = reader.IsDBNull(reader.GetOrdinal("ExchangeVariantId")) ? (int?)null : reader.GetInt32(reader.GetOrdinal("ExchangeVariantId")),
                                CustomerNotes = reader.IsDBNull(reader.GetOrdinal("CustomerNotes")) ? null : reader.GetString(reader.GetOrdinal("CustomerNotes")),
                                Status = reader.GetString(reader.GetOrdinal("Status")),
                                ResolutionType = reader.IsDBNull(reader.GetOrdinal("ResolutionType")) ? null : reader.GetString(reader.GetOrdinal("ResolutionType")),
                                RefundAmount = reader.IsDBNull(reader.GetOrdinal("RefundAmount")) ? (decimal?)null : reader.GetDecimal(reader.GetOrdinal("RefundAmount")),
                                Restocked = reader.GetBoolean(reader.GetOrdinal("Restocked")),
                                AdminNotes = reader.IsDBNull(reader.GetOrdinal("AdminNotes")) ? null : reader.GetString(reader.GetOrdinal("AdminNotes")),
                                ProcessedBy = reader.IsDBNull(reader.GetOrdinal("ProcessedBy")) ? (int?)null : reader.GetInt32(reader.GetOrdinal("ProcessedBy")),
                                ProcessedByName = reader.IsDBNull(reader.GetOrdinal("ProcessedByName")) ? null : reader.GetString(reader.GetOrdinal("ProcessedByName")),
                                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                                UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt"))
                            });
                        }
                    }
                }
            }

            return list;
        }

        public async Task<ReturnOperationResultDto> AdminProcessReturnRequestAsync(int rmaId, ProcessReturnRequestDto dto, int? processedBy = null)
        {
            if (dto == null) throw new ArgumentNullException(nameof(dto));

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_AdminProcessReturnRequest", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.Add(new SqlParameter("@RmaId", SqlDbType.Int) { Value = rmaId });
                    cmd.Parameters.Add(new SqlParameter("@NewStatus", SqlDbType.NVarChar, 30) { Value = dto.NewStatus });
                    cmd.Parameters.Add(new SqlParameter("@ResolutionType", SqlDbType.NVarChar, 30) { Value = string.IsNullOrWhiteSpace(dto.ResolutionType) ? (object)DBNull.Value : dto.ResolutionType.Trim() });
                    cmd.Parameters.Add(new SqlParameter("@RefundAmount", SqlDbType.Decimal) { Value = (object)dto.RefundAmount ?? DBNull.Value, Precision = 18, Scale = 2 });
                    cmd.Parameters.Add(new SqlParameter("@RestockItem", SqlDbType.Bit) { Value = dto.RestockItem });
                    cmd.Parameters.Add(new SqlParameter("@AdminNotes", SqlDbType.NVarChar, 1000) { Value = string.IsNullOrWhiteSpace(dto.AdminNotes) ? (object)DBNull.Value : dto.AdminNotes.Trim() });
                    cmd.Parameters.Add(new SqlParameter("@ProcessedBy", SqlDbType.Int) { Value = (object)processedBy ?? DBNull.Value });

                    var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
                    var errorParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 255) { Direction = ParameterDirection.Output };

                    cmd.Parameters.Add(successParam);
                    cmd.Parameters.Add(errorParam);

                    await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);

                    bool success = successParam.Value != DBNull.Value && (bool)successParam.Value;
                    string error = errorParam.Value != DBNull.Value ? errorParam.Value.ToString() : null;

                    return new ReturnOperationResultDto
                    {
                        Success = success,
                        ErrorMessage = error,
                        RmaId = rmaId
                    };
                }
            }
        }
    }
}
