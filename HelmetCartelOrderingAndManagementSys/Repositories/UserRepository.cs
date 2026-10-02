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
                            PhoneNumber = reader.IsDBNull(reader.GetOrdinal("PhoneNumber")) ? null : reader.GetString(reader.GetOrdinal("PhoneNumber")),
                            CreatedAt = reader.IsDBNull(reader.GetOrdinal("CreatedAt")) ? (DateTime?)null : reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
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
                            CustomerName = reader.GetString(reader.GetOrdinal("CustomerName")),
                            CustomerEmail = reader.GetString(reader.GetOrdinal("CustomerEmail")),
                            CustomerPhone = reader.GetString(reader.GetOrdinal("CustomerPhone")),
                            Subtotal = reader.GetDecimal(reader.GetOrdinal("Subtotal")),
                            DiscountAmount = reader.GetDecimal(reader.GetOrdinal("DiscountAmount")),
                            ShippingFee = reader.GetDecimal(reader.GetOrdinal("ShippingFee")),
                            TotalAmount = reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
                            OrderStatus = reader.GetString(reader.GetOrdinal("OrderStatus")),
                            OrderSource = reader.GetString(reader.GetOrdinal("OrderSource")),
                            ShippingMethod = reader.IsDBNull(reader.GetOrdinal("ShippingMethod")) ? "Pickup" : reader.GetString(reader.GetOrdinal("ShippingMethod")),
                            ShippingRegion = reader.IsDBNull(reader.GetOrdinal("ShippingRegion")) ? null : reader.GetString(reader.GetOrdinal("ShippingRegion")),
                            ShippingAddress = reader.IsDBNull(reader.GetOrdinal("ShippingAddress")) ? null : reader.GetString(reader.GetOrdinal("ShippingAddress")),
                            ShippingBarangay = reader.IsDBNull(reader.GetOrdinal("ShippingBarangay")) ? null : reader.GetString(reader.GetOrdinal("ShippingBarangay")),
                            ShippingCity = reader.IsDBNull(reader.GetOrdinal("ShippingCity")) ? null : reader.GetString(reader.GetOrdinal("ShippingCity")),
                            ShippingProvince = reader.IsDBNull(reader.GetOrdinal("ShippingProvince")) ? null : reader.GetString(reader.GetOrdinal("ShippingProvince")),
                            ShippingPostalCode = reader.IsDBNull(reader.GetOrdinal("ShippingPostalCode")) ? null : reader.GetString(reader.GetOrdinal("ShippingPostalCode")),
                            Courier = reader.IsDBNull(reader.GetOrdinal("Courier")) ? null : reader.GetString(reader.GetOrdinal("Courier")),
                            TrackingNumber = reader.IsDBNull(reader.GetOrdinal("TrackingNumber")) ? null : reader.GetString(reader.GetOrdinal("TrackingNumber")),
                            DeliveryNotes = reader.IsDBNull(reader.GetOrdinal("DeliveryNotes")) ? null : reader.GetString(reader.GetOrdinal("DeliveryNotes")),
                            Notes = reader.IsDBNull(reader.GetOrdinal("Notes")) ? null : reader.GetString(reader.GetOrdinal("Notes")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                            UpdatedAt = reader.IsDBNull(reader.GetOrdinal("UpdatedAt")) ? (DateTime?)null : reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
                            PaymentGateway = reader.GetString(reader.GetOrdinal("PaymentGateway")),
                            PaymentStatus = reader.GetString(reader.GetOrdinal("PaymentStatus")),
                            GatewayReference = reader.IsDBNull(reader.GetOrdinal("GatewayReference")) ? null : reader.GetString(reader.GetOrdinal("GatewayReference")),
                            ItemCount = reader.GetInt32(reader.GetOrdinal("ItemCount")),
                            PreviewImages = reader.IsDBNull(reader.GetOrdinal("PreviewImages")) ? null : reader.GetString(reader.GetOrdinal("PreviewImages")),
                            PreviewImageList = reader.IsDBNull(reader.GetOrdinal("PreviewImages"))
                                ? new List<string>()
                                : new List<string>(reader.GetString(reader.GetOrdinal("PreviewImages")).Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries))
                        });
                    }
                }
            }

            return list;
        }

        public async Task<UserProfileDto> UpdateProfileAsync(int userId, string firstName, string lastName, string phoneNumber)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_UpdateUserProfile", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
                cmd.Parameters.Add(new SqlParameter("@FirstName", SqlDbType.NVarChar, 100) { Value = firstName });
                cmd.Parameters.Add(new SqlParameter("@LastName", SqlDbType.NVarChar, 100) { Value = lastName });
                cmd.Parameters.Add(new SqlParameter("@PhoneNumber", SqlDbType.NVarChar, 30) { Value = (object)phoneNumber ?? DBNull.Value });

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
                            PhoneNumber = reader.IsDBNull(reader.GetOrdinal("PhoneNumber")) ? null : reader.GetString(reader.GetOrdinal("PhoneNumber")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
                        };
                    }
                }
            }

            return null;
        }

        public async Task<bool> ChangePasswordAsync(int userId, string newPasswordHash, string newSalt)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_ChangeUserPassword", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
                cmd.Parameters.Add(new SqlParameter("@NewPasswordHash", SqlDbType.NVarChar, 512) { Value = newPasswordHash });
                cmd.Parameters.Add(new SqlParameter("@NewSalt", SqlDbType.NVarChar, 128) { Value = newSalt });

                await conn.OpenAsync().ConfigureAwait(false);
                var result = await cmd.ExecuteScalarAsync().ConfigureAwait(false);
                return result != null && Convert.ToInt32(result) == 1;
            }
        }

        public async Task<List<UserPaymentHistoryDto>> GetUserPaymentsAsync(int userId)
        {
            var list = new List<UserPaymentHistoryDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_GetUserPayments", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });

                await conn.OpenAsync().ConfigureAwait(false);

                using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new UserPaymentHistoryDto
                        {
                            PaymentId = reader.GetInt32(reader.GetOrdinal("PaymentId")),
                            OrderId = reader.GetInt32(reader.GetOrdinal("OrderId")),
                            OrderNumber = reader.GetString(reader.GetOrdinal("OrderNumber")),
                            PaymentGateway = reader.GetString(reader.GetOrdinal("PaymentGateway")),
                            GatewayReference = reader.IsDBNull(reader.GetOrdinal("GatewayReference")) ? null : reader.GetString(reader.GetOrdinal("GatewayReference")),
                            Amount = reader.GetDecimal(reader.GetOrdinal("Amount")),
                            PaymentStatus = reader.GetString(reader.GetOrdinal("PaymentStatus")),
                            PaidAt = reader.IsDBNull(reader.GetOrdinal("PaidAt")) ? (DateTime?)null : reader.GetDateTime(reader.GetOrdinal("PaidAt")),
                            PaymentCreatedAt = reader.GetDateTime(reader.GetOrdinal("PaymentCreatedAt")),
                            CustomerName = reader.GetString(reader.GetOrdinal("CustomerName")),
                            CustomerEmail = reader.GetString(reader.GetOrdinal("CustomerEmail")),
                            ShippingMethod = reader.IsDBNull(reader.GetOrdinal("ShippingMethod")) ? "Pickup" : reader.GetString(reader.GetOrdinal("ShippingMethod")),
                            OrderTotalAmount = reader.GetDecimal(reader.GetOrdinal("OrderTotalAmount")),
                            ItemCount = reader.GetInt32(reader.GetOrdinal("ItemCount"))
                        });
                    }
                }
            }

            return list;
        }

        public async Task<OrderSummaryDto> GetUserOrderDetailsAsync(int userId, int? orderId, string orderNumber)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_GetUserOrderDetails", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
                cmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = (object)orderId ?? DBNull.Value });
                cmd.Parameters.Add(new SqlParameter("@OrderNumber", SqlDbType.NVarChar, 50) { Value = (object)orderNumber ?? DBNull.Value });

                await conn.OpenAsync().ConfigureAwait(false);

                using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    // 1. Order Header
                    if (!await reader.ReadAsync().ConfigureAwait(false))
                    {
                        return null;
                    }

                    var order = new OrderSummaryDto
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
                        ShippingFee = reader.GetDecimal(reader.GetOrdinal("ShippingFee")),
                        TotalAmount = reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
                        ShippingMethod = reader.IsDBNull(reader.GetOrdinal("ShippingMethod")) ? "Pickup" : reader.GetString(reader.GetOrdinal("ShippingMethod")),
                        ShippingRegion = reader.IsDBNull(reader.GetOrdinal("ShippingRegion")) ? null : reader.GetString(reader.GetOrdinal("ShippingRegion")),
                        ShippingAddress = reader.IsDBNull(reader.GetOrdinal("ShippingAddress")) ? null : reader.GetString(reader.GetOrdinal("ShippingAddress")),
                        ShippingBarangay = reader.IsDBNull(reader.GetOrdinal("ShippingBarangay")) ? null : reader.GetString(reader.GetOrdinal("ShippingBarangay")),
                        ShippingCity = reader.IsDBNull(reader.GetOrdinal("ShippingCity")) ? null : reader.GetString(reader.GetOrdinal("ShippingCity")),
                        ShippingProvince = reader.IsDBNull(reader.GetOrdinal("ShippingProvince")) ? null : reader.GetString(reader.GetOrdinal("ShippingProvince")),
                        ShippingPostalCode = reader.IsDBNull(reader.GetOrdinal("ShippingPostalCode")) ? null : reader.GetString(reader.GetOrdinal("ShippingPostalCode")),
                        Courier = reader.IsDBNull(reader.GetOrdinal("Courier")) ? null : reader.GetString(reader.GetOrdinal("Courier")),
                        TrackingNumber = reader.IsDBNull(reader.GetOrdinal("TrackingNumber")) ? null : reader.GetString(reader.GetOrdinal("TrackingNumber")),
                        DeliveryNotes = reader.IsDBNull(reader.GetOrdinal("DeliveryNotes")) ? null : reader.GetString(reader.GetOrdinal("DeliveryNotes")),
                        PaymentMethod = reader.GetString(reader.GetOrdinal("PaymentMethod")),
                        PaymentStatus = reader.GetString(reader.GetOrdinal("PaymentStatus")),
                        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                        Items = new List<OrderItemSummaryDto>()
                    };

                    // 2. Order Items
                    if (await reader.NextResultAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            string mainImg = reader.IsDBNull(reader.GetOrdinal("MainImageUrl")) ? null : reader.GetString(reader.GetOrdinal("MainImageUrl"));
                            order.Items.Add(new OrderItemSummaryDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                VariantId = reader.GetInt32(reader.GetOrdinal("VariantId")),
                                ProductName = reader.GetString(reader.GetOrdinal("ProductName")),
                                SKU = reader.GetString(reader.GetOrdinal("SKU")),
                                Size = reader.GetString(reader.GetOrdinal("Size")),
                                Color = reader.GetString(reader.GetOrdinal("Color")),
                                Quantity = reader.GetInt32(reader.GetOrdinal("Quantity")),
                                UnitPrice = reader.GetDecimal(reader.GetOrdinal("UnitPrice")),
                                TotalPrice = reader.GetDecimal(reader.GetOrdinal("TotalPrice")),
                                MainImageUrl = mainImg,
                                ImageUrl = mainImg
                            });
                        }
                    }

                    return order;
                }
            }
        }

        public async Task<List<UserAddressDto>> GetUserAddressesAsync(int userId)
        {
            var list = new List<UserAddressDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_GetUserAddresses", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });

                await conn.OpenAsync().ConfigureAwait(false);

                using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        list.Add(new UserAddressDto
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                            AddressLabel = reader.IsDBNull(reader.GetOrdinal("AddressLabel")) ? "Home" : reader.GetString(reader.GetOrdinal("AddressLabel")),
                            RecipientName = reader.IsDBNull(reader.GetOrdinal("RecipientName")) ? null : reader.GetString(reader.GetOrdinal("RecipientName")),
                            PhoneNumber = reader.IsDBNull(reader.GetOrdinal("PhoneNumber")) ? null : reader.GetString(reader.GetOrdinal("PhoneNumber")),
                            StreetAddress = reader.IsDBNull(reader.GetOrdinal("StreetAddress")) ? "" : reader.GetString(reader.GetOrdinal("StreetAddress")),
                            Barangay = reader.IsDBNull(reader.GetOrdinal("Barangay")) ? "" : reader.GetString(reader.GetOrdinal("Barangay")),
                            City = reader.IsDBNull(reader.GetOrdinal("City")) ? "" : reader.GetString(reader.GetOrdinal("City")),
                            Province = reader.IsDBNull(reader.GetOrdinal("Province")) ? "" : reader.GetString(reader.GetOrdinal("Province")),
                            PostalCode = reader.IsDBNull(reader.GetOrdinal("PostalCode")) ? "" : reader.GetString(reader.GetOrdinal("PostalCode")),
                            DeliveryLandmark = reader.IsDBNull(reader.GetOrdinal("DeliveryLandmark")) ? null : reader.GetString(reader.GetOrdinal("DeliveryLandmark")),
                            IsDefault = reader.GetBoolean(reader.GetOrdinal("IsDefault")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                            UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt"))
                        });
                    }
                }
            }

            return list;
        }

        public async Task<UserAddressDto> SaveUserAddressAsync(int userId, SaveUserAddressRequestDto dto)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_SaveUserAddress", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = (object)dto.Id ?? DBNull.Value });
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
                cmd.Parameters.Add(new SqlParameter("@AddressLabel", SqlDbType.NVarChar, 50) { Value = string.IsNullOrWhiteSpace(dto.AddressLabel) ? "Home" : dto.AddressLabel.Trim() });
                cmd.Parameters.Add(new SqlParameter("@RecipientName", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(dto.RecipientName) ? DBNull.Value : (object)dto.RecipientName.Trim() });
                cmd.Parameters.Add(new SqlParameter("@PhoneNumber", SqlDbType.NVarChar, 50) { Value = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? DBNull.Value : (object)dto.PhoneNumber.Trim() });
                cmd.Parameters.Add(new SqlParameter("@StreetAddress", SqlDbType.NVarChar, 255) { Value = string.IsNullOrWhiteSpace(dto.StreetAddress) ? "" : dto.StreetAddress.Trim() });
                cmd.Parameters.Add(new SqlParameter("@Barangay", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(dto.Barangay) ? DBNull.Value : (object)dto.Barangay.Trim() });
                cmd.Parameters.Add(new SqlParameter("@City", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(dto.City) ? "" : dto.City.Trim() });
                cmd.Parameters.Add(new SqlParameter("@Province", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(dto.Province) ? "" : dto.Province.Trim() });
                cmd.Parameters.Add(new SqlParameter("@PostalCode", SqlDbType.NVarChar, 20) { Value = string.IsNullOrWhiteSpace(dto.PostalCode) ? DBNull.Value : (object)dto.PostalCode.Trim() });
                cmd.Parameters.Add(new SqlParameter("@DeliveryLandmark", SqlDbType.NVarChar, 255) { Value = string.IsNullOrWhiteSpace(dto.DeliveryLandmark) ? DBNull.Value : (object)dto.DeliveryLandmark.Trim() });
                cmd.Parameters.Add(new SqlParameter("@IsDefault", SqlDbType.Bit) { Value = dto.IsDefault });

                await conn.OpenAsync().ConfigureAwait(false);

                using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                {
                    if (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        return new UserAddressDto
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                            AddressLabel = reader.IsDBNull(reader.GetOrdinal("AddressLabel")) ? "Home" : reader.GetString(reader.GetOrdinal("AddressLabel")),
                            RecipientName = reader.IsDBNull(reader.GetOrdinal("RecipientName")) ? null : reader.GetString(reader.GetOrdinal("RecipientName")),
                            PhoneNumber = reader.IsDBNull(reader.GetOrdinal("PhoneNumber")) ? null : reader.GetString(reader.GetOrdinal("PhoneNumber")),
                            StreetAddress = reader.IsDBNull(reader.GetOrdinal("StreetAddress")) ? "" : reader.GetString(reader.GetOrdinal("StreetAddress")),
                            Barangay = reader.IsDBNull(reader.GetOrdinal("Barangay")) ? "" : reader.GetString(reader.GetOrdinal("Barangay")),
                            City = reader.IsDBNull(reader.GetOrdinal("City")) ? "" : reader.GetString(reader.GetOrdinal("City")),
                            Province = reader.IsDBNull(reader.GetOrdinal("Province")) ? "" : reader.GetString(reader.GetOrdinal("Province")),
                            PostalCode = reader.IsDBNull(reader.GetOrdinal("PostalCode")) ? "" : reader.GetString(reader.GetOrdinal("PostalCode")),
                            DeliveryLandmark = reader.IsDBNull(reader.GetOrdinal("DeliveryLandmark")) ? null : reader.GetString(reader.GetOrdinal("DeliveryLandmark")),
                            IsDefault = reader.GetBoolean(reader.GetOrdinal("IsDefault")),
                            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                            UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt"))
                        };
                    }
                }
            }

            return null;
        }

        public async Task<bool> DeleteUserAddressAsync(int userId, int addressId)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            using (var cmd = new SqlCommand("dbo.sp_DeleteUserAddress", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = addressId });
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });

                await conn.OpenAsync().ConfigureAwait(false);
                var result = await cmd.ExecuteScalarAsync().ConfigureAwait(false);
                return result != null && Convert.ToInt32(result) == 1;
            }
        }
    }
}

