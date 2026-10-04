<%@ Page Title="My Wishlist & Favorites" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Favorites.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.FavoritesPage" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="container favorites-page-container">
        <!-- Breadcrumb Navigation -->
        <nav class="shop-breadcrumb" aria-label="Breadcrumb">
            <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="shop-breadcrumb__link">Home</asp:HyperLink>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2">
                <polyline points="9 18 15 12 9 6"></polyline>
            </svg>
            <span class="shop-breadcrumb__current">Wishlist</span>
        </nav>

        <!-- Page Header -->
        <div class="favorites-header">
            <div class="favorites-header__left">
                <h1 class="favorites-header__title">SAVED FAVORITES</h1>
                <p class="favorites-header__subtitle" id="favorites-count-label">Loading your saved gear...</p>
            </div>
            <div class="favorites-header__actions is-hidden" id="favorites-header-actions">
                <button type="button" class="btn btn--outline btn--sm" id="btn-clear-favorites">
                    <span>Clear All</span>
                </button>
            </div>
        </div>

        <!-- Favorites Grid or Empty State -->
        <div class="favorites-content" id="favorites-content">
            <!-- Dynamically populated via JS -->
        </div>
    </div>

    <!-- External Storefront Favorites Script -->
    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/favorites.js?v=20261004") %>'></script>
</asp:Content>
