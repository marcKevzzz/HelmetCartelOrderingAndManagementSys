using System;
using System.Web.UI;

namespace HelmetCartelOrderingAndManagementSys.Pages
{
    public partial class CheckoutPage : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                string returnUrl = Request.RawUrl ?? "/Pages/Storefront/Checkout/Checkout.aspx";
                checkoutAddressComponent.NavigateUrl = $"~/Pages/Storefront/Profile/Profile.aspx?tab=addresses&returnUrl={Server.UrlEncode(returnUrl)}";
            }
        }
    }
}
