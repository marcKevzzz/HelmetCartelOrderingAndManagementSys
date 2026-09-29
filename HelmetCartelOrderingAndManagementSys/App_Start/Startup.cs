using Microsoft.AspNet.SignalR;
using Owin;

[assembly: Microsoft.Owin.OwinStartup(typeof(HelmetCartelOrderingAndManagementSys.App_Start.Startup))]

namespace HelmetCartelOrderingAndManagementSys.App_Start
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            app.MapSignalR();
        }
    }
}
