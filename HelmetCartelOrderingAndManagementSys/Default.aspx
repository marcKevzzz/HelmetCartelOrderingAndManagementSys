<%@ Page Title="Find Helmets That Match Your Style" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Default" ResponseEncoding="utf-8" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <!-- 1. HERO SECTION (Shop.co Layout & Proportions) -->
    <section class="hero-section">
        <div class="container hero-grid">
            <div class="hero-content">
                <h1 class="hero-content__title">FIND HELMETS Matching<br />YOUR STYLE</h1>
                <p class="hero-content__desc">
                    Browse helmets and riding gear by brand, size, and color. Check each product's specifications to find the right fit.
                </p>
                <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx" CssClass="btn--hero">
                    <span>Shop Now</span>
                    <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="7" y1="17" x2="17" y2="7"></line>
                        <polyline points="7 7 17 7 17 17"></polyline>
                    </svg>
                </asp:HyperLink>

                <div class="hero-stats">
                    <div class="hero-stat">
                        <div class="hero-stat__number"><asp:Literal ID="litBrandsCount" runat="server">0</asp:Literal></div>
                        <div class="hero-stat__label">Top Brands</div>
                    </div>
                    <div class="hero-stat">
                        <div class="hero-stat__number"><asp:Literal ID="litHelmetsCount" runat="server">0</asp:Literal></div>
                        <div class="hero-stat__label">High-Quality Helmets</div>
                    </div>
                    <div class="hero-stat">
                        <div class="hero-stat__number"><asp:Literal ID="litRidersCount" runat="server">0</asp:Literal></div>
                        <div class="hero-stat__label">Completed Orders</div>
                    </div>
                </div>
            </div>

            <div class="hero-media">
                <img runat="server" src="~/Content/images/hero_img.png" 
                     alt="Helmet Cartel Style Showcase" 
                     class="hero-media__img" />
                
                <!-- 4-point decorative star vector accents matching design template -->
                <svg class="hero-star-vector hero-star-vector--lg" viewBox="0 0 104 104" fill="currentColor">
                    <path d="M52 0C53.7654 27.955 76.0448 50.2346 104 52C76.0448 53.7654 53.7654 76.0448 52 104C50.2346 76.0448 27.9552 53.7654 0 52C27.9552 50.2346 50.2346 27.955 52 0Z"/>
                </svg>
                <svg class="hero-star-vector hero-star-vector--sm" viewBox="0 0 104 104" fill="currentColor">
                    <path d="M52 0C53.7654 27.955 76.0448 50.2346 104 52C76.0448 53.7654 53.7654 76.0448 52 104C50.2346 76.0448 27.9552 53.7654 0 52C27.9552 50.2346 50.2346 27.955 52 0Z"/>
                </svg>
            </div>
        </div>
    </section>

    <!-- 2. BRAND TICKER STRIP -->
    <div class="brand-ticker" id="brands">
        <div class="container">
            <div class="brand-ticker__list">
                <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx?brand=Zebra" CssClass="brand-ticker__item" ToolTip="View Zebra Gear">
                    <img runat="server" src="~/Content/images/zebra.png" alt="Zebra" class="brand-logo-img" />
                </asp:HyperLink>
                <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx?brand=Gille" CssClass="brand-ticker__item" ToolTip="View Gille Helmets">
                    <img runat="server" src="~/Content/images/gille.png" alt="Gille" class="brand-logo-img" />
                </asp:HyperLink>
                <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx?brand=HNJ" CssClass="brand-ticker__item" ToolTip="View HNJ Top Boxes &amp; Gear">
                    <img runat="server" src="~/Content/images/hnj.png" alt="HNJ" class="brand-logo-img" />
                </asp:HyperLink>
                <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx?brand=Shoei" CssClass="brand-ticker__item" ToolTip="View Shoei Helmets">
                    <img runat="server" src="~/Content/images/shoei.png" alt="Shoei Japan" class="brand-logo-img" />
                </asp:HyperLink>
                <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx?brand=AGV" CssClass="brand-ticker__item" ToolTip="View AGV Helmets">
                    <img runat="server" src="~/Content/images/agv.png" alt="AGV" class="brand-logo-img avg" />
                </asp:HyperLink>
            </div>
        </div>
    </div>

    <!-- 3. NEW ARRIVALS SECTION -->
    <section class="container section--new-arrivals" id="new-arrivals">
        <div class="section-header">
            <h2 class="section-title">NEW ARRIVALS</h2>
        </div>
        <div class="products-grid" id="new-arrivals-grid">
            <asp:Repeater ID="rptNewArrivals" runat="server">
                <ItemTemplate>
                    <asp:HyperLink runat="server" CssClass="product-card" NavigateUrl='<%# "~/Pages/Storefront/ProductDetail/ProductDetail.aspx?slug=" + Eval("Slug") %>'>
                        <div class="product-card__img-wrap">
                            <img src="<%# Eval("MainImageUrl") %>" alt="<%# Server.HtmlEncode((string)Eval("Name")) %>" class="product-card__img" loading="lazy" />
                        </div>
                        <h3 class="product-card__title"><%# Server.HtmlEncode((string)Eval("Name")) %></h3>
                        <p class="product-card__description"><%# Server.HtmlEncode(Convert.ToString(Eval("Description"))) %></p>
                        <div class="product-card__rating">
                            <div class="stars">
                                <%# RenderStars((decimal)Eval("Rating")) %>
                            </div>
                            <span class="rating-score"><%# Eval("Rating", "{0:0.0}") %>/5</span>
                        </div>
                        <div class="product-card__price">
                            <span class="price-current">&#8369;<%# Eval("EffectivePrice", "{0:N0}") %></span>
                            <%# (decimal)Eval("EffectivePrice") < (decimal)Eval("BasePrice") ? "<span class=\"price-original\">&#8369;" + string.Format("{0:N0}", Eval("BasePrice")) + "</span><span class=\"discount-badge\">" + Eval("DiscountBadgeText") + "</span>" : "" %>
                        </div>
                    </asp:HyperLink>
                </ItemTemplate>
            </asp:Repeater>
        </div>
        <div class="section-action">
            <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx" CssClass="btn btn--outline">
                <span>View All</span>
                <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="7" y1="17" x2="17" y2="7"></line>
                    <polyline points="7 7 17 7 17 17"></polyline>
                </svg>
            </asp:HyperLink>
        </div>
    </section>

    <hr class="section-divider" />

    <!-- 4. TOP SELLING SECTION -->
    <section class="container section--top-selling" id="top-selling">
        <div class="section-header">
            <h2 class="section-title">TOP SELLING</h2>
        </div>
        <div class="products-grid" id="top-selling-grid">
            <asp:Repeater ID="rptTopSelling" runat="server">
                <ItemTemplate>
                    <asp:HyperLink runat="server" CssClass="product-card" NavigateUrl='<%# "~/Pages/Storefront/ProductDetail/ProductDetail.aspx?slug=" + Eval("Slug") %>'>
                        <div class="product-card__img-wrap">
                            <img src="<%# Eval("MainImageUrl") %>" alt="<%# Server.HtmlEncode((string)Eval("Name")) %>" class="product-card__img" loading="lazy" />
                        </div>
                        <h3 class="product-card__title"><%# Server.HtmlEncode((string)Eval("Name")) %></h3>
                        <p class="product-card__description"><%# Server.HtmlEncode(Convert.ToString(Eval("Description"))) %></p>
                        <div class="product-card__rating">
                            <div class="stars">
                                <%# RenderStars((decimal)Eval("Rating")) %>
                            </div>
                            <span class="rating-score"><%# Eval("Rating", "{0:0.0}") %>/5</span>
                        </div>
                        <div class="product-card__price">
                            <span class="price-current">&#8369;<%# Eval("EffectivePrice", "{0:N0}") %></span>
                            <%# (decimal)Eval("EffectivePrice") < (decimal)Eval("BasePrice") ? "<span class=\"price-original\">&#8369;" + string.Format("{0:N0}", Eval("BasePrice")) + "</span><span class=\"discount-badge\">" + Eval("DiscountBadgeText") + "</span>" : "" %>
                        </div>
                    </asp:HyperLink>
                </ItemTemplate>
            </asp:Repeater>
        </div>
        <div class="section-action">
            <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx" CssClass="btn btn--outline">
                <span>View All</span>
                <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="7" y1="17" x2="17" y2="7"></line>
                    <polyline points="7 7 17 7 17 17"></polyline>
                </svg>
            </asp:HyperLink>
        </div>
    </section>

    <!-- 5. BROWSE BY RIDING STYLE (Bento Box with Minimal Edge Curves) -->
    <section class="container bento-section" id="riding-styles">
        <div class="bento-wrapper">
            <h2 class="bento-title">BROWSE BY RIDING STYLE</h2>
            <div class="bento-grid">
                <asp:HyperLink runat="server" CssClass="bento-card bento-card--span-4" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx">
                    <div class="bento-card__title">Casual</div>
                    <img runat="server" src="~/Content/images/casual.png" alt="Casual Urban" class="bento-card__bg-img casual" />
                </asp:HyperLink>
                <asp:HyperLink runat="server" CssClass="bento-card bento-card--span-8" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx">
                    <div class="bento-card__title">Sport / Track</div>
                    <img runat="server" src="~/Content/images/track.png" alt="Sport Track" class="bento-card__bg-img sport" />
                </asp:HyperLink>
                <asp:HyperLink runat="server" CssClass="bento-card bento-card--span-8" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx">
                    <div class="bento-card__title">Touring / Adventure</div>
                    <img runat="server" src="~/Content/images/touring.png" alt="Touring Adventure" class="bento-card__bg-img touring" />
                </asp:HyperLink>
                <asp:HyperLink runat="server" CssClass="bento-card bento-card--span-4" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx">
                    <div class="bento-card__title">Off-Road</div>
                    <img runat="server" src="~/Content/images/offroad.png" alt="Off-Road Dirt" class="bento-card__bg-img offroad" />
                </asp:HyperLink>
            </div>
        </div>
    </section>

    <!-- 6. OUR HAPPY CUSTOMERS (Testimonials Carousel) -->
    <section class="container testimonials-section">
        <div class="testimonials-header">
            <div>
                <h2 class="section-title section-title--no-margin">OUR HAPPY CUSTOMERS</h2>
                <p class="testimonials-subtitle">Real feedback and track-tested impressions from verified riders across the Philippines.</p>
            </div>
            <div class="testimonials-nav">
                <button type="button" class="carousel-arrow" id="prev-testimonial" aria-label="Previous Reviews">
                    <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="19" y1="12" x2="5" y2="12"></line>
                        <polyline points="12 19 5 12 12 5"></polyline>
                    </svg>
                </button>
                <button type="button" class="carousel-arrow" id="next-testimonial" aria-label="Next Reviews">
                    <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="5" y1="12" x2="19" y2="12"></line>
                        <polyline points="12 5 19 12 12 19"></polyline>
                    </svg>
                </button>
            </div>
        </div>

        <div class="testimonials-viewport">
            <div class="testimonials-track" id="testimonials-track" role="region" aria-label="Customer Testimonials Carousel">
                <asp:Repeater ID="rptHappyCustomers" runat="server">
                    <ItemTemplate>
                        <div class="testimonial-card" data-review-id='<%# Eval("Id") %>'>
                            <div class="testimonial-card__header">
                                <div class="testimonial-card__user">
                                    <div class="testimonial-card__name-row">
                                        <span class="testimonial-card__name"><%# Server.HtmlEncode((string)Eval("ReviewerName")) %></span>
                                        <%# (bool)Eval("IsVerifiedPurchase") ? "<span class=\"verified-badge\" title=\"Verified Customer\"><svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"20 6 9 17 4 12\"></polyline></svg></span>" : "" %>
                                    </div>
                                    <div class="testimonial-card__rating-row">
                                        <span class="testimonial-card__score"><%# Convert.ToDecimal(Eval("Rating")).ToString("0.0") %></span>
                                        <div class="stars" aria-label='<%# Eval("Rating") %> out of 5 stars'>
                                            <%# RenderStars(Convert.ToDecimal(Eval("Rating"))) %>
                                        </div>
                                    </div>
                                </div>
                                <div class="testimonial-card__quote-icon" aria-hidden="true">
                                    <svg viewBox="0 0 24 24" fill="currentColor">
                                        <path d="M14.017 21v-7.391c0-5.704 3.731-9.57 8.983-10.609l.995 2.151c-2.432.917-3.995 3.638-3.995 5.849h4v10h-9.983zm-14.017 0v-7.391c0-5.704 3.748-9.57 9-10.609l.996 2.151c-2.433.917-3.996 3.638-3.996 5.849h3.983v10h-9.983z"/>
                                    </svg>
                                </div>
                            </div>
                            <p class="testimonial-card__text">
                                <%# Server.HtmlEncode((string)Eval("Comment")) %>
                            </p>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </div>
    </section>

    <!-- Client-Side Dynamic Loader -->
    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/storefront.js?v=10") %>'></script>
</asp:Content>
