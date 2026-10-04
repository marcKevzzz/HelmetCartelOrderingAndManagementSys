<%@ Page Title="Shop Helmets & Riding Gear" EnableViewState="false" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Shop.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.ShopPage" ResponseEncoding="utf-8" Async="true" %>
<%@ Register Src="~/Pages/Storefront/Shop/ProductFilterControl.ascx" TagPrefix="hc" TagName="ProductFilter" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="container shop-catalog-container">
        <!-- Breadcrumb Matching Shop.co Image 4 -->
        <nav class="shop-breadcrumb" aria-label="Breadcrumb">
            <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="shop-breadcrumb__link">Home</asp:HyperLink>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2">
                <polyline points="9 18 15 12 9 6"></polyline>
            </svg>
            <span class="shop-breadcrumb__current">Shop</span>
        </nav>

        <button type="button" class="shop-mobile-filter-toggle" id="shop-mobile-filter-toggle" aria-controls="shop-filter-panel" aria-expanded="false">
            <span>Filters</span>
            <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><line x1="4" y1="7" x2="20" y2="7"></line><line x1="7" y1="12" x2="17" y2="12"></line><line x1="10" y1="17" x2="14" y2="17"></line></svg>
        </button>
        <div class="shop-catalog-layout">
            <!-- Sidebar User Control Component (295px width) -->
            <hc:ProductFilter ID="ProductFilterCtrl" runat="server" />

            <!-- Product Listing (3 Columns) -->
            <section>
                <!-- Catalog Header -->
                <div class="shop-header">
                    <h1 class="shop-header__title"><%= Server.HtmlEncode(CatalogHeading) %></h1>
                    <div class="shop-header__meta">
                        <span id="shop-products-count"><asp:Literal ID="litProductsCount" runat="server" /></span>
                        <div class="shop-header__sort" id="shop-sort-dropdown-wrap">
                            <button type="button" class="shop-sort-btn" id="shop-sort-btn" aria-label="Sort products">
                                <span>Sort by: <strong id="current-sort-label">Most Popular</strong></span>
                                <svg class="shop-header__sort-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <polyline points="6 9 12 15 18 9"></polyline>
                                </svg>
                            </button>
                            <div class="shop-sort-menu" id="shop-sort-menu">
                                <button type="button" class="shop-sort-option active" data-sort="popular">Most Popular</button>
                                <button type="button" class="shop-sort-option" data-sort="price_asc">Price: Low to High</button>
                                <button type="button" class="shop-sort-option" data-sort="price_desc">Price: High to Low</button>
                                <button type="button" class="shop-sort-option" data-sort="newest">Newest Arrivals</button>
                                <button type="button" class="shop-sort-option" data-sort="rating">Customer Rating</button>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- 3-Column Product Grid -->
                <div class="products-grid-3col" id="catalog-products-grid">
                    <asp:Repeater ID="rptCatalog" runat="server">
                        <ItemTemplate>
                            <article class="product-card product-card--with-favorite" data-product-id='<%# Eval("Id") %>'>
                              <asp:HyperLink runat="server" CssClass="product-card__link" NavigateUrl='<%# "~/Pages/Storefront/ProductDetail/ProductDetail.aspx?slug=" + Eval("Slug") %>'>
                                <div class="product-card__img-wrap">
                                    <img src='<%# System.Web.HttpUtility.HtmlAttributeEncode(HelmetCartelOrderingAndManagementSys.Infrastructure.CatalogImageHelper.GetUrl(Convert.ToString(Eval("MainImageUrl")))) %>' alt='<%# System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("Name"))) %>' class="product-card__img" decoding="async" loading='<%# Container.ItemIndex < 3 ? "eager" : "lazy" %>' />
                                </div>
                                <h3 class="product-card__title"><%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %></h3>
                                <p class="product-card__description"><%# Server.HtmlEncode(Convert.ToString(Eval("Description"))) %></p>
                                <div class="product-card__rating">
                                    <div class="stars">
                                        <%# RenderStars((decimal)Eval("Rating")) %>
                                    </div>
                                    <span class="rating-score"><%# Eval("Rating", "{0:0.0}") %>/5 (<%# Eval("ReviewCount") %>)</span>
                                </div>
                                <div class="product-card__pricing">
                                    <%# RenderPricingHtml(Eval("BasePrice"), Eval("EffectivePrice"), Eval("HasActiveDiscount"), Eval("DiscountPercentage"), Eval("DiscountBadgeText")) %>
                                </div>
                              </asp:HyperLink>
                              <button type="button" class="product-card__fav-btn" data-fav-id='<%# Eval("Id") %>' aria-label="Toggle Wishlist" title="Save to Wishlist">
                                  <svg class="heart-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path></svg>
                              </button>
                            </article>
                        </ItemTemplate>
                    </asp:Repeater>
                    <asp:Panel ID="pnlNoProducts" runat="server" CssClass="empty-catalog-message" Visible="false">
                        <p>No helmets match your selected filters.</p>
                        <a href="Shop.aspx" class="btn btn--outline btn--sm">View All Helmets</a>
                    </asp:Panel>
                </div>

                <!-- Pagination Matching Shop.co Image 4 -->
                <asp:Panel ID="pnlPagination" runat="server" CssClass="catalog-pagination" Visible="false">
                    <a id="lnkPrev" runat="server" class="pagination-btn pagination-btn--prev">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <line x1="19" y1="12" x2="5" y2="12"></line>
                            <polyline points="12 19 5 12 12 5"></polyline>
                        </svg>
                        Previous
                    </a>
                    <div class="pagination-pages">
                        <asp:Repeater ID="rptPages" runat="server">
                            <ItemTemplate>
                                <asp:PlaceHolder runat="server" Visible='<%# !(bool)Eval("IsEllipsis") %>'>
                                    <a href='<%# Eval("Url") %>' class='pagination-page <%# Eval("CssClass") %>' aria-current='<%# (bool)Eval("IsCurrent") ? "page" : "false" %>'><%# Eval("Number") %></a>
                                </asp:PlaceHolder>
                                <asp:PlaceHolder runat="server" Visible='<%# (bool)Eval("IsEllipsis") %>'>
                                    <span class="pagination-ellipsis">&hellip;</span>
                                </asp:PlaceHolder>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                    <a id="lnkNext" runat="server" class="pagination-btn pagination-btn--next">
                        Next
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <line x1="5" y1="12" x2="19" y2="12"></line>
                            <polyline points="12 5 19 12 12 19"></polyline>
                        </svg>
                    </a>
                </asp:Panel>
            </section>
        </div>
    </div>

    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/storefront.js?v=20261004") %>'></script>
</asp:Content>
