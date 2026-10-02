<%@ Page Title="Product Details" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ProductDetail.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.ProductDetailPage" ResponseEncoding="utf-8" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="container product-detail-container">
        <!-- Breadcrumb -->
        <nav class="shop-breadcrumb" aria-label="Breadcrumb">
            <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="shop-breadcrumb__link">Home</asp:HyperLink>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
            <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx" CssClass="shop-breadcrumb__link">Shop</asp:HyperLink>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
            <span class="shop-breadcrumb__current" id="detail-breadcrumb-name"><%= ProductItem != null ? Server.HtmlEncode(ProductItem.Name) : "Product unavailable" %></span>
        </nav>

        <!-- Product Presentation Grid (Matching Shop.co Image 2) -->
        <div class="product-detail-layout">
            <!-- Gallery: Vertical Layout with Thumbnails on the Left Side -->
            <div class="product-gallery">
                <div class="product-gallery__thumbs" id="product-gallery-thumbs">
                    <asp:Repeater ID="rptGalleryImages" runat="server">
                        <ItemTemplate>
                            <button type="button" 
                                    class='<%# GetGalleryThumbClass(Container.ItemIndex) %>' 
                                    data-index='<%# Container.ItemIndex %>'
                                    data-has-more='<%# IsFifthThumbWithMore(Container.ItemIndex) ? "true" : "false" %>'
                                    aria-label='<%# IsFifthThumbWithMore(Container.ItemIndex) ? "View all additional product images" : ("Show " + System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("AltText")))) %>'>
                                <img src='<%# System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("ImageUrl"))) %>' alt='<%# System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("AltText"))) %>' />
                                <%# IsFifthThumbWithMore(Container.ItemIndex) ? "<span class=\"gallery-thumb__more\">" + GetExtraImagesCount() + "+</span>" : "" %>
                            </button>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
                <div class="product-gallery__main">
                    <img id="main-product-img" src="<%= ProductItem?.MainImageUrl ?? "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=700&auto=format&fit=crop&q=80" %>" alt="<%= ProductItem != null ? Server.HtmlEncode(ProductItem.Name) : "Helmet" %>" />
                </div>
            </div>

            <!-- Details & Actions -->
            <div class="product-info">
                <h1 class="product-info__title" id="detail-title"><%= ProductItem != null ? Server.HtmlEncode(ProductItem.Name.ToUpperInvariant()) : "PRODUCT UNAVAILABLE" %></h1>
                <p id="detail-stock-message" class="product-info__stock-message" aria-live="polite"></p>
                <div class="product-card__rating product-detail-rating">
                    <div class="stars" id="detail-stars">
                        <% decimal rating = ProductItem != null ? ProductItem.Rating : 0m;
                           int fullStars = (int)Math.Floor(rating);
                           for (int i = 0; i < 5; i++) {
                               if (i < fullStars) { %>
                                   <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                               <% } else { %>
                                   <svg viewBox="0 0 24 24" class="star--empty"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                               <% }
                           } %>
                    </div>
                    <span class="rating-score detail-rating-score" id="detail-rating-score"><%= (ProductItem?.Rating ?? 0m).ToString("0.0") %>/5</span>
                    <% if (ProductItem != null && ProductItem.OrderCount > 0) { %>
                        <span class="product-info__orders"><%= ProductItem.OrderCount.ToString("N0") %> <%= ProductItem.OrderCount == 1 ? "order" : "orders" %></span>
                    <% } %>
                </div>

                <div class="product-info__price-row" id="detail-price-row">
                    <span class="price-current-lg" id="detail-price"><%= ProductItem != null ? "&#8369;" + ProductItem.EffectivePrice.ToString("N0") : "Unavailable" %></span>
                    <% if (ProductItem != null && ProductItem.DiscountPercentage > 0) { %>
                        <span class="price-original-lg" id="detail-orig-price">&#8369;<%= ProductItem.BasePrice.ToString("N0") %></span>
                        <span class="discount-badge-lg" id="detail-discount-badge">-<%= ProductItem.DiscountPercentage %>%</span>
                    <% } %>
                </div>

                <!-- Color Selection (Selected color receives checkmark) -->
                <div class="selector-group">
                    <div class="selector-label">Select Colors</div>
                    <div class="color-swatches" id="detail-color-swatches">
                        <% if (UniqueColors != null && UniqueColors.Count > 0) {
                               bool firstColor = true;
                               foreach (var clr in UniqueColors) { 
                                   string swatchClass = GetColorSwatchClass(clr.Color);
                               %>
                                   <span class="color-swatch <%= swatchClass %> <%= firstColor ? "active" : "" %>" 
                                         title="<%= Server.HtmlEncode(clr.Color) %>" 
                                         data-color="<%= Server.HtmlEncode(clr.Color) %>"
                                         data-color-hex="<%= Server.HtmlEncode(clr.ColorHex ?? "") %>">
                                       <% if (firstColor) { %>
                                           <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                                       <% } %>
                                   </span>
                               <% firstColor = false;
                               }
                           } else { %>
                               <span class="color-swatch swatch--charcoal active" title="Matte Charcoal Black" data-color="Matte Charcoal Black">
                                   <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                               </span>
                               <span class="color-swatch swatch--olive" title="Dark Olive Green" data-color="Dark Olive Green"></span>
                               <span class="color-swatch swatch--navy" title="Midnight Navy" data-color="Midnight Navy"></span>
                        <% } %>
                    </div>
                </div>

                <!-- Size Selection -->
                <div class="selector-group">
                    <div class="selector-label">Choose Size</div>
                    <div class="size-pills" id="detail-size-pills">
                        <% if (UniqueSizes != null && UniqueSizes.Count > 0) {
                               bool firstSize = true;
                               foreach (var sz in UniqueSizes) { %>
                                   <button type="button" class="size-pill <%= firstSize ? "active" : "" %>"><%= Server.HtmlEncode(sz) %></button>
                               <% firstSize = false;
                               }
                           } else { %>
                               <button type="button" class="size-pill">Small</button>
                               <button type="button" class="size-pill">Medium</button>
                               <button type="button" class="size-pill active">Large</button>
                               <button type="button" class="size-pill">X-Large</button>
                        <% } %>
                    </div>
                </div>

                <!-- Quantity Selection (Separated cleanly below size) -->
                <div class="selector-group">
                    <div class="selector-label">Quantity</div>
                    <div class="quantity-stepper-lg">
                        <button type="button" class="stepper-btn" id="btn-qty-dec" aria-label="Decrease quantity">&minus;</button>
                        <span class="stepper-value" id="detail-qty">1</span>
                        <button type="button" class="stepper-btn" id="btn-qty-inc" aria-label="Increase quantity">&plus;</button>
                    </div>
                </div>

                <!-- Action Buttons Row (Add to Cart, Wishlist, Buy Now) -->
                <div class="product-actions-row">
                    <button type="button" id="btn-detail-favorite" class="btn--fav-detail" aria-label="Add to Wishlist" title="Save to Wishlist">
                        <svg class="heart-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>
                        </svg>
                    </button>
                    <button type="button" id="btn-add-detail" class="btn--add-cart" aria-label="Add to Cart">
                        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="9" cy="21" r="1"></circle>
                            <circle cx="20" cy="21" r="1"></circle>
                            <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path>
                        </svg>
                        <span>Add to Cart</span>
                    </button>
                    <button type="button" id="btn-buy-now" class="btn--buy-now" aria-label="Buy Now">
                        <span>Buy Now</span>
                        <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <line x1="7" y1="17" x2="17" y2="7"></line>
                            <polyline points="7 7 17 7 17 17"></polyline>
                        </svg>
                    </button>
                </div>
            </div>
        </div>

        <div class="product-detail-content">
        <section id="product-details" class="product-details-section" aria-labelledby="product-details-heading">
            <h2 id="product-details-heading" class="details-section-heading">Product Details</h2>
            <p class="product-details-summary" id="detail-description"><%= ProductItem != null ? Server.HtmlEncode(ProductItem.Description) : "Product information is not available yet." %></p>
            <% if (ProductItem != null) { %>
            <h3 class="product-overview-heading" id="product-overview-heading">Helmet at a glance</h3>
            <dl class="product-info__meta" aria-labelledby="product-overview-heading">
                <div>
                    <dt><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 7V4h9l9 9-8 8-10-10V7Z"></path><circle cx="8" cy="8" r="1"></circle></svg>Brand</dt>
                    <dd><%= Server.HtmlEncode(ProductItem.Brand) %></dd>
                </div>
                <div>
                    <dt><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 13a9 9 0 0 1 18 0v3h-5l-3 4H7l-4-4v-3Z"></path><path d="M3 14h18"></path></svg>Helmet category</dt>
                    <dd><%= Server.HtmlEncode(ProductItem.Category) %></dd>
                </div>
                <div>
                    <dt><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 21 10 3m7 18L14 3M3 21h18"></path><path d="M12 7v3m0 4v3"></path></svg>Intended riding</dt>
                    <dd><%= Server.HtmlEncode(ProductItem.RidingStyle) %></dd>
                </div>
                <% if (UniqueSizes != null && UniqueSizes.Count > 0) { %>
                <div>
                    <dt><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v14H4z"></path><path d="M8 5v4m4-4v3m4-3v4"></path></svg>Sizes offered</dt>
                    <dd><%= Server.HtmlEncode(string.Join(", ", UniqueSizes)) %></dd>
                </div>
                <% } %>
                <% if (UniqueColors != null && UniqueColors.Count > 0) { %>
                <div>
                    <dt><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="9" cy="9" r="5"></circle><circle cx="16" cy="8" r="4"></circle><circle cx="15" cy="16" r="5"></circle></svg>Color options</dt>
                    <dd><%= UniqueColors.Count %> <%= UniqueColors.Count == 1 ? "color" : "colors" %> listed</dd>
                </div>
                <% } %>
            </dl>
            <% } %>
            <asp:Panel ID="pnlProductSpecifications" runat="server" CssClass="details-specs-container">
                <h3 class="details-specs-heading">Technical Specifications</h3>
                <table class="details-specs-table" id="product-spec-list">
                    <tbody>
                        <asp:Repeater ID="rptProductSpecifications" runat="server">
                            <ItemTemplate>
                                <tr class='<%# Container.ItemIndex >= 3 ? "detail-spec-row detail-spec-row--extra" : "detail-spec-row" %>'>
                                    <th scope="row"><%# System.Web.HttpUtility.HtmlEncode(Convert.ToString(Eval("DisplayName"))) %></th>
                                    <td><%# System.Web.HttpUtility.HtmlEncode(Convert.ToString(Eval("SpecificationValue"))) %></td>
                                </tr>
                            </ItemTemplate>
                        </asp:Repeater>
                    </tbody>
                </table>
            </asp:Panel>
            <asp:Label ID="lblNoSpecifications" runat="server" CssClass="details-specs-empty" Text="Specifications are not available for this product yet." />
            <asp:Panel ID="pnlSpecToggle" runat="server" CssClass="details-toggle-wrap" Visible="false">
                <button type="button" id="btn-toggle-details" class="details-toggle-btn" aria-expanded="false" aria-controls="product-spec-list">Show more</button>
            </asp:Panel>
        </section>

        <section id="product-reviews" class="product-reviews-section" aria-labelledby="reviews-heading">
            <div class="reviews-section-heading">
                <h2 id="reviews-heading">Ratings &amp; Reviews</h2>
                <div class="reviews-summary-score" aria-label="Average customer rating">
                    <span class="stars"><%= RenderReviewStars((int)Math.Floor(ProductItem?.Rating ?? 0m)) %></span>
                    <strong><%= (ProductItem?.Rating ?? 0m).ToString("0.0") %>/5</strong>
                    <span>(<%= ReviewsCount %> reviews)</span>
                </div>
            </div>
            <div class="reviews-header-row">
                <div class="reviews-title">
                    All Reviews <span class="reviews-count" id="reviews-count-display">(<%= ReviewsCount %>)</span>
                </div>
                <div class="reviews-controls">
                    <!-- Filter Dropdown Trigger & Popover -->
                    <div class="review-filter-dropdown-wrap">
                        <button type="button" class="review-filter-btn" id="btn-review-filter" aria-label="Filter Reviews" title="Filter reviews by star rating">
                            <svg class="review-filter-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"></polygon>
                            </svg>
                        </button>
                        <div class="review-filter-menu" id="review-filter-menu">
                            <div class="review-filter-menu-title">Filter by Rating</div>
                            <button type="button" class="review-filter-option active" data-filter="all" title="All Reviews">
                                <span>All Stars</span>
                                <span class="filter-count-badge"><%= ReviewsCount %></span>
                            </button>
                            <button type="button" class="review-filter-option" data-filter="5" title="5 Stars">
                                <span class="review-filter-stars-wrap">
                                    <span class="stars"><%= RenderReviewStars(5) %></span>
                                </span>
                                <span class="filter-count-badge"><%= Reviews != null ? Reviews.Count(r => r.Rating == 5) : 0 %></span>
                            </button>
                            <button type="button" class="review-filter-option" data-filter="4" title="4 Stars">
                                <span class="review-filter-stars-wrap">
                                    <span class="stars"><%= RenderReviewStars(4) %></span>
                                </span>
                                <span class="filter-count-badge"><%= Reviews != null ? Reviews.Count(r => r.Rating == 4) : 0 %></span>
                            </button>
                            <button type="button" class="review-filter-option" data-filter="3" title="3 Stars">
                                <span class="review-filter-stars-wrap">
                                    <span class="stars"><%= RenderReviewStars(3) %></span>
                                </span>
                                <span class="filter-count-badge"><%= Reviews != null ? Reviews.Count(r => r.Rating == 3) : 0 %></span>
                            </button>
                            <button type="button" class="review-filter-option" data-filter="2" title="2 Stars">
                                <span class="review-filter-stars-wrap">
                                    <span class="stars"><%= RenderReviewStars(2) %></span>
                                </span>
                                <span class="filter-count-badge"><%= Reviews != null ? Reviews.Count(r => r.Rating == 2) : 0 %></span>
                            </button>
                            <button type="button" class="review-filter-option" data-filter="1" title="1 Star">
                                <span class="review-filter-stars-wrap">
                                    <span class="stars"><%= RenderReviewStars(1) %></span>
                                </span>
                                <span class="filter-count-badge"><%= Reviews != null ? Reviews.Count(r => r.Rating == 1) : 0 %></span>
                            </button>
                            <div class="review-filter-divider"></div>
                            <label class="review-filter-checkbox-label" for="chk-verified-only">
                                <span class="review-filter-checkbox-content">
                                    <input type="checkbox" id="chk-verified-only" />
                                    <span>Verified Purchases Only</span>
                                </span>
                                <span class="filter-count-badge"><%= Reviews != null ? Reviews.Count(r => r.IsVerifiedPurchase) : 0 %></span>
                            </label>
                        </div>
                    </div>

                    <!-- Sort Dropdown Trigger & Popover -->
                    <div class="review-sort-wrap">
                        <button type="button" class="review-control-btn" id="btn-review-sort" aria-label="Sort Reviews">
                            <span id="review-sort-label">Latest</span>
                            <svg class="review-chevron-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polyline points="6 9 12 15 18 9"></polyline>
                            </svg>
                        </button>
                        <div class="review-sort-menu" id="review-sort-menu">
                            <button type="button" class="review-sort-option active" data-sort="latest">Latest First</button>
                            <button type="button" class="review-sort-option" data-sort="highest">Highest Rating</button>
                            <button type="button" class="review-sort-option" data-sort="lowest">Lowest Rating</button>
                        </div>
                    </div>

                    <button type="button" class="btn btn--primary btn--write-review btn-open-write-review">
                        Write a Review
                    </button>
                </div>
            </div>

            <div class="reviews-discussion-list" id="reviews-grid">
                <% if (Reviews != null && Reviews.Count > 0) {
                       int reviewIndex = 0;
                       foreach (var rev in Reviews) { %>
                    <div class="review-card-full <%= reviewIndex++ >= 3 ? "is-review-page-hidden" : "" %>"
                         data-review-id="<%= rev.Id %>" 
                         data-rating="<%= rev.Rating %>" 
                         data-verified="<%= rev.IsVerifiedPurchase ? "true" : "false" %>"
                         data-date="<%= rev.CreatedAt.ToString("o") %>">
                        <div class="review-card__top">
                            <div class="review-card-row">
                                <span class="review-avatar" aria-hidden="true"><%= Server.HtmlEncode(GetReviewerInitial(rev.ReviewerName)) %></span>
                                <span class="review-author-name"><%= Server.HtmlEncode(rev.ReviewerName) %></span>
                                <% if (rev.IsVerifiedPurchase) { %>
                                    <span class="review-verified-badge" title="Verified Buyer">
                                        <svg viewBox="0 0 24 24" fill="none"><polyline points="20 6 9 17 4 12"></polyline></svg>
                                    </span>
                                <% } %>
                                <div class="stars review-stars">
                                    <%= RenderReviewStars(rev.Rating) %>
                                </div>
                            </div>
                            <div class="review-actions-wrap">
                                <button type="button" class="review-more-btn" aria-label="Review actions" title="More options" data-review-id="<%= rev.Id %>">•••</button>
                                <div class="review-action-popover" id="review-popover-<%= rev.Id %>">
                                    <button type="button" class="review-popover-item btn-report-review" data-review-id="<%= rev.Id %>" data-reviewer="<%= Server.HtmlEncode(rev.ReviewerName) %>">
                                        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"></path><line x1="4" y1="22" x2="4" y2="15"></line></svg>
                                        <span>Report this review</span>
                                    </button>
                                </div>
                            </div>
                        </div>
                        <% if (!string.IsNullOrEmpty(rev.Title)) { %>
                            <div class="review-title-heading"><%= Server.HtmlEncode(rev.Title) %></div>
                        <% } %>
                        <p class="review-text">
                            "<%= Server.HtmlEncode(rev.Comment) %>"
                        </p>
                        <div class="review-footer-row">
                            <div class="review-date">Posted on <%= rev.FormattedDate %></div>
                            <div class="review-report-status" id="report-status-<%= rev.Id %>"></div>
                        </div>
                    </div>
                <%   }
                   } else { %>
                    <div class="reviews-empty-state">
                        <div class="reviews-empty-title">No Reviews Yet</div>
                        <p>Be the first rider to review this helmet.</p>
                        <button type="button" class="btn btn--primary btn--sm btn-open-write-review">Write a Review</button>
                    </div>
                <% } %>
            </div>
            <div class="reviews-load-more <%= Reviews != null && Reviews.Count > 3 ? "" : "is-hidden" %>">
                <button type="button" class="btn btn--outline" id="btn-load-more-reviews">Load more</button>
            </div>

            <!-- Empty Filter State (Shown when active filter matches 0 reviews) -->
            <div id="reviews-no-filter-match" class="reviews-empty-state is-hidden">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"></circle><line x1="8" y1="12" x2="16" y2="12"></line></svg>
                <div class="reviews-empty-title">No Reviews Found</div>
                <p>There are no reviews matching your selected rating or filter criteria.</p>
                <button type="button" class="btn btn--outline btn--sm" id="btn-reset-filters">Reset Filters</button>
            </div>
        </section>

        <asp:Panel ID="pnlRelatedProducts" runat="server" CssClass="related-products-section" Visible="false">
            <div class="related-products-heading">
                <h2>You Might Also Like</h2>
            </div>
            <div class="related-products-grid">
                <asp:Repeater ID="rptRelatedProducts" runat="server">
                    <ItemTemplate>
                        <asp:HyperLink runat="server" CssClass="product-card" NavigateUrl='<%# "~/Pages/Storefront/ProductDetail/ProductDetail.aspx?id=" + Eval("Id") %>'>
                            <div class="product-card__img-wrap">
                                <img class="product-card__img" src='<%# System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("MainImageUrl"))) %>' alt='<%# System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("Name"))) %>' loading="lazy" />
                            </div>
                            <h3 class="product-card__title"><%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %></h3>
                            <p class="product-card__description"><%# Server.HtmlEncode(Convert.ToString(Eval("Description"))) %></p>
                            <div class="product-card__rating">
                                <div class="stars"><%# RenderReviewStars((int)Math.Floor(Convert.ToDecimal(Eval("Rating")))) %></div>
                                <span class="rating-score"><%# Eval("Rating", "{0:0.0}") %>/5 (<%# Eval("ReviewCount") %>)</span>
                            </div>
                            <div class="product-card__pricing">
                                <span class="price-current">&#8369;<%# Eval("EffectivePrice", "{0:N0}") %></span>
                                <%# (int)Eval("DiscountPercentage") > 0 ? "<span class=\"price-original\">&#8369;" + string.Format("{0:N0}", Eval("BasePrice")) + "</span><span class=\"discount-badge\">-" + Eval("DiscountPercentage") + "%</span>" : "" %>
                            </div>
                        </asp:HyperLink>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </asp:Panel>
        </div>

        <!-- Report Review Modal -->
        <div id="report-review-modal" class="modal-backdrop review-modal-backdrop is-hidden">
            <div class="modal-dialog review-modal-dialog">
                <div class="modal-header">
                    <div>
                        <h3 class="modal-title">Report Review</h3>
                        <p class="modal-subtitle">Help Helmet Cartel maintain an authentic and trustworthy community.</p>
                    </div>
                    <button type="button" class="modal-close-btn" id="btn-close-report-modal">&times;</button>
                </div>
                <div class="modal-body">
                    <input type="hidden" id="report-target-review-id" value="" />
                    <div class="report-meta-target" id="report-meta-target">
                        Reporting review by: <strong id="report-target-author"></strong>
                    </div>

                    <label class="modal-field-label">Reason for reporting:</label>
                    <div class="report-reasons-list">
                        <label class="report-reason-option">
                            <input type="radio" name="report-reason" value="SPAM" checked />
                            <div class="report-reason-text">
                                <strong>Spam or Promotional</strong>
                                <span>Contains commercial ads, promo links, repetitive text, or unsolicited solicitations</span>
                            </div>
                        </label>
                        <label class="report-reason-option">
                            <input type="radio" name="report-reason" value="OFFENSIVE" />
                            <div class="report-reason-text">
                                <strong>Inappropriate or Offensive</strong>
                                <span>Contains hate speech, profanity, harassment, or abusive content</span>
                            </div>
                        </label>
                        <label class="report-reason-option">
                            <input type="radio" name="report-reason" value="IRRELEVANT" />
                            <div class="report-reason-text">
                                <strong>Not Relevant to Product</strong>
                                <span>Discusses unrelated items, carrier delays, or non-motorcycle gear topics</span>
                            </div>
                        </label>
                        <label class="report-reason-option">
                            <input type="radio" name="report-reason" value="FAKE" />
                            <div class="report-reason-text">
                                <strong>Dishonest or Fake Review</strong>
                                <span>Suspected competitor review, paid deceptive feedback, or manufactured testimonial</span>
                            </div>
                        </label>
                    </div>

                    <div class="modal-field-group">
                        <label for="report-notes" class="modal-field-label">Additional Details (Optional):</label>
                        <textarea id="report-notes" class="modal-textarea" rows="3" placeholder="Provide any additional context for moderators..."></textarea>
                    </div>

                    <div id="report-error-msg" class="report-alert-danger is-hidden"></div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn--outline" id="btn-cancel-report-modal">Cancel</button>
                    <button type="button" class="btn btn--primary" id="btn-submit-report">Submit Report</button>
                </div>
            </div>
        </div>

        <!-- Write Review Modal -->
        <div id="write-review-modal" class="modal-backdrop review-modal-backdrop is-hidden">
            <div class="modal-dialog review-modal-dialog">
                <div class="modal-header">
                    <div>
                        <h3 class="modal-title">Write a Review</h3>
                        <p class="modal-subtitle">Share your riding experience with fellow motorcyclists.</p>
                    </div>
                    <button type="button" class="modal-close-btn" id="btn-close-write-modal">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="modal-field-group">
                        <label class="modal-field-label">Your Overall Rating:</label>
                        <div class="interactive-star-rating" id="write-star-picker">
                            <span class="star-pick" data-val="1">&#9733;</span>
                            <span class="star-pick" data-val="2">&#9733;</span>
                            <span class="star-pick" data-val="3">&#9733;</span>
                            <span class="star-pick" data-val="4">&#9733;</span>
                            <span class="star-pick active" data-val="5">&#9733;</span>
                        </div>
                        <input type="hidden" id="write-rating-val" value="5" />
                    </div>

                    <div class="modal-field-group">
                        <label for="write-reviewer-name" class="modal-field-label">Your Name / Handle:</label>
                        <input type="text" id="write-reviewer-name" class="modal-input" placeholder="e.g. Juan D." required />
                    </div>

                    <div class="modal-field-group">
                        <label for="write-review-title" class="modal-field-label">Review Headline:</label>
                        <input type="text" id="write-review-title" class="modal-input" placeholder="e.g. Exceptional aerodynamic stability and comfort" />
                    </div>

                    <div class="modal-field-group">
                        <label for="write-review-comment" class="modal-field-label">Your Review:</label>
                        <textarea id="write-review-comment" class="modal-textarea" rows="4" placeholder="How does the helmet feel at speed? How is the ventilation and visor optical clarity?" required></textarea>
                    </div>

                    <div id="write-error-msg" class="report-alert-danger is-hidden"></div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn--outline" id="btn-cancel-write-modal">Cancel</button>
                    <button type="button" class="btn btn--primary" id="btn-submit-review">Post Review</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Gallery More Images Modal Dialog -->
    <div id="gallery-modal" class="gallery-modal" aria-hidden="true" role="dialog" aria-modal="true" aria-labelledby="gallery-modal-title">
        <div class="gallery-modal__backdrop" id="gallery-modal-backdrop"></div>
        <div class="gallery-modal__dialog">
            <div class="gallery-modal__header">
                <div class="gallery-modal__titles">
                    <span class="gallery-modal__badge">Product Gallery</span>
                    <h3 class="gallery-modal__title" id="gallery-modal-title">Additional Images</h3>
                    <p class="gallery-modal__subtitle">Click any image to set it as active on the main product view.</p>
                </div>
                <button type="button" class="gallery-modal__close" id="gallery-modal-close" aria-label="Close dialog">&times;</button>
            </div>
            <div class="gallery-modal__body">
                <div class="gallery-modal__grid" id="gallery-modal-grid">
                    <asp:Repeater ID="rptGalleryModalImages" runat="server">
                        <ItemTemplate>
                            <button type="button" 
                                    class='gallery-modal__item <%# Container.ItemIndex == 0 ? "is-active" : "" %>' 
                                    data-index='<%# Container.ItemIndex %>' 
                                    data-src='<%# System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("ImageUrl"))) %>'
                                    aria-label='Select image <%# Container.ItemIndex + 1 %>'>
                                <div class="gallery-modal__item-img">
                                    <img src='<%# System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("ImageUrl"))) %>' alt='<%# System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("AltText"))) %>' loading="lazy" />
                                </div>
                                <div class="gallery-modal__item-info">
                                    <span class="gallery-modal__item-action">Click to select</span>
                                </div>
                            </button>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </div>
        </div>
    </div>

    <!-- Product Detail Data Configuration & External Modular Script -->
    <script type="application/json" id="product-detail-data">
        <%= ProductJson %>
    </script>
    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/product-detail.js?v=6") %>'></script>
</asp:Content>
