/**
 * HELMET CARTEL - SHOPPING CART STATE MANAGER
 * Manages cart persistence, quantities, discounts, and order payload generation.
 */

import { APP_CONSTANTS } from './constants.js';
import { ApiClient } from './api.js';

export const CartManager = {
  getItems() {
    try {
      const stored = localStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.CART_ITEMS);
      const items = stored ? JSON.parse(stored) : [];
      return Array.isArray(items) ? items : [];
    } catch {
      return [];
    }
  },

  saveItems(items) {
    localStorage.setItem(APP_CONSTANTS.STORAGE_KEYS.CART_ITEMS, JSON.stringify(items));
    this.updateCartBadge();
    window.dispatchEvent(new CustomEvent('cartUpdated', { detail: items }));
  },

  addItem(item) {
    const variantId = Number(item.variantId);
    const quantity = Number(item.quantity);
    const price = Number(item.price);
    const availableStock = Number(item.availableStock);
    if (!Number.isSafeInteger(variantId) || variantId <= 0 ||
        !Number.isSafeInteger(quantity) || quantity <= 0 ||
        !Number.isFinite(price) || price <= 0) return false;
    const items = this.getItems();
    const existingIndex = items.findIndex(i => Number(i.variantId) === variantId);
    const nextQuantity = quantity + (existingIndex >= 0 ? Number(items[existingIndex].quantity) : 0);
    if (Number.isFinite(availableStock) && nextQuantity > availableStock) return false;

    if (existingIndex > -1) {
      items[existingIndex].quantity += quantity;
      items[existingIndex].price = price;
      items[existingIndex].availableStock = availableStock;
      items[existingIndex].isSelected = true;
    } else {
      items.push({
        variantId,
        productId: Number(item.productId),
        name: item.name,
        brand: item.brand,
        size: item.size,
        color: item.color,
        price,
        availableStock,
        imageUrl: item.imageUrl,
        quantity,
        isSelected: true
      });
    }

    this.saveItems(items);
    return true;
  },

  toggleItemSelection(variantId) {
    const items = this.getItems();
    const item = items.find(i => String(i.variantId) === String(variantId));
    if (item) {
      if (Number(item.availableStock) <= 0) return;
      item.isSelected = !(item.isSelected !== false);
      this.saveItems(items);
    }
  },

  selectAll(selected = true) {
    const items = this.getItems();
    items.forEach(i => {
      if (Number(i.availableStock) > 0 || !Number.isFinite(Number(i.availableStock))) {
        i.isSelected = selected;
      } else {
        i.isSelected = false;
      }
    });
    this.saveItems(items);
  },

  getSelectedItems() {
    return this.getItems().filter(i => i.isSelected !== false && (Number(i.availableStock) > 0 || !Number.isFinite(Number(i.availableStock))));
  },

  getSelectedSubtotal() {
    return this.getSelectedItems().reduce((sum, item) => sum + (Number(item.price) * Number(item.quantity)), 0);
  },

  updateQuantity(variantId, quantity) {
    let items = this.getItems();
    if (quantity <= 0) {
      items = items.filter(i => String(i.variantId) !== String(variantId));
    } else {
      const item = items.find(i => String(i.variantId) === String(variantId));
      if (item && (!Number.isFinite(Number(item.availableStock)) || quantity <= Number(item.availableStock))) item.quantity = quantity;
    }
    this.saveItems(items);
  },

  removeItem(variantId) {
    this.updateQuantity(variantId, 0);
  },

  clear() {
    localStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.CART_ITEMS);
    this.updateCartBadge();
    window.dispatchEvent(new CustomEvent('cartUpdated', { detail: [] }));
  },

  getSubtotal() {
    return this.getItems().reduce((sum, item) => sum + (Number(item.price) * Number(item.quantity)), 0);
  },

  async refreshItems() {
    const items = this.getItems();
    const ids = [...new Set(items.map(item => Number(item.productId)).filter(Number.isSafeInteger))];
    if (!ids.length) return items;
    const results = await Promise.allSettled(ids.map(id => ApiClient.getProductById(id)));
    const products = new Map(results.map((result, index) => [ids[index], result.status === 'fulfilled' ? result.value : null]));
    const updated = this.getItems().map(item => {
      const product = products.get(Number(item.productId));
      if (!product) return item;
      const variant = product.variants?.find(v => Number(v.id) === Number(item.variantId));
      if (!variant) return { ...item, availableStock: 0 };
      const base = Number(product.basePrice) + Number(variant.priceAdjustment || 0);
      return {
        ...item,
        name: product.name,
        brand: product.brand,
        imageUrl: product.mainImageUrl,
        size: variant.size,
        color: variant.color,
        price: Math.round(base * (1 - Number(product.discountPercentage || 0) / 100) * 100) / 100,
        availableStock: Number(variant.availableStock ?? variant.currentStock ?? 0)
      };
    });
    this.saveItems(updated);
    return updated;
  },

  getDiscountAmount() {
    return 0;
  },

  getTotal() {
    return this.getSelectedSubtotal() - this.getDiscountAmount();
  },

  updateCartBadge() {
    const badges = document.querySelectorAll('.nav-badge:not(.nav-badge--favorites)');
    if (!badges || badges.length === 0) return;

    const count = this.getItems().reduce((sum, i) => sum + i.quantity, 0);
    badges.forEach(badge => {
      badge.textContent = count;
      badge.style.display = count > 0 ? 'flex' : 'none';
    });
  }
};
