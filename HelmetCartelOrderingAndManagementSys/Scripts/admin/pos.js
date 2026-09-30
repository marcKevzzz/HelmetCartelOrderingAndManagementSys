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
  const safeImage = url => typeof url === 'string' && ((url.startsWith('/') && !url.startsWith('//')) || url.startsWith('https://'))
    ? url : '/Content/images/products/helmets/agv/images.jpg';
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
    return root.querySelector('input[name="posPayment"]:checked')?.value || APP_CONSTANTS.PAYMENT_METHODS.CASH;
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
      const method = saved.paymentMethod === APP_CONSTANTS.PAYMENT_METHODS.CARD_POS
        ? APP_CONSTANTS.PAYMENT_METHODS.CARD_POS : APP_CONSTANTS.PAYMENT_METHODS.CASH;
      const radio = root.querySelector(`input[name="posPayment"][value="${method}"]`);
      if (radio) radio.checked = true;
      renderPayment();
    } catch {
      sessionStorage.removeItem(storageKey);
    }
  }

  function renderImages(container) {
    container.querySelectorAll('img[data-pos-image]').forEach(image => {
      image.addEventListener('error', () => {
        if (!image.src.endsWith('/Content/images/products/helmets/agv/images.jpg'))
          image.src = '/Content/images/products/helmets/agv/images.jpg';
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
        <img class="pos-product-image" data-pos-image src="${escapeHtml(safeImage(item.mainImageUrl))}" alt="${escapeHtml(item.productName)}" loading="lazy" />
        <span class="pos-product-brand">${escapeHtml(item.brand)}</span>
        <span class="pos-product-name">${escapeHtml(item.productName)}</span>
        <span class="pos-product-variant">${escapeHtml(item.color)} &middot; ${escapeHtml(item.size)}</span>
        <span class="pos-product-sku">${escapeHtml(item.sku)}</span>
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
          <img data-pos-image src="${escapeHtml(safeImage(item.mainImageUrl))}" alt="${escapeHtml(item.productName)}" loading="lazy" />
        </div>
        <div class="pos-cart-line-content">
          <div class="pos-cart-line-header">
            <div class="pos-cart-line-title-group">
              <span class="pos-cart-line-brand">${escapeHtml(item.brand)}</span>
              <h4 class="pos-cart-line-name">${escapeHtml(item.productName)}</h4>
            </div>
            <button type="button" class="pos-cart-line-remove" data-remove-id="${id}" aria-label="Remove ${escapeHtml(item.productName)}" title="Remove item">
              <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
            </button>
          </div>
          <div class="pos-cart-line-meta">
            <span class="pos-variant-pill">${escapeHtml(item.color)}</span>
            <span class="pos-variant-pill pos-variant-pill--size">${escapeHtml(item.size)}</span>
            <span class="pos-cart-line-sku">${escapeHtml(item.sku)}</span>
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
      const cardError = ui.cardApproved.checked ? '' : 'Confirm the card terminal approved the payment.';
      setFieldError(ui.cardApproved, ui.cardError, cardError);
      if (cardError) { ui.cardApproved.focus(); return false; }
    }
    return true;
  }

  function showReceipt(order, method, tendered) {
    byId('posReceiptNumber').textContent = order.orderNumber || '';
    byId('posReceiptTotal').textContent = money(order.totalAmount);
    byId('posReceiptItems').innerHTML = (order.items || []).map(item =>
      `<div class="pos-receipt-item"><span>${Number(item.quantity)} &times; ${escapeHtml(item.productName)} (${escapeHtml(item.color)}, ${escapeHtml(item.size)})</span><strong>${money(item.totalPrice)}</strong></div>`
    ).join('');
    byId('posReceiptPayment').textContent = method === APP_CONSTANTS.PAYMENT_METHODS.CASH
      ? `Cash received ${money(tendered)} · Change ${money(tendered - Number(order.totalAmount))}`
      : 'Card terminal payment';
    ui.receipt.hidden = false;
    byId('posNewSale').focus();
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

  ui.grid.addEventListener('click', event => {
    const card = event.target.closest('[data-add-id]');
    if (!card || card.disabled) return;
    const id = Number(card.dataset.addId);
    const item = itemFor(id);
    const next = (state.cart.get(id) || 0) + 1;
    if (!item || next > Number(item.availableStock)) { showError('No more units are available.'); return; }
    state.cart.set(id, next);
    showError('');
    saveSale();
    renderCart();
  });
  ui.cart.addEventListener('click', event => {
    const remove = event.target.closest('[data-remove-id]');
    const qty = event.target.closest('[data-qty-id]');
    if (remove) state.cart.delete(Number(remove.dataset.removeId));
    else if (qty) {
      const id = Number(qty.dataset.qtyId);
      const next = (state.cart.get(id) || 0) + Number(qty.dataset.delta);
      if (next <= 0) state.cart.delete(id);
      else if (next <= Number(itemFor(id)?.availableStock || 0)) state.cart.set(id, next);
    } else return;
    showError('');
    saveSale();
    renderCart();
  });
  if (ui.search) {
    ui.search.addEventListener('input', () => { clearTimeout(searchTimer); searchTimer = setTimeout(loadCatalog, 200); });
    ui.search.addEventListener('keydown', event => {
      if (event.key === 'Escape') {
        ui.search.value = '';
        loadCatalog();
      }
      if (event.key === 'Enter') {
        event.preventDefault();
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
  byId('posPrintReceipt').addEventListener('click', () => window.print());
  byId('posNewSale').addEventListener('click', () => {
    ui.receipt.hidden = true;
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
  refreshAll().then(items => { state.catalog = items; renderCatalog(); renderCart(); })
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
