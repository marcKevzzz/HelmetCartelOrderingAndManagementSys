/**
 * HELMET CARTEL - STOREFRONT FAVORITES / WISHLIST PAGE CONTROLLER (favorites.js)
 * Manages rendering of saved user favorites, star ratings, catalog linking,
 * item removal, and catalog price synchronization.
 */

import { FavoritesManager } from '../favorites.js?v=20261004';
import { ShoppingState } from '../shopping-state.js?v=20261004';
import { ApiClient } from '../api.js';
import { RealtimeManager } from '../realtime.js';
import { APP_CONSTANTS } from '../constants.js';

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

function escapeHtml(str) {
    if (!str) return '';
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

export function renderFavorites() {
    const container = document.getElementById('favorites-content');
    const countLabel = document.getElementById('favorites-count-label');
    const headerActions = document.getElementById('favorites-header-actions');
    if (!container) return;

    const items = FavoritesManager.getItems();

    if (items.length === 0) {
        if (countLabel) countLabel.textContent = "You don't have any saved helmets yet.";
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
                <a href="${APP_CONSTANTS.ROUTES.SHOP}" class="btn btn--primary">
                    <span>Explore Shop</span>
                    <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="7" y1="17" x2="17" y2="7"></line>
                        <polyline points="7 7 17 7 17 17"></polyline>
                    </svg>
                </a>
            </div>
        `;
        return;
    }

    if (countLabel) countLabel.textContent = `${items.length} ${items.length === 1 ? 'helmet' : 'helmets'} saved to your personal wishlist`;
    headerActions?.classList.remove('is-hidden');

    container.innerHTML = `
        <div class="favorites-grid">
            ${items.map(item => {
                const origPrice = Number(item.originalPrice ?? item.price ?? 0);
                const discount = Number(item.discountPercentage ?? 0);
                const price = Number(item.price ?? origPrice);
                const rating = Number(item.rating ?? 0);
                const hasPrice = item.price != null && Number.isFinite(price) && price > 0;
                const detailUrl = APP_CONSTANTS.ROUTES.PRODUCT_DETAIL(item.productId);
                const isOos = Boolean(item.isOutOfStock);
                return `
                <div class="fav-card ${isOos ? 'is-out-of-stock' : ''}" data-id="${item.productId}">
                    <div class="fav-card__media">
                        ${isOos ? '<span class="badge-out-of-stock">Out of Stock</span>' : ''}
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
                            <a href="${detailUrl}">${escapeHtml(item.name)}</a>
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
                            ${isOos ? `<a href="${detailUrl}" class="btn btn--outline btn--sm btn--block"><span>Out of Stock &bull; View</span></a>` : `<a href="${detailUrl}" class="btn btn--primary btn--sm btn--block"><span>View &amp; Configure</span></a>`}
                        </div>
                    </div>
                </div>
            `;
            }).join('')}
        </div>
    `;

    // Attach remove listeners
    container.querySelectorAll('[data-remove-id]').forEach(btn => {
        btn.addEventListener('click', () => ShoppingState.run(async () => {
            const id = parseInt(btn.getAttribute('data-remove-id'), 10);
            const target = items.find(i => parseInt(i.productId, 10) === id);
            await FavoritesManager.removeFavorite(id);
            RealtimeManager.showToast(`${target?.name || 'Item'} removed from your Wishlist.`, 'delete');
            renderFavorites();
        }));
    });
}

document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('btn-clear-favorites')?.addEventListener('click', () => ShoppingState.run(async () => {
        if (confirm('Are you sure you want to clear your wishlist?')) {
            await FavoritesManager.clear();
            RealtimeManager.showToast('All items cleared from your Wishlist.', 'delete');
            renderFavorites();
        }
    }));

    window.addEventListener('favoritesUpdated', renderFavorites);
    renderFavorites();
    ShoppingState.run(() => FavoritesManager.refreshItems());
});
