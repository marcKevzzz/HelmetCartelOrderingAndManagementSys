<%@ Page Title="My Wishlist & Favorites" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Favorites.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.FavoritesPage" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="<%= ResolveUrl("~/Content/css/storefront.css?v=7") %>" />
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="container favorites-page-container">
        <!-- Breadcrumb Navigation -->
        <nav class="shop-breadcrumb" aria-label="Breadcrumb">
            <a href="<%= ResolveUrl("~/Default.aspx") %>" class="shop-breadcrumb__link">Home</a>
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

    <script type="module">
        import { FavoritesManager } from '<%= ResolveUrl("~/Scripts/favorites.js") %>';
        import { ApiClient } from '<%= ResolveUrl("~/Scripts/api.js") %>';
        import { RealtimeManager } from '<%= ResolveUrl("~/Scripts/realtime.js") %>';

        function generateStarsSvg(rating) {
            let svgs = '';
            const full = Math.floor(rating);
            for (let i = 0; i < 5; i++) {
                if (i < full) {
                    svgs += `<svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;
                } else {
                    svgs += `<svg viewBox="0 0 24 24" class="star--empty"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;
                }
            }
            return svgs;
        }

        function renderFavorites() {
            const container = document.getElementById('favorites-content');
            const countLabel = document.getElementById('favorites-count-label');
            const headerActions = document.getElementById('favorites-header-actions');
            if (!container) return;

            const items = FavoritesManager.getItems();

            if (items.length === 0) {
                countLabel.textContent = "You don't have any saved helmets yet.";
                headerActions?.classList.add('is-hidden');
                container.innerHTML = `
                    <div class="favorites-empty-card">
                        <div class="favorites-empty-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                                <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>
                            </svg>
                        </div>
                        <h2 class="favorites-empty-title">Your Wishlist is Empty</h2>
                        <p class="favorites-empty-desc">Browse helmets and tap the heart icon on gear you want to save for later.</p>
                        <a href="<%= ResolveUrl("~/Pages/Shop.aspx") %>" class="btn btn--primary">
                            <span>Explore Catalog</span>
                            <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <line x1="7" y1="17" x2="17" y2="7"></line>
                                <polyline points="7 7 17 7 17 17"></polyline>
                            </svg>
                        </a>
                    </div>
                `;
                return;
            }

            countLabel.textContent = `${items.length} ${items.length === 1 ? 'helmet' : 'helmets'} saved to your personal wishlist`;
            headerActions?.classList.remove('is-hidden');

            container.innerHTML = `
                <div class="favorites-grid">
                    ${items.map(item => {
                        const origPrice = Number(item.originalPrice ?? item.price ?? 0);
                        const discount = Number(item.discountPercentage ?? 0);
                        const price = Number(item.price ?? origPrice);
                        const rating = Number(item.rating ?? 0);
                        const hasPrice = item.price != null && Number.isFinite(price) && price > 0;
                        return `
                        <div class="fav-card" data-id="${item.productId}">
                            <div class="fav-card__media">
                                <img src="${escapeHtml(item.imageUrl)}" alt="${escapeHtml(item.name)}" class="fav-card__img" />
                                <button type="button" class="fav-card__remove-btn" data-remove-id="${item.productId}" aria-label="Remove from wishlist" title="Remove">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <line x1="18" y1="6" x2="6" y2="18"></line>
                                        <line x1="6" y1="6" x2="18" y2="18"></line>
                                    </svg>
                                </button>
                            </div>
                            <div class="fav-card__body">
                                <h3 class="fav-card__title">
                                    <a href="<%= ResolveUrl("~/Pages/ProductDetail.aspx?id=") %>${item.productId}">${escapeHtml(item.name)}</a>
                                </h3>
                                <div class="product-card__rating">
                                    <div class="stars">${generateStarsSvg(rating)}</div>
                                    <span class="rating-score">${Number(item.reviewCount || 0) > 0 ? `<span>${rating}</span>/5` : 'No reviews yet'}</span>
                                </div>
                                <div class="product-card__pricing">
                                    ${hasPrice ? `<span class="price-current">&#8369;${price.toLocaleString()}</span>` : '<span class="price-current">Price unavailable</span>'}
                                    ${hasPrice && discount > 0 ? `<span class="price-original">&#8369;${origPrice.toLocaleString()}</span><span class="discount-badge">-${discount}%</span>` : ''}
                                </div>
                                <div class="fav-card__actions">
                                    <a href="<%= ResolveUrl("~/Pages/ProductDetail.aspx?id=") %>${item.productId}" class="btn btn--primary btn--sm btn--block">
                                        <span>View &amp; Configure</span>
                                    </a>
                                </div>
                            </div>
                        </div>
                    `;
                    }).join('')}
                </div>
            `;

            // Attach remove listeners
            container.querySelectorAll('[data-remove-id]').forEach(btn => {
                btn.addEventListener('click', (e) => {
                    const id = parseInt(btn.getAttribute('data-remove-id'), 10);
                    const target = items.find(i => parseInt(i.productId, 10) === id);
                    FavoritesManager.removeFavorite(id);
                    RealtimeManager.showToast(`${target?.name || 'Item'} removed from your Wishlist.`, 'delete');
                    renderFavorites();
                });
            });
        }

        document.getElementById('btn-clear-favorites')?.addEventListener('click', () => {
            if (confirm('Are you sure you want to clear your wishlist?')) {
                FavoritesManager.clear();
                RealtimeManager.showToast('All items cleared from your Wishlist.', 'delete');
                renderFavorites();
            }
        });

        window.addEventListener('favoritesUpdated', renderFavorites);

        function escapeHtml(str) {
            if (!str) return '';
            return str
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;');
        }

        renderFavorites();
        async function refreshFavorites() {
            const saved = FavoritesManager.getItems();
            if (!saved.length) return;
            const fetched = await Promise.allSettled(saved.map(item => ApiClient.getProductById(item.productId)));
            const updated = saved.map((item, index) => {
                const product = fetched[index].status === 'fulfilled' ? fetched[index].value : null;
                if (!product) return item;
                const basePrice = Number(product.basePrice ?? 0);
                const discount = Number(product.discountPercentage ?? 0);
                return {
                    productId: product.id,
                    name: product.name,
                    brand: product.brand,
                    category: product.category,
                    imageUrl: product.mainImageUrl,
                    originalPrice: basePrice,
                    discountPercentage: discount,
                    price: Math.round(basePrice * (1 - discount / 100) * 100) / 100,
                    rating: Number(product.rating ?? 0),
                    reviewCount: Number(product.reviewCount ?? 0)
                };
            });
            const refreshedById = new Map(updated.map(item => [Number(item.productId), item]));
            FavoritesManager.saveItems(FavoritesManager.getItems().map(item => refreshedById.get(Number(item.productId)) || item));
        }
        refreshFavorites();
    </script>
</asp:Content>
