<%@ Page Title="Your Shopping Cart" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Cart.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.Cart" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="~/Content/css/storefront/storefront.css?v=8" runat="server" />
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="container cart-page-container">
        <!-- Breadcrumb -->
        <nav class="shop-breadcrumb" aria-label="Breadcrumb">
            <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="shop-breadcrumb__link">Home</asp:HyperLink>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
            <span class="shop-breadcrumb__current">Cart</span>
        </nav>

        <h1 class="cart-page-title">YOUR CART</h1>

        <div class="cart-layout">
            <!-- Left: Cart Items -->
            <div class="cart-items-box" id="cart-items-container">
                <div id="empty-cart-msg" class="cart-drawer-empty">
                    <div class="cart-drawer-empty__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <circle cx="9" cy="21" r="1"></circle>
                            <circle cx="20" cy="21" r="1"></circle>
                            <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path>
                        </svg>
                    </div>
                    <h3 class="cart-drawer-empty__title">YOUR CART IS EMPTY</h3>
                    <p class="cart-drawer-empty__desc">Explore our DOT &amp; ECE-certified helmets to protect your next ride.</p>
                    <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx" CssClass="cart-drawer-empty__btn">
                        <span>Explore Catalog</span>
                        <svg class="nav-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                            <line x1="7" y1="17" x2="17" y2="7"></line>
                            <polyline points="7 7 17 7 17 17"></polyline>
                        </svg>
                    </asp:HyperLink>
                </div>
            </div>

            <!-- Right: Order Summary Card -->
            <div class="order-summary-card">
                <h2 class="order-summary-title">Order Summary</h2>

                <div class="order-summary__row">
                    <span class="order-summary__label">Subtotal</span>
                    <strong id="summary-subtotal">&#8369;0</strong>
                </div>

                <div class="order-summary__row">
                    <span class="order-summary__label">Fulfillment</span>
                    <strong>FREE (In-Store Pickup)</strong>
                </div>

                <div class="order-summary__row order-summary__total">
                    <span>Total</span>
                    <span id="summary-total">&#8369;0</span>
                </div>

                <button type="button" id="btn-checkout" class="btn btn--primary btn--block">
                    <span>Go to Checkout</span>
                    <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="7" y1="17" x2="17" y2="7"></line>
                        <polyline points="7 7 17 7 17 17"></polyline>
                    </svg>
                </button>
            </div>
        </div>
    </div>

    <!-- External Storefront Cart Script -->
    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/cart.js?v=1") %>'></script>
</asp:Content>
