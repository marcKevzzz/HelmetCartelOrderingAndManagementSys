/**
 * HELMET CARTEL - REAL-TIME SIGNALR CLIENT INTEGRATION
 * Listens for stock updates, low-stock alerts, and orders.
 * Renders pure white toasts with clean SVG icons and minimal edge curve.
 */

import { APP_CONSTANTS } from './constants.js';

export const RealtimeManager = {
  hubConnection: null,

  init() {
    console.log('[RealtimeManager] Initializing real-time listener...');

    if (window.$ && window.$.hubConnection) {
      this.hubConnection = window.$.hubConnection('/signalr');
      const inventoryHubProxy = this.hubConnection.createHubProxy('inventoryHub');

      inventoryHubProxy.on(APP_CONSTANTS.SIGNALR_EVENTS.STOCK_UPDATED, (data) => {
        this.handleStockUpdated(data);
      });

      inventoryHubProxy.on(APP_CONSTANTS.SIGNALR_EVENTS.LOW_STOCK_ALERT, (data) => {
        this.handleLowStockAlert(data);
      });


      this.hubConnection.start()
        .done(() => {
          this.updateConnectionStatus(true);
        })
        .fail(() => {
          this.updateConnectionStatus(false);
        });

      // Clean disconnect and reconnect when page enters/leaves Back-Forward Cache (bfcache)
      window.addEventListener('pagehide', () => {
        try {
          if (this.hubConnection && typeof this.hubConnection.stop === 'function') {
            this.hubConnection.stop();
          }
        } catch (_) {}
      });

      window.addEventListener('pageshow', (event) => {
        if (event.persisted && this.hubConnection && typeof this.hubConnection.start === 'function') {
          this.hubConnection.start()
            .done(() => {
              this.updateConnectionStatus(true);
            })
            .fail(() => {
              this.updateConnectionStatus(false);
            });
        }
      });
    } else {
      this.updateConnectionStatus(false);
    }
  },

  handleStockUpdated(data) {
    const stockElements = document.querySelectorAll(`[data-variant-stock="${data.variantId}"]`);
    stockElements.forEach(el => {
      el.textContent = `${data.newStock} in stock`;
      if (data.newStock === 0) {
        el.classList.add('badge--danger');
        el.textContent = 'Out of Stock';
      }
    });

    window.dispatchEvent(new CustomEvent('stockUpdated', { detail: data }));
  },

  handleLowStockAlert(data) {
    this.showToast(`Low Stock: SKU ${data.sku} has only ${data.currentStock} left!`, 'alert');
  },

  handleNewOrder(data) {
    this.showToast(`New Order ${data.orderNumber} placed (\u20B1${data.totalAmount.toLocaleString()})`, 'success');
    window.dispatchEvent(new CustomEvent('newOrderReceived', { detail: data }));
  },

  updateConnectionStatus(isConnected) {
    const dot = document.querySelector('.status-dot');
    const label = document.querySelector('.status-label');
    if (dot && label) {
      dot.classList.toggle('is-connected', isConnected);
      label.textContent = isConnected ? 'SignalR Live Sync Active' : 'Offline';
    }
  },

  /**
   * Pure White Toast with minimal edge curve and vector icon
   */
  showToast(message, type = 'info') {
    let container = document.querySelector('.toast-container');
    if (!container) {
      container = document.createElement('div');
      container.className = 'toast-container';
      document.body.appendChild(container);
    }

    let iconSvg = '';
    if (type === 'cart') {
      iconSvg = `
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <circle cx="9" cy="21" r="1"></circle>
          <circle cx="20" cy="21" r="1"></circle>
          <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path>
        </svg>`;
    } else if (type === 'success') {
      iconSvg = `
        <svg viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
          <polyline points="22 4 12 14.01 9 11.01"></polyline>
        </svg>`;
    } else if (type === 'wishlist') {
      iconSvg = `
        <svg viewBox="0 0 24 24" fill="#DC2626" stroke="#DC2626" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>
        </svg>`;
    } else if (type === 'delete') {
      iconSvg = `
        <svg viewBox="0 0 24 24" fill="none" stroke="#DC2626" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="3 6 5 6 21 6"></polyline>
          <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
        </svg>`;
    } else if (type === 'alert') {
      iconSvg = `
        <svg viewBox="0 0 24 24" fill="none" stroke="#F59E0B" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
          <line x1="12" y1="9" x2="12" y2="13"></line>
          <line x1="12" y1="17" x2="12.01" y2="17"></line>
        </svg>`;
    } else {
      iconSvg = `
        <svg viewBox="0 0 24 24" fill="none" stroke="#171717" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"></circle>
          <line x1="12" y1="16" x2="12" y2="12"></line>
          <line x1="12" y1="8" x2="12.01" y2="8"></line>
        </svg>`;
    }

    const toast = document.createElement('div');
    toast.className = `toast toast--${type}`;
    toast.innerHTML = `
      <span class="toast__icon">${iconSvg}</span>
      <span class="toast__message">${message}</span>
    `;
    container.appendChild(toast);

    setTimeout(() => toast.remove(), 4000);
  }
};
