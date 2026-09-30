/**
 * HELMET CARTEL - GLOBAL SITE CONTROLLER (site.js)
 * Controls Mega Menu, Mobile Drawer, Live Search Autocomplete, 
 * Balanced Sliding Cart Drawer, and Favorites Wishlist.
 */

import { CartManager } from './cart.js';
import { FavoritesManager } from './favorites.js';
import { RealtimeManager } from './realtime.js';
import { ApiClient } from './api.js';
import { APP_CONSTANTS } from './constants.js';

export const SiteController = {
  getSearchHistory() {
    try {
      const stored = JSON.parse(localStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.SEARCH_HISTORY) || '[]');
      return Array.isArray(stored)
        ? stored.filter(query => typeof query === 'string' && query.trim()).slice(0, APP_CONSTANTS.UI.SEARCH_HISTORY_LIMIT)
        : [];
    } catch (_) {
      return [];
    }
  },

  saveSearchHistory(query) {
    const value = String(query || '').trim().slice(0, 200);
    if (!value) return;
    const updated = [value, ...this.getSearchHistory().filter(item => item.toLowerCase() !== value.toLowerCase())]
      .slice(0, APP_CONSTANTS.UI.SEARCH_HISTORY_LIMIT);
    try {
      localStorage.setItem(APP_CONSTANTS.STORAGE_KEYS.SEARCH_HISTORY, JSON.stringify(updated));
    } catch (_) {
      // Search remains usable when browser storage is unavailable.
    }
  },

  clearSearchHistory() {
    try {
      localStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.SEARCH_HISTORY);
    } catch (_) {
      // Search remains usable when browser storage is unavailable.
    }
  },

  removeSearchHistory(query) {
    const value = String(query || '').trim().toLowerCase();
    if (!value) return;
    const updated = this.getSearchHistory().filter(item => item.toLowerCase() !== value);
    try {
      if (updated.length) {
        localStorage.setItem(APP_CONSTANTS.STORAGE_KEYS.SEARCH_HISTORY, JSON.stringify(updated));
      } else {
        localStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.SEARCH_HISTORY);
      }
    } catch (_) {
      // Search remains usable when browser storage is unavailable.
    }
  },

  init() {
    document.querySelector('.top-bar__close')?.addEventListener('click', () => {
      document.querySelector('.top-bar')?.classList.add('is-hidden');
    });
    this.initMegaMenu();
    this.initMobileNav();
    this.initSearchSuggestions();
    this.initCartDrawer();
    CartManager.updateCartBadge();
    FavoritesManager.updateFavoritesBadge();
  },

  /* ==========================================================================
     1. FULL-WIDTH MEGA MENU (Desktop)
     ========================================================================== */
  initMegaMenu() {
    const triggerWrap = document.querySelector('.nav-item--has-mega');
    const triggerLink = document.getElementById('shop-mega-trigger');
    const megaMenu = document.getElementById('shop-mega-menu');

    if (!triggerWrap || !megaMenu) return;

    let timeoutId = null;

    const openMenu = () => {
      clearTimeout(timeoutId);
      megaMenu.classList.add('is-active');
      triggerLink?.classList.add('is-active');
    };

    const closeMenu = () => {
      timeoutId = setTimeout(() => {
        megaMenu.classList.remove('is-active');
        triggerLink?.classList.remove('is-active');
      }, 150);
    };

    triggerWrap.addEventListener('mouseenter', openMenu);
    triggerWrap.addEventListener('mouseleave', closeMenu);
    megaMenu.addEventListener('mouseenter', openMenu);
    megaMenu.addEventListener('mouseleave', closeMenu);

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && megaMenu.classList.contains('is-active')) {
        megaMenu.classList.remove('is-active');
        triggerLink?.classList.remove('is-active');
      }
    });

    document.addEventListener('click', (e) => {
      if (!triggerWrap.contains(e.target) && !megaMenu.contains(e.target)) {
        megaMenu.classList.remove('is-active');
        triggerLink?.classList.remove('is-active');
      }
    });
  },

  /* ==========================================================================
     2. MOBILE NAVIGATION DRAWER
     ========================================================================== */
  initMobileNav() {
    const toggleBtn = document.getElementById('mobile-nav-toggle');
    const drawer = document.getElementById('mobile-nav-drawer');
    const overlay = document.getElementById('mobile-nav-overlay');
    const closeBtn = document.getElementById('mobile-nav-close');
    const accordionBtn = document.getElementById('mobile-shop-accordion-btn');
    const accordionPanel = document.getElementById('mobile-shop-accordion-panel');
    const mobileSearchInput = document.getElementById('mobile-search-input');
    const mobileSearchBtn = document.getElementById('mobile-search-btn');
    const mobileSearchResults = document.getElementById('mobile-search-results');

    if (!drawer || !overlay) return;

    const openMobileNav = () => {
      drawer.classList.add('is-open');
      overlay.classList.add('is-open');
      drawer.setAttribute('aria-hidden', 'false');
      document.body.classList.add('drawer-locked');
      FavoritesManager.updateFavoritesBadge();
      CartManager.updateCartBadge();
    };

    const closeMobileNav = () => {
      drawer.classList.remove('is-open');
      overlay.classList.remove('is-open');
      drawer.setAttribute('aria-hidden', 'true');
      document.body.classList.remove('drawer-locked');
      mobileSearchResults?.classList.remove('is-open');
    };

    toggleBtn?.addEventListener('click', openMobileNav);
    closeBtn?.addEventListener('click', closeMobileNav);
    overlay?.addEventListener('click', closeMobileNav);

    // Accordion toggle inside mobile nav
    accordionBtn?.addEventListener('click', () => {
      accordionBtn.classList.toggle('active');
      accordionPanel?.classList.toggle('is-open');
    });

    const renderMobileHistory = () => {
      if (!mobileSearchResults) return;
      const history = this.getSearchHistory();
      mobileSearchResults.innerHTML = history.length ? `
        <div class="search-history-header">
        <span class="admin-search-history-title">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <circle cx="12" cy="12" r="10"></circle>
              <polyline points="12 6 12 12 16 14"></polyline>
            </svg>
            Recent Searches
          </span>
           <button type="button" class="search-history-clear">Clear All</button></div>
        ${history.map(query => `<div class="search-history-entry">
          <a href="/Pages/Shop.aspx?q=${encodeURIComponent(query)}" class="mobile-search-result search-history-item" data-search-query="${this.escapeHtml(query)}">${this.escapeHtml(query)}</a>
          <button type="button" class="search-history-remove" data-search-query="${this.escapeHtml(query)}" aria-label="Remove ${this.escapeHtml(query)} from search history" title="Remove search"><span aria-hidden="true">&times;</span></button>
        </div>`).join('')}` : '';
      mobileSearchResults.classList.toggle('is-open', history.length > 0);
    };

    // Mobile Search Submission
    const handleMobileSearch = () => {
      const q = (mobileSearchInput?.value || '').trim();
      if (q) {
        this.saveSearchHistory(q);
        closeMobileNav();
        const baseUrl = window.location.pathname.toLowerCase().includes('/pages/') ? 'Shop.aspx' : 'Pages/Shop.aspx';
        window.location.href = `${baseUrl}?q=${encodeURIComponent(q)}`;
      }
    };

    mobileSearchBtn?.addEventListener('click', handleMobileSearch);
    mobileSearchInput?.addEventListener('focus', () => {
      if (!mobileSearchInput.value.trim()) renderMobileHistory();
    });
    mobileSearchResults?.addEventListener('click', event => {
      const removeButton = event.target.closest('.search-history-remove');
      if (removeButton) {
        event.preventDefault();
        this.removeSearchHistory(removeButton.dataset.searchQuery);
        renderMobileHistory();
        return;
      }
      if (event.target.closest('.search-history-clear')) {
        event.preventDefault();
        this.clearSearchHistory();
        renderMobileHistory();
        return;
      }
      const link = event.target.closest('a');
      if (link) this.saveSearchHistory(link.dataset.searchQuery || mobileSearchInput?.value);
    });
    mobileSearchInput?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        handleMobileSearch();
      }
    });

    let mobileSearchTimer;
    let mobileRequestId = 0;
    mobileSearchInput?.addEventListener('input', () => {
      clearTimeout(mobileSearchTimer);
      const q = mobileSearchInput.value.trim();
      const currentRequest = ++mobileRequestId;
      if (!q) {
        renderMobileHistory();
        return;
      }
      mobileSearchTimer = setTimeout(async () => {
        try {
          const result = await ApiClient.getProducts({ search: q, page: 1, pageSize: 4 });
          if (currentRequest !== mobileRequestId || !mobileSearchResults) return;
          const items = result?.items || [];
          mobileSearchResults.innerHTML = items.length
            ? items.map(item => `<a href="/Pages/ProductDetail.aspx?id=${Number(item.id)}" class="mobile-search-result">
                ${this.escapeHtml(item.name)} <span>&#8369;${Number(item.effectivePrice ?? item.basePrice ?? 0).toLocaleString()}</span>
              </a>`).join('') + `<a href="/Pages/Shop.aspx?q=${encodeURIComponent(q)}" class="mobile-search-result mobile-search-result--all">View all results</a>`
            : `<a href="/Pages/Shop.aspx?q=${encodeURIComponent(q)}" class="mobile-search-result">No suggestions. View shop results</a>`;
          mobileSearchResults.classList.add('is-open');
        } catch (error) {
          if (currentRequest !== mobileRequestId || !mobileSearchResults) return;
          mobileSearchResults.innerHTML = `<a href="/Pages/Shop.aspx?q=${encodeURIComponent(q)}" class="mobile-search-result">Open shop results</a>`;
          mobileSearchResults.classList.add('is-open');
        }
      }, 180);
    });

    // Close when clicking mobile sublinks
    drawer.querySelectorAll('a').forEach(a => {
      a.addEventListener('click', () => {
        closeMobileNav();
      });
    });
  },

  /* ==========================================================================
     3. LIVE NAVBAR SEARCH & AUTO-SUGGESTIONS
     ========================================================================== */
  initSearchSuggestions() {
    const input = document.getElementById('nav-search-input');
    const clearBtn = document.getElementById('nav-search-clear');
    const dropdown = document.getElementById('nav-search-dropdown');
    const container = document.getElementById('nav-search-container');

    if (!input || !dropdown) return;

    let activeIndex = -1;
    let requestId = 0;
    let debounceTimer;
    const shopUrl = query => `/Pages/Shop.aspx?q=${encodeURIComponent(query)}`;
    const showSuggestions = async query => {
      const q = (query || '').trim();
      const thisRequest = ++requestId;
      if (!q) {
        const history = this.getSearchHistory();
        if (!history.length) {
          hideSuggestions();
          return;
        }
        dropdown.innerHTML = `
          <div class="search-group">
            <div class="search-group-title">
            <span class="search-group-history">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <circle cx="12" cy="12" r="10"></circle>
              <polyline points="12 6 12 12 16 14"></polyline>
            </svg>
            Recent Searches
          </span>
              <button type="button" class="search-history-clear">Clear All</button>
            </div>
            ${history.map(item => `
              <div class="search-item search-history-entry">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="admin-search-history-icon" aria-hidden="true">
              <circle cx="11" cy="11" r="8"></circle>
              <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
            </svg>
                <a href="${shopUrl(item)}" class="search-item-info search-history-item" data-search-query="${this.escapeHtml(item)}">
                  <span class="search-item-title">${this.escapeHtml(item)}</span>
                </a>
                <button type="button" class="search-history-remove" data-search-query="${this.escapeHtml(item)}" aria-label="Remove ${this.escapeHtml(item)}" title="Remove">&times;</button>
              </div>`).join('')}
          </div>`;
      } else {
        dropdown.innerHTML = `
          <div class="search-group">
            <div class="search-group-title">SEARCHING...</div>
          </div>`;
        try {
          const result = await ApiClient.getProducts({ search: q, page: 1, pageSize: 6 });
          if (thisRequest !== requestId) return;
          const matches = result?.items || [];
          if (matches.length === 0) {
            dropdown.innerHTML = `
              <div class="search-empty">
                <p>No helmets found matching "<strong>${this.escapeHtml(q)}</strong>"</p>
                <a href="${shopUrl(q)}" class="search-view-all-pill">Browse all in shop &rarr;</a>
              </div>`;
          } else {
            dropdown.innerHTML = `
              <div class="search-group">
                <div class="search-group-title">MATCHING HELMETS (${result.totalCount || matches.length})</div>
                <div class="search-results-list">
                  ${matches.map((item, index) => `
                    <a href="/Pages/ProductDetail.aspx?id=${Number(item.id)}" class="search-item search-result-row" data-index="${index}">
                      <img src="${this.escapeHtml(item.mainImageUrl || '/Content/images/placeholder-helmet.png')}" alt="${this.escapeHtml(item.name)}" class="search-thumb search-result-thumb" onerror="this.src='/Content/images/placeholder-helmet.png'" />
                      <div class="search-item-info search-result-info">
                        <span class="search-item-title search-result-title">${this.highlightMatch(item.name, q)}</span>
                        <span class="search-item-sub search-result-brand">${this.escapeHtml(item.brand)} &bull; ${this.escapeHtml(item.category || item.ridingStyle || 'Helmet')}</span>
                      </div>
                      <span class="search-badge search-result-price">&#8369;${Number(item.effectivePrice ?? item.basePrice ?? 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                    </a>`).join('')}
                </div>
              </div>
              <a href="${shopUrl(q)}" class="search-view-all">
                <span>View all results for "<strong>${this.escapeHtml(q)}</strong>"</span>
                <span class="search-badge">&rarr;</span>
              </a>`;
          }
        } catch (error) {
          if (thisRequest !== requestId) return;
          dropdown.innerHTML = `
            <div class="search-empty">
              <p>Search is unavailable right now.</p>
              <a href="${shopUrl(q)}" class="search-view-all-pill">Open shop &rarr;</a>
            </div>`;
        }
      }
      dropdown.classList.add('is-open');
      dropdown.setAttribute('aria-hidden', 'false');
    };

    dropdown.addEventListener('click', (e) => {
      const removeButton = e.target.closest('.search-history-remove');
      if (removeButton) {
        e.preventDefault();
        e.stopPropagation();
        this.removeSearchHistory(removeButton.dataset.searchQuery);
        showSuggestions('');
        return;
      }
      if (e.target.closest('.search-history-clear')) {
        e.preventDefault();
        this.clearSearchHistory();
        hideSuggestions();
        return;
      }
      const link = e.target.closest('a');
      if (link) this.saveSearchHistory(link.dataset.searchQuery || input.value);
      e.stopPropagation();
    });

    const hideSuggestions = () => {
      dropdown.classList.remove('is-open');
      dropdown.setAttribute('aria-hidden', 'true');
      activeIndex = -1;
    };

    input.addEventListener('focus', () => {
      showSuggestions(input.value);
    });

    input.addEventListener('input', () => {
      const val = input.value;
      clearBtn?.classList.toggle('is-visible', val.length > 0);
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => showSuggestions(val), 180);
    });

    clearBtn?.addEventListener('click', () => {
      input.value = '';
      clearBtn.classList.remove('is-visible');
      input.focus();
      showSuggestions('');
    });

    const initialQuery = new URLSearchParams(window.location.search).get('q');
    if (initialQuery && window.location.pathname.toLowerCase().includes('/shop.aspx')) {
      input.value = initialQuery;
      clearBtn?.classList.add('is-visible');
      this.saveSearchHistory(initialQuery);
    }

    // Keyboard navigation
    input.addEventListener('keydown', (e) => {
      const rows = dropdown.querySelectorAll('.search-result-row');

      if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (rows.length === 0) return;
        activeIndex = (activeIndex + 1) % rows.length;
        rows.forEach((r, i) => r.classList.toggle('active', i === activeIndex));
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (rows.length === 0) return;
        activeIndex = (activeIndex - 1 + rows.length) % rows.length;
        rows.forEach((r, i) => r.classList.toggle('active', i === activeIndex));
      } else if (e.key === 'Enter') {
        if (activeIndex > -1 && rows[activeIndex]) {
          e.preventDefault();
          rows[activeIndex].click();
        } else if (input.value.trim()) {
          e.preventDefault();
          this.saveSearchHistory(input.value.trim());
          const baseUrl = window.location.pathname.toLowerCase().includes('/pages/') ? 'Shop.aspx' : 'Pages/Shop.aspx';
          window.location.href = `${baseUrl}?q=${encodeURIComponent(input.value.trim())}`;
        }
      } else if (e.key === 'Escape') {
        hideSuggestions();
      }
    });

    document.addEventListener('click', (e) => {
      if (!container?.contains(e.target)) {
        hideSuggestions();
      }
    });
  },

  /* ==========================================================================
     4. SLIDING SHOPPING CART DRAWER (Balanced Layout)
     ========================================================================== */
  initCartDrawer() {
    const cartBtn = document.getElementById('nav-cart-btn');
    const mobileCartLink = document.getElementById('mobile-nav-cart-link');
    const drawer = document.getElementById('cart-drawer');
    const overlay = document.getElementById('cart-drawer-overlay');
    const closeBtn = document.getElementById('cart-drawer-close');
    const viewCartBtn = document.getElementById('drawer-view-cart');

    if (!drawer || !overlay) return;

    const openDrawer = () => {
      this.renderCartDrawer();
      drawer.classList.add('is-open');
      overlay.classList.add('is-open');
      drawer.setAttribute('aria-hidden', 'false');
      document.body.classList.add('drawer-locked');
    };

    const closeDrawer = () => {
      drawer.classList.remove('is-open');
      overlay.classList.remove('is-open');
      drawer.setAttribute('aria-hidden', 'true');
      document.body.classList.remove('drawer-locked');
    };

    if (cartBtn) {
      cartBtn.addEventListener('click', (e) => {
        if (!e.ctrlKey && !e.metaKey) {
          e.preventDefault();
          openDrawer();
        }
      });
    }

    if (mobileCartLink) {
      mobileCartLink.addEventListener('click', (e) => {
        e.preventDefault();
        const mobileDrawer = document.getElementById('mobile-nav-drawer');
        const mobileOverlay = document.getElementById('mobile-nav-overlay');
        mobileDrawer?.classList.remove('is-open');
        mobileOverlay?.classList.remove('is-open');
        openDrawer();
      });
    }

    closeBtn?.addEventListener('click', closeDrawer);
    viewCartBtn?.addEventListener('click', closeDrawer);
    viewCartBtn?.addEventListener('click', () => {
      window.location.href = '/Pages/Cart.aspx';
    });
    overlay?.addEventListener('click', closeDrawer);

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && drawer.classList.contains('is-open')) {
        closeDrawer();
      }
    });

    window.addEventListener('cartUpdated', () => {
      this.renderCartDrawer();
    });

    // NOTE: Removed auto-open on add-to-cart per user requirement
    // Initial render
    this.renderCartDrawer();
  },

  renderCartDrawer() {
    const bodyEl = document.getElementById('drawer-cart-body');
    const footerEl = document.getElementById('drawer-cart-footer');
    const countEl = document.getElementById('drawer-cart-count');
    const subtotalEl = document.getElementById('drawer-subtotal');

    if (!bodyEl) return;

    const items = CartManager.getItems();
    const totalQty = items.reduce((sum, item) => sum + item.quantity, 0);

    if (countEl) {
      countEl.textContent = `(${totalQty} ${totalQty === 1 ? 'item' : 'items'})`;
    }

    if (items.length === 0) {
      bodyEl.innerHTML = `
        <div class="cart-drawer-empty">
          <div class="cart-drawer-empty__icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <circle cx="9" cy="21" r="1"></circle>
              <circle cx="20" cy="21" r="1"></circle>
              <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path>
            </svg>
          </div>
          <h4 class="cart-drawer-empty__title">Your cart is empty</h4>
          <p class="cart-drawer-empty__desc">Explore our DOT &amp; ECE-certified helmets to protect your next ride.</p>
          <a href="/Pages/Shop.aspx" class="btn btn--outline btn--sm">
            <span>Explore Catalog</span>
            <svg class="nav-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="7" y1="17" x2="17" y2="7"></line>
              <polyline points="7 7 17 7 17 17"></polyline>
            </svg>
          </a>
        </div>
      `;

      if (footerEl) footerEl.style.display = 'none';
      return;
    }

    if (footerEl) footerEl.style.display = 'flex';

    const baseUrl = window.location.pathname.toLowerCase().includes('/pages/') ? 'ProductDetail.aspx' : 'Pages/ProductDetail.aspx';

    // Perfectly balanced, proportional card layout with selection checkbox and clickable media
    bodyEl.innerHTML = `
      <div class="cart-drawer-items">
        ${items.map(item => {
          const detailUrl = `${baseUrl}?id=${item.productId || 1}`;
          const isChecked = item.isSelected !== false;
          return `
          <div class="cart-drawer-item ${isChecked ? '' : 'cart-drawer-item--unselected'}" data-variant-id="${item.variantId}">
            <button type="button" class="cart-drawer-item__check ${isChecked ? 'is-checked' : ''}" data-action="toggle-check" data-id="${item.variantId}" title="${isChecked ? 'Deselect item' : 'Select for checkout'}" aria-label="Toggle item selection">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                <polyline points="20 6 9 17 4 12"></polyline>
              </svg>
            </button>
            <div class="cart-drawer-item__info">
              <a href="${detailUrl}" class="cart-drawer-item__media" title="View details for ${this.escapeHtml(item.name)}">
                <img src="${item.imageUrl}" alt="${this.escapeHtml(item.name)}" class="cart-drawer-item__img" />
              </a>
              <div class="cart-drawer-item__content">
                <div class="cart-drawer-item__header">
                  <span class="cart-drawer-item__brand">${this.escapeHtml(item.brand || 'HELMET')}</span>
                  <button type="button" class="cart-drawer-item__remove" data-action="remove" data-id="${item.variantId}" title="Remove item" aria-label="Remove item">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                      <line x1="18" y1="6" x2="6" y2="18"></line>
                      <line x1="6" y1="6" x2="18" y2="18"></line>
                    </svg>
                  </button>
                </div>
                <div class="cart-drawer-item__title">
                  <h4 class="cart-drawer-item__name" title="${this.escapeHtml(item.name)}">${this.escapeHtml(item.name)}</h4>
                </div>
                <div class="cart-drawer-item__meta">
                  <span class="cart-drawer-item__badge">${this.escapeHtml(item.size || 'Large')}</span>
                  <span class="cart-drawer-item__badge">${this.escapeHtml(item.color || 'Matte Black')}</span>
                </div>
                <div class="cart-drawer-item__bottom">
                  <div class="cart-drawer-stepper">
                    <button type="button" class="cart-stepper-btn" data-action="decrease" data-id="${item.variantId}" aria-label="Decrease quantity">&minus;</button>
                    <span class="cart-stepper-val">${item.quantity}</span>
                    <button type="button" class="cart-stepper-btn" data-action="increase" data-id="${item.variantId}" aria-label="Increase quantity">&plus;</button>
                  </div>
                  <div class="cart-drawer-item__price">&#8369;${(item.price * item.quantity).toLocaleString()}</div>
                </div>
              </div>
            </div>
          </div>
          `;
        }).join('')}
      </div>
    `;

    const selectedItems = CartManager.getSelectedItems();
    const subtotal = CartManager.getSelectedSubtotal();
    if (subtotalEl) {
      subtotalEl.innerHTML = `&#8369;${subtotal.toLocaleString()}`;
    }

    const checkoutBtn = document.getElementById('drawer-checkout-btn') || document.querySelector('.cart-drawer__actions .btn--primary');
    if (checkoutBtn) {
      const span = checkoutBtn.querySelector('span');
      if (span) {
        span.textContent = selectedItems.length > 0 
          ? `Checkout (${selectedItems.length})` 
          : 'Select items to checkout';
      }
      checkoutBtn.classList.toggle('btn--disabled', selectedItems.length === 0);
    }

    bodyEl.querySelectorAll('[data-action]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const action = btn.getAttribute('data-action');
        const variantId = parseInt(btn.getAttribute('data-id'), 10);
        const item = items.find(i => i.variantId === variantId);

        if (!item) return;

        if (action === 'toggle-check') {
          CartManager.toggleItemSelection(variantId);
          this.renderCartDrawer();
        } else if (action === 'increase') {
          CartManager.updateQuantity(variantId, item.quantity + 1);
        } else if (action === 'decrease') {
          CartManager.updateQuantity(variantId, item.quantity - 1);
        } else if (action === 'remove') {
          const itemName = item.name;
          CartManager.removeItem(variantId);
          RealtimeManager.showToast(`${itemName} removed from your cart.`, 'delete');
        }
      });
    });

    // Allow clicking the item body to toggle checkbox like a label
    bodyEl.querySelectorAll('.cart-drawer-item').forEach(itemRow => {
      itemRow.addEventListener('click', (e) => {
        if (e.target.closest('button, a, input, select')) return;
        const variantId = parseInt(itemRow.getAttribute('data-variant-id'), 10);
        if (variantId) {
          CartManager.toggleItemSelection(variantId);
          this.renderCartDrawer();
        }
      });
    });
  },

  highlightMatch(text, query) {
    if (!query) return this.escapeHtml(text);
    const regex = new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi');
    return this.escapeHtml(text).replace(regex, '<strong>$1</strong>');
  },

  escapeHtml(str) {
    if (!str) return '';
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
};

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    SiteController.init();
  });
} else {
  SiteController.init();
}
