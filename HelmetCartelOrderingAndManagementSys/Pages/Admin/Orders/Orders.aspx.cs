using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.UI;
using System.Web.UI.WebControls;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Admin
{
    public partial class OrdersPage : Page
    {
        private readonly AdminDataRepository _adminRepo;

        public string CurrentStatus
        {
            get => (ViewState["CurrentStatus"] as string) ?? "all";
            set => ViewState["CurrentStatus"] = value;
        }

        public DateTime? CurrentOrderDate
        {
            get => ViewState["CurrentOrderDate"] == null ? (DateTime?)null : (DateTime)ViewState["CurrentOrderDate"];
            set => ViewState["CurrentOrderDate"] = value.HasValue ? (object)value.Value.Date : null;
        }

        public OrdersPage()
        {
            _adminRepo = new AdminDataRepository(new DbConnectionFactory());
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (IsPostBack)
            {
                string eventTarget = Request["__EVENTTARGET"];
                string eventArg = Request["__EVENTARGUMENT"];
                if (!string.IsNullOrEmpty(eventTarget) && eventTarget.EndsWith("rptOrders") && !string.IsNullOrEmpty(eventArg))
                {
                    var parts = eventArg.Split('$');
                    if (parts.Length >= 2 && int.TryParse(parts[1], out int orderId))
                    {
                        string targetStatus = parts[0];
                        RegisterAsyncTask(new PageAsyncTask(async () =>
                        {
                            try
                            {
                                await _adminRepo.UpdateOrderStatusAsync(orderId, targetStatus).ConfigureAwait(false);
                                try
                                {
                                    var orderHub = Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<Hubs.OrderHub>();
                                    orderHub.Clients.All.orderUpdated(new { orderId = orderId, status = targetStatus });
                                }
                                catch { }
                            }
                            catch (Exception ex)
                            {
                                System.Diagnostics.Trace.TraceError($"Failed to update order status: {ex.Message}");
                            }
                            await LoadOrdersDataAsync().ConfigureAwait(false);
                        }));
                        return;
                    }
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(Request.QueryString["status"]))
                {
                    CurrentStatus = Request.QueryString["status"];
                }

                if (DateTime.TryParseExact(Request.QueryString["date"], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var orderDate))
                {
                    CurrentOrderDate = orderDate.Date;
                    txtOrderDate.Text = orderDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                }
                RegisterAsyncTask(new PageAsyncTask(LoadOrdersDataAsync));
            }
        }

        public int CurrentPage
        {
            get => ViewState["CurrentPage"] != null ? (int)ViewState["CurrentPage"] : 1;
            set => ViewState["CurrentPage"] = value;
        }

        public const int PageSize = 20;

        private async Task LoadOrdersDataAsync()
        {
            string search = Request.QueryString["q"] ?? Request.QueryString["search"];
            string status = CurrentStatus == "all" ? null : CurrentStatus;

            var orders = await _adminRepo.GetOrdersAsync(search, status, null, 250, CurrentOrderDate).ConfigureAwait(false);

            int totalCount = orders.Count;
            int totalPages = Math.Max(1, (int)Math.Ceiling((double)totalCount / PageSize));

            if (CurrentPage < 1) CurrentPage = 1;
            if (CurrentPage > totalPages) CurrentPage = totalPages;

            var pagedOrders = orders.Skip((CurrentPage - 1) * PageSize).Take(PageSize).ToList();

            rptOrders.DataSource = pagedOrders;
            rptOrders.DataBind();

            litTotalTop.Text = totalCount.ToString();
            litShowingTop.Text = totalCount == 0 ? "0" : $"{((CurrentPage - 1) * PageSize) + 1}–{Math.Min(CurrentPage * PageSize, totalCount)}";

            // Centered pagination
            pnlOrdersPagination.Visible = totalPages > 1;
            if (totalPages > 1)
            {
                lnkOrdersPrev.CssClass = "admin-pagination-btn" + (CurrentPage <= 1 ? " disabled" : "");
                lnkOrdersNext.CssClass = "admin-pagination-btn" + (CurrentPage >= totalPages ? " disabled" : "");

                var pageLinks = PaginationHelper.BuildPageLinks(CurrentPage, totalPages, i => i.ToString());
                rptOrdersPages.DataSource = pageLinks;
                rptOrdersPages.DataBind();
            }

            UpdateTabButtonStyles();
        }

        protected void OrdersPage_Change(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                string arg = btn.CommandArgument;
                if (arg == "prev")
                {
                    CurrentPage = Math.Max(1, CurrentPage - 1);
                }
                else if (arg == "next")
                {
                    CurrentPage++;
                }
                else if (int.TryParse(arg, out int p))
                {
                    CurrentPage = p;
                }
                RegisterAsyncTask(new PageAsyncTask(LoadOrdersDataAsync));
            }
        }

        protected void FilterTab_Click(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                CurrentStatus = btn.CommandArgument;
                CurrentPage = 1;
                RegisterAsyncTask(new PageAsyncTask(LoadOrdersDataAsync));
            }
        }

        protected void ApplyDateFilter_Click(object sender, EventArgs e)
        {
            if (DateTime.TryParseExact(txtOrderDate.Text, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var orderDate))
            {
                CurrentOrderDate = orderDate.Date;
            }
            else
            {
                CurrentOrderDate = null;
                txtOrderDate.Text = string.Empty;
            }

            CurrentPage = 1;
            RegisterAsyncTask(new PageAsyncTask(LoadOrdersDataAsync));
        }

        private void UpdateTabButtonStyles()
        {
            btnTabAll.CssClass = "admin-tab-btn" + (CurrentStatus == "all" ? " active" : "");
            btnTabProcessing.CssClass = "admin-tab-btn" + (CurrentStatus == "Processing" ? " active" : "");
            btnTabReady.CssClass = "admin-tab-btn" + (CurrentStatus == "ReadyForPickup" ? " active" : "");
            btnTabShipped.CssClass = "admin-tab-btn" + (CurrentStatus == "Shipped" ? " active" : "");
            btnTabCompleted.CssClass = "admin-tab-btn" + (CurrentStatus == "Completed" ? " active" : "");
            btnTabPending.CssClass = "admin-tab-btn" + (CurrentStatus == "PendingPayment" ? " active" : "");
        }

        protected void rptOrders_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            string arg = Convert.ToString(e.CommandArgument);
            if (string.IsNullOrEmpty(arg))
            {
                arg = Request["__EVENTARGUMENT"];
            }

            string targetStatus = e.CommandName;
            int orderId = 0;

            if (arg != null && arg.Contains("$"))
            {
                var parts = arg.Split('$');
                if (parts.Length >= 2 && int.TryParse(parts[1], out int parsedId))
                {
                    targetStatus = parts[0];
                    orderId = parsedId;
                }
            }
            else if (int.TryParse(arg, out int parsedId))
            {
                orderId = parsedId;
            }

            if (orderId > 0 && !string.IsNullOrWhiteSpace(targetStatus))
            {
                RegisterAsyncTask(new PageAsyncTask(async () =>
                {
                    try
                    {
                        await _adminRepo.UpdateOrderStatusAsync(orderId, targetStatus).ConfigureAwait(false);
                    }
                    catch (Exception)
                    {
                        // handled gracefully
                    }
                    await LoadOrdersDataAsync().ConfigureAwait(false);
                }));
            }
        }

        protected string RenderSourceBadge(string source)
        {
            if (source == "INSTORE_POS")
            {
                return "<span class=\"admin-badge\">POS Counter</span>";
            }
            return "<span class=\"admin-badge\">Online Store</span>";
        }

        protected string RenderDeliveryCell(string shippingMethod, string shippingRegion, string courier, string trackingNumber)
        {
            if (string.Equals(shippingMethod, "Delivery", StringComparison.OrdinalIgnoreCase))
            {
                return "<span>Delivery</span>";
            }
            return "<span>Store Pickup</span>";
        }

        protected string RenderFulfillmentCell(string shippingMethod, string shippingRegion, string courier, string trackingNumber)
        {
            return RenderDeliveryCell(shippingMethod, shippingRegion, courier, trackingNumber);
        }

        protected string RenderPaymentBadge(string paymentStatus, string paymentMethod)
        {
            if (paymentStatus == "Completed")
            {
                return "<span>Paid</span>";
            }
            if (string.Equals(paymentMethod, "CashOnDelivery", StringComparison.OrdinalIgnoreCase))
            {
                return "<span>COD Pending</span>";
            }
            return "<span>Pending</span>";
        }

        protected string RenderStatusBadge(string status)
        {
            switch (status)
            {
                case "Completed":
                    return "<span class=\"admin-badge admin-badge--completed\">Completed</span>";
                case "ReadyForPickup":
                    return "<span class=\"admin-badge admin-badge--ready\">Ready for Pickup</span>";
                case "Shipped":
                    return "<span class=\"admin-badge admin-badge--shipped\">In Transit</span>";
                case "Delivered":
                    return "<span class=\"admin-badge admin-badge--delivered\">Delivered</span>";
                case "Processing":
                    return "<span class=\"admin-badge admin-badge--processing\">Preparing Order</span>";
                case "PendingPayment":
                    return "<span class=\"admin-badge admin-badge--pending\">Pending Payment</span>";
                case "Cancelled":
                    return "<span class=\"admin-badge admin-badge--cancelled\">Cancelled</span>";
                default:
                    return $"<span class=\"admin-badge\">{Server.HtmlEncode(status)}</span>";
            }
        }

        protected string RenderTransitionButton(int orderId, string status, string paymentStatus, string shippingMethod, decimal totalAmount, string paymentMethod, string orderNumber, string customerName, string city)
        {
            bool isDelivery = string.Equals(shippingMethod, "Delivery", StringComparison.OrdinalIgnoreCase);
            string safeCity = Server.HtmlEncode(string.IsNullOrEmpty(city) ? "Customer Address" : city).Replace("'", "\\'");
            string safeOrderNo = Server.HtmlEncode(orderNumber ?? "").Replace("'", "\\'");
            string safeCustomer = Server.HtmlEncode(customerName ?? "").Replace("'", "\\'");

            if (status == "Processing")
            {
                if (isDelivery)
                {
                    return $"<button type=\"button\" onclick=\"openDispatchModal({orderId}, '{safeOrderNo}', '{safeCustomer}', '{safeCity}'); return false;\" class=\"btn-pill-sm btn-pill--primary\"><svg viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"1\" y=\"3\" width=\"15\" height=\"13\"></rect><polygon points=\"16 8 20 8 23 11 23 16 16 16 16 8\"></polygon><circle cx=\"5.5\" cy=\"18.5\" r=\"2.5\"></circle><circle cx=\"18.5\" cy=\"18.5\" r=\"2.5\"></circle></svg><span>Dispatch</span></button>";
                }
                return $"<button type=\"button\" onclick=\"__doPostBack('ctl00$MainContent$rptOrders','ReadyForPickup${orderId}'); return false;\" class=\"btn-pill-sm btn-pill--primary\"><svg viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"20 6 9 17 4 12\"></polyline></svg><span>Mark Ready</span></button>";
            }
            if (status == "ReadyForPickup")
            {
                return $"<button type=\"button\" onclick=\"__doPostBack('ctl00$MainContent$rptOrders','Completed${orderId}'); return false;\" class=\"btn-pill-sm btn-pill--outline\"><svg viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><polyline points=\"22 4 12 14.01 9 11.01\"></polyline></svg><span>Collected</span></button>";
            }
            if (status == "Shipped")
            {
                bool isCod = string.Equals(paymentMethod, "CashOnDelivery", StringComparison.OrdinalIgnoreCase);
                if (isCod)
                {
                    return $"<button type=\"button\" onclick=\"__doPostBack('ctl00$MainContent$rptOrders','Completed${orderId}'); return false;\" class=\"btn-pill-sm btn-pill--primary\"><svg viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><polyline points=\"22 4 12 14.01 9 11.01\"></polyline></svg><span>Mark Fulfilled</span></button>";
                }

                return $"<button type=\"button\" onclick=\"__doPostBack('ctl00$MainContent$rptOrders','Delivered${orderId}'); return false;\" class=\"btn-pill-sm btn-pill--primary\"><svg viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"20 6 9 17 4 12\"></polyline></svg><span>Mark Delivered</span></button>";
            }
            if (status == "Delivered")
            {
                return $"<button type=\"button\" onclick=\"__doPostBack('ctl00$MainContent$rptOrders','Completed${orderId}'); return false;\" class=\"btn-pill-sm btn-pill--outline\"><svg viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><polyline points=\"22 4 12 14.01 9 11.01\"></polyline></svg><span>Finalize</span></button>";
            }
            return "<span class=\"admin-activity-time\">&mdash;</span>";
        }

        protected void btnExportOrders_Click(object sender, EventArgs e)
        {
            RegisterAsyncTask(new PageAsyncTask(async () =>
            {
                string status = CurrentStatus == "all" ? null : CurrentStatus;
                var orders = await _adminRepo.GetOrdersAsync(null, status, null, 500, CurrentOrderDate).ConfigureAwait(false);
                var sb = new StringBuilder();
                sb.AppendLine("OrderId,OrderNumber,CustomerName,Email,Phone,Source,Fulfillment,ShippingFee,Courier,TrackingNumber,Items,TotalAmount,PaymentStatus,PaymentMethod,OrderStatus,CreatedAt");

                foreach (var o in orders)
                {
                    sb.AppendLine($"\"{o.Id}\",\"{o.OrderNumber}\",\"{o.CustomerName.Replace("\"", "\"\"")}\",\"{o.CustomerEmail}\",\"{o.CustomerPhone}\",\"{o.OrderSource}\",\"{o.ShippingMethod}\",{o.ShippingFee},\"{o.Courier}\",\"{o.TrackingNumber}\",{o.ItemCount},{o.TotalAmount},\"{o.PaymentStatus}\",\"{o.PaymentMethod}\",\"{o.Status}\",\"{o.CreatedAt:yyyy-MM-dd HH:mm}\"");
                }

                Response.Clear();
                Response.Buffer = true;
                Response.AddHeader("content-disposition", "attachment;filename=HelmetCartel_Orders.csv");
                Response.Charset = "utf-8";
                Response.ContentType = "text/csv";
                Response.Output.Write(sb.ToString());
                Response.Flush();
                Response.End();
            }));
        }
    }
}
