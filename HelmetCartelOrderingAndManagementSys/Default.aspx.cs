using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.UI;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys
{
    public partial class Default : Page
    {
        private readonly IProductRepository _productRepository;
        private readonly IReviewRepository _reviewRepository;
        private readonly IDbConnectionFactory _dbConnectionFactory;

        public Default()
        {
            _dbConnectionFactory = new DbConnectionFactory();
            _productRepository = new ProductRepository(_dbConnectionFactory);
            _reviewRepository = new ReviewRepository(_dbConnectionFactory);
        }

        public Default(
            IProductRepository productRepository,
            IReviewRepository reviewRepository,
            IDbConnectionFactory dbConnectionFactory
        )
        {
            _dbConnectionFactory = dbConnectionFactory ?? new DbConnectionFactory();
            _productRepository = productRepository ?? new ProductRepository(_dbConnectionFactory);
            _reviewRepository = reviewRepository ?? new ReviewRepository(_dbConnectionFactory);
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                try
                {
                    LoadHeroStats();

                    var newArrivals = _productRepository
                        .GetNewArrivalsAsync(4)
                        .GetAwaiter()
                        .GetResult();
                    rptNewArrivals.DataSource = newArrivals ?? new List<ProductListDto>();
                    rptNewArrivals.DataBind();

                    var topSelling = _productRepository
                        .GetTopSellingAsync(4)
                        .GetAwaiter()
                        .GetResult();
                    rptTopSelling.DataSource = topSelling ?? new List<ProductListDto>();
                    rptTopSelling.DataBind();

                    var topReviews = _reviewRepository
                        .GetTopCustomerReviewsAsync(12)
                        .GetAwaiter()
                        .GetResult();
                    rptHappyCustomers.DataSource = topReviews ?? new List<ProductReviewDto>();
                    rptHappyCustomers.DataBind();
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Trace.TraceError(
                        $"[Default] Error loading data via C#: {ex}"
                    );
                }
            }
        }

        private void LoadHeroStats()
        {
            try
            {
                using (
                    var conn = (System.Data.SqlClient.SqlConnection)
                        _dbConnectionFactory.CreateConnection()
                )
                {
                    conn.Open();
                    using (
                        var cmd = new System.Data.SqlClient.SqlCommand(
                            "dbo.sp_GetStorefrontStats",
                            conn
                        )
                    )
                    {
                        cmd.CommandType = System.Data.CommandType.StoredProcedure;
                        using (var reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                int totalBrands = reader.GetInt32(reader.GetOrdinal("TotalBrands"));
                                int totalProducts = reader.GetInt32(
                                    reader.GetOrdinal("TotalProducts")
                                );
                                int completedOrders = reader.GetInt32(
                                    reader.GetOrdinal("CompletedOrders")
                                );

                                litBrandsCount.Text = $"{totalBrands:N0}";
                                litHelmetsCount.Text = $"{totalProducts:N0}";
                                litRidersCount.Text = $"{completedOrders:N0}";
                                return;
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError($"[Default] Error loading stats: {ex}");
            }

            // Fallback display
            litBrandsCount.Text = "5";
            litHelmetsCount.Text = "37";
            litRidersCount.Text = "9";
        }

        public string RenderStars(decimal rating)
        {
            var sb = new StringBuilder();
            int fullStars = (int)Math.Floor(rating);
            for (int i = 0; i < 5; i++)
            {
                if (i < fullStars)
                {
                    sb.Append(
                        "<svg viewBox=\"0 0 24 24\"><polygon points=\"12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2\"/></svg>"
                    );
                }
                else
                {
                    sb.Append(
                        "<svg viewBox=\"0 0 24 24\" class=\"star--empty\"><polygon points=\"12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2\"/></svg>"
                    );
                }
            }
            return sb.ToString();
        }
    }
}
