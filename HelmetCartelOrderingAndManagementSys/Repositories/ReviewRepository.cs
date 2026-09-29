using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public class ReviewRepository : IReviewRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public ReviewRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory ?? throw new ArgumentNullException(nameof(dbFactory));
        }

        public async Task<List<ProductReviewDto>> GetProductReviewsAsync(int productId, bool includeHidden = false)
        {
            var list = new List<ProductReviewDto>();

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_GetProductReviews", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });
                    cmd.Parameters.Add(new SqlParameter("@IncludeHidden", SqlDbType.Bit) { Value = includeHidden });

                    using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            var review = new ProductReviewDto
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                ProductId = reader.GetInt32(reader.GetOrdinal("ProductId")),
                                UserId = reader.IsDBNull(reader.GetOrdinal("UserId")) ? (int?)null : reader.GetInt32(reader.GetOrdinal("UserId")),
                                OrderId = reader.IsDBNull(reader.GetOrdinal("OrderId")) ? (int?)null : reader.GetInt32(reader.GetOrdinal("OrderId")),
                                ReviewerName = reader.GetString(reader.GetOrdinal("ReviewerName")),
                                Rating = reader.GetInt32(reader.GetOrdinal("Rating")),
                                Title = reader.IsDBNull(reader.GetOrdinal("Title")) ? null : reader.GetString(reader.GetOrdinal("Title")),
                                Comment = reader.GetString(reader.GetOrdinal("Comment")),
                                IsVerifiedPurchase = reader.GetBoolean(reader.GetOrdinal("IsVerifiedPurchase")),
                                FlagCount = Convert.ToInt32(reader["FlagCount"]),
                                IsHidden = reader.GetBoolean(reader.GetOrdinal("IsHidden")),
                                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
                            };

                            list.Add(review);
                        }
                    }
                }
            }

            return list;
        }

        public async Task<ReportReviewResultDto> ReportReviewAsync(int reviewId, int? userId, string ipAddress, string reason, string notes)
        {
            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_ReportReview", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.Add(new SqlParameter("@ReviewId", SqlDbType.Int) { Value = reviewId });
                    cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = (object)userId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@IpAddress", SqlDbType.NVarChar, 45) { Value = string.IsNullOrWhiteSpace(ipAddress) ? (object)DBNull.Value : ipAddress });
                    cmd.Parameters.Add(new SqlParameter("@Reason", SqlDbType.NVarChar, 50) { Value = reason ?? "SPAM" });
                    cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 255) { Value = string.IsNullOrWhiteSpace(notes) ? (object)DBNull.Value : notes });

                    var successParam = new SqlParameter("@Success", SqlDbType.Bit)
                    {
                        Direction = ParameterDirection.Output
                    };
                    cmd.Parameters.Add(successParam);

                    var errorParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 255)
                    {
                        Direction = ParameterDirection.Output
                    };
                    cmd.Parameters.Add(errorParam);

                    await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);

                    bool success = successParam.Value != DBNull.Value && (bool)successParam.Value;
                    string errorMessage = errorParam.Value != DBNull.Value ? errorParam.Value.ToString() : null;

                    return new ReportReviewResultDto
                    {
                        Success = success,
                        ErrorMessage = errorMessage
                    };
                }
            }
        }

        public async Task<int> AddReviewAsync(AddReviewRequestDto request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));

            using (var conn = (SqlConnection)_dbFactory.CreateConnection())
            {
                await conn.OpenAsync().ConfigureAwait(false);

                using (var cmd = new SqlCommand("dbo.sp_AddProductReview", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = request.ProductId });
                    cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = (object)request.UserId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = (object)request.OrderId ?? DBNull.Value });
                    cmd.Parameters.Add(new SqlParameter("@ReviewerName", SqlDbType.NVarChar, 100) { Value = request.ReviewerName });
                    cmd.Parameters.Add(new SqlParameter("@Rating", SqlDbType.Int) { Value = request.Rating });
                    cmd.Parameters.Add(new SqlParameter("@Title", SqlDbType.NVarChar, 150) { Value = string.IsNullOrWhiteSpace(request.Title) ? (object)DBNull.Value : request.Title });
                    cmd.Parameters.Add(new SqlParameter("@Comment", SqlDbType.NVarChar, -1) { Value = request.Comment ?? string.Empty });
                    cmd.Parameters.Add(new SqlParameter("@IsVerifiedPurchase", SqlDbType.Bit) { Value = false });

                    var newIdParam = new SqlParameter("@NewReviewId", SqlDbType.Int)
                    {
                        Direction = ParameterDirection.Output
                    };
                    cmd.Parameters.Add(newIdParam);

                    await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);

                    return newIdParam.Value != DBNull.Value ? (int)newIdParam.Value : 0;
                }
            }
        }
    }
}
