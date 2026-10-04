using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using Newtonsoft.Json;

namespace HelmetCartelOrderingAndManagementSys.Repositories
{
    public sealed class ShoppingRepository
    {
        private readonly IDbConnectionFactory _factory;
        public ShoppingRepository(IDbConnectionFactory factory) { _factory = factory; }

        public Task<ShoppingStateDto> GetAsync(int userId)
        {
            return ExecuteAsync("dbo.sp_GetShoppingState", userId);
        }

        public async Task<ShoppingStateDto> ImportAsync(int userId, ShoppingImportDto items)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand("dbo.sp_ImportShoppingState", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@UserId", SqlDbType.Int).Value = userId;
                command.Parameters.Add("@Cart", SqlDbType.NVarChar, -1).Value = JsonConvert.SerializeObject(items.Cart);
                command.Parameters.Add("@Favorites", SqlDbType.NVarChar, -1).Value = JsonConvert.SerializeObject(items.Favorites);
                await connection.OpenAsync().ConfigureAwait(false);
                return Normalize(JsonConvert.DeserializeObject<ShoppingStateDto>((string)await command.ExecuteScalarAsync().ConfigureAwait(false)));
            }
        }

        public Task<ShoppingStateDto> ChangeAsync(int userId, string operation, int? id = null,
            int? quantity = null, bool? selected = null)
        {
            return ExecuteAsync("dbo.sp_ChangeShoppingState", userId, operation, id, quantity, selected);
        }

        private static ShoppingStateDto Normalize(ShoppingStateDto state)
        {
            foreach (var item in state.Cart) item.ImageUrl = (item.ImageUrl ?? string.Empty).Replace("/Content/images/helmets/", "/Content/images/products/helmets/");
            foreach (var item in state.Favorites) item.ImageUrl = (item.ImageUrl ?? string.Empty).Replace("/Content/images/helmets/", "/Content/images/products/helmets/");
            return state;
        }

        private async Task<ShoppingStateDto> ExecuteAsync(string procedure, int userId,
            string operation = null, int? id = null, int? quantity = null, bool? selected = null)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            using (var command = new SqlCommand(procedure, connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@UserId", SqlDbType.Int).Value = userId;
                if (operation != null)
                {
                    command.Parameters.Add("@Operation", SqlDbType.NVarChar, 30).Value = operation;
                    command.Parameters.Add("@Id", SqlDbType.Int).Value = (object)id ?? System.DBNull.Value;
                    command.Parameters.Add("@Quantity", SqlDbType.Int).Value = (object)quantity ?? System.DBNull.Value;
                    command.Parameters.Add("@IsSelected", SqlDbType.Bit).Value = (object)selected ?? System.DBNull.Value;
                }
                await connection.OpenAsync().ConfigureAwait(false);
                var json = (string)await command.ExecuteScalarAsync().ConfigureAwait(false);
                return Normalize(JsonConvert.DeserializeObject<ShoppingStateDto>(json));
            }
        }
    }
}
