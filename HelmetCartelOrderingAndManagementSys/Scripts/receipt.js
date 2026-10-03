import { APP_CONSTANTS as importedConstants } from './constants.js?v=20261003';

const safeConstants = (typeof importedConstants !== 'undefined' && importedConstants)
  || (typeof window !== 'undefined' && window.APP_CONSTANTS)
  || {};

const RECEIPTS = safeConstants.RECEIPTS || { BRAND: 'HELMET CARTEL', SIMULATION_PREFIX: 'SIM-' };
const UI = safeConstants.UI || { CURRENCY_SYMBOL_HTML: '&#8369;' };
const PAYMENT_METHODS = safeConstants.PAYMENT_METHODS || {
  HITPAY: 'HitPay',
  CASH: 'Cash',
  CARD_POS: 'Card_POS',
  CASH_ON_DELIVERY: 'CashOnDelivery'
};
const PAYMENT_STATUS = safeConstants.PAYMENT_STATUS || {
  PENDING: 'Pending',
  COMPLETED: 'Completed'
};
const SHIPPING_METHODS = safeConstants.SHIPPING_METHODS || {
  DELIVERY: 'Delivery',
  PICKUP: 'Pickup'
};

const escape = value => String(value ?? '').replace(/[&<>"']/g, char =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
const money = value => `${Number(value) < 0 ? '-' : ''}${UI.CURRENCY_SYMBOL_HTML || '&#8369;'}${Math.abs(Number(value ?? 0)).toLocaleString('en-PH', {
  minimumFractionDigits: 2, maximumFractionDigits: 2
})}`;
const field = (label, value) => `<div class="hc-receipt-field"><span>${label}</span><strong>${escape(value || 'Unavailable')}</strong></div>`;
const amount = (label, value, className = '') => `<div class="hc-receipt-amount ${className}"><span>${label}</span><strong>${money(value)}</strong></div>`;

const paymentLabels = {
  [PAYMENT_METHODS.HITPAY]: 'QRPh',
  [PAYMENT_METHODS.CASH]: 'Cash',
  [PAYMENT_METHODS.CARD_POS]: 'Card terminal',
  [PAYMENT_METHODS.CASH_ON_DELIVERY]: 'Cash on delivery'
};
const readableStatus = value => String(value || '').replace(/([a-z])([A-Z])/g, '$1 $2');

export function renderReceipt(order) {
  if (!order) return '<div class="receipt-error">Unable to load receipt: Order details are unavailable.</div>';

  const paid = (order.paymentStatus || '') === PAYMENT_STATUS.COMPLETED;
  const reference = order.gatewayReference;
  const simulationPrefix = RECEIPTS.SIMULATION_PREFIX || 'SIM-';
  const simulated = String(reference || '').startsWith(simulationPrefix);
  const delivery = String(order.shippingMethod || '').toLowerCase() === 'delivery' || order.shippingMethod === SHIPPING_METHODS.DELIVERY;

  // Format receipt number (#REC-000004)
  const recNumber = order.id
    ? String(order.id).padStart(6, '0')
    : (order.orderNumber ? String(order.orderNumber).replace(/^[^-]+-/, '').substring(0, 6) : '000001');

  // SQL DATETIME2 order timestamps are stored in UTC; JSON may omit the suffix.
  const rawDate = String(order.createdAt || '');
  const date = new Date(rawDate && !/(Z|[+-]\d\d:\d\d)$/.test(rawDate) ? `${rawDate}Z` : rawDate);
  const timestamp = Number.isNaN(date.getTime())
    ? 'Unavailable'
    : date.toLocaleString('en-US', {
        timeZone: 'Asia/Manila', month: 'long', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit'
      }).replace(',', ' at');

  const address = [
    order.shippingAddress,
    order.shippingBarangay ? `Brgy. ${order.shippingBarangay}` : '',
    order.shippingCity,
    order.shippingProvince,
    order.shippingPostalCode
  ].filter(Boolean).join(', ');

  const gatewayName = paymentLabels[order.paymentMethod || order.paymentGateway] || order.paymentMethod || order.paymentGateway || 'Unavailable';

  const rows = (order.items || []).map(item => {
    const specs = [item.sku ? `SKU: ${item.sku}` : '', item.color, item.size].filter(Boolean).join(' | ');
    return `<tr>
      <td>
        <strong>${escape(item.productName || 'Helmet Merchandise')}</strong><br />
        <span class="receipt-item-sku">${escape(specs)}</span>
      </td>
      <td class="receipt-col-qty">${escape(item.quantity ?? 1)}</td>
      <td class="receipt-col-price">${money(item.unitPrice)}</td>
      <td class="receipt-col-total">${money(item.totalPrice)}</td>
    </tr>`;
  }).join('');

  return `<div class="digital-receipt-doc hc-receipt-card" aria-label="Helmet Cartel transaction receipt">
    <div class="digital-receipt-top">
      <div>
        <div class="receipt-brand-logo">${escape(RECEIPTS.BRAND || 'HELMET CARTEL')}</div>
        <div class="receipt-brand-hub">
          Flagship Store &amp; Fulfillment Hub<br />
          Katipunan Ave, Quezon City, Metro Manila, 1108<br />
          TIN: 420-691-888-000 &bull; support@helmetcartel.com
        </div>
      </div>
      <div class="receipt-doc-meta">
        <span class="receipt-doc-tag">Digital Transaction Receipt</span>
        <span class="receipt-doc-no">#REC-${escape(recNumber)}</span>
        <span class="receipt-doc-date">${escape(timestamp)}</span>
      </div>
    </div>

    ${simulated ? '<p class="hc-receipt-notice">Simulated payment &mdash; academic demonstration</p>' : ''}
    <div class="receipt-parties-grid">
      <div>
        <div class="receipt-party-title">Billed To</div>
        <div class="receipt-party-val">
          <strong>${escape(order.customerName || 'Valued Customer')}</strong><br />
          ${escape(order.customerEmail || 'support@helmetcartel.com')}<br />
          ${escape(order.customerPhone || '0917 000 0000')}
           ${delivery && address ? `<div class="receipt-party-val">${escape(address)}</div>` : ''}
        </div>
      </div>
      <div>
        <div class="receipt-party-title">Fulfillment &amp; Payment</div>
        <div class="receipt-party-val">
          <strong>Method:</strong> ${delivery ? 'Door-to-Door Delivery' : 'Store Pickup (QC Hub)'}<br />
          <strong>Gateway:</strong> ${escape(gatewayName)}<br />
          <strong>Reference:</strong> ${escape(reference || 'Unavailable')}<br />
          <strong>Payment Status:</strong> <span class="receipt-status-text">${escape(order.paymentStatus || (paid ? 'Completed' : 'Pending'))}</span>
        </div>
      </div>
    </div>

    <table class="receipt-items-table">
      <thead>
        <tr>
          <th>Item &amp; Specification</th>
          <th class="receipt-col-qty">Qty</th>
          <th class="receipt-col-price">Unit Price</th>
          <th class="receipt-col-total">Total</th>
        </tr>
      </thead>
      <tbody>
        ${rows}
      </tbody>
    </table>

    <div class="receipt-totals-list">
      <div class="receipt-total-row">
        <span>Subtotal</span>
        <span>${money(order.subtotal)}</span>
      </div>
      ${Number(order.discountAmount) > 0 ? `
      <div class="receipt-total-row receipt-total-row--discount">
        <span>Voucher Discount${order.voucherCode ? ` (${escape(order.voucherCode)})` : ''}</span>
        <span>-${money(order.discountAmount)}</span>
      </div>` : ''}
      ${delivery || Number(order.shippingFee) > 0 ? `
      <div class="receipt-total-row">
        <span>Shipping Fee</span>
        <span>${money(order.shippingFee)}</span>
      </div>` : ''}
      <div class="receipt-total-row receipt-total-row--grand">
        <span>${paid ? 'Total Paid' : 'Order Total'}</span>
        <span>${money(order.totalAmount)}</span>
      </div>
      ${order.cashTendered != null ? `
      <div class="receipt-total-row">
        <span>Cash received</span>
        <span>${money(order.cashTendered)}</span>
      </div>
      <div class="receipt-total-row">
        <span>Change</span>
        <span>${money(Number(order.cashTendered) - Number(order.totalAmount))}</span>
      </div>` : ''}
    </div>

    <div class="receipt-footer-seal">
      <span>Order Number: <strong>${escape(order.orderNumber)}</strong></span>
      <span>Verified Electronic Transaction</span>
    </div>
  </div>`;
}

export async function printReceipt(element) {
  if (!element?.querySelector('.digital-receipt-doc, .hc-receipt-card, .hc-receipt')) return;
  document.getElementById('hc-receipt-print')?.remove();
  const surface = document.createElement('section');
  surface.id = 'hc-receipt-print';
  surface.innerHTML = element.innerHTML;
  document.body.appendChild(surface);
  document.body.classList.add('hc-printing-receipt');
  const cleanup = () => {
    surface.remove();
    document.body.classList.remove('hc-printing-receipt');
  };
  window.addEventListener('afterprint', cleanup, { once: true });
  try {
    await document.fonts?.ready;
    window.print();
  } catch (error) { cleanup(); throw error; }
}

// Keep keyboard focus inside an open receipt dialog and restore it when closed.
export function focusReceiptDialog(dialog, onClose) {
  const previous = document.activeElement;
  const focusable = () => [...dialog.querySelectorAll('button, a[href], [tabindex="0"]')].filter(el => !el.disabled && el.getClientRects().length);
  const keydown = event => {
    if (event.key === 'Escape') { event.preventDefault(); onClose(); }
    if (event.key !== 'Tab') return;
    const nodes = focusable();
    if (!nodes.length) return;
    const first = nodes[0], last = nodes[nodes.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  };
  dialog.addEventListener('keydown', keydown);
  focusable()[0]?.focus();
  return () => { dialog.removeEventListener('keydown', keydown); previous?.focus(); };
}
