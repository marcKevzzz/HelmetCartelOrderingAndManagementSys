import { ApiClient } from '../api.js';
import { APP_CONSTANTS } from '../constants.js';
import { renderReceipt, printReceipt, focusReceiptDialog } from '../receipt.js?v=20261003-3';

const viewButton = document.getElementById('btn-view-order-receipt');
const overlay = document.getElementById('order-receipt-overlay');
const dialog = document.getElementById('order-receipt-dialog');
const receiptDocument = document.getElementById('order-receipt-document');
const printButton = document.getElementById('btn-print-order-receipt');
let cleanupFocus;
let requestVersion = 0;

function closeReceipt() {
    requestVersion++;
    overlay.hidden = true;
    overlay.classList.add('is-hidden');
    document.body.classList.remove('hc-receipt-dialog-open');
    cleanupFocus?.();
    cleanupFocus = null;
}

viewButton?.addEventListener('click', async () => {
    const version = ++requestVersion;
    receiptDocument.textContent = 'Loading receipt...';
    printButton.disabled = true;
    overlay.hidden = false;
    overlay.classList.remove('is-hidden');
    document.body.classList.add('hc-receipt-dialog-open');
    cleanupFocus?.();
    cleanupFocus = focusReceiptDialog(dialog, closeReceipt);
    try {
        const order = await ApiClient.get(`${APP_CONSTANTS.ENDPOINTS.ORDERS}/${viewButton.dataset.orderId}`);
        if (version !== requestVersion) return;
        if (!order?.orderNumber) throw new Error('Order record not found.');
        receiptDocument.innerHTML = renderReceipt(order);
        printButton.disabled = false;
    } catch (error) {
        if (version === requestVersion) receiptDocument.textContent = `Unable to load receipt: ${error.message}`;
    }
});

document.getElementById('btn-close-order-receipt')?.addEventListener('click', closeReceipt);
overlay?.addEventListener('click', event => { if (event.target === overlay) closeReceipt(); });
printButton?.addEventListener('click', () => printReceipt(receiptDocument));
