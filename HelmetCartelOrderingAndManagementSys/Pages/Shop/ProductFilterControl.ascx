<%@ Control Language="C#" AutoEventWireup="true" CodeBehind="ProductFilterControl.ascx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.Shop.ProductFilterControl" %>

<aside class="shop-filter-card" id="shop-filter-panel">
    <!-- Header with sliders icon -->
    <div class="shop-filter-header">
        <h3 class="shop-filter-title">Filters</h3>
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="shop-breadcrumb__icon">
            <line x1="4" y1="21" x2="4" y2="14"></line>
            <line x1="4" y1="10" x2="4" y2="3"></line>
            <line x1="12" y1="21" x2="12" y2="12"></line>
            <line x1="12" y1="8" x2="12" y2="3"></line>
            <line x1="20" y1="21" x2="20" y2="16"></line>
            <line x1="20" y1="12" x2="20" y2="3"></line>
            <line x1="1" y1="14" x2="7" y2="14"></line>
            <line x1="9" y1="8" x2="15" y2="8"></line>
            <line x1="17" y1="16" x2="23" y2="16"></line>
        </svg>
    </div>

    <!-- Category Filter List (Collapsible Accordion) -->
    <div class="filter-accordion-header" id="filter-categories-header" role="button" tabindex="0" aria-expanded="true">
        <span>Categories</span>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="accordion-chevron"><polyline points="18 15 12 9 6 15"></polyline></svg>
    </div>
    <div class="filter-categories-list filter-accordion-content" id="filter-categories-container">
        <a href="Shop.aspx" class="filter-category-item <%= SelectedCategory == "all" ? "active" : "" %>" data-category="all">
            <span>All Categories</span>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
        </a>
        <asp:Repeater ID="rptCategoryFilter" runat="server">
            <ItemTemplate>
                <a href='Shop.aspx?category=<%# Server.UrlEncode((string)Eval("Slug")) %>' 
                   class='filter-category-item <%# IsCategoryActive((string)Eval("Slug")) ? "active" : "" %>' 
                   data-category='<%# System.Web.HttpUtility.HtmlAttributeEncode((string)Eval("Slug")) %>'>
                    <span><%# Server.HtmlEncode((string)Eval("Name")) %></span>
                    <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
                </a>
            </ItemTemplate>
        </asp:Repeater>
    </div>

    <hr class="filter-section-divider" />

    <!-- Brand Section -->
    <div class="filter-accordion-header">
        <span>Brands</span>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="accordion-chevron"><polyline points="18 15 12 9 6 15"></polyline></svg>
    </div>
    <div class="filter-brands-list filter-accordion-content" id="filter-brands-container">
        <a href="Shop.aspx" class="filter-brand-btn <%= SelectedBrand == "all" ? "active" : "" %>" data-brand="all">All Brands</a>
        <asp:Repeater ID="rptBrandFilter" runat="server">
            <ItemTemplate>
                <a href='Shop.aspx?brand=<%# Server.UrlEncode((string)Eval("Name")) %>' 
                   class='filter-brand-btn <%# IsBrandActive((string)Eval("Name")) ? "active" : "" %>' 
                   data-brand='<%# System.Web.HttpUtility.HtmlAttributeEncode((string)Eval("Name")) %>'>
                    <%# Server.HtmlEncode((string)Eval("Name")) %>
                </a>
            </ItemTemplate>
        </asp:Repeater>
    </div>

    <hr class="filter-section-divider" />

    <!-- Price Section -->
    <div class="filter-accordion-header">
        <span>Price</span>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="accordion-chevron"><polyline points="18 15 12 9 6 15"></polyline></svg>
    </div>
    <div class="filter-price-slider-wrap filter-accordion-content">
        <div class="dual-range-slider-container">
            <div class="dual-range-track-bg"></div>
            <div class="dual-range-progress" id="dual-range-progress"></div>
            <input type="range" class="dual-range-input dual-range-min" id="price-range-min" min="0" max="100000" value="0" step="1000" aria-label="Minimum Price" />
            <input type="range" class="dual-range-input dual-range-max" id="price-range-max" min="0" max="100000" value="100000" step="1000" aria-label="Maximum Price" />
        </div>
        <div class="filter-price-labels">
            <span id="price-min-display" class="filter-price-current">&#8369;0</span>
            <span class="filter-price-separator">&mdash;</span>
            <span id="price-max-display" class="filter-price-current">&#8369;100,000</span>
        </div>
    </div>

    <hr class="filter-section-divider" />

    <!-- Colors Section -->
    <div class="filter-accordion-header">
        <span>Colors</span>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="accordion-chevron"><polyline points="18 15 12 9 6 15"></polyline></svg>
    </div>
    <div class="filter-colors-grid filter-accordion-content">
        <button type="button" class="filter-color-swatch swatch--green" data-color="Green" aria-label="Green" aria-pressed="false"></button>
        <button type="button" class="filter-color-swatch swatch--red" data-color="Red" aria-label="Red" aria-pressed="false"></button>
        <button type="button" class="filter-color-swatch swatch--orange" data-color="Orange" aria-label="Orange" aria-pressed="false"></button>
        <button type="button" class="filter-color-swatch swatch--cyan" data-color="Cyan" aria-label="Cyan" aria-pressed="false"></button>
        <button type="button" class="filter-color-swatch swatch--blue" data-color="Blue" aria-label="Blue" aria-pressed="false"></button>
        <button type="button" class="filter-color-swatch swatch--purple" data-color="Purple" aria-label="Purple" aria-pressed="false"></button>
        <button type="button" class="filter-color-swatch swatch--pink" data-color="Pink" aria-label="Pink" aria-pressed="false"></button>
        <button type="button" class="filter-color-swatch swatch--white" data-color="White" aria-label="White" aria-pressed="false"></button>
        <button type="button" class="filter-color-swatch swatch--black" data-color="Black" aria-label="Black" aria-pressed="false"></button>
        <button type="button" class="filter-color-swatch swatch--grey" data-color="Grey" aria-label="Grey" aria-pressed="false"></button>
    </div>

    <hr class="filter-section-divider" />

    <!-- Size Section -->
    <div class="filter-accordion-header">
        <span>Size</span>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="accordion-chevron"><polyline points="18 15 12 9 6 15"></polyline></svg>
    </div>
    <div class="filter-sizes-grid filter-accordion-content">
        <button type="button" class="filter-size-pill" data-size="S" aria-pressed="false">S</button>
        <button type="button" class="filter-size-pill" data-size="M" aria-pressed="false">M</button>
        <button type="button" class="filter-size-pill" data-size="L" aria-pressed="false">L</button>
        <button type="button" class="filter-size-pill" data-size="XL" aria-pressed="false">XL</button>
        <button type="button" class="filter-size-pill" data-size="XXL" aria-pressed="false">XXL</button>
    </div>

    <!-- Apply Filter Button -->
    <button type="button" class="btn--apply-filters" id="btn-apply-filters">
        <span>Apply Filter</span>
        <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="7" y1="17" x2="17" y2="7"></line>
            <polyline points="7 7 17 7 17 17"></polyline>
        </svg>
    </button>
    <button type="button" class="btn btn--outline btn--clear-filters" id="btn-clear-all-filters">Clear all filters</button>
</aside>
