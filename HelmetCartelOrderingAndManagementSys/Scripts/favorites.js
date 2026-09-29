/**
 * HELMET CARTEL - FAVORITES / WISHLIST STATE MANAGER (favorites.js)
 * Manages persisted user wishlist items, badge counters, and real-time updates.
 */

import { APP_CONSTANTS } from './constants.js';

export const FavoritesManager = {
  STORAGE_KEY: APP_CONSTANTS.STORAGE_KEYS.FAVORITES_ITEMS,

  getItems() {
    try {
      const stored = localStorage.getItem(this.STORAGE_KEY);
      const items = stored ? JSON.parse(stored) : [];
      return Array.isArray(items) ? items.filter(item => item && typeof item === 'object').map(item =>
        Object.prototype.hasOwnProperty.call(item, 'reviewCount') ? item :
          { ...item, price: null, originalPrice: null, discountPercentage: 0, rating: 0, needsRefresh: true }
      ) : [];
    } catch {
      return [];
    }
  },

  saveItems(items) {
    try {
      localStorage.setItem(this.STORAGE_KEY, JSON.stringify(items));
    } catch (e) {
      console.warn('Unable to persist favorites:', e);
    }
    this.updateFavoritesBadge();
    window.dispatchEvent(new CustomEvent('favoritesUpdated', { detail: items }));
  },

  isFavorite(productId) {
    const id = parseInt(productId, 10);
    return this.getItems().some(item => parseInt(item.productId, 10) === id);
  },

  toggleFavorite(product) {
    const items = this.getItems();
    const prodId = parseInt(product.productId || product.id, 10);
    if (!Number.isSafeInteger(prodId) || prodId <= 0) return false;
    const existingIndex = items.findIndex(item => parseInt(item.productId, 10) === prodId);
    let isAdded = false;

    if (existingIndex > -1) {
      items.splice(existingIndex, 1);
      isAdded = false;
    } else {
      const basePrice = Number(product.basePrice ?? product.originalPrice ?? product.price ?? 0);
      const discount = Number(product.discountPercentage ?? 0);
      const price = Math.round(basePrice * (1 - discount / 100) * 100) / 100;

      items.push({
        productId: prodId,
        name: product.name,
        brand: product.brand || '',
        price: price,
        originalPrice: basePrice,
        discountPercentage: discount,
        imageUrl: product.mainImageUrl || product.imageUrl || '',
        rating: Number(product.rating ?? 0),
        reviewCount: Number(product.reviewCount ?? 0),
        category: product.category || ''
      });
      isAdded = true;
    }

    this.saveItems(items);
    return isAdded;
  },

  removeFavorite(productId) {
    const prodId = parseInt(productId, 10);
    const items = this.getItems().filter(item => parseInt(item.productId, 10) !== prodId);
    this.saveItems(items);
  },

  clear() {
    localStorage.removeItem(this.STORAGE_KEY);
    this.updateFavoritesBadge();
    window.dispatchEvent(new CustomEvent('favoritesUpdated', { detail: [] }));
  },

  updateFavoritesBadge() {
    const badges = document.querySelectorAll('.nav-badge--favorites');
    const count = this.getItems().length;
    badges.forEach(badge => {
      badge.textContent = count;
      badge.classList.toggle('nav-badge--hidden', count === 0);
      badge.style.display = count > 0 ? 'flex' : 'none';
    });
  }
};
