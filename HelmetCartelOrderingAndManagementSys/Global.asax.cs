using System;
using System.Collections.Generic;
using System.Web;
using System.Web.Routing;
using System.Web.Http;

namespace HelmetCartelOrderingAndManagementSys
{
    public class Global : HttpApplication
    {
        private static readonly Dictionary<string, string> LegacyPageRedirects = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            // Storefront legacy routes
            { "~/Pages/Auth.aspx", "~/Pages/Auth/Auth.aspx" },
            { "~/Pages/Login.aspx", "~/Pages/Auth/Auth.aspx" },
            { "~/Pages/Shop.aspx", "~/Pages/Storefront/Shop/Shop.aspx" },
            { "~/Pages/ProductDetail.aspx", "~/Pages/Storefront/ProductDetail/ProductDetail.aspx" },
            { "~/Pages/Cart.aspx", "~/Pages/Storefront/Cart/Cart.aspx" },
            { "~/Pages/Checkout.aspx", "~/Pages/Storefront/Checkout/Checkout.aspx" },
            { "~/Pages/Profile.aspx", "~/Pages/Storefront/Profile/Profile.aspx" },
            { "~/Pages/Dashboard.aspx", "~/Pages/Storefront/Profile/Profile.aspx" },
            { "~/Pages/Favorites.aspx", "~/Pages/Storefront/Favorites/Favorites.aspx" },
            { "~/Pages/TrackOrder.aspx", "~/Pages/Storefront/TrackOrder/TrackOrder.aspx" },

            // Admin legacy root routes
            { "~/Admin/Dashboard.aspx", "~/Pages/Admin/Dashboard/Dashboard.aspx" },
            { "~/Admin/Catalog.aspx", "~/Pages/Admin/Catalog/Catalog.aspx" },
            { "~/Admin/CatalogItem.aspx", "~/Pages/Admin/CatalogItem/CatalogItem.aspx" },
            { "~/Admin/Inventory.aspx", "~/Pages/Admin/Inventory/Inventory.aspx" },
            { "~/Admin/Orders.aspx", "~/Pages/Admin/Orders/Orders.aspx" },
            { "~/Admin/OrderDetail.aspx", "~/Pages/Admin/Orders/OrderDetail.aspx" },
            { "~/Admin/Orders/OrderDetail.aspx", "~/Pages/Admin/Orders/OrderDetail.aspx" },
            { "~/Admin/Returns.aspx", "~/Pages/Admin/Returns/Returns.aspx" },
            { "~/Admin/POS.aspx", "~/Pages/Admin/POS/POS.aspx" },
            { "~/Admin/Reports.aspx", "~/Pages/Admin/Reports/Reports.aspx" },
            { "~/Admin/Users.aspx", "~/Pages/Admin/Users/Users.aspx" },
            { "~/Admin/Reviews.aspx", "~/Pages/Admin/Reviews/Reviews.aspx" },
            { "~/Admin/Payments.aspx", "~/Pages/Admin/Payments/Payments.aspx" }
        };

        void Application_BeginRequest(object sender, EventArgs e)
        {
            string appRelativePath = Request.AppRelativeCurrentExecutionFilePath;

            // 1. Check for legacy URL redirects
            if (LegacyPageRedirects.TryGetValue(appRelativePath, out string targetUrl))
            {
                string destination = VirtualPathUtility.ToAbsolute(targetUrl) + Request.Url.Query;
                Response.RedirectPermanent(destination, false);
                CompleteRequest();
                return;
            }

            // 2. Admin authorization gate for ~/Pages/Admin/ and ~/Admin/
            bool isAdminPath = appRelativePath.StartsWith("~/Pages/Admin/", StringComparison.OrdinalIgnoreCase) ||
                               appRelativePath.StartsWith("~/Admin/", StringComparison.OrdinalIgnoreCase);

            if (isAdminPath && Request.Path.EndsWith(".aspx", StringComparison.OrdinalIgnoreCase))
            {
                var token = Request.Cookies[Constants.AppConstants.JwtConfiguration.AuthCookieName]?.Value;
                var user = new Infrastructure.JwtTokenProvider().ValidateToken(token);
                if (user != null && (user.Role == Constants.AppConstants.Roles.Admin || user.Role == Constants.AppConstants.Roles.Staff))
                {
                    bool isAdminOnlySection = appRelativePath.StartsWith("~/Pages/Admin/Vouchers/", StringComparison.OrdinalIgnoreCase) ||
                                              appRelativePath.StartsWith("~/Pages/Admin/Users/", StringComparison.OrdinalIgnoreCase);

                    if (isAdminOnlySection && user.Role != Constants.AppConstants.Roles.Admin)
                    {
                        Response.Redirect("~/Pages/Admin/Inventory/Inventory.aspx", false);
                        CompleteRequest();
                    }
                    return;
                }

                Response.Cookies.Add(new HttpCookie(Constants.AppConstants.JwtConfiguration.AuthCookieName, "")
                {
                    HttpOnly = true,
                    Path = "/",
                    Expires = DateTime.UtcNow.AddDays(-1)
                });
                Response.Redirect("~/Pages/Auth/Auth.aspx?sessionExpired=1&returnUrl=" + HttpUtility.UrlEncode(Request.RawUrl), false);
                CompleteRequest();
            }
        }

        void Application_Start(object sender, EventArgs e)
        {
            // Code that runs on application startup
            GlobalConfiguration.Configure(WebApiConfig.Register);
        }
    }
}
