/**
 * HELMET CARTEL - API CLIENT MODULE
 * Handles fetch calls, JSON payloads, and JWT authorization headers.
 */

import { APP_CONSTANTS } from './constants.js';

export const ApiClient = {
  async get(url, params = {}) {
    const query = new URLSearchParams(params).toString();
    const fullUrl = query ? `${url}?${query}` : url;
    return this.request(fullUrl, { method: 'GET' });
  },

  async post(url, data = {}) {
    return this.request(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
  },

  async put(url, data = {}) {
    return this.request(url, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
  },

  async getProducts(params = {}) {
    return this.get('/api/v1/products', params);
  },

  async getProductById(id) {
    return this.get(`/api/v1/products/${id}`);
  },

  async getCategories() {
    return this.get('/api/v1/products/categories');
  },

  async getBrands() {
    return this.get('/api/v1/products/brands');
  },

  async createOrder(orderData) {
    return this.post('/api/v1/orders', orderData);
  },

  async getProfile() {
    return this.get(APP_CONSTANTS.ENDPOINTS.AUTH_ME);
  },

  async updateProfile(data) {
    return this.put(APP_CONSTANTS.ENDPOINTS.AUTH_PROFILE, data);
  },

  async changePassword(data) {
    return this.put(APP_CONSTANTS.ENDPOINTS.AUTH_CHANGE_PASSWORD, data);
  },

  async getUserOrders() {
    return this.get(APP_CONSTANTS.ENDPOINTS.AUTH_MY_ORDERS);
  },

  async getUserOrderDetails(id) {
    return this.get(APP_CONSTANTS.ENDPOINTS.AUTH_MY_ORDER_DETAILS(id));
  },

  async getUserPayments() {
    return this.get(APP_CONSTANTS.ENDPOINTS.AUTH_MY_PAYMENTS);
  },

  async getUserAddresses() {
    return this.get(APP_CONSTANTS.ENDPOINTS.AUTH_ADDRESSES);
  },

  async saveUserAddress(data) {
    return this.post(APP_CONSTANTS.ENDPOINTS.AUTH_ADDRESSES, data);
  },

  async deleteUserAddress(id) {
    return this.request(APP_CONSTANTS.ENDPOINTS.AUTH_ADDRESS_BY_ID(id), { method: 'DELETE' });
  },

  isAuthenticated() {
    return !!localStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.AUTH_TOKEN);
  },

  getCurrentUser() {
    try {
      const stored = localStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.USER_PROFILE);
      return stored ? JSON.parse(stored) : null;
    } catch {
      return null;
    }
  },

  async trackOrder(orderNumber) {
    return this.get(APP_CONSTANTS.ENDPOINTS.ORDER_TRACK(orderNumber));
  },

  async logout() {
    return this.post(APP_CONSTANTS.ENDPOINTS.AUTH_LOGOUT);
  },

  async request(url, options = {}) {
    const token = localStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.AUTH_TOKEN);
    const headers = {
      Accept: 'application/json',
      ...options.headers
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    try {
      const response = await fetch(url, { ...options, headers });
      const json = await response.json();

      if (!response.ok) {
        throw new Error(json.message || `HTTP ${response.status}: Request failed`);
      }

      return json.data !== undefined ? json.data : json;
    } catch (err) {
      console.error(`[API Error] ${options.method || 'GET'} ${url}:`, err);
      throw err;
    }
  }
};
