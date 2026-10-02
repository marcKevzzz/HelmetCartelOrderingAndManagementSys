/**
 * HELMET CARTEL - STOREFRONT CART PAGE CONTROLLER (cart.js)
 * Manages cart item rendering, selection toggling, quantity stepping,
 * and seamless redirection to the multi-step checkout workflow.
 */

import { CartManager } from '../cart.js';
import { RealtimeManager } from '../realtime.js';
import { ApiClient } from '../api.js';
import { APP_CONSTANTS } from '../constants.js';

const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
})[char]);

let emptyCartMarkup = '';

export function renderCartView() {
    CartManager.updateCartBadge();
    const container = document.getElementById('cart-items-container');
    const emptyMsg = document.getElementById('empty-cart-msg');
    if (!container) return;

    if (!emptyCartMarkup && emptyMsg) {
        emptyCartMarkup = emptyMsg.outerHTML;
    }

    const items = CartManager.getItems();

    if (items.length === 0) {
        container.innerHTML = emptyCartMarkup;
    } else {
        if (emptyMsg) emptyMsg.classList.add('tab-pane--hidden');
        const selectedItems = CartManager.getSelectedItems();
        const allSelected = selectedItems.length === items.length && items.length > 0;
        
        let html = `
        <div class="cart-select-all-bar">
            <div class="cart-select-all-left btn-select-all" title="Toggle select all items">
                <button type="button" class="cart-drawer-item__check ${allSelected ? 'is-checked' : ''}" aria-label="Select all items">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                        <polyline points="20 6 9 17 4 12"></polyline>
                    </svg>
                </button>
                <span class="cart-select-all-text">Select All (${items.length} items)</span>
            </div>
            <button type="button" class="btn-clear-selected ${selectedItems.length > 0 ? '' : 'is-disabled'}" title="Remove selected items">
                Remove Selected
            </button>
        </div>
        `;

        html += items.map(item => {
            const isChecked = item.isSelected !== false;
            const productUrl = APP_CONSTANTS.ROUTES.PRODUCT_DETAIL(Number(item.productId));
            return `
            <div class="cart-item ${isChecked ? '' : 'cart-item--unselected'}" data-variant-id="${escapeHtml(item.variantId)}">
                <button type="button" class="cart-drawer-item__check ${isChecked ? 'is-checked' : ''} btn-toggle-check" data-variant-id="${escapeHtml(item.variantId)}" title="${isChecked ? 'Deselect item' : 'Select for checkout'}" aria-label="Toggle selection">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                        <polyline points="20 6 9 17 4 12"></polyline>
                    </svg>
                </button>
                <a href="${productUrl}" class="cart-item__thumb" title="View details for ${escapeHtml(item.name)}">
                    <img src="${escapeHtml(item.imageUrl)}" alt="${escapeHtml(item.name)}" class="cart-item__img" />
                </a>
                <div class="cart-item__details">
                    <h3 class="cart-item__title"><a href="${productUrl}">${escapeHtml(item.name)}</a></h3>
                    <p class="cart-item__variant-text">Size: <strong>${escapeHtml(item.size)}</strong></p>
                    <p class="cart-item__variant-text">Color: <strong>${escapeHtml(item.color)}</strong></p>
                    <div class="cart-item__price">&#8369;${Number(item.price).toLocaleString()}</div>
                    ${Number(item.availableStock) < Number(item.quantity) ? '<p class="cart-item__stock-note">Insufficient stock. Update or remove this item before checkout.</p>' : ''}
                </div>
                <div class="cart-item__actions">
                    <button type="button" class="btn-remove-item" data-variant-id="${escapeHtml(item.variantId)}" title="Remove Item" aria-label="Remove ${escapeHtml(item.name)}">
                        <svg viewBox="0 0 24 24">
                            <polyline points="3 6 5 6 21 6"></polyline>
                            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                        </svg>
                    </button>
                    <div class="quantity-stepper">
                        <button type="button" class="stepper-btn btn-qty-minus" data-variant-id="${escapeHtml(item.variantId)}" aria-label="Decrease quantity of ${escapeHtml(item.name)}">-</button>
                        <span class="stepper-value">${item.quantity}</span>
                        <button type="button" class="stepper-btn btn-qty-plus" data-variant-id="${escapeHtml(item.variantId)}" aria-label="Increase quantity of ${escapeHtml(item.name)}">+</button>
                    </div>
                </div>
            </div>
            `;
        }).join('');

        container.innerHTML = html;
    }

    const selectedItems = CartManager.getSelectedItems();
    const subtotal = CartManager.getSelectedSubtotal();
    const total = CartManager.getTotal();

    const subtotalEl = document.getElementById('summary-subtotal');
    const totalEl = document.getElementById('summary-total');
    if (subtotalEl) subtotalEl.innerHTML = `&#8369;${subtotal.toLocaleString()}`;
    if (totalEl) totalEl.innerHTML = `&#8369;${total.toLocaleString()}`;

    const checkoutBtn = document.getElementById('btn-checkout');
    if (checkoutBtn) {
        const btnSpan = checkoutBtn.querySelector('span');
        if (btnSpan) {
            btnSpan.textContent = selectedItems.length > 0 
                ? `Go to Checkout (${selectedItems.length})` 
                : 'Select items to checkout';
        }
        checkoutBtn.classList.toggle('btn--disabled', selectedItems.length === 0);
    }
}

// Global click event dispatcher for Cart UI
function initCartEvents() {
    document.addEventListener('click', (e) => {
        if (e.target.closest('.btn-select-all')) {
            const allSelected = CartManager.getSelectedItems().length === CartManager.getItems().length;
            CartManager.selectAll(!allSelected);
            renderCartView();
            return;
        }
        if (e.target.closest('.btn-clear-selected')) {
            const selected = CartManager.getSelectedItems();
            if (selected.length > 0) {
                selected.forEach(item => CartManager.removeItem(item.variantId));
                renderCartView();
                RealtimeManager.showToast(`Removed ${selected.length} items from cart.`, 'delete');
            }
            return;
        }
        const toggleCheckBtn = e.target.closest('.btn-toggle-check');
        if (toggleCheckBtn) {
            const id = toggleCheckBtn.dataset.variantId;
            CartManager.toggleItemSelection(id);
            renderCartView();
            return;
        }
        if (e.target.closest('.btn-remove-item')) {
            const id = e.target.closest('.btn-remove-item').dataset.variantId;
            const item = CartManager.getItems().find(i => String(i.variantId) === String(id));
            const name = item ? item.name : 'Item';
            CartManager.removeItem(id);
            renderCartView();
            RealtimeManager.showToast(`${name} removed from your cart.`, 'delete');
            return;
        }
        if (e.target.closest('.btn-qty-minus')) {
            const id = e.target.closest('.btn-qty-minus').dataset.variantId;
            const item = CartManager.getItems().find(i => String(i.variantId) === String(id));
            if (item) {
                CartManager.updateQuantity(id, item.quantity - 1);
                renderCartView();
            }
            return;
        }
        if (e.target.closest('.btn-qty-plus')) {
            const id = e.target.closest('.btn-qty-plus').dataset.variantId;
            const item = CartManager.getItems().find(i => String(i.variantId) === String(id));
            if (item) {
                CartManager.updateQuantity(id, item.quantity + 1);
                renderCartView();
            }
            return;
        }
        // Allow clicking item container like a label
        const cartItem = e.target.closest('.cart-item');
        if (cartItem && !e.target.closest('.cart-item__actions, a, .btn-remove-item, .quantity-stepper')) {
            const id = cartItem.dataset.variantId;
            if (id) {
                CartManager.toggleItemSelection(id);
                renderCartView();
                return;
            }
        }
        if (e.target.closest('#btn-checkout')) {
            const selected = CartManager.getSelectedItems();
            if (selected.length === 0) {
                RealtimeManager.showToast('Please select at least 1 item to checkout.', 'alert');
                return;
            }
            if (selected.some(item => !Number.isSafeInteger(Number(item.variantId)))) {
                RealtimeManager.showToast('An older cart item needs to be added again from its product page.', 'alert');
                return;
            }
            if (selected.some(item => Number(item.availableStock) < Number(item.quantity))) {
                RealtimeManager.showToast('One or more selected items have insufficient stock.', 'alert');
                return;
            }
            if (!ApiClient.isAuthenticated()) {
                window.showAuthPromptModal?.({
                    title: 'Sign In to Checkout',
                    message: 'Please sign in or create an account before proceeding to checkout.',
                    returnUrl: APP_CONSTANTS.ROUTES.CHECKOUT
                });
                return;
            }
            window.location.href = APP_CONSTANTS.ROUTES.CHECKOUT;
            return;
        }
    });
}

document.addEventListener('DOMContentLoaded', () => {
    initCartEvents();
    renderCartView();
    CartManager.refreshItems().then(renderCartView).catch(() => {});
});
