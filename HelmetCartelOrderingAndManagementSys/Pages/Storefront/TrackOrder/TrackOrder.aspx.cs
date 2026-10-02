using System;
using System.Web.UI;

namespace HelmetCartelOrderingAndManagementSys.Pages
{
    public partial class TrackOrderPage : Page
    {
        public string OrderNumber { get; private set; } = string.Empty;

        protected void Page_Load(object sender, EventArgs e)
        {
            OrderNumber = Request.QueryString["orderNumber"] ?? string.Empty;
        }
    }
}
