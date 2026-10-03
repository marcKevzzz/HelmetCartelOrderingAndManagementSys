import { ApiClient } from '../api.js';
import { APP_CONSTANTS } from '../constants.js';

const byId = (id) => document.getElementById(id);
const escapeHtml = (val) => String(val ?? '').replace(/[&<>"']/g, (c) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
})[c]);

const fields = ['code', 'type', 'value', 'minimum', 'expiry', 'limit'];
let vouchers = [];
let editingVoucher = null;
let isBusy = false;
let currentStatusFilter = 'ALL';
let currentSearchTerm = '';

const input = (key) => byId(`voucher-${key}`);
const currency = (val) => `${APP_CONSTANTS.UI.CURRENCY_SYMBOL}${Number(val || 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const utcDate = (raw) => new Date(/(Z|[+-]\d\d:\d\d)$/.test(raw) ? raw : raw + 'Z');

/* ==========================================================================
   TOAST HELPER
   ========================================================================== */
function notify(message, type = 'info', title = null) {
  if (typeof window.showAdminToast === 'function') {
    window.showAdminToast(message, type, title);
  }
}

/* ==========================================================================
   INLINE VALIDATION & ERRORS
   ========================================================================== */
function setError(key, message) {
  const el = input(key);
  if (!el) return !message;
  el.classList.toggle('is-invalid', !!message);
  el.setAttribute('aria-invalid', String(!!message));
  const errEl = byId(`voucher-${key}-error`);
  if (errEl) errEl.textContent = message;
  return !message;
}

function validateField(key) {
  const el = input(key);
  if (!el) return true;
  const value = el.value.trim();
  const num = Number(value);
  let msg = '';

  if (key === 'code') {
    if (!/^[A-Z0-9-]{3,30}$/i.test(value)) {
      msg = 'Code must be 3–30 letters, numbers, or hyphens.';
    }
  } else if (key === 'value') {
    const isPct = input('type').value === APP_CONSTANTS.VOUCHER_TYPES.PERCENTAGE;
    if (!value || !Number.isFinite(num) || num <= 0 || num > 999999999999) {
      msg = 'Enter a positive discount amount.';
    } else if (isPct && num > 100) {
      msg = 'Percentage discount cannot exceed 100%.';
    } else if (!/^\d+(\.\d{1,2})?$/.test(value)) {
      msg = 'Enter a valid amount with at most 2 decimal places.';
    }
  } else if (key === 'minimum') {
    if (!value || !Number.isFinite(num) || num < 0 || !/^\d+(\.\d{1,2})?$/.test(value)) {
      msg = 'Enter a nonnegative minimum spend with at most 2 decimals.';
    }
  } else if (key === 'limit') {
    if (value && (!Number.isSafeInteger(num) || num <= 0 || num > 2147483647 || num < Number(editingVoucher?.usageCount || 0))) {
      msg = 'Enter a positive whole number at least equal to current redemptions.';
    }
  } else if (key === 'expiry' && value) {
    const dt = new Date(value);
    if (Number.isNaN(dt.getTime()) || (dt <= new Date() && value !== input('expiry').dataset.original)) {
      msg = 'Expiration date must be set in the future.';
    }
  }

  return setError(key, msg);
}

/* ==========================================================================
   LIVE PREVIEW CARD UPDATES
   ========================================================================== */
function updateLivePreview() {
  const code = (input('code')?.value || '').trim().toUpperCase() || 'CODE';
  const type = input('type')?.value || APP_CONSTANTS.VOUCHER_TYPES.PERCENTAGE;
  const rawVal = parseFloat(input('value')?.value);
  const minSpend = parseFloat(input('minimum')?.value) || 0;
  const expiryVal = input('expiry')?.value;
  const isActive = byId('voucher-active')?.checked ?? true;

  // 1. Discount Callout
  let discountStr = '0% OFF';
  if (!isNaN(rawVal) && rawVal > 0) {
    if (type === APP_CONSTANTS.VOUCHER_TYPES.PERCENTAGE) {
      discountStr = `${rawVal}% OFF`;
    } else {
      discountStr = `${currency(rawVal)} OFF`;
    }
  }
  const previewDiscount = byId('preview-discount-val');
  if (previewDiscount) previewDiscount.textContent = discountStr;

  // 2. Code
  const previewCode = byId('preview-code-val');
  if (previewCode) previewCode.textContent = code;

  // 3. Min Spend
  const previewMin = byId('preview-min-spend');
  if (previewMin) {
    previewMin.textContent = minSpend > 0 ? `Min. spend: ${currency(minSpend)}` : 'No minimum spend';
  }

  // 4. Expiry
  const previewExp = byId('preview-expiry');
  if (previewExp) {
    if (expiryVal) {
      const d = new Date(expiryVal);
      if (!isNaN(d.getTime())) {
        previewExp.textContent = `Expires: ${d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}`;
      } else {
        previewExp.textContent = 'No expiration date';
      }
    } else {
      previewExp.textContent = 'No expiration date';
    }
  }

  // 5. Status Pill
  const previewStatus = byId('preview-status-pill');
  if (previewStatus) {
    previewStatus.textContent = isActive ? 'Active' : 'Inactive';
    previewStatus.classList.toggle('is-inactive', !isActive);
  }

  // 6. Update unit label beside discount value
  const unitAddon = byId('voucher-value-unit');
  if (unitAddon) {
    unitAddon.textContent = type === APP_CONSTANTS.VOUCHER_TYPES.PERCENTAGE ? '%' : '₱';
  }
}

/* ==========================================================================
   MODAL DIALOG MANAGEMENT
   ========================================================================== */
function openModal(voucher = null) {
  editingVoucher = voucher;
  const modal = byId('modal-voucher');
  const alert = byId('voucher-modal-alert');
  if (alert) alert.classList.add('is-hidden');

  byId('voucher-modal-title').textContent = voucher ? `Edit Voucher: ${voucher.code}` : 'Create Promotional Voucher';

  input('code').value = voucher?.code || '';
  input('code').disabled = !!voucher?.hasRedemptions;
  input('type').value = voucher?.discountType || APP_CONSTANTS.VOUCHER_TYPES.PERCENTAGE;
  input('value').value = voucher?.discountValue ?? '';
  input('minimum').value = voucher?.minimumSpend ?? 0;
  input('limit').value = voucher?.usageLimit ?? '';

  let local = '';
  if (voucher?.expiresAt) {
    const d = utcDate(voucher.expiresAt);
    local = new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  }
  input('expiry').value = local;
  input('expiry').dataset.original = local;

  fields.forEach((k) => setError(k, ''));
  updateLivePreview();

  if (modal) {
    modal.classList.remove('is-hidden');
    document.body.style.overflow = 'hidden';
    setTimeout(() => input('code').focus(), 100);
  }
}

function closeModal() {
  const modal = byId('modal-voucher');
  if (modal) {
    modal.classList.add('is-hidden');
    document.body.style.overflow = '';
  }
  editingVoucher = null;
}

/* ==========================================================================
   KPI SUMMARY CALCULATIONS
   ========================================================================== */
function renderTrendBadge(direction, text, title = '') {
  const dir = (direction || 'neutral').toLowerCase();
  let trendClass = 'admin-trend--neutral';
  let svg = '<svg class="admin-trend-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><line x1="5" y1="12" x2="19" y2="12"></line></svg>';

  if (dir === 'up') {
    trendClass = 'admin-trend--up';
    svg = '<svg class="admin-trend-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"></polyline><polyline points="16 7 22 7 22 13"></polyline></svg>';
  } else if (dir === 'down') {
    trendClass = 'admin-trend--down';
    svg = '<svg class="admin-trend-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="22 17 13.5 8.5 8.5 13.5 2 7"></polyline><polyline points="16 17 22 17 22 11"></polyline></svg>';
  }

  const titleAttr = title ? ` title="${title.replace(/"/g, '&quot;')}"` : '';
  return `<span class="admin-trend-badge ${trendClass}"${titleAttr}>
    ${svg}
    <span>${text}</span>
  </span>`;
}

function updateKPIs() {
  const now = new Date();
  const total = vouchers.length;
  let active = 0;
  let redemptions = 0;
  let expiredOrDepleted = 0;

  vouchers.forEach((v) => {
    const isExpired = v.expiresAt && utcDate(v.expiresAt) <= now;
    const isDepleted = v.usageLimit && v.usageCount >= v.usageLimit;
    const isOperable = v.isActive && !isExpired && !isDepleted;

    if (isOperable) active++;
    if (!v.isActive || isExpired || isDepleted) expiredOrDepleted++;
    redemptions += Number(v.usageCount || 0);
  });

  const totalEl = byId('stat-total-vouchers');
  if (totalEl) totalEl.textContent = total.toLocaleString();

  const activeEl = byId('stat-active-vouchers');
  if (activeEl) activeEl.textContent = active.toLocaleString();

  const redemptionsEl = byId('stat-total-redemptions');
  if (redemptionsEl) redemptionsEl.textContent = redemptions.toLocaleString();

  const expiredEl = byId('stat-expired-vouchers');
  if (expiredEl) expiredEl.textContent = expiredOrDepleted.toLocaleString();

  // Dynamic trend badges matching dashboard styling
  const totalTrendEl = byId('stat-total-trend');
  if (totalTrendEl) {
    totalTrendEl.innerHTML = renderTrendBadge('neutral', '0.0%', 'Promotional codes created');
  }

  const activeTrendEl = byId('stat-active-trend');
  if (activeTrendEl) {
    const activePct = total > 0 ? ((active / total) * 100).toFixed(1) : '0.0';
    activeTrendEl.innerHTML = renderTrendBadge(
      active > 0 ? 'up' : 'neutral',
      active > 0 ? `+${activePct}%` : '0.0%',
      `${active} of ${total} vouchers active and ready`
    );
  }

  const redemptionsTrendEl = byId('stat-redemptions-trend');
  if (redemptionsTrendEl) {
    redemptionsTrendEl.innerHTML = renderTrendBadge(
      redemptions > 0 ? 'up' : 'neutral',
      redemptions > 0 ? `+${redemptions}` : '0.0%',
      `${redemptions} total redemptions completed`
    );
  }

  const expiredTrendEl = byId('stat-expired-trend');
  if (expiredTrendEl) {
    const expiredPct = total > 0 ? ((expiredOrDepleted / total) * 100).toFixed(1) : '0.0';
    expiredTrendEl.innerHTML = renderTrendBadge(
      expiredOrDepleted > 0 ? 'down' : 'neutral',
      expiredOrDepleted > 0 ? `-${expiredPct}%` : '0.0%',
      `${expiredOrDepleted} inactive or expired vouchers`
    );
  }
}

/* ==========================================================================
   TABLE RENDERING & FILTERING
   ========================================================================== */
function renderTable() {
  const tbody = byId('voucher-rows');
  const now = new Date();

  // Filter
  const filtered = vouchers.filter((v) => {
    // Status filter
    const isExpired = v.expiresAt && utcDate(v.expiresAt) <= now;
    const isDepleted = v.usageLimit && v.usageCount >= v.usageLimit;

    if (currentStatusFilter === 'ACTIVE') {
      if (!v.isActive || isExpired || isDepleted) return false;
    } else if (currentStatusFilter === 'INACTIVE') {
      if (v.isActive) return false;
    } else if (currentStatusFilter === 'EXPIRED') {
      if (!isExpired && !isDepleted) return false;
    }

    // Search filter
    if (currentSearchTerm) {
      const q = currentSearchTerm.toLowerCase();
      const matchCode = (v.code || '').toLowerCase().includes(q);
      const matchDiscount = String(v.discountValue || '').includes(q);
      if (!matchCode && !matchDiscount) return false;
    }

    return true;
  });

  // Count indicator
  byId('voucher-count-indicator').textContent = `Showing ${filtered.length} of ${vouchers.length} vouchers`;

  if (!filtered.length) {
    tbody.innerHTML = `
      <tr>
        <td colspan="7">
          <div class="admin-empty-state">
            <div class="admin-empty-title">No Vouchers Found</div>
            <p>${currentSearchTerm || currentStatusFilter !== 'ALL' ? 'No promotional codes match your current search or status filter.' : 'No promotional vouchers configured yet. Create your first code to boost checkout conversions.'}</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = filtered.map((v) => {
    const isPct = v.discountType === APP_CONSTANTS.VOUCHER_TYPES.PERCENTAGE;
    const discountText = isPct ? `${Number(v.discountValue)}% OFF` : `${currency(v.discountValue)} OFF`;
    const minSpendText = Number(v.minimumSpend) > 0 ? currency(v.minimumSpend) : '<span class="voucher-min-spend-none">No minimum</span>';

    // Usage Progress
    const uses = Number(v.usageCount || 0);
    const limit = v.usageLimit ? Number(v.usageLimit) : null;
    const pct = limit ? Math.min(100, Math.round((uses / limit) * 100)) : 0;
    const isDepleted = limit && uses >= limit;
    const isHigh = limit && pct >= 80 && !isDepleted;

    let usageHtml = '';
    if (limit) {
      usageHtml = `
        <div class="voucher-usage-wrap">
          <div class="voucher-usage-text">
            <span><strong>${uses}</strong> / ${limit}</span>
            <span class="voucher-usage-percent">${pct}%</span>
          </div>
          <div class="voucher-progress-track">
            <div class="voucher-progress-fill ${isDepleted ? 'is-depleted' : (isHigh ? 'is-high' : '')}" style="width: ${pct}%;"></div>
          </div>
        </div>
      `;
    } else {
      usageHtml = `
        <div class="voucher-usage-wrap">
          <div class="voucher-usage-text">
            <span><strong>${uses}</strong> uses</span>
            <span class="voucher-usage-percent">Unlimited</span>
          </div>
        </div>
      `;
    }

    // Expiry Status
    let expiryHtml = '';
    const expDate = v.expiresAt ? utcDate(v.expiresAt) : null;
    const isExpired = expDate && expDate <= now;
    const daysUntil = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : null;

    if (!expDate) {
      expiryHtml = `
        <div class="voucher-expiry-cell">
          <span class="voucher-expiry-date">Never expires</span>
          <span class="voucher-expiry-tag voucher-expiry-tag--valid">Lifetime</span>
        </div>
      `;
    } else if (isExpired) {
      expiryHtml = `
        <div class="voucher-expiry-cell">
          <span class="voucher-expiry-date">${expDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}</span>
          <span class="voucher-expiry-tag voucher-expiry-tag--expired">Expired</span>
        </div>
      `;
    } else if (daysUntil <= 3) {
      expiryHtml = `
        <div class="voucher-expiry-cell">
          <span class="voucher-expiry-date">${expDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}</span>
          <span class="voucher-expiry-tag voucher-expiry-tag--soon">Expires in ${daysUntil} day${daysUntil === 1 ? '' : 's'}</span>
        </div>
      `;
    } else {
      expiryHtml = `
        <div class="voucher-expiry-cell">
          <span class="voucher-expiry-date">${expDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}</span>
          <span class="voucher-expiry-tag voucher-expiry-tag--valid">Valid</span>
        </div>
      `;
    }

    return `
      <tr>
        <!-- 1. Code -->
        <td>
          <div class="voucher-code-cell">
            <span class="voucher-code-chip" title="Click copy to copy code">
              <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"></path>
                <line x1="7" y1="7" x2="7.01" y2="7"></line>
              </svg>
              ${escapeHtml(v.code)}
            </span>
            <button type="button" class="btn-copy-code" data-copy="${escapeHtml(v.code)}" title="Copy voucher code">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
              </svg>
            </button>
          </div>
        </td>

        <!-- 2. Discount -->
        <td>
          <div class="voucher-discount-lead">
            ${discountText}
          </div>
          <span class="voucher-type-badge ${isPct ? 'voucher-type-badge--pct' : 'voucher-type-badge--fixed'}">
            ${isPct ? 'Percentage' : 'Fixed Peso'}
          </span>
        </td>

        <!-- 3. Min. Spend -->
        <td>
          <span class="voucher-min-spend">${minSpendText}</span>
        </td>

        <!-- 4. Usage Progress -->
        <td>${usageHtml}</td>

        <!-- 5. Expiry -->
        <td>${expiryHtml}</td>

        <!-- 7. Actions -->
        <td>
          <div class="voucher-table-actions" style="justify-content: flex-end;">
            <button type="button" class="admin-table-toggle-btn ${v.isActive ? 'is-active' : 'is-inactive'}" data-toggle="${v.id}" title="${v.isActive ? 'Deactivate code' : 'Activate code'}">
              <span>${v.isActive ? 'Active' : 'Inactive'}</span>
            </button>
            <button type="button" class="btn-pill-sm btn-pill--outline" data-edit="${v.id}" title="Edit voucher details">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
              </svg>Edit
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

/* ==========================================================================
   DATA LOADING & PERSISTENCE
   ========================================================================== */
async function loadVouchers() {
  try {
    vouchers = await ApiClient.get(APP_CONSTANTS.ENDPOINTS.ADMIN_VOUCHERS);
    updateKPIs();
    renderTable();
  } catch (e) {
    notify(e.message || 'Failed to load vouchers.', 'error', 'Error');
    byId('voucher-rows').innerHTML = `
      <tr>
        <td colspan="7">
          <div class="admin-empty-state">
            <div class="admin-empty-title">Error Loading Vouchers</div>
            <p>${escapeHtml(e.message)}</p>
          </div>
        </td>
      </tr>
    `;
  }
}

async function saveVoucher() {
  if (isBusy) return;
  const checks = fields.map(validateField);
  if (checks.some((r) => !r)) {
    const firstInvalid = document.querySelector('.admin-modal-voucher .is-invalid');
    if (firstInvalid) firstInvalid.focus();
    return;
  }

  const alert = byId('voucher-modal-alert');
  if (alert) alert.classList.add('is-hidden');

  const unchangedExpiry = input('expiry').value === input('expiry').dataset.original && editingVoucher?.expiresAt;
  const request = {
    code: input('code').value.trim().toUpperCase(),
    discountType: input('type').value,
    discountValue: Number(input('value').value),
    minimumSpend: Number(input('minimum').value || 0),
    expiresAt: unchangedExpiry
      ? utcDate(editingVoucher.expiresAt).toISOString()
      : (input('expiry').value ? new Date(input('expiry').value).toISOString() : null),
    usageLimit: input('limit').value ? Number(input('limit').value) : null,
    isActive: byId('voucher-active').checked
  };

  isBusy = true;
  const saveBtn = byId('btn-save-voucher');
  if (saveBtn) {
    saveBtn.disabled = true;
    saveBtn.textContent = 'Saving...';
  }

  try {
    if (editingVoucher) {
      await ApiClient.put(APP_CONSTANTS.ENDPOINTS.ADMIN_VOUCHER(editingVoucher.id), request);
      notify(`Voucher "${request.code}" updated successfully.`, 'success', 'Voucher Updated');
    } else {
      await ApiClient.post(APP_CONSTANTS.ENDPOINTS.ADMIN_VOUCHERS, request);
      notify(`Voucher "${request.code}" created successfully.`, 'success', 'Voucher Created');
    }
    closeModal();
    await loadVouchers();
  } catch (e) {
    if (alert) {
      alert.textContent = e.message || 'Error saving voucher.';
      alert.classList.remove('is-hidden');
    }
    const key = /code|renamed/i.test(e.message)
      ? 'code'
      : /expiry/i.test(e.message)
      ? 'expiry'
      : /limit|usage/i.test(e.message)
      ? 'limit'
      : 'value';
    setError(key, e.message);
    input(key)?.focus();
  } finally {
    isBusy = false;
    if (saveBtn) {
      saveBtn.disabled = false;
      saveBtn.textContent = 'Save Voucher';
    }
  }
}

async function toggleVoucherActive(id, buttonEl) {
  if (isBusy) return;
  const voucher = vouchers.find((v) => v.id === id);
  if (!voucher) return;

  const newStatus = !voucher.isActive;
  isBusy = true;
  buttonEl.disabled = true;

  try {
    const payload = {
      code: voucher.code,
      discountType: voucher.discountType,
      discountValue: voucher.discountValue,
      minimumSpend: voucher.minimumSpend,
      expiresAt: voucher.expiresAt ? utcDate(voucher.expiresAt).toISOString() : null,
      usageLimit: voucher.usageLimit,
      isActive: newStatus
    };

    await ApiClient.put(APP_CONSTANTS.ENDPOINTS.ADMIN_VOUCHER(id), payload);
    voucher.isActive = newStatus;
    notify(`Voucher "${voucher.code}" ${newStatus ? 'activated' : 'deactivated'}.`, 'success', 'Status Changed');
    updateKPIs();
    renderTable();
  } catch (e) {
    notify(e.message || 'Failed to update voucher status.', 'error', 'Error');
  } finally {
    isBusy = false;
    buttonEl.disabled = false;
  }
}

/* ==========================================================================
   EVENT LISTENERS & ATTACHMENTS
   ========================================================================== */
function attachEvents() {
  // Top Create Button
  byId('btn-open-create')?.addEventListener('click', () => openModal(null));
  window.openCreateVoucherModal = () => openModal(null);

  // Modal Cancel & Close
  byId('btn-close-modal')?.addEventListener('click', closeModal);
  byId('btn-cancel-modal')?.addEventListener('click', closeModal);
  byId('modal-voucher')?.addEventListener('click', (e) => {
    if (e.target === byId('modal-voucher')) closeModal();
  });
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !byId('modal-voucher')?.classList.contains('is-hidden')) {
      closeModal();
    }
  });

  // Modal Save
  byId('btn-save-voucher')?.addEventListener('click', saveVoucher);

  // Form Inputs live preview & validation
  fields.forEach((key) => {
    const el = input(key);
    if (!el) return;
    el.addEventListener('blur', () => {
      validateField(key);
      updateLivePreview();
    });
    el.addEventListener('input', () => {
      if (key === 'code') {
        el.value = el.value.toUpperCase();
      }
      setError(key, '');
      updateLivePreview();
    });
  });

  input('type')?.addEventListener('change', () => {
    validateField('value');
    updateLivePreview();
  });

  byId('voucher-active')?.addEventListener('change', updateLivePreview);

  // Global Search integration for Vouchers
  const searchInput = document.getElementById('adminGlobalSearch');
  if (searchInput) {
    const urlParams = new URLSearchParams(window.location.search);
    const q = urlParams.get('q') || urlParams.get('search');
    if (q) {
      currentSearchTerm = q.trim();
      searchInput.value = currentSearchTerm;
    }
    let debounceTimer;
    searchInput.addEventListener('input', () => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        currentSearchTerm = searchInput.value.trim();
        renderTable();
      }, 150);
    });
  }

  // Filter Tabs
  document.querySelectorAll('#voucher-status-tabs .admin-tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#voucher-status-tabs .admin-tab-btn').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      currentStatusFilter = btn.dataset.status || 'ALL';
      renderTable();
    });
  });

  // Table Delegation (Edit, Toggle, Copy)
  byId('voucher-rows')?.addEventListener('click', (e) => {
    // 1. Copy code
    const copyBtn = e.target.closest('.btn-copy-code');
    if (copyBtn) {
      const code = copyBtn.dataset.copy;
      if (code) {
        navigator.clipboard.writeText(code).then(() => {
          notify(`Copied "${code}" to clipboard!`, 'success');
        }).catch(() => {
          notify(`Failed to copy code.`, 'warning');
        });
      }
      return;
    }

    // 2. Edit voucher
    const editBtn = e.target.closest('[data-edit]');
    if (editBtn) {
      const id = Number(editBtn.dataset.edit);
      const v = vouchers.find((item) => item.id === id);
      if (v) openModal(v);
      return;
    }

    // 3. Toggle status
    const toggleBtn = e.target.closest('[data-toggle]');
    if (toggleBtn) {
      const id = Number(toggleBtn.dataset.toggle);
      toggleVoucherActive(id, toggleBtn);
      return;
    }
  });
}

// Initial Boot
attachEvents();
loadVouchers();
