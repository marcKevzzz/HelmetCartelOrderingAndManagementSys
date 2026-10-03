import { renderReceipt, printReceipt, focusReceiptDialog } from '../receipt.js?v=20261003-3';
import { APP_CONSTANTS } from '../constants.js';

const root = document.getElementById('posCounter');
if (root) {
  const byId = id => document.getElementById(id);
  const globalSearch = document.getElementById('adminGlobalSearch');
  const ui = {
    search: byId('posSearch') || globalSearch, brand: byId('posBrand'), category: byId('posCategory'),
    grid: byId('posProductGrid'), message: byId('posCatalogMessage'), count: byId('posResultCount'),
    panel: byId('posSalePanel'), cart: byId('posCartItems'), itemCount: byId('posItemCount'),
    subtotal: byId('posSubtotal'), total: byId('posTotal'), saleError: byId('posSaleError'), complete: byId('posCompleteSale'),
    name: byId('posCustomerName'), phone: byId('posCustomerPhone'), email: byId('posCustomerEmail'),
    emailError: byId('posCustomerEmailError'), cash: byId('posCashTendered'),
    cashError: byId('posCashError'), cashFields: byId('posCashFields'),
    cardFields: byId('posCardFields'), cardApproved: byId('posCardApproved'),
    cardError: byId('posCardError'), change: byId('posChange'),
    mobileCart: byId('posMobileCart'), mobileCount: byId('posMobileCount'),
    mobileTotal: byId('posMobileTotal'), mobileBackdrop: byId('posMobileBackdrop'),
    closeSale: byId('posCloseSale'), receipt: byId('posReceiptModal')
  };
  if (globalSearch) {
    globalSearch.placeholder = 'Search POS products by model, brand, color, SKU... (Ctrl+K)';
  }
  const storageKey = APP_CONSTANTS.STORAGE_KEYS.POS_SALE;
  const money = amount => `${APP_CONSTANTS.UI.CURRENCY_SYMBOL}${Number(amount || 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
  const safeImage = url => {
    if (!url || typeof url !== 'string') return '/Content/images/placeholder-helmet.png';
    const trimmed = url.trim();
    if (!trimmed || trimmed.startsWith('//')) return '/Content/images/placeholder-helmet.png';
    if (trimmed.startsWith('~/')) return trimmed.substring(1);
    if (trimmed.startsWith('/')) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (trimmed.startsWith('data:image/')) return trimmed;
    return '/' + trimmed;
  };
  const state = { catalog: [], allById: new Map(), cart: new Map(), loading: false, submitting: false, requestSeq: 0 };
  let searchTimer;
  let stockTimer;

  async function api(url, options = {}) {
    const token = localStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.AUTH_TOKEN);
    const response = await fetch(url, {
      ...options,
      headers: { Accept: 'application/json', ...(options.body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}) }
    });
    let body;
    try { body = await response.json(); } catch { body = {}; }
    if (!response.ok || body.success === false) {
      const error = new Error(body.message || `Request failed (${response.status}).`);
      error.status = response.status;
      throw error;
    }
    return body.data ?? body;
  }

  function showError(message) {
    ui.saleError.textContent = message;
    ui.saleError.hidden = !message;
  }

  function showToast(message, type = 'info', title = null) {
    if (typeof window.showAdminToast === 'function') {
      window.showAdminToast(message, type, title);
    }
  }

  function setFieldError(input, target, message) {
    input.classList.toggle('is-invalid', !!message);
    target.textContent = message || '';
    target.hidden = !message;
  }

  function paymentMethod() {
    const val = root.querySelector('input[name="posPayment"]:checked')?.value;
    return val === 'Cash' ? APP_CONSTANTS.PAYMENT_METHODS.CASH : APP_CONSTANTS.PAYMENT_METHODS.CARD_POS;
  }

  function itemFor(id) { return state.allById.get(Number(id)); }
  function saleTotal() {
    return Array.from(state.cart.entries()).reduce((sum, [id, quantity]) => sum + Number(itemFor(id)?.unitPrice || 0) * quantity, 0);
  }

  function saveSale() {
    const sale = {
      items: Array.from(state.cart.entries()).map(([variantId, quantity]) => ({ variantId, quantity })),
      customerName: ui.name.value.trim(), customerPhone: ui.phone.value.trim(),
      customerEmail: ui.email.value.trim(), paymentMethod: paymentMethod()
    };
    sessionStorage.setItem(storageKey, JSON.stringify(sale));
  }

  function restoreSale() {
    try {
      const saved = JSON.parse(sessionStorage.getItem(storageKey) || '{}');
      if (Array.isArray(saved.items)) {
        saved.items.forEach(item => {
          const id = Number(item.variantId);
          const quantity = Number(item.quantity);
          if (Number.isInteger(id) && id > 0 && Number.isInteger(quantity) && quantity > 0 && quantity <= 999)
            state.cart.set(id, quantity);
        });
      }
      ui.name.value = typeof saved.customerName === 'string' ? saved.customerName.slice(0, 100) : '';
      ui.phone.value = typeof saved.customerPhone === 'string' ? saved.customerPhone.slice(0, 30) : '';
      ui.email.value = typeof saved.customerEmail === 'string' ? saved.customerEmail.slice(0, 256) : '';
      const method = (saved.paymentMethod === APP_CONSTANTS.PAYMENT_METHODS.CARD_POS || saved.paymentMethod === 'E_Wallet')
        ? 'E_Wallet' : APP_CONSTANTS.PAYMENT_METHODS.CASH;
      const radio = root.querySelector(`input[name="posPayment"][value="${method}"]`) || root.querySelector(`input[name="posPayment"][value="E_Wallet"]`);
      if (radio) radio.checked = true;
      renderPayment();
    } catch {
      sessionStorage.removeItem(storageKey);
    }
  }

  function renderImages(container) {
    if (!container) return;
    container.querySelectorAll('img[data-pos-image]').forEach(image => {
      image.addEventListener('error', () => {
        if (!image.src.endsWith('/Content/images/placeholder-helmet.png'))
          image.src = '/Content/images/placeholder-helmet.png';
      }, { once: true });
    });
  }

  function renderCatalog() {
    ui.count.textContent = `${state.catalog.length} ${state.catalog.length === 1 ? 'variant' : 'variants'}`;
    if (!state.catalog.length) {
      ui.grid.replaceChildren();
      ui.message.hidden = false;
      ui.message.textContent = 'No matching products.';
      return;
    }
    ui.message.hidden = true;
    ui.grid.innerHTML = state.catalog.map(item => {
      const available = Math.max(0, Number(item.availableStock || 0));
      const disabled = available <= 0;
      const stockText = disabled ? 'Out of stock' : `${available} available`;
      const stockClass = disabled ? 'pos-stock--out' : item.stockStatus === 'low_stock' ? 'pos-stock--low' : '';
      return `<button type="button" class="pos-product-card" data-add-id="${Number(item.variantId)}" ${disabled ? 'disabled' : ''} aria-label="Add ${escapeHtml(item.brand)} ${escapeHtml(item.productName)}, ${escapeHtml(item.color)}, size ${escapeHtml(item.size)} to current sale">
        <div class="pos-product-media-wrap">
          <img class="pos-product-image" data-pos-image src="${escapeHtml(safeImage(item.mainImageUrl))}" alt="${escapeHtml(item.productName)}" loading="lazy" onerror="this.onerror=null;this.src='/Content/images/placeholder-helmet.png';" />
          <span class="pos-card-brand-pill" title="${escapeHtml(item.brand)}">${escapeHtml(item.brand)}</span>
        </div>
        <div class="pos-product-info">
          <span class="pos-product-sku" title="${escapeHtml(item.sku)}">${escapeHtml(item.sku)}</span>
          <span class="pos-product-name" title="${escapeHtml(item.productName)}">${escapeHtml(item.productName)}</span>
          <span class="pos-product-variant" title="${escapeHtml(item.color)} · ${escapeHtml(item.size)}">${escapeHtml(item.color)} &middot; ${escapeHtml(item.size)}</span>
        </div>
        <span class="pos-product-foot"><strong>${money(item.unitPrice)}</strong><span class="pos-stock ${stockClass}">${stockText}</span></span>
      </button>`;
    }).join('');
    renderImages(ui.grid);
  }

  function renderCart() {
    const rows = Array.from(state.cart.entries());
    const count = rows.reduce((sum, [, quantity]) => sum + quantity, 0);
    const total = saleTotal();
    ui.itemCount.textContent = `${count} ${count === 1 ? 'item' : 'items'}`;
    ui.mobileCount.textContent = ui.itemCount.textContent;
    ui.subtotal.textContent = money(total);
    ui.total.textContent = money(total);
    ui.mobileTotal.textContent = money(total);
    ui.complete.disabled = !rows.length || state.submitting || state.loading || rows.some(([id, quantity]) => {
      const item = itemFor(id);
      return !item || Number(item.availableStock) < quantity;
    });
    if (!rows.length) {
      ui.cart.innerHTML = `<div class="pos-cart-empty">
        <div class="pos-cart-empty-icon">
          <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <circle cx="9" cy="21" r="1"></circle>
            <circle cx="20" cy="21" r="1"></circle>
            <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path>
          </svg>
        </div>
        <p class="pos-cart-empty-title">Current sale is empty</p>
        <p class="pos-cart-empty-subtitle">Select helmets from the catalog to add them to this order</p>
      </div>`;
      updateChange();
      return;
    }
    ui.cart.innerHTML = rows.map(([id, quantity]) => {
      const item = itemFor(id);
      if (!item) {
        return `<div class="pos-cart-line pos-cart-line--unavailable">
          <div class="pos-cart-line-content">
            <div class="pos-cart-line-header">
              <strong class="pos-cart-line-name">Item unavailable</strong>
              <button type="button" class="pos-cart-line-remove" data-remove-id="${id}" aria-label="Remove item" title="Remove item">
                <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
              </button>
            </div>
          </div>
        </div>`;
      }
      const available = Math.max(0, Number(item.availableStock || 0));
      return `<div class="pos-cart-line" data-variant-id="${id}">
        <div class="pos-cart-line-media">
          <img data-pos-image src="${escapeHtml(safeImage(item.mainImageUrl))}" alt="${escapeHtml(item.productName)}" loading="lazy" onerror="this.onerror=null;this.src='/Content/images/placeholder-helmet.png';" />
        </div>
        <div class="pos-cart-line-content">
          <div class="pos-cart-line-header">
            <div class="pos-cart-line-title-group">
              <span class="pos-cart-line-sku-badge" title="${escapeHtml(item.sku)}">${escapeHtml(item.sku)}</span>
              <h4 class="pos-cart-line-name" title="${escapeHtml(item.productName)}">${escapeHtml(item.productName)}</h4>
            </div>
            <button type="button" class="pos-cart-line-remove" data-remove-id="${id}" aria-label="Remove ${escapeHtml(item.productName)}" title="Remove item">
              <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
            </button>
          </div>
          <div class="pos-cart-line-single-meta" title="${escapeHtml(item.color)} · ${escapeHtml(item.size)}">
            <span class="pos-cart-line-specs">${escapeHtml(item.color)} &middot; ${escapeHtml(item.size)}</span>
          </div>
          ${quantity > available ? `<div class="pos-stock-warning">Only ${available} available in stock</div>` : ''}
          <div class="pos-cart-line-bottom">
            <div class="pos-quantity-stepper">
              <button type="button" class="pos-qty-btn" data-qty-id="${id}" data-delta="-1" aria-label="Decrease quantity">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"></line></svg>
              </button>
              <span class="pos-qty-val">${quantity}</span>
              <button type="button" class="pos-qty-btn" data-qty-id="${id}" data-delta="1" aria-label="Increase quantity" ${quantity >= available ? 'disabled' : ''}>
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
              </button>
            </div>
            <div class="pos-cart-line-pricing">
              <span class="pos-cart-unit-price">${money(item.unitPrice)} each</span>
              <strong class="pos-cart-line-total">${money(Number(item.unitPrice) * quantity)}</strong>
            </div>
          </div>
        </div>
      </div>`;
    }).join('');
    renderImages(ui.cart);
    updateChange();
  }

  function updateChange() {
    const tendered = Number(ui.cash.value);
    ui.change.textContent = money(Number.isFinite(tendered) && tendered > saleTotal() ? tendered - saleTotal() : 0);
  }

  function renderPayment() {
    const isCash = paymentMethod() === APP_CONSTANTS.PAYMENT_METHODS.CASH;
    ui.cashFields.hidden = !isCash;
    ui.cardFields.hidden = isCash;
    setFieldError(ui.cash, ui.cashError, '');
    setFieldError(ui.cardApproved, ui.cardError, '');
  }

  function fillFilters(items) {
    const update = (select, values, label) => {
      const prior = select.value;
      select.innerHTML = `<option value="">All ${label}</option>` + [...new Set(values.filter(Boolean))]
        .sort((a, b) => a.localeCompare(b)).map(value => `<option value="${escapeHtml(value)}">${escapeHtml(value)}</option>`).join('');
      select.value = prior;
    };
    update(ui.brand, items.map(item => item.brand), 'brands');
    update(ui.category, items.map(item => item.category), 'categories');
  }

  async function loadCatalog() {
    const seq = ++state.requestSeq;
    ui.message.hidden = false;
    ui.message.textContent = 'Loading products...';
    const params = new URLSearchParams();
    if (ui.search.value.trim()) params.set('search', ui.search.value.trim());
    if (ui.brand.value) params.set('brand', ui.brand.value);
    if (ui.category.value) params.set('category', ui.category.value);
    try {
      const path = APP_CONSTANTS.ENDPOINTS.ADMIN_SELLABLE_VARIANTS + (params.size ? `?${params}` : '');
      const items = await api(path);
      if (seq !== state.requestSeq) return;
      state.catalog = Array.isArray(items) ? items : [];
      state.catalog.forEach(item => state.allById.set(Number(item.variantId), item));
      renderCatalog();
      renderCart();
    } catch (error) {
      if (seq !== state.requestSeq) return;
      ui.grid.replaceChildren();
      ui.message.hidden = false;
      ui.message.textContent = error.status === 401 ? 'Sign in as staff to use the POS counter.' : 'Products could not be loaded. Try again.';
    }
  }

  async function refreshAll() {
    const items = await api(APP_CONSTANTS.ENDPOINTS.ADMIN_SELLABLE_VARIANTS);
    if (!Array.isArray(items)) throw new Error('Inventory is unavailable.');
    state.allById = new Map(items.map(item => [Number(item.variantId), item]));
    fillFilters(items);
    renderCart();
    return items;
  }

  function validateSale() {
    showError('');
    if (!state.cart.size) { showError('Add an item to the sale.'); return false; }
    for (const [id, quantity] of state.cart) {
      const item = itemFor(id);
      if (!item || quantity > Number(item.availableStock)) {
        showError(`${item?.productName || 'An item'} has insufficient stock. Adjust or remove it.`);
        return false;
      }
    }
    const email = ui.email.value.trim();
    const emailError = email && ui.email.validity.typeMismatch ? 'Enter a valid email address.' : '';
    setFieldError(ui.email, ui.emailError, emailError);
    if (emailError) { byId('posCustomerDetails').open = true; ui.email.focus(); return false; }
    if (paymentMethod() === APP_CONSTANTS.PAYMENT_METHODS.CASH) {
      const amount = Number(ui.cash.value);
      const cashError = !ui.cash.value || !Number.isFinite(amount) || amount < saleTotal()
        ? `Enter at least ${money(saleTotal())} in cash received.` : '';
      setFieldError(ui.cash, ui.cashError, cashError);
      if (cashError) { ui.cash.focus(); return false; }
    } else {
      const cardError = ui.cardApproved.checked ? '' : 'Confirm the E-Wallet payment was received.';
      setFieldError(ui.cardApproved, ui.cardError, cardError);
      if (cardError) { ui.cardApproved.focus(); return false; }
    }
    return true;
  }

  let receiptFocusCleanup;
  function showReceipt(order) {
    byId('posReceiptDoc').innerHTML = renderReceipt(order);
    ui.receipt.hidden = false;
    receiptFocusCleanup?.();
    receiptFocusCleanup = focusReceiptDialog(ui.receipt, () => byId('posNewSale').click());
  }

  async function completeSale() {
    if (state.submitting || !validateSale()) return;
    state.submitting = true;
    ui.complete.disabled = true;
    ui.complete.textContent = 'Completing...';
    const method = paymentMethod();
    const tendered = method === APP_CONSTANTS.PAYMENT_METHODS.CASH ? Number(ui.cash.value) : null;
    try {
      await refreshAll();
      if (!validateSale()) return;
      const body = {
        customerName: ui.name.value.trim() || 'Walk-in Retail Customer',
        customerPhone: ui.phone.value.trim() || null,
        customerEmail: ui.email.value.trim() || null,
        paymentMethod: method, cashTendered: tendered,
        cardTerminalApproved: method === APP_CONSTANTS.PAYMENT_METHODS.CARD_POS && ui.cardApproved.checked,
        items: Array.from(state.cart.entries()).map(([variantId, quantity]) => ({ variantId, quantity }))
      };
      const order = await api(APP_CONSTANTS.ENDPOINTS.ORDERS_INSTORE, { method: 'POST', body: JSON.stringify(body) });
      state.cart.clear();
      sessionStorage.removeItem(storageKey);
      renderCart();
      closeMobileSale();
      showReceipt(order, method, tendered);
      showToast(`Order ${order.orderNumber || ''} was completed successfully.`, 'success', 'Sale Complete');
      await refreshAll();
      await loadCatalog();
    } catch (error) {
      if (error.status === 401) {
        showError('Your staff session expired. Sign in again to complete the sale.');
        showToast('Your staff session expired. Sign in again to complete the sale.', 'error', 'Session Expired');
      } else if (error.status === 409) {
        showError(error.message || 'The stock or final total changed. Review the sale and try again.');
        showToast(error.message || 'The stock or final total changed. Review the sale and try again.', 'warning', 'Sale Updated');
        try { await refreshAll(); await loadCatalog(); } catch { /* keep current sale visible */ }
      } else {
        showError(error.message || 'The sale could not be completed. Try again.');
        showToast(error.message || 'The sale could not be completed. Try again.', 'error', 'Sale Failed');
      }
    } finally {
      state.submitting = false;
      ui.complete.textContent = 'Complete Sale';
      renderCart();
    }
  }

  function openMobileSale() {
    ui.panel.classList.add('is-open');
    ui.mobileBackdrop.hidden = false;
    ui.mobileCart.setAttribute('aria-expanded', 'true');
    ui.closeSale.focus();
  }
  function closeMobileSale() {
    ui.panel.classList.remove('is-open');
    ui.mobileBackdrop.hidden = true;
    ui.mobileCart.setAttribute('aria-expanded', 'false');
    ui.mobileCart.focus();
  }

  function flashLowStockCard(id, message) {
    const card = ui.grid?.querySelector(`[data-add-id="${id}"]`);
    if (!card) return;
    card.classList.remove('has-stock-alert');
    void card.offsetWidth; // trigger reflow for smooth animation
    card.classList.add('has-stock-alert');

    // Remove any previous tooltip
    card.querySelector('.pos-card-stock-tooltip')?.remove();
    const tip = document.createElement('span');
    tip.className = 'pos-card-stock-tooltip';
    tip.textContent = message || 'Low Stock';
    card.appendChild(tip);

    setTimeout(() => {
      card.classList.remove('has-stock-alert');
      tip.remove();
    }, 2500);
  }

  function addToCart(variantId) {
    const id = Number(variantId);
    const item = itemFor(id);
    if (!item) {
      showToast('Product variant could not be found.', 'error', 'Not Found');
      return false;
    }
    const currentQty = state.cart.get(id) || 0;
    const available = Number(item.availableStock || 0);
    if (available <= 0) {
      flashLowStockCard(id, 'Out of stock');
      showToast(`${item.brand} ${item.productName} is currently out of stock.`, 'warning', 'Out of Stock');
      return false;
    }
    if (currentQty + 1 > available) {
      flashLowStockCard(id, `Max ${available} in stock`);
      showToast(`Cannot add more. Only ${available} units available in stock.`, 'warning', 'Stock Limit');
      return false;
    }
    state.cart.set(id, currentQty + 1);
    showError(''); // Keep header clean of item errors
    saveSale();
    renderCart();
    showToast(`${item.brand} ${item.productName} (${item.color} / ${item.size}) x1 added to Current Sale.`, 'success', 'Added to Sale');
    return true;
  }

  let posSelectedIndex = -1;
  const searchDropdown = document.getElementById('adminSearchDropdown');

  function renderPosSearchDropdown(query) {
    if (!searchDropdown) return;
    const q = (query || '').trim().toLowerCase();
    if (!q) {
      searchDropdown.style.display = 'none';
      searchDropdown.innerHTML = '';
      posSelectedIndex = -1;
      return;
    }

    const allVariants = Array.from(state.allById.values());
    const matches = allVariants.filter(item => {
      const fullText = `${item.brand || ''} ${item.productName || ''} ${item.color || ''} ${item.size || ''} ${item.sku || ''} ${item.category || ''}`.toLowerCase();
      return fullText.includes(q);
    }).slice(0, 10);

    if (matches.length === 0) {
      searchDropdown.innerHTML = `<div class="admin-search-empty">No sellable POS products found matching "${escapeHtml(query.trim())}"</div>`;
      searchDropdown.classList.remove('is-hidden');
      searchDropdown.removeAttribute('hidden');
      searchDropdown.style.display = 'block';
      posSelectedIndex = -1;
      return;
    }

    let html = `<div class="admin-search-group">
      <div class="admin-search-group-title">POINT OF SALE PRODUCTS (${matches.length})</div>`;

    matches.forEach((item, idx) => {
      const available = Math.max(0, Number(item.availableStock || 0));
      const isOut = available <= 0;
      const stockBadge = isOut
        ? `<span class="admin-search-badge is-out-of-stock">Out of stock</span>`
        : `<span class="admin-search-badge is-in-stock">${available} in stock</span>`;

      html += `
        <div class="admin-search-item pos-search-item" data-variant-id="${Number(item.variantId)}" data-index="${idx}" tabindex="-1" role="button" aria-disabled="${isOut}">
          <img class="admin-search-thumb" src="${escapeHtml(safeImage(item.mainImageUrl))}" alt="${escapeHtml(item.productName)}" loading="lazy" />
          <div class="admin-search-item-info">
            <span class="admin-search-item-title">${escapeHtml(item.brand)} ${escapeHtml(item.productName)}</span>
            <span class="admin-search-item-sub">${escapeHtml(item.color)} &bull; Size ${escapeHtml(item.size)} &bull; SKU: ${escapeHtml(item.sku)}</span>
          </div>
          <div class="admin-search-meta">
            ${stockBadge}
            <span class="admin-search-price">${money(item.unitPrice)}</span>
            <button type="button" class="pos-quick-add-btn" data-variant-id="${Number(item.variantId)}" ${isOut ? 'disabled' : ''} title="Add to current sale">Add &rarr;</button>
          </div>
        </div>`;
    });

    html += `</div>`;
    searchDropdown.innerHTML = html;
    searchDropdown.classList.remove('is-hidden');
    searchDropdown.removeAttribute('hidden');
    searchDropdown.style.display = 'block';
    posSelectedIndex = -1;
  }

  function updateHighlight(items) {
    items.forEach((item, idx) => {
      if (idx === posSelectedIndex) {
        item.classList.add('is-selected');
        item.scrollIntoView({ block: 'nearest' });
      } else {
        item.classList.remove('is-selected');
      }
    });
  }

  window.posSearchHandler = function(query) {
    renderPosSearchDropdown(query);
  };

  window.posKeydownHandler = function(event) {
    if (!searchDropdown || searchDropdown.style.display === 'none') {
      if (event.key === 'Enter') event.preventDefault();
      return;
    }

    const items = searchDropdown.querySelectorAll('.pos-search-item');
    if (!items.length) {
      if (event.key === 'Enter') event.preventDefault();
      return;
    }

    if (event.key === 'ArrowDown') {
      event.preventDefault();
      posSelectedIndex = (posSelectedIndex + 1) % items.length;
      updateHighlight(items);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      posSelectedIndex = (posSelectedIndex - 1 + items.length) % items.length;
      updateHighlight(items);
    } else if (event.key === 'Enter') {
      event.preventDefault();
      const targetIndex = posSelectedIndex >= 0 ? posSelectedIndex : 0;
      const targetItem = items[targetIndex];
      if (targetItem) {
        const variantId = Number(targetItem.dataset.variantId);
        if (variantId) {
          const added = addToCart(variantId);
          if (added) {
            searchDropdown.style.display = 'none';
            posSelectedIndex = -1;
          }
        }
      }
    } else if (event.key === 'Escape') {
      searchDropdown.style.display = 'none';
      posSelectedIndex = -1;
    }
  };

  if (searchDropdown) {
    searchDropdown.addEventListener('click', event => {
      const itemRow = event.target.closest('.pos-search-item');
      if (!itemRow) return;
      const variantId = Number(itemRow.dataset.variantId);
      if (variantId) {
        const added = addToCart(variantId);
        if (added) {
          searchDropdown.style.display = 'none';
          posSelectedIndex = -1;
          if (ui.search) ui.search.focus();
        }
      }
    });
  }

  ui.grid.addEventListener('click', event => {
    const card = event.target.closest('[data-add-id]');
    if (!card || card.disabled) return;
    const id = Number(card.dataset.addId);
    addToCart(id);
  });
  ui.cart.addEventListener('click', event => {
    const remove = event.target.closest('[data-remove-id]');
    const qty = event.target.closest('[data-qty-id]');
    let removedItem;
    if (remove) {
      const id = Number(remove.dataset.removeId);
      removedItem = itemFor(id);
      if (!state.cart.delete(id)) return;
    }
    else if (qty) {
      const id = Number(qty.dataset.qtyId);
      const next = (state.cart.get(id) || 0) + Number(qty.dataset.delta);
      if (next <= 0) {
        removedItem = itemFor(id);
        state.cart.delete(id);
      }
      else if (next <= Number(itemFor(id)?.availableStock || 0)) state.cart.set(id, next);
    } else return;
    showError('');
    saveSale();
    renderCart();
    if (remove || removedItem) {
      const label = removedItem
        ? `${removedItem.brand} ${removedItem.productName} (${removedItem.color} / ${removedItem.size})`
        : 'Unavailable item';
      showToast(`${label} removed from Current Sale.`, 'info', 'Item Removed');
    }
  });
  if (ui.search) {
    ui.search.addEventListener('input', () => {
      clearTimeout(searchTimer);
      searchTimer = setTimeout(() => {
        loadCatalog();
        renderPosSearchDropdown(ui.search.value);
      }, 200);
    });
    ui.search.addEventListener('keydown', event => {
      if (event.key === 'Escape') {
        ui.search.value = '';
        if (searchDropdown) {
          searchDropdown.style.display = 'none';
          searchDropdown.innerHTML = '';
        }
        loadCatalog();
      }
    });
  }
  ui.brand.addEventListener('change', loadCatalog);
  ui.category.addEventListener('change', loadCatalog);
  [ui.name, ui.phone, ui.email].forEach(input => input.addEventListener('input', saveSale));
  ui.email.addEventListener('blur', () => {
    const invalid = ui.email.value.trim() && ui.email.validity.typeMismatch;
    setFieldError(ui.email, ui.emailError, invalid ? 'Enter a valid email address.' : '');
  });
  root.querySelectorAll('input[name="posPayment"]').forEach(input => input.addEventListener('change', () => {
    renderPayment(); saveSale(); updateChange();
  }));
  ui.cash.addEventListener('input', () => { setFieldError(ui.cash, ui.cashError, ''); updateChange(); });
  ui.cash.addEventListener('blur', () => {
    if (!ui.cash.value) return;
    setFieldError(ui.cash, ui.cashError, Number(ui.cash.value) < saleTotal() ? `Enter at least ${money(saleTotal())}.` : '');
  });
  ui.cardApproved.addEventListener('change', () => setFieldError(ui.cardApproved, ui.cardError, ''));
  ui.complete.addEventListener('click', completeSale);
  ui.mobileCart.hidden = false;
  ui.mobileCart.addEventListener('click', openMobileSale);
  ui.closeSale.addEventListener('click', closeMobileSale);
  ui.mobileBackdrop.addEventListener('click', closeMobileSale);
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && ui.panel.classList.contains('is-open')) closeMobileSale();
  });
  byId('adminForm')?.addEventListener('submit', event => {
    if (root.contains(document.activeElement)) event.preventDefault();
  });
  byId('posPrintReceipt').addEventListener('click', () => printReceipt(byId('posReceiptDoc')));
  byId('posNewSale').addEventListener('click', () => {
    ui.receipt.hidden = true;
    receiptFocusCleanup?.();
    receiptFocusCleanup = null;
    ui.name.value = ''; ui.phone.value = ''; ui.email.value = ''; ui.cash.value = '';
    ui.cardApproved.checked = false;
    root.querySelector(`input[name="posPayment"][value="${APP_CONSTANTS.PAYMENT_METHODS.CASH}"]`).checked = true;
    renderPayment();
    renderCart();
    if (ui.search) {
      ui.search.value = '';
      ui.search.focus();
      loadCatalog();
    }
  });

  const urlParams = new URLSearchParams(window.location.search);
  const initialSearch = urlParams.get('search') || urlParams.get('q');
  if (initialSearch && ui.search) {
    ui.search.value = initialSearch;
  }

  restoreSale();
  renderCart();
  refreshAll().then(items => {
    state.catalog = items;
    renderCatalog();
    renderCart();
    if (initialSearch) {
      renderPosSearchDropdown(initialSearch);
    }
  })
    .catch(error => { ui.message.hidden = false; ui.message.textContent = error.status === 401 ? 'Sign in as staff to use the POS counter.' : 'Products could not be loaded. Try again.'; });

  if (window.jQuery?.hubConnection) {
    const connection = window.jQuery.hubConnection('/signalr');
    const inventory = connection.createHubProxy('inventoryHub');
    inventory.on(APP_CONSTANTS.SIGNALR_EVENTS.STOCK_UPDATED, () => {
      clearTimeout(stockTimer);
      stockTimer = setTimeout(async () => {
        try { await refreshAll(); await loadCatalog(); } catch { /* checkout rechecks server stock */ }
      }, 300);
    });
    connection.start().fail(() => { /* checkout still rechecks server stock */ });
  }
}
