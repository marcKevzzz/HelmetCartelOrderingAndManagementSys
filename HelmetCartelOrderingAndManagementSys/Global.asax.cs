using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Routing;
using System.Web.Security;
using System.Web.SessionState;
using System.Web.Http;

namespace HelmetCartelOrderingAndManagementSys
{
    public class Global : HttpApplication
    {
        void Application_BeginRequest(object sender, EventArgs e)
        {
            if (!Request.AppRelativeCurrentExecutionFilePath.StartsWith("~/Admin/", StringComparison.OrdinalIgnoreCase) ||
                !Request.Path.EndsWith(".aspx", StringComparison.OrdinalIgnoreCase)) return;

            var token = Request.Cookies[Constants.AppConstants.JwtConfiguration.AuthCookieName]?.Value;
            var user = new Infrastructure.JwtTokenProvider().ValidateToken(token);
            if (user != null && (user.Role == Constants.AppConstants.Roles.Admin || user.Role == Constants.AppConstants.Roles.Staff)) return;

            Response.Cookies.Add(new HttpCookie(Constants.AppConstants.JwtConfiguration.AuthCookieName, "")
            {
                HttpOnly = true, Path = "/", Expires = DateTime.UtcNow.AddDays(-1)
            });
            Response.Redirect("~/Pages/Auth.aspx?sessionExpired=1&returnUrl=" + HttpUtility.UrlEncode(Request.RawUrl), false);
            CompleteRequest();
        }

        void Application_Start(object sender, EventArgs e)
        {
            // Code that runs on application startup
            GlobalConfiguration.Configure(WebApiConfig.Register);
        }
    }
}
