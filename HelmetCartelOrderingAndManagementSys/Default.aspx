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
                    Browse through our curated range of rigorously tested, DOT & ECE-certified helmets, engineered to protect your ride and elevate your individuality.
                </p>
                <a href="#new-arrivals" class="btn--hero">
                    <span>Shop Now</span>
                    <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="7" y1="17" x2="17" y2="7"></line>
                        <polyline points="7 7 17 7 17 17"></polyline>
                    </svg>
                </a>

                <div class="hero-stats">
                    <div class="hero-stat">
                        <div class="hero-stat__number">200+</div>
                        <div class="hero-stat__label">International Brands</div>
                    </div>
                    <div class="hero-stat">
                        <div class="hero-stat__number">2,000+</div>
                        <div class="hero-stat__label">High-Quality Helmets</div>
                    </div>
                    <div class="hero-stat">
                        <div class="hero-stat__number">30,000+</div>
                        <div class="hero-stat__label">Satisfied Riders</div>
                    </div>
                </div>
            </div>

            <div class="hero-media">
                <img src="<%= ResolveUrl("~/Content/images/hero_img.png") %>" 
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
                <a href="<%= ResolveUrl("~/Pages/Shop.aspx?brand=Zebra") %>" class="brand-ticker__item" title="View Zebra Gear">
                    <img src="<%= ResolveUrl("~/Content/images/zebra.png") %>" alt="Zebra" class="brand-logo-img" />
                </a>
                <a href="<%= ResolveUrl("~/Pages/Shop.aspx?brand=Gille") %>" class="brand-ticker__item" title="View Gille Helmets">
                    <img src="<%= ResolveUrl("~/Content/images/gille.png") %>" alt="Gille" class="brand-logo-img" />
                </a>
                <a href="<%= ResolveUrl("~/Pages/Shop.aspx?brand=HNJ") %>" class="brand-ticker__item" title="View HNJ Top Boxes & Gear">
                    <img src="<%= ResolveUrl("~/Content/images/hnj.png") %>" alt="HNJ" class="brand-logo-img" />
                </a>
                <a href="<%= ResolveUrl("~/Pages/Shop.aspx?brand=Shoei") %>" class="brand-ticker__item" title="View Shoei Helmets">
                    <img src="<%= ResolveUrl("~/Content/images/shoei.png") %>" alt="Shoei Japan" class="brand-logo-img" />
                </a>
                <a href="<%= ResolveUrl("~/Pages/Shop.aspx?brand=AGV") %>" class="brand-ticker__item" title="View AGV Helmets">
                    <img src="<%= ResolveUrl("~/Content/images/agv.png") %>" alt="AGV" class="brand-logo-img avg" />
                </a>
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
                    <div class="product-card" onclick="window.location.href='<%= ResolveUrl("~/Pages/ProductDetail.aspx?id=") %><%# Eval("Id") %>'">
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
                            <%# (int)Eval("DiscountPercentage") > 0 ? "<span class=\"price-original\">&#8369;" + string.Format("{0:N0}", Eval("BasePrice")) + "</span><span class=\"discount-badge\">-" + Eval("DiscountPercentage") + "%</span>" : "" %>
                        </div>
                    </div>
                </ItemTemplate>
            </asp:Repeater>
        </div>
        <div class="section-action">
            <a href="<%= ResolveUrl("~/Pages/Shop.aspx") %>" class="btn btn--outline">
                <span>View All</span>
                <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="7" y1="17" x2="17" y2="7"></line>
                    <polyline points="7 7 17 7 17 17"></polyline>
                </svg>
            </a>
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
                    <div class="product-card" onclick="window.location.href='<%= ResolveUrl("~/Pages/ProductDetail.aspx?id=") %><%# Eval("Id") %>'">
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
                            <%# (int)Eval("DiscountPercentage") > 0 ? "<span class=\"price-original\">&#8369;" + string.Format("{0:N0}", Eval("BasePrice")) + "</span><span class=\"discount-badge\">-" + Eval("DiscountPercentage") + "%</span>" : "" %>
                        </div>
                    </div>
                </ItemTemplate>
            </asp:Repeater>
        </div>
        <div class="section-action">
            <a href="<%= ResolveUrl("~/Pages/Shop.aspx") %>" class="btn btn--outline">
                <span>View All</span>
                <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="7" y1="17" x2="17" y2="7"></line>
                    <polyline points="7 7 17 7 17 17"></polyline>
                </svg>
            </a>
        </div>
    </section>

    <!-- 5. BROWSE BY RIDING STYLE (Bento Box with Minimal Edge Curves) -->
    <section class="container bento-section" id="riding-styles">
        <div class="bento-wrapper">
            <h2 class="bento-title">BROWSE BY RIDING STYLE</h2>
            <div class="bento-grid">
                <a class="bento-card bento-card--span-4" href="<%= ResolveUrl("~/Pages/Shop.aspx") %>">
                    <div class="bento-card__title">Casual</div>
                    <img src="<%= ResolveUrl("~/Content/images/casual.png") %>" alt="Casual Urban" class="bento-card__bg-img casual" />
                </a>
                <a class="bento-card bento-card--span-8" href="<%= ResolveUrl("~/Pages/Shop.aspx") %>">
                    <div class="bento-card__title">Sport / Track</div>
                    <img src="<%= ResolveUrl("~/Content/images/track.png") %>" alt="Sport Track" class="bento-card__bg-img sport" />
                </a>
                <a class="bento-card bento-card--span-8" href="<%= ResolveUrl("~/Pages/Shop.aspx") %>">
                    <div class="bento-card__title">Touring / Adventure</div>
                    <img src="<%= ResolveUrl("~/Content/images/touring.png") %>" alt="Touring Adventure" class="bento-card__bg-img touring" />
                </a>
                <a class="bento-card bento-card--span-4" href="<%= ResolveUrl("~/Pages/Shop.aspx") %>">
                    <div class="bento-card__title">Off-Road</div>
                    <img src="<%= ResolveUrl("~/Content/images/offroad.png") %>" alt="Off-Road Dirt" class="bento-card__bg-img offroad" />
                </a>
            </div>
        </div>
    </section>

    <!-- 6. OUR HAPPY CUSTOMERS (Testimonials Carousel) -->
    <section class="container testimonials-section">
        <div class="testimonials-header">
            <h2 class="section-title section-title--no-margin">OUR HAPPY CUSTOMERS</h2>
            <div class="testimonials-nav">
                <button type="button" class="carousel-arrow" id="prev-testimonial" aria-label="Previous">
                    <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="19" y1="12" x2="5" y2="12"></line>
                        <polyline points="12 19 5 12 12 5"></polyline>
                    </svg>
                </button>
                <button type="button" class="carousel-arrow" id="next-testimonial" aria-label="Next">
                    <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="5" y1="12" x2="19" y2="12"></line>
                        <polyline points="12 5 19 12 12 19"></polyline>
                    </svg>
                </button>
            </div>
        </div>

        <div class="testimonials-carousel">
            <div class="testimonial-card">
                <div class="stars">
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                </div>
                <div class="testimonial-card__header">
                    <span class="author-name">
                        Sarah M.
                        <span class="verified-icon">
                            <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
                        </span>
                    </span>
                </div>
                <p class="testimonial-card__text">
                    "I'm blown away by the fit and noise isolation of the Shoei RF-1400. Stock levels on the site were 100% accurate and delivery took only 2 days."
                </p>
            </div>

            <div class="testimonial-card">
                <div class="stars">
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                </div>
                <div class="testimonial-card__header">
                    <span class="author-name">
                        Alex K.
                        <span class="verified-icon">
                            <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
                        </span>
                    </span>
                </div>
                <p class="testimonial-card__text">
                    "Finding a genuine AGV carbon helmet in Medium used to be impossible. With Helmet Cartel's live stock, I secured it online and walked in to collect without fuss."
                </p>
            </div>

            <div class="testimonial-card">
                <div class="stars">
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                </div>
                <div class="testimonial-card__header">
                    <span class="author-name">
                        James L.
                        <span class="verified-icon">
                            <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
                        </span>
                    </span>
                </div>
                <p class="testimonial-card__text">
                    "Seamless HitPay transaction, rapid order confirmation email, and immaculate packaging. Definitely my go-to motorcycle gear shop."
                </p>
            </div>
        </div>
    </section>

    <!-- Client-Side Dynamic Loader -->
    <script type="module" src="<%= ResolveUrl("~/Scripts/storefront.js?v=8") %>"></script>
</asp:Content>
