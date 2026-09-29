/**
 * HELMET CARTEL - FRONTEND CONSTANTS
 * Single source of truth for client-side API routes, statuses, storage keys, and events.
 */

export const APP_CONSTANTS = Object.freeze({
  API_BASE_URL: '/api/v1',

  ENDPOINTS: {
    AUTH_LOGIN: '/api/v1/auth/login',
    AUTH_REGISTER: '/api/v1/auth/register',
    PRODUCTS: '/api/v1/products',
    PRODUCT_DETAIL: (id) => `/api/v1/products/${id}`,
    INVENTORY: '/api/v1/inventory',
    INVENTORY_RESTOCK: '/api/v1/inventory/restock',
    ORDERS: '/api/v1/orders',
    ORDERS_INSTORE: '/api/v1/orders/in-store',
    ORDER_STATUS: (id) => `/api/v1/orders/${id}/status`,
    REPORTS_SALES: '/api/v1/reports/sales-summary',
    REPORTS_INVENTORY: '/api/v1/reports/inventory-valuation'
  },

  ORDER_STATUS: {
    PENDING_PAYMENT: 'PendingPayment',
    PROCESSING: 'Processing',
    READY_FOR_PICKUP: 'ReadyForPickup',
    COMPLETED: 'Completed',
    CANCELLED: 'Cancelled'
  },

  PAYMENT_METHODS: {
    HITPAY: 'HitPay',
    CASH: 'Cash',
    CARD_POS: 'Card_POS'
  },

  PAYMENT_STATUS: {
    COMPLETED: 'Completed'
  },

  COLOR_TYPES: {
    SOLID: 'SOLID',
    LINEAR_GRADIENT: 'LINEAR_GRADIENT'
  },

  ROLES: {
    ADMIN: 'Admin',
    STAFF: 'Staff',
    CUSTOMER: 'Customer'
  },

  SIGNALR_EVENTS: {
    STOCK_UPDATED: 'stockUpdated',
    LOW_STOCK_ALERT: 'lowStockAlert',
    NEW_ORDER_RECEIVED: 'newOrderReceived',
    ORDER_STATUS_CHANGED: 'orderStatusChanged'
  },

  STORAGE_KEYS: {
    AUTH_TOKEN: 'hc_auth_token',
    USER_PROFILE: 'hc_user_profile',
    CART_ITEMS: 'hc_cart_items',
    FAVORITES_ITEMS: 'hc_favorites_items',
    CART_PROMO: 'hc_cart_promo',
    SEARCH_HISTORY: 'hc_search_history'
  },

  UI: {
    LOW_STOCK_THRESHOLD: 3,
    DEFAULT_PAGE_SIZE: 12,
    SEARCH_HISTORY_LIMIT: 5,
    CURRENCY_SYMBOL: '\u20B1',
    CURRENCY_SYMBOL_HTML: '&#8369;'
  }
});
