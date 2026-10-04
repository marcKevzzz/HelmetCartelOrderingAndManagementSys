using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public sealed class VoucherRepository
    {
        private readonly IDbConnectionFactory _factory;
        public VoucherRepository(IDbConnectionFactory factory) { _factory = factory; }

        public async Task<VoucherQuoteDto> PreviewAsync(VoucherRequestDto request)
        {
            var items = new DataTable();
            items.Columns.Add("VariantId", typeof(int));
            items.Columns.Add("Quantity", typeof(int));
            foreach (var item in request.Items) items.Rows.Add(item.VariantId, item.Quantity);
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_PreviewVoucher", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@Code", SqlDbType.NVarChar, 30) { Value = request.Code });
                command.Parameters.Add(new SqlParameter("@Items", SqlDbType.Structured) { TypeName = "dbo.SaleLineInput", Value = items });
                await connection.OpenAsync().ConfigureAwait(false);
                return await ReadQuoteAsync(command).ConfigureAwait(false);
            }
        }

        public static async Task<VoucherQuoteDto> ApplyAsync(SqlConnection connection, SqlTransaction transaction, int orderId, string code)
        {
            using (var command = new SqlCommand("dbo.sp_ApplyOrderVoucher", connection, transaction))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add(new SqlParameter("@OrderId", SqlDbType.Int) { Value = orderId });
                command.Parameters.Add(new SqlParameter("@Code", SqlDbType.NVarChar, 30) { Value = code.Trim().ToUpperInvariant() });
                return await ReadQuoteAsync(command).ConfigureAwait(false);
            }
        }

        private static async Task<VoucherQuoteDto> ReadQuoteAsync(SqlCommand command)
        {
            using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
            {
                if (!await reader.ReadAsync().ConfigureAwait(false)) throw new InvalidOperationException("Voucher validation returned no result.");
                var quote = new VoucherQuoteDto
                {
                    Code = reader.GetString(0),
                    Subtotal = reader.GetDecimal(1),
                    DiscountAmount = reader.GetDecimal(2),
                    DiscountedSubtotal = reader.GetDecimal(3)
                };
                if (reader.FieldCount > 4 && !reader.IsDBNull(4))
                {
                    quote.DiscountType = reader.GetString(4);
                }
                return quote;
            }
        }

        public Task<List<Dictionary<string, object>>> ListAsync() => new AdminDataRepository(_factory).QueryAsync("dbo.sp_AdminVouchers");

        public Task<List<Dictionary<string, object>>> SaveAsync(int id, SaveVoucherDto request)
        {
            return new AdminDataRepository(_factory).QueryAsync("dbo.sp_AdminSaveVoucher",
                new SqlParameter("@Id", SqlDbType.Int) { Value = id },
                new SqlParameter("@Code", SqlDbType.NVarChar, 30) { Value = request.Code },
                new SqlParameter("@DiscountType", SqlDbType.NVarChar, 20) { Value = request.DiscountType },
                Amount("@DiscountValue", request.DiscountValue), Amount("@MinimumSpend", request.MinimumSpend),
                new SqlParameter("@ExpiresAt", SqlDbType.DateTime2) { Value = (object)request.ExpiresAt ?? DBNull.Value },
                new SqlParameter("@UsageLimit", SqlDbType.Int) { Value = (object)request.UsageLimit ?? DBNull.Value },
                new SqlParameter("@IsActive", SqlDbType.Bit) { Value = request.IsActive });
        }

        private static SqlParameter Amount(string name, decimal value) =>
            new SqlParameter(name, SqlDbType.Decimal) { Precision = 18, Scale = 2, Value = value };
    }
}
