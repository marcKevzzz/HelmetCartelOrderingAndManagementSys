/**
 * HELMET CARTEL - FRONTEND CONSTANTS
 * Single source of truth for client-side API routes, statuses, storage keys, and events.
 */

export const APP_CONSTANTS = Object.freeze({
  API_BASE_URL: '/api/v1',

  ENDPOINTS: {
    AUTH_LOGIN: '/api/v1/auth/login',
    AUTH_REGISTER: '/api/v1/auth/register',
    AUTH_LOGOUT: '/api/v1/auth/logout',
    AUTH_ME: '/api/v1/auth/me',
    AUTH_PROFILE: '/api/v1/auth/profile',
    AUTH_CHANGE_PASSWORD: '/api/v1/auth/change-password',
    AUTH_MY_ORDERS: '/api/v1/auth/my-orders',
    AUTH_MY_ORDER_DETAILS: (id) => `/api/v1/auth/my-orders/${id}`,
    AUTH_MY_PAYMENTS: '/api/v1/auth/my-payments',
    AUTH_ADDRESSES: '/api/v1/auth/addresses',
    AUTH_ADDRESS_BY_ID: (id) => `/api/v1/auth/addresses/${id}`,
    PRODUCTS: '/api/v1/products',
    PRODUCT_DETAIL: (id) => `/api/v1/products/${id}`,
    INVENTORY: '/api/v1/inventory',
    INVENTORY_RESTOCK: '/api/v1/inventory/restock',
    ORDERS: '/api/v1/orders',
    ORDERS_INSTORE: '/api/v1/orders/in-store',
    ORDER_TRACK: (orderNumber) => `/api/v1/orders/track/${orderNumber}`,
    ADMIN_SELLABLE_VARIANTS: '/api/v1/admin/sellable-variants',
    ORDER_STATUS: (id) => `/api/v1/orders/${id}/status`,
    REPORTS_SALES: '/api/v1/reports/sales-summary',
    REPORTS_INVENTORY: '/api/v1/reports/inventory-valuation'
  },

  ORDER_STATUS: {
    PENDING_PAYMENT: 'PendingPayment',
    PROCESSING: 'Processing',
    READY_FOR_PICKUP: 'ReadyForPickup',
    SHIPPED: 'Shipped',
    DELIVERED: 'Delivered',
    COMPLETED: 'Completed',
    CANCELLED: 'Cancelled'
  },

  SHIPPING_METHODS: {
    PICKUP: 'Pickup',
    DELIVERY: 'Delivery'
  },

  COURIERS: {
    JT: 'J&T Express',
    LBC: 'LBC Express',
    FLASH: 'Flash Express',
    LALAMOVE: 'Lalamove',
    GRAB: 'Grab Express',
    OTHER: 'Other Courier'
  },

  SHIPPING_TIERS: {
    NCR: { name: 'Metro Manila (NCR)', fee: 150, eta: '1 - 2 Business Days' },
    GMA: { name: 'Greater Manila Area', fee: 250, eta: '2 - 3 Business Days' },
    LUZON: { name: 'Rest of Luzon', fee: 350, eta: '3 - 5 Business Days' },
    VISAYAS: { name: 'Visayas', fee: 450, eta: '5 - 7 Business Days' },
    MINDANAO: { name: 'Mindanao & Island Provinces', fee: 500, eta: '5 - 8 Business Days' },
    PICKUP: { name: 'Store Pickup (QC Hub)', fee: 0, eta: 'Ready in 1 - 2 Hours' }
  },

  PAYMENT_METHODS: {
    HITPAY: 'HitPay',
    CASH: 'Cash',
    CARD_POS: 'Card_POS',
    CASH_ON_DELIVERY: 'CashOnDelivery'
  },

  PAYMENT_STATUS: {
    PENDING: 'Pending',
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
    ADMIN_LOGIN_SUCCESS: 'hc_admin_login_success',
    AUTH_TOKEN: 'hc_auth_token',
    USER_PROFILE: 'hc_user_profile',
    CART_ITEMS: 'hc_cart_items',
    FAVORITES_ITEMS: 'hc_favorites_items',
    CART_PROMO: 'hc_cart_promo',
    SEARCH_HISTORY: 'hc_search_history',
    POS_SALE: 'hc_pos_sale'
  },

  UI: {
    LOW_STOCK_THRESHOLD: 3,
    DEFAULT_PAGE_SIZE: 12,
    SEARCH_HISTORY_LIMIT: 5,
    CURRENCY_SYMBOL: '\u20B1',
    CURRENCY_SYMBOL_HTML: '&#8369;'
  },

  ROUTES: {
    HOME: '/',
    AUTH: '/Pages/Auth/Auth.aspx',
    SHOP: '/Pages/Storefront/Shop/Shop.aspx',
    PRODUCT_DETAIL: (id) => `/Pages/Storefront/ProductDetail/ProductDetail.aspx?id=${id}`,
    CART: '/Pages/Storefront/Cart/Cart.aspx',
    CHECKOUT: '/Pages/Storefront/Checkout/Checkout.aspx',
    PROFILE: '/Pages/Storefront/Profile/Profile.aspx',
    FAVORITES: '/Pages/Storefront/Favorites/Favorites.aspx',
    TRACK_ORDER: '/Pages/Storefront/TrackOrder/TrackOrder.aspx',
    ADMIN_DASHBOARD: '/Pages/Admin/Dashboard/Dashboard.aspx',
    ADMIN_CATALOG: '/Pages/Admin/Catalog/Catalog.aspx',
    ADMIN_CATALOG_ITEM: (id) => id ? `/Pages/Admin/CatalogItem/CatalogItem.aspx?id=${id}` : '/Pages/Admin/CatalogItem/CatalogItem.aspx',
    ADMIN_INVENTORY: '/Pages/Admin/Inventory/Inventory.aspx',
    ADMIN_ORDERS: '/Pages/Admin/Orders/Orders.aspx',
    ADMIN_POS: '/Pages/Admin/POS/POS.aspx',
    ADMIN_REPORTS: '/Pages/Admin/Reports/Reports.aspx',
    ADMIN_USERS: '/Pages/Admin/Users/Users.aspx',
    ADMIN_REVIEWS: '/Pages/Admin/Reviews/Reviews.aspx',
    ADMIN_PAYMENTS: '/Pages/Admin/Payments/Payments.aspx'
  }
});
