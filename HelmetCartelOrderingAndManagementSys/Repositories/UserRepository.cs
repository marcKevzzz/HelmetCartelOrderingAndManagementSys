using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public class UserRepository : IUserRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public UserRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory ?? throw new ArgumentNullException(nameof(dbFactory));
        }

        public async Task<UserRecordDto> GetUserByEmailAsync(string email)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_GetUserByEmail", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@Email", SqlDbType.NVarChar, 256) { Value = (object)email ?? DBNull.Value });

                await conn.OpenAsync().ConfigureAwait(false);

                using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    if (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        return new UserRecordDto
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            RoleId = reader.GetInt32(reader.GetOrdinal("RoleId")),
                            RoleName = reader.GetString(reader.GetOrdinal("RoleName")),
                            FirstName = reader.GetString(reader.GetOrdinal("FirstName")),
                            LastName = reader.GetString(reader.GetOrdinal("LastName")),
                            FullName = reader.GetString(reader.GetOrdinal("FullName")),
                            Email = reader.GetString(reader.GetOrdinal("Email")),
                            PasswordHash = reader.GetString(reader.GetOrdinal("PasswordHash")),
                            Salt = reader.GetString(reader.GetOrdinal("Salt")),
                            PhoneNumber = reader.IsDBNull(reader.GetOrdinal("PhoneNumber")) ? null : reader.GetString(reader.GetOrdinal("PhoneNumber")),
                            IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
                        };
                    }
                }
            }

            return null;
        }

        public async Task<UserProfileDto> GetUserProfileAsync(int userId)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_GetUserProfile", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });

                await conn.OpenAsync().ConfigureAwait(false);

                using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    if (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        return new UserProfileDto
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            Role = reader.GetString(reader.GetOrdinal("RoleName")),
                            FirstName = reader.GetString(reader.GetOrdinal("FirstName")),
                            LastName = reader.GetString(reader.GetOrdinal("LastName")),
                            FullName = reader.GetString(reader.GetOrdinal("FullName")),
                            Email = reader.GetString(reader.GetOrdinal("Email")),
                            PhoneNumber = reader.IsDBNull(reader.GetOrdinal("PhoneNumber")) ? null : reader.GetString(reader.GetOrdinal("PhoneNumber"))
                        };
                    }
                }
            }

            return null;
        }

        public async Task<(bool Success, int UserId, string ErrorMessage)> RegisterUserAsync(
            string firstName, string lastName, string email, string passwordHash, string salt, string phoneNumber, string roleName)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_RegisterUser", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;

                cmd.Parameters.Add(new SqlParameter("@FirstName", SqlDbType.NVarChar, 100) { Value = firstName });
                cmd.Parameters.Add(new SqlParameter("@LastName", SqlDbType.NVarChar, 100) { Value = lastName });
                cmd.Parameters.Add(new SqlParameter("@Email", SqlDbType.NVarChar, 256) { Value = email });
                cmd.Parameters.Add(new SqlParameter("@PasswordHash", SqlDbType.NVarChar, 512) { Value = passwordHash });
                cmd.Parameters.Add(new SqlParameter("@Salt", SqlDbType.NVarChar, 128) { Value = salt });
                cmd.Parameters.Add(new SqlParameter("@PhoneNumber", SqlDbType.NVarChar, 30) { Value = (object)phoneNumber ?? DBNull.Value });
                cmd.Parameters.Add(new SqlParameter("@RoleName", SqlDbType.NVarChar, 50) { Value = roleName ?? HelmetCartelOrderingAndManagementSys.Constants.AppConstants.Roles.Customer });

                var newUserIdParam = new SqlParameter("@NewUserId", SqlDbType.Int) { Direction = ParameterDirection.Output };
                var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
                var errorParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 255) { Direction = ParameterDirection.Output };

                cmd.Parameters.Add(newUserIdParam);
                cmd.Parameters.Add(successParam);
                cmd.Parameters.Add(errorParam);

                await conn.OpenAsync().ConfigureAwait(false);
                await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);

                var success = successParam.Value != DBNull.Value && (bool)successParam.Value;
                var newUserId = newUserIdParam.Value != DBNull.Value ? (int)newUserIdParam.Value : 0;
                var error = errorParam.Value != DBNull.Value ? errorParam.Value.ToString() : null;

                return (success, newUserId, error);
            }
        }

        public async Task<List<UserOrderSummaryDto>> GetUserOrdersAsync(int userId)
        {
            var list = new List<UserOrderSummaryDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_GetUserOrders", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });

                await conn.OpenAsync().ConfigureAwait(false);

                using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new UserOrderSummaryDto
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            OrderNumber = reader.GetString(reader.GetOrdinal("OrderNumber")),
                            Subtotal = reader.GetDecimal(reader.GetOrdinal("Subtotal")),
                            DiscountAmount = reader.GetDecimal(reader.GetOrdinal("DiscountAmount")),
                            TotalAmount = reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
                            OrderStatus = reader.GetString(reader.GetOrdinal("OrderStatus")),
                            OrderSource = reader.GetString(reader.GetOrdinal("OrderSource")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                            PaymentGateway = reader.GetString(reader.GetOrdinal("PaymentGateway")),
                            ItemCount = reader.GetInt32(reader.GetOrdinal("ItemCount"))
                        });
                    }
                }
            }

            return list;
        }
    }
}
