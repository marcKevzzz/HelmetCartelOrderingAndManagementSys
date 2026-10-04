/** Shopping cart presentation backed by the authenticated shopping API. */
import { APP_CONSTANTS } from './constants.js';
import { ShoppingState } from './shopping-state.js?v=20261004';

export const CartManager = {
  getItems() { return ShoppingState.snapshot().cart; },
  async saveItems(items) {
    await ShoppingState.load();
    const keep = new Set(items.map(item => Number(item.variantId)));
    for (const item of this.getItems()) {
      if (!keep.has(Number(item.variantId))) await this.removeItem(item.variantId);
    }
  },
  async addItem(item) {
    if (!Number.isSafeInteger(Number(item.variantId)) || Number(item.quantity) <= 0) return false;
    await ShoppingState.mutate(APP_CONSTANTS.ENDPOINTS.SHOPPING_CART, 'POST', {
      variantId: Number(item.variantId), quantity: Number(item.quantity)
    });
    return true;
  },
  async toggleItemSelection(variantId) {
    await ShoppingState.load();
    const item = this.getItems().find(i => Number(i.variantId) === Number(variantId));
    if (!item || item.availableStock <= 0) return;
    await ShoppingState.mutate(APP_CONSTANTS.ENDPOINTS.SHOPPING_CART, 'PUT', {
      variantId: Number(variantId), isSelected: !item.isSelected
    });
  },
  selectAll(selected = true) {
    return ShoppingState.mutate(APP_CONSTANTS.ENDPOINTS.SHOPPING_CART_SELECTION(selected), 'PUT');
  },
  getSelectedItems() { return this.getItems().filter(i => i.isSelected && i.availableStock > 0); },
  getSelectedSubtotal() { return this.getSelectedItems().reduce((sum, i) => sum + i.price * i.quantity, 0); },
  updateQuantity(variantId, quantity) {
    return ShoppingState.mutate(APP_CONSTANTS.ENDPOINTS.SHOPPING_CART, 'PUT', {
      variantId: Number(variantId), quantity: Number(quantity)
    });
  },
  removeItem(variantId) { return ShoppingState.mutate(APP_CONSTANTS.ENDPOINTS.SHOPPING_CART_ITEM(variantId), 'DELETE'); },
  clear() { return ShoppingState.mutate(APP_CONSTANTS.ENDPOINTS.SHOPPING_CART, 'DELETE'); },
  getSubtotal() { return this.getItems().reduce((sum, i) => sum + i.price * i.quantity, 0); },
  async refreshItems() { await ShoppingState.load(true); return this.getItems(); },
  getDiscountAmount() { return 0; },
  getTotal() { return this.getSelectedSubtotal(); },
  updateCartBadge() {
    const count = this.getItems().reduce((sum, i) => sum + i.quantity, 0);
    document.querySelectorAll('.nav-badge:not(.nav-badge--favorites)').forEach(badge => {
      badge.textContent = count;
      badge.classList.toggle('nav-badge--hidden', count === 0);
    });
  }
};
window.addEventListener('cartUpdated', () => CartManager.updateCartBadge());
