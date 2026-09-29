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

        public Default()
        {
            _productRepository = new ProductRepository(new DbConnectionFactory());
        }

        public Default(IProductRepository productRepository)
        {
            _productRepository = productRepository;
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            RegisterAsyncTask(new PageAsyncTask(LoadHomeProductsAsync));
        }

        private async Task LoadHomeProductsAsync()
        {
            try
            {
                var newArrivals = await _productRepository.GetNewArrivalsAsync(4).ConfigureAwait(false);
                rptNewArrivals.DataSource = newArrivals ?? new List<ProductListDto>();
                rptNewArrivals.DataBind();

                var topSelling = await _productRepository.GetTopSellingAsync(4).ConfigureAwait(false);
                rptTopSelling.DataSource = topSelling ?? new List<ProductListDto>();
                rptTopSelling.DataBind();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[Default] Error loading products via C#: {ex.Message}");
            }
        }

        public string RenderStars(decimal rating)
        {
            var sb = new StringBuilder();
            int fullStars = (int)Math.Floor(rating);
            for (int i = 0; i < 5; i++)
            {
                if (i < fullStars)
                {
                    sb.Append("<svg viewBox=\"0 0 24 24\"><polygon points=\"12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2\"/></svg>");
                }
                else
                {
                    sb.Append("<svg viewBox=\"0 0 24 24\" class=\"star--empty\"><polygon points=\"12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2\"/></svg>");
                }
            }
            return sb.ToString();
        }
    }
}
