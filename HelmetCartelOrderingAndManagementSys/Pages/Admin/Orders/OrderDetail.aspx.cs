using System;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Web.UI;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Pages.Admin.Orders
{
    public partial class OrderDetail : Page
    {
        private readonly OrderRepository _orderRepo;
        private readonly AdminDataRepository _adminRepo;

        protected int OrderId
        {
            get => ViewState["OrderId"] != null ? (int)ViewState["OrderId"] : 0;
            set => ViewState["OrderId"] = value;
        }

        public OrderDetail()
        {
            var dbFactory = new DbConnectionFactory();
            _orderRepo = new OrderRepository(dbFactory);
            _adminRepo = new AdminDataRepository(dbFactory);
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                if (int.TryParse(Request.QueryString["id"], out int id) && id > 0)
                {
                    OrderId = id;
                    RegisterAsyncTask(new PageAsyncTask(() => LoadOrderDetailsAsync(id)));
                }
                else
                {
                    ShowNotFound();
                }
            }
            else
            {
                // Handle status postbacks
                string eventTarget = Request["__EVENTTARGET"];
                string eventArg = Request["__EVENTARGUMENT"];
                if (!string.IsNullOrEmpty(eventTarget) && eventTarget.Contains("btnActionStatus") && !string.IsNullOrEmpty(eventArg))
                {
                    string targetStatus = eventArg;
                    if (OrderId > 0 && !string.IsNullOrWhiteSpace(targetStatus))
                    {
                        RegisterAsyncTask(new PageAsyncTask(async () =>
                        {
                            try
                            {
                                await _adminRepo.UpdateOrderStatusAsync(OrderId, targetStatus).ConfigureAwait(false);
                                try
                                {
                                    var orderHub = Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<Hubs.OrderHub>();
                                    orderHub.Clients.All.orderUpdated(new { orderId = OrderId, status = targetStatus });
                                }
                                catch { }
                            }
                            catch { }

                            await LoadOrderDetailsAsync(OrderId).ConfigureAwait(false);
                        }));
                    }
                }
            }
        }

        private async Task LoadOrderDetailsAsync(int id)
        {
            var order = await _orderRepo.GetOrderByIdAsync(id).ConfigureAwait(false);
            if (order == null)
            {
                ShowNotFound();
                return;
            }

            pnlNotFound.Visible = false;
            pnlOrderContent.Visible = true;

            litOrderNumberTitle.Text = Server.HtmlEncode(order.OrderNumber);
            litCreatedAt.Text = order.CreatedAt.ToString("MMMM dd, yyyy h:mm tt");
            litOrderSource.Text = order.OrderSource == "INSTORE_POS" ? "POS Counter" : "Online Store";

            // Header Badges - Payment Status badge and Fulfillment/Order Status badge
            string paymentBadge = RenderPaymentBadge(order.PaymentStatus, order.PaymentMethod);
            string statusBadge = RenderStatusBadge(order.Status);
            litHeaderBadges.Text = $"{paymentBadge} {statusBadge}";

            // Action Buttons
            litActionButtons.Text = RenderActionButtons(order);

            // Items
            litItemCount.Text = (order.Items != null ? order.Items.Count : 0).ToString();
            rptOrderItems.DataSource = order.Items;
            rptOrderItems.DataBind();

            // Financials
            litSubtotal.Text = order.Subtotal.ToString("N2");
            litDeliveryFee.Text = order.ShippingFee.ToString("N2");
            if (order.DiscountAmount > 0)
            {
                phDiscount.Visible = true;
                litDiscount.Text = order.DiscountAmount.ToString("N2");
            }
            else
            {
                phDiscount.Visible = false;
            }
            litTotalAmount.Text = order.TotalAmount.ToString("N2");

            // Special notes
            if (!string.IsNullOrWhiteSpace(order.DeliveryNotes))
            {
                phNotes.Visible = true;
                litDeliveryNotes.Text = Server.HtmlEncode(order.DeliveryNotes);
            }
            else
            {
                phNotes.Visible = false;
            }

            // Customer
            litCustomerName.Text = Server.HtmlEncode(order.CustomerName ?? "Valued Customer");
            litCustomerEmail.Text = Server.HtmlEncode(order.CustomerEmail ?? "N/A");
            litCustomerPhone.Text = Server.HtmlEncode(order.CustomerPhone ?? "N/A");
            litCustomerChannel.Text = order.OrderSource == "INSTORE_POS" ? "In-Store POS" : "Online Storefront";

            // Delivery & Address
            bool isDelivery = string.Equals(order.ShippingMethod, "Delivery", StringComparison.OrdinalIgnoreCase);
            if (litDeliveryMethod != null) litDeliveryMethod.Text = isDelivery ? "Door-to-Door Delivery" : "Store Pickup (QC Flagship Hub)";
            if (litShippingSectionTitle != null) litShippingSectionTitle.Text = isDelivery ? "Shipping Address" : "Pickup Location";
            if (litShippingRecipient != null) litShippingRecipient.Text = Server.HtmlEncode(order.CustomerName ?? "Valued Customer");
            if (litKpiDeliveryMethod != null) litKpiDeliveryMethod.Text = isDelivery ? "Delivery" : "Store Pickup";

            int totalUnits = 0;
            if (order.Items != null)
            {
                foreach (var item in order.Items)
                {
                    totalUnits += item.Quantity;
                }
            }
            if (litSummaryItemCount != null) litSummaryItemCount.Text = totalUnits.ToString();

            string paymentText = order.PaymentStatus == "Completed" ? "Paid" :
                (string.Equals(order.PaymentMethod, "CashOnDelivery", StringComparison.OrdinalIgnoreCase) ? "COD Pending" : "Pending");
            if (litKpiPaymentStatus != null) litKpiPaymentStatus.Text = Server.HtmlEncode(paymentText);

            if (litKpiOrderStatus != null) litKpiOrderStatus.Text = RenderStatusBadge(order.Status);

            decimal paidAmount = string.Equals(order.PaymentStatus, "Completed", StringComparison.OrdinalIgnoreCase) ? order.TotalAmount : 0m;
            if (litPaidAmountText != null) litPaidAmountText.Text = $"&#8369;{paidAmount:N2}";

            if (isDelivery)
            {
                var addressParts = new StringBuilder();
                if (!string.IsNullOrWhiteSpace(order.ShippingAddress)) addressParts.Append(order.ShippingAddress);
                if (!string.IsNullOrWhiteSpace(order.ShippingBarangay)) addressParts.Append($", Brgy. {order.ShippingBarangay}");
                if (!string.IsNullOrWhiteSpace(order.ShippingCity)) addressParts.Append($", {order.ShippingCity}");
                if (!string.IsNullOrWhiteSpace(order.ShippingProvince)) addressParts.Append($", {order.ShippingProvince}");
                if (!string.IsNullOrWhiteSpace(order.ShippingPostalCode)) addressParts.Append($" {order.ShippingPostalCode}");
                litFullAddress.Text = Server.HtmlEncode(addressParts.ToString());

                if (!string.IsNullOrWhiteSpace(order.Courier) || !string.IsNullOrWhiteSpace(order.TrackingNumber))
                {
                    phCourierInfo.Visible = true;
                    litCourier.Text = Server.HtmlEncode(order.Courier ?? "Standard Courier");
                    litTrackingNumber.Text = Server.HtmlEncode(order.TrackingNumber ?? "N/A");
                }
                else
                {
                    phCourierInfo.Visible = false;
                }
            }
            else
            {
                litFullAddress.Text = "Helmet Cartel QC Flagship Hub &mdash; 107 Kamuning Rd, Quezon City, Metro Manila";
                phCourierInfo.Visible = false;
            }

            // Payment
            string paymentMethodDisplay = order.PaymentMethod;
            if (string.Equals(order.PaymentMethod, "HitPay", StringComparison.OrdinalIgnoreCase))
                paymentMethodDisplay = "HitPay Online (QR Ph / GCash / Maya)";
            else if (string.Equals(order.PaymentMethod, "CashOnDelivery", StringComparison.OrdinalIgnoreCase))
                paymentMethodDisplay = "Cash on Delivery (COD)";
            else if (string.Equals(order.PaymentMethod, "Cash", StringComparison.OrdinalIgnoreCase))
                paymentMethodDisplay = "Cash Payment";

            litPaymentMethod.Text = Server.HtmlEncode(paymentMethodDisplay ?? "Pending Method");
            litPaymentStatus.Text = Server.HtmlEncode(order.PaymentStatus ?? "Pending");
        }

        private void ShowNotFound()
        {
            pnlNotFound.Visible = true;
            pnlOrderContent.Visible = false;
            litOrderNumberTitle.Text = "Not Found";
        }

        protected string ResolveItemImage(object imgObj)
        {
            string url = Convert.ToString(imgObj);
            if (string.IsNullOrWhiteSpace(url))
            {
                return "/Content/images/placeholder-helmet.png";
            }
            return url;
        }

        private string RenderStatusBadge(string status)
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

        private string RenderPaymentBadge(string paymentStatus, string paymentMethod)
        {
            if (paymentStatus == "Completed")
            {
                return "<span class=\"admin-badge admin-badge--in-stock\">Paid</span>";
            }
            if (string.Equals(paymentMethod, "CashOnDelivery", StringComparison.OrdinalIgnoreCase))
            {
                return "<span class=\"admin-badge admin-badge--role-staff\">COD Pending</span>";
            }
            return "<span class=\"admin-badge admin-badge--pending\">Pending</span>";
        }

        private string RenderDeliveryBadge(string shippingMethod)
        {
            if (string.Equals(shippingMethod, "Delivery", StringComparison.OrdinalIgnoreCase))
            {
                return "<span class=\"admin-badge admin-badge--ready\">Delivery</span>";
            }
            return "<span class=\"admin-badge admin-badge--pending\">Pickup</span>";
        }

        private string RenderActionButtons(OrderSummaryDto order)
        {
            bool isDelivery = string.Equals(order.ShippingMethod, "Delivery", StringComparison.OrdinalIgnoreCase);

            if (order.Status == "Processing")
            {
                if (isDelivery)
                {
                    return "<button type=\"button\" onclick=\"openDispatchModal(); return false;\" class=\"btn-pill btn-pill--primary\"><svg viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"1\" y=\"3\" width=\"15\" height=\"13\"></rect><polygon points=\"16 8 20 8 23 11 23 16 16 16 16 8\"></polygon><circle cx=\"5.5\" cy=\"18.5\" r=\"2.5\"></circle><circle cx=\"18.5\" cy=\"18.5\" r=\"2.5\"></circle></svg><span>Dispatch Order</span></button>";
                }
                return "<button type=\"button\" onclick=\"__doPostBack('btnActionStatus','ReadyForPickup'); return false;\" class=\"btn-pill btn-pill--primary\"><svg viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"20 6 9 17 4 12\"></polyline></svg><span>Mark Ready for Pickup</span></button>";
            }
            if (order.Status == "ReadyForPickup")
            {
                return "<button type=\"button\" onclick=\"__doPostBack('btnActionStatus','Completed'); return false;\" class=\"btn-pill btn-pill--primary\"><svg viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><polyline points=\"22 4 12 14.01 9 11.01\"></polyline></svg><span>Mark Collected</span></button>";
            }
            if (order.Status == "Shipped")
            {
                bool isCod = string.Equals(order.PaymentMethod, "CashOnDelivery", StringComparison.OrdinalIgnoreCase);
                if (isCod)
                {
                    return "<button type=\"button\" onclick=\"__doPostBack('btnActionStatus','Completed'); return false;\" class=\"btn-pill btn-pill--primary\"><svg viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><polyline points=\"22 4 12 14.01 9 11.01\"></polyline></svg><span>Mark Fulfilled (Delivered &amp; Paid)</span></button>";
                }

                return "<button type=\"button\" onclick=\"__doPostBack('btnActionStatus','Delivered'); return false;\" class=\"btn-pill btn-pill--primary\"><svg viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"20 6 9 17 4 12\"></polyline></svg><span>Mark Delivered</span></button>";
            }
            if (order.Status == "Delivered")
            {
                return "<button type=\"button\" onclick=\"__doPostBack('btnActionStatus','Completed'); return false;\" class=\"btn-pill btn-pill--outline\"><svg viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><polyline points=\"22 4 12 14.01 9 11.01\"></polyline></svg><span>Finalize Order</span></button>";
            }

            return string.Empty;
        }

        protected void btnConfirmDispatch_Click(object sender, EventArgs e)
        {
            if (OrderId <= 0) return;

            string courier = txtCourier.Text.Trim();
            string tracking = txtTrackingNumber.Text.Trim();

            RegisterAsyncTask(new PageAsyncTask(async () =>
            {
                try
                {
                    await _adminRepo.UpdateOrderStatusAsync(OrderId, "Shipped", null, courier, tracking).ConfigureAwait(false);
                    try
                    {
                        var orderHub = Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<Hubs.OrderHub>();
                        orderHub.Clients.All.orderUpdated(new { orderId = OrderId, status = "Shipped", courier = courier, trackingNumber = tracking });
                    }
                    catch { }
                }
                catch { }

                await LoadOrderDetailsAsync(OrderId).ConfigureAwait(false);
            }));
        }
    }
}
