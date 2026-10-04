import { ApiClient } from './api.js';
import { APP_CONSTANTS } from './constants.js';
import { RealtimeManager } from './realtime.js';

// Memory is only a presentation snapshot. SQL Server owns all shopping state.
let state = { cart: [], favorites: [] };
let owner = null;
let loading = null;
let loadingOwner = null;
let revision = 0;
let queue = Promise.resolve();

function token() { return localStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.AUTH_TOKEN); }
function legacyItems(key) {
  try {
    const items = JSON.parse(localStorage.getItem(key) || '[]');
    return Array.isArray(items) ? items.slice(0, 500) : [];
  } catch { return []; }
}
function publish(value) {
  state = value;
  window.dispatchEvent(new CustomEvent('cartUpdated', { detail: state.cart }));
  window.dispatchEvent(new CustomEvent('favoritesUpdated', { detail: state.favorites }));
}

export const ShoppingState = {
  snapshot() {
    if (owner !== token()) { owner = null; state = { cart: [], favorites: [] }; }
    return state;
  },

  async load(force = false) {
    const current = token();
    if (!current) { owner = null; publish({ cart: [], favorites: [] }); return state; }
    if (loading) {
      if (loadingOwner === current) return loading;
      await loading;
      return this.load(force);
    }
    if (!force && owner === current) return state;
    loadingOwner = current;
    const startedRevision = revision;
    loading = (async () => {
      const cartKey = APP_CONSTANTS.STORAGE_KEYS.CART_ITEMS;
      const favoritesKey = APP_CONSTANTS.STORAGE_KEYS.FAVORITES_ITEMS;
      const hasLegacy = localStorage.getItem(cartKey) !== null || localStorage.getItem(favoritesKey) !== null;
      const cart = legacyItems(cartKey).filter(item => Number.isSafeInteger(Number(item?.variantId)) &&
        Number(item.variantId) > 0 && Number.isSafeInteger(Number(item.quantity)) && Number(item.quantity) > 0)
        .map(item => ({ variantId: Number(item.variantId), quantity: Math.min(9999, Number(item.quantity)), isSelected: item.isSelected !== false }));
      const favorites = legacyItems(favoritesKey).map(item => Number(item?.productId))
        .filter(id => Number.isSafeInteger(id) && id > 0);
      const result = hasLegacy ? await ApiClient.post(APP_CONSTANTS.ENDPOINTS.SHOPPING_IMPORT, { cart, favorites }) :
        await ApiClient.get(APP_CONSTANTS.ENDPOINTS.SHOPPING);
      if (token() !== current) return this.snapshot();
      if (hasLegacy) { localStorage.removeItem(cartKey); localStorage.removeItem(favoritesKey); }
      if (revision !== startedRevision) return state;
      owner = current;
      publish(result);
      return result;
    })();
    try { return await loading; } finally { loading = null; loadingOwner = null; }
  },

  mutate(url, method, data) {
    const current = token();
    const task = queue.then(async () => {
      if (!current || token() !== current) throw new Error('Sign in to save shopping items.');
      await this.load();
      const result = await ApiClient.request(url, {
        method,
        ...(data === undefined ? {} : { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
      });
      if (token() === current) { revision++; owner = current; publish(result); }
      return result;
    });
    queue = task.catch(() => {});
    return task;
  },

  async run(action) {
    try { return await action(); }
    catch (error) { RealtimeManager.showToast(error.message || 'Shopping items could not be saved.', 'alert'); return undefined; }
  }
};

// Every storefront page hydrates both collections with one request.
function hydrate() { ShoppingState.run(() => ShoppingState.load()); }
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', hydrate);
else hydrate();
window.addEventListener('storage', event => {
  if (event.key === APP_CONSTANTS.STORAGE_KEYS.AUTH_TOKEN || event.key === null) {
    owner = null;
    publish({ cart: [], favorites: [] });
    hydrate();
  }
});
window.addEventListener('pageshow', event => { if (event.persisted) ShoppingState.run(() => ShoppingState.load(true)); });
window.addEventListener('focus', () => { if (token()) ShoppingState.run(() => ShoppingState.load(true)); });
