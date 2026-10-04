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

export async function downloadReceipt(element, fallbackOrderNum = '') {
  const card = element?.querySelector('.hc-receipt-card, .digital-receipt-doc, .hc-receipt') || element;
  if (!card) return;

  const orderNumMatch = card.textContent.match(/#?(HC-\d{8}-[A-F0-9]+|SIM-[A-F0-9]+|ORD-\d+)/i);
  const orderNumber = orderNumMatch ? orderNumMatch[1] : (fallbackOrderNum || 'HC-Receipt');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Receipt - ${orderNumber}</title>
  <style>
    :root {
      --color-border-subtle: #e5e7eb;
      --color-text-main: #111827;
      --color-text-secondary: #4b5563;
      --color-text-muted: #6b7280;
      --color-surface-subtle: #f8fafc;
      --radius-sm: 6px;
      --radius-md: 8px;
      --space-2: 8px;
      --space-3: 12px;
      --space-4: 16px;
      --space-5: 20px;
      --space-6: 24px;
    }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #f1f5f9;
      color: #111827;
      margin: 0;
      padding: 32px 16px;
      display: flex;
      justify-content: center;
    }
    .receipt-page-container {
      max-width: 680px;
      width: 100%;
    }
    .receipt-download-actions {
      display: flex;
      justify-content: flex-end;
      margin-bottom: 16px;
    }
    .btn-print-page {
      background: #000000;
      color: #ffffff;
      border: 1px solid #000000;
      border-radius: 9999px;
      padding: 8px 18px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
    }
    .btn-print-page:hover { background: #27272a; }
    .hc-receipt-card {
      background: #ffffff;
      border: 1px solid #e5e7eb;
      border-radius: 8px;
      padding: 24px;
      display: flex;
      flex-direction: column;
      gap: 20px;
      font-size: 0.875rem;
      color: #111827;
      box-shadow: 0 4px 16px rgba(0,0,0,0.06);
    }
    .digital-receipt-top {
      display: flex;
      justify-content: space-between;
      border-bottom: 2px solid #000000;
      padding-bottom: 16px;
      flex-wrap: wrap;
      gap: 16px;
    }
    .receipt-brand-logo { font-size: 1.35rem; font-weight: 900; letter-spacing: -0.02em; color: #000000; }
    .receipt-brand-hub { font-size: 11px; color: #737373; line-height: 1.4; margin-top: 2px; }
    .receipt-doc-meta { display: flex; flex-direction: column; align-items: flex-end; gap: 2px; }
    .receipt-doc-tag { font-size: 0.75rem; font-weight: 700; text-transform: uppercase; color: #4b5563; }
    .receipt-doc-no { font-family: monospace; font-weight: 800; font-size: 1rem; color: #000000; }
    .receipt-doc-date { font-size: 0.75rem; color: #737373; }
    .receipt-sim-notice { padding: 8px 12px; background: #fffbeb; color: #b45309; border: 1px solid #fde68a; border-radius: 6px; font-size: 0.75rem; font-weight: 600; }
    .receipt-parties-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; background-color: #f8fafc; padding: 16px; border-radius: 8px; border: 1px solid #e2e8f0; }
    .receipt-party-title { font-size: 0.75rem; font-weight: 700; text-transform: uppercase; color: #64748b; margin-bottom: 4px; }
    .receipt-party-val { font-size: 12px; line-height: 1.5; color: #1e293b; text-align: left; }
    .receipt-party-val strong { color: #000000; }
    .receipt-status-text { font-weight: 700; color: #047857; }
    .receipt-address-row { background-color: #f8fafc; padding: 12px 16px; border-radius: 8px; border: 1px solid #e2e8f0; }
    .receipt-items-table { width: 100%; border-collapse: collapse; margin-top: 8px; }
    .receipt-items-table th { border-bottom: 2px solid #000000; padding: 8px; font-size: 0.75rem; font-weight: 800; text-transform: uppercase; color: #000000; text-align: left; }
    .receipt-items-table td { padding: 10px 8px; border-bottom: 1px solid #e5e7eb; font-size: 13px; vertical-align: middle; }
    .receipt-col-qty { text-align: center; width: 60px; }
    .receipt-col-price, .receipt-col-total { text-align: right; width: 120px; }
    .receipt-items-table tr:last-child td { border-bottom: 1px solid #000000; }
    .receipt-item-sku { font-size: 11px; color: #6b7280; }
    .receipt-totals-list { display: flex; flex-direction: column; gap: 6px; align-self: flex-end; width: 260px; margin-top: 8px; }
    .receipt-total-row { display: flex; justify-content: space-between; font-size: 13px; color: #4b5563; }
    .receipt-total-row--discount { color: #047857; font-weight: 600; }
    .receipt-total-row--grand { border-top: 2px solid #000000; padding-top: 8px; margin-top: 4px; font-size: 15px; font-weight: 900; color: #000000; }
    .receipt-footer-seal { display: flex; justify-content: space-between; border-top: 1px dashed #cbd5e1; padding-top: 12px; font-size: 11px; color: #64748b; flex-wrap: wrap; gap: 8px; margin-top: 8px; }
    @media print {
      body { background: #ffffff; padding: 0; }
      .receipt-download-actions { display: none; }
      .hc-receipt-card { border: none; box-shadow: none; padding: 0; }
    }
  </style>
</head>
<body>
  <div class="receipt-page-container">
    <div class="receipt-download-actions">
      <button type="button" class="btn-print-page" onclick="window.print()">Print Document</button>
    </div>
    ${card.outerHTML}
  </div>
</body>
</html>`;

  const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
  const blobUrl = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = blobUrl;
  anchor.download = `Receipt-${orderNumber}.html`;
  document.body.appendChild(anchor);
  anchor.click();
  setTimeout(() => {
    anchor.remove();
    URL.revokeObjectURL(blobUrl);
  }, 250);
}

export async function printReceipt(element) {
  return downloadReceipt(element);
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
