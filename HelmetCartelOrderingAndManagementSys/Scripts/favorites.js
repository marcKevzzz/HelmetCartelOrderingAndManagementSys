/** Wishlist presentation backed by the authenticated shopping API. */
import { APP_CONSTANTS } from './constants.js';
import { ShoppingState } from './shopping-state.js?v=20261004';

export const FavoritesManager = {
  getItems() { return ShoppingState.snapshot().favorites; },
  isFavorite(productId) { return this.getItems().some(i => Number(i.productId) === Number(productId)); },
  async toggleFavorite(product) {
    await ShoppingState.load();
    const id = Number(product.productId || product.id);
    const added = !this.isFavorite(id);
    await ShoppingState.mutate(APP_CONSTANTS.ENDPOINTS.SHOPPING_FAVORITE(id), added ? 'PUT' : 'DELETE');
    return added;
  },
  removeFavorite(id) { return ShoppingState.mutate(APP_CONSTANTS.ENDPOINTS.SHOPPING_FAVORITE(id), 'DELETE'); },
  clear() { return ShoppingState.mutate(APP_CONSTANTS.ENDPOINTS.SHOPPING_FAVORITES, 'DELETE'); },
  async refreshItems() { await ShoppingState.load(true); return this.getItems(); },
  updateFavoritesBadge() {
    const count = this.getItems().length;
    document.querySelectorAll('.nav-badge--favorites').forEach(badge => {
      badge.textContent = count;
      badge.classList.toggle('nav-badge--hidden', count === 0);
    });
  }
};
window.addEventListener('favoritesUpdated', () => FavoritesManager.updateFavoritesBadge());
