/**
 * HELMET CARTEL - STOREFRONT CHECKOUT CONTROLLER (checkout.js)
 * Manages multi-step checkout workflow, shipping calculations, state restoration,
 * address selection, payment options, and live order submission.
 */

import { ApiClient } from '../api.js';
import { CartManager } from '../cart.js?v=20261004';
import { RealtimeManager } from '../realtime.js';
import { renderReceipt, printReceipt } from '../receipt.js?v=20261003-4';
import { APP_CONSTANTS } from '../constants.js';

const CHECKOUT_STATE_KEY = 'hc_checkout_state';
const urlParams = new URLSearchParams(window.location.search);
const isBuyNowMode = urlParams.get('mode') === 'buynow';
let shoppingReady = isBuyNowMode;
let emptyCartTimer;

function getBuyNowItem() {
    try {
        const raw = sessionStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.BUY_NOW_ITEM)
                 || localStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.BUY_NOW_ITEM);
        return raw ? JSON.parse(raw) : null;
    } catch {
        return null;
    }
}

function saveBuyNowItem(item) {
    try {
        const str = JSON.stringify(item);
        sessionStorage.setItem(APP_CONSTANTS.STORAGE_KEYS.BUY_NOW_ITEM, str);
        localStorage.setItem(APP_CONSTANTS.STORAGE_KEYS.BUY_NOW_ITEM, str);
    } catch {}
}

function clearBuyNowItem() {
    try {
        sessionStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.BUY_NOW_ITEM);
        localStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.BUY_NOW_ITEM);
    } catch {}
}

function getStoredCheckoutState() {
    try {
        const raw = localStorage.getItem(CHECKOUT_STATE_KEY);
        return raw ? JSON.parse(raw) : null;
    } catch {
        return null;
    }
}

const initialDraft = getStoredCheckoutState();

let currentStep = 1;
let selectedFulfillment = (initialDraft?.fulfillment === 'delivery' || initialDraft?.fulfillment === 'pickup')
    ? initialDraft.fulfillment
    : 'pickup';
let selectedShippingCost = 0;
let selectedPaymentMethodName = "QRPh";
let selectedPaymentKey = initialDraft?.paymentKey || "hitpay";
let savedAddressesList = [];
let selectedAddress = null;
let appliedVoucher = null;
let merchandiseQuote = null;
let voucherSignature = '';
let voucherSequence = 0;
let voucherPending = false;
let placingOrder = false;
let checkoutComplete = false;
const voucherItemsSignature = () => JSON.stringify(getCheckoutItems().map(item => [Number(item.variantId), Number(item.quantity), Number(item.price)]));
function voucherError(message) {
    const input = document.getElementById('checkout-voucher');
    input?.classList.toggle('is-invalid', !!message);
    input?.setAttribute('aria-invalid', String(!!message));
    const error = document.getElementById('checkout-voucher-error');
    if (error) error.textContent = message;
}
async function validateVoucher() {
    const input = document.getElementById('checkout-voucher');
    const code = input?.value.trim().toUpperCase() || '';
    const sequence = ++voucherSequence;
    appliedVoucher = null;
    voucherSignature = voucherItemsSignature();
    if (!code) { voucherPending = false; voucherError(''); renderSidebar(); return true; }
    if (!/^[A-Z0-9-]{3,30}$/.test(code)) {
        voucherPending = false; voucherError('Use 3-30 letters, numbers or hyphens.'); renderSidebar(); return false;
    }
    voucherPending = true;
    document.getElementById('checkout-voucher-status').textContent = 'Checking voucher...';
    renderSidebar();
    try {
        const customerEmail = document.getElementById('checkout-email')?.value?.trim() || 
                              document.getElementById('profile-email')?.value?.trim() || null;
        const quote = await ApiClient.post(APP_CONSTANTS.ENDPOINTS.VOUCHER_VALIDATE, {
            code, 
            items: getCheckoutItems().map(item => ({variantId: Number(item.variantId), quantity: Number(item.quantity)})),
            customerEmail
        });
        if (sequence !== voucherSequence) return false;
        if (voucherSignature !== voucherItemsSignature()) return validateVoucher();
        appliedVoucher = quote;
        merchandiseQuote = {signature: voucherSignature, subtotal: Number(quote.subtotal)};
        input.value = quote.code;
        voucherError('');
        return true;
    } catch (e) {
        if (sequence === voucherSequence) voucherError(e.message);
        return false;
    } finally {
        if (sequence === voucherSequence) { voucherPending = false; renderSidebar(); }
    }
}
function removeVoucher() {
    if (placingOrder) return;
    ++voucherSequence; appliedVoucher = null; voucherPending = false; voucherSignature = '';
    document.getElementById('checkout-voucher').value = '';
    voucherError(''); renderSidebar();
}

function saveCheckoutState() {
    try {
        const agreeCheckbox = document.getElementById('chk-agree-terms');
        const state = {
            step: currentStep,
            fulfillment: selectedFulfillment,
            selectedAddressId: selectedAddress ? selectedAddress.id : null,
            paymentKey: selectedPaymentKey,
            termsAgreed: agreeCheckbox ? agreeCheckbox.checked : true
        };
        localStorage.setItem(CHECKOUT_STATE_KEY, JSON.stringify(state));
    } catch (e) {
        console.warn('[Checkout] Failed to save checkout state:', e);
    }
}

function clearCheckoutState() {
    try {
        localStorage.removeItem(CHECKOUT_STATE_KEY);
    } catch {}
}

// Dynamic Shipping Calculator
function computeShippingDetails(cityInput, provinceInput) {
    const city = (cityInput || '').trim().toLowerCase();
    const prov = (provinceInput || '').trim().toLowerCase();

    if (!city && !prov) {
        return { fee: 0, region: 'Unspecified Address', eta: 'Select address to calculate' };
    }

    const isNcr = prov === 'metro manila' || prov === 'ncr';
    if (isNcr) {
        const tier = APP_CONSTANTS.SHIPPING_TIERS.NCR;
        return { fee: tier.fee, region: tier.name, eta: tier.eta };
    }

    const gmaProvinces = ['cavite', 'laguna', 'batangas', 'rizal', 'bulacan'];
    const isGma = gmaProvinces.some(p => prov.includes(p));
    if (isGma) {
        const tier = APP_CONSTANTS.SHIPPING_TIERS.GMA;
        return { fee: tier.fee, region: tier.name, eta: tier.eta };
    }

    const luzonProvinces = [
        'pampanga', 'nueva ecija', 'tarlac', 'zambales', 'bataan', 'pangasinan',
        'ilocos', 'la union', 'benguet', 'baguio', 'cagayan', 'isabela',
        'nueva vizcaya', 'quirino', 'aurora', 'quezon', 'albay', 'camarines',
        'sorsogon', 'catanduanes', 'masbate', 'marinduque', 'occidental mindoro',
        'oriental mindoro', 'palawan', 'romblon', 'abra', 'apayao', 'ifugao',
        'kalinga', 'mountain province'
    ];
    const isLuzon = luzonProvinces.some(p => prov.includes(p));
    if (isLuzon) {
        const tier = APP_CONSTANTS.SHIPPING_TIERS.LUZON;
        return { fee: tier.fee, region: tier.name, eta: tier.eta };
    }

    const visayasProvinces = [
        'cebu', 'bohol', 'iloilo', 'negros', 'leyte', 'samar', 'panay',
        'capiz', 'aklan', 'boracay', 'antique', 'guimaras', 'biliran', 'siquijor'
    ];
    const isVisayas = visayasProvinces.some(p => prov.includes(p));
    if (isVisayas) {
        const tier = APP_CONSTANTS.SHIPPING_TIERS.VISAYAS;
        return { fee: tier.fee, region: tier.name, eta: tier.eta };
    }

    const mindanaoProvinces = [
        'davao', 'cagayan de oro', 'cdo', 'misamis', 'bukidnon', 'general santos',
        'gensan', 'south cotabato', 'cotabato', 'zamboanga', 'iligan', 'lanaw',
        'lanao', 'agusan', 'surigao', 'sultan kudarat', 'sarangani', 'basilan',
        'sulu', 'tawi-tawi', 'maguindanao'
    ];
    const isMindanao = mindanaoProvinces.some(p => prov.includes(p));
    if (isMindanao) {
        const tier = APP_CONSTANTS.SHIPPING_TIERS.MINDANAO;
        return { fee: tier.fee, region: tier.name, eta: tier.eta };
    }

    return { fee: 175, region: 'Standard Nationwide Delivery', eta: '3\u20136 Business Days' };
}

// Determine Checkout Items (Single Buy Now item OR Cart selected items)
function getCheckoutItems() {
    if (isBuyNowMode) {
        const singleItem = getBuyNowItem();
        return singleItem ? [singleItem] : [];
    }
    return CartManager.getSelectedItems();
}

function calculateTotals() {
    const items = getCheckoutItems();
    const validQuote = appliedVoucher && voucherSignature === voucherItemsSignature();
    const subtotal = merchandiseQuote?.signature === voucherItemsSignature() ? merchandiseQuote.subtotal : items.reduce((sum, i) => sum + (i.price * i.quantity), 0);
    const isFreeShipping = validQuote && appliedVoucher.discountType === (APP_CONSTANTS.VOUCHER_TYPES?.FREE_SHIPPING || 'FREE_SHIPPING');
    const hasDeliveryAddress = selectedFulfillment === 'pickup' || !!selectedAddress;
    const effectiveShipping = (isFreeShipping || !hasDeliveryAddress) ? 0 : selectedShippingCost;
    const discount = validQuote ? (isFreeShipping ? selectedShippingCost : Number(appliedVoucher.discountAmount)) : 0;
    const total = subtotal - (isFreeShipping ? 0 : discount) + effectiveShipping;
    return { subtotal, discount, total, isFreeShipping, effectiveShipping, hasDeliveryAddress };
}

function renderSidebar() {
    if (checkoutComplete || !shoppingReady) return;
    if (appliedVoucher && voucherSignature !== voucherItemsSignature()) {
        appliedVoucher = null;
        validateVoucher();
        return;
    }
    const items = getCheckoutItems();
    if (items.length === 0 && currentStep < 4) {
        const emptyMsg = isBuyNowMode
            ? 'Buy Now item is missing. Redirecting to Shop...'
            : 'Your cart is empty. Redirecting to Shop...';
        if (!emptyCartTimer) {
            RealtimeManager.showToast(emptyMsg, 'alert');
            emptyCartTimer = setTimeout(() => {
                if (shoppingReady && !getCheckoutItems().length && !checkoutComplete) window.location.href = APP_CONSTANTS.ROUTES.SHOP;
            }, 1500);
        }
        return;
    }

    clearTimeout(emptyCartTimer);
    emptyCartTimer = null;
    const { subtotal, discount, total, isFreeShipping } = calculateTotals();
    const discountRow = document.getElementById('sidebar-voucher-row');
    if (discountRow) discountRow.hidden = !appliedVoucher;
    const discountLabelEl = document.getElementById('sidebar-voucher-label');
    if (discountLabelEl && appliedVoucher) {
        if (isFreeShipping) {
            discountLabelEl.textContent = `Free Delivery (${appliedVoucher.code})`;
        } else if (appliedVoucher.discountType === APP_CONSTANTS.VOUCHER_TYPES?.PERCENTAGE && appliedVoucher.discountValue) {
            discountLabelEl.textContent = `Discount (-${appliedVoucher.discountValue}%)`;
        } else if (appliedVoucher.code) {
            discountLabelEl.textContent = `Discount (${appliedVoucher.code})`;
        } else {
            discountLabelEl.textContent = 'Discount';
        }
    }
    const discountEl = document.getElementById('sidebar-voucher-discount');
    if (discountEl) discountEl.textContent = `-${APP_CONSTANTS.UI.CURRENCY_SYMBOL}${discount.toLocaleString('en-PH', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    const voucherStatus = document.getElementById('checkout-voucher-status');
    if (voucherStatus) voucherStatus.textContent = voucherPending ? 'Checking voucher...' : (appliedVoucher ? `${appliedVoucher.code} applied${isFreeShipping ? ' (100% Free Delivery)' : ''}` : '');
    const removeButton = document.getElementById('checkout-voucher-remove');
    if (removeButton) removeButton.hidden = !appliedVoucher;
    const applyButton = document.getElementById('checkout-voucher-apply');
    if (applyButton) applyButton.disabled = voucherPending || placingOrder;

    const subtotalEl = document.getElementById('sidebar-subtotal');
    const shippingEl = document.getElementById('sidebar-shipping');
    const totalEl = document.getElementById('sidebar-total');

    if (subtotalEl) subtotalEl.innerHTML = `&#8369;${subtotal.toLocaleString()}`;
    if (shippingEl) {
        if (selectedFulfillment === 'pickup') {
            shippingEl.innerHTML = 'FREE (In-Store Pickup)';
        } else if (isFreeShipping) {
            shippingEl.innerHTML = '<span class="status-badge status--completed">FREE (Voucher)</span>';
        } else if (!selectedAddress) {
            shippingEl.innerHTML = '<span class="status-badge status--pending">Add Address</span>';
        } else {
            shippingEl.innerHTML = `&#8369;${selectedShippingCost.toLocaleString()}`;
        }
    }
    if (totalEl) totalEl.innerHTML = `&#8369;${total.toLocaleString()}`;
}

function renderSelectedAddressCard() {
    const nameEl = document.getElementById('checkout-card-name');
    const phoneEl = document.getElementById('checkout-card-phone');
    const addressEl = document.getElementById('checkout-card-address');
    const cardEl = document.getElementById('checkout-address-component') || document.getElementById('checkoutAddressComponent');
    const user = ApiClient.getCurrentUser();

    if (selectedAddress) {
        cardEl?.classList.remove('is-empty');
        const name = selectedAddress.recipientName || user?.fullName || 'Valued Customer';
        const phone = selectedAddress.phoneNumber ? `(${selectedAddress.phoneNumber})` : (user?.phoneNumber ? `(${user.phoneNumber})` : '');
        if (nameEl) nameEl.textContent = name;
        if (phoneEl) phoneEl.textContent = phone;

        const line1 = selectedAddress.streetAddress || '';
        const line2Parts = [
            selectedAddress.barangay ? `Brgy. ${selectedAddress.barangay}` : '',
            selectedAddress.deliveryLandmark ? `Near ${selectedAddress.deliveryLandmark}` : ''
        ].filter(Boolean).join(', ');
        const line3Parts = [
            selectedAddress.city,
            selectedAddress.province,
            selectedAddress.postalCode ? selectedAddress.postalCode : '',
            'Philippines'
        ].filter(Boolean).join(', ');

        const lines = [line1, line2Parts, line3Parts].filter(Boolean).join('<br />');
        if (addressEl) addressEl.innerHTML = lines;
    } else {
        cardEl?.classList.add('is-empty');
        if (nameEl) nameEl.textContent = 'Add Delivery Address & Recipient Details';
        if (phoneEl) phoneEl.textContent = '';
        if (addressEl) addressEl.textContent = 'No delivery address found. Click here to add an address with recipient contact info in your profile.';
    }
}

function updateDynamicShippingFee() {
    const cardDeliveryPriceEl = document.getElementById('card-delivery-price-text');
    if (selectedFulfillment === 'pickup') {
        selectedShippingCost = 0;
        if (cardDeliveryPriceEl) cardDeliveryPriceEl.innerHTML = 'FREE';
    } else if (!selectedAddress) {
        selectedShippingCost = 0;
        if (cardDeliveryPriceEl) cardDeliveryPriceEl.innerHTML = '<span class="status-badge status--pending">Add Address</span>';
    } else {
        const city = selectedAddress?.city || '';
        const prov = selectedAddress?.province || '';
        const details = computeShippingDetails(city, prov);
        selectedShippingCost = details.fee;

        if (cardDeliveryPriceEl) cardDeliveryPriceEl.innerHTML = `&#8369;${details.fee.toLocaleString()}`;
    }
    renderSidebar();
}

async function loadSavedAddresses() {
    if (!ApiClient.isAuthenticated()) {
        renderSelectedAddressCard();
        return;
    }

    try {
        const response = await ApiClient.getUserAddresses();
        const addresses = response?.data || response || [];
        savedAddressesList = Array.isArray(addresses) ? addresses : [];

        const draft = getStoredCheckoutState();
        const targetAddressId = draft?.selectedAddressId;

        if (savedAddressesList.length > 0) {
            if (targetAddressId) {
                selectedAddress = savedAddressesList.find(a => a.id === targetAddressId)
                               || savedAddressesList.find(a => a.isDefault)
                               || savedAddressesList[0];
            } else {
                selectedAddress = savedAddressesList.find(a => a.isDefault) || savedAddressesList[0];
            }
        } else {
            selectedAddress = null;
        }
        renderSelectedAddressCard();
        updateDynamicShippingFee();

        // If user was previously on step 2 or 3 on refresh, safely restore step
        if (draft && draft.step > 1 && draft.step <= 3) {
            if (draft.step === 2 && validateStep1()) {
                setStep(2);
            } else if (draft.step === 3 && validateStep1()) {
                setStep(3);
            }
        }
    } catch (err) {
        console.warn('[Checkout] Unable to load saved addresses:', err);
        renderSelectedAddressCard();
    }
}

function renderReviewItems() {
    const items = getCheckoutItems();
    const container = document.getElementById('review-items-list');
    if (container) {
        container.innerHTML = items.map(item => `
            <div class="review-item-row">
                <img src="${escapeHtml(item.imageUrl)}" alt="${escapeHtml(item.name)}" class="review-item-img" />
                <div class="review-item-info">
                    <h4 class="review-item-name">${escapeHtml(item.name)}</h4>
                    <div class="review-item-meta">${escapeHtml(item.size)} &bull; ${escapeHtml(item.color)} &bull; Qty: ${Number(item.quantity)}</div>
                </div>
                <div class="review-item-price">&#8369;${(Number(item.price) * Number(item.quantity)).toLocaleString()}</div>
            </div>
        `).join('');
    }
}

// Inline Field Error Management
function setFieldError(fieldId, errorMsg) {
    const errSpan = document.getElementById(`err-${fieldId}`);
    if (errSpan) {
        errSpan.textContent = errorMsg || '';
        errSpan.classList.toggle('has-error', !!errorMsg);
    }
}

function validateStep1() {
    let isValid = true;
    setFieldError('checkout-address', '');

    if (selectedFulfillment === 'delivery') {
        if (!selectedAddress || !selectedAddress.streetAddress || !selectedAddress.city || !selectedAddress.province || !selectedAddress.recipientName || !selectedAddress.phoneNumber) {
            setFieldError('checkout-address', 'Please select or add a delivery address with recipient name and phone in your profile.');
            isValid = false;
        }
    }

    return isValid;
}

// Fulfillment Selection Toggle (Pickup vs Delivery)
function updateFulfillmentUI() {
    const pickupCard = document.getElementById('option-fulfillment-pickup');
    const deliveryCard = document.getElementById('option-fulfillment-delivery');
    const codCard = document.getElementById('payment-cod-card');
    const cashCard = document.getElementById('payment-cash-card');

    if (selectedFulfillment === 'pickup') {
        pickupCard?.classList.add('is-selected');
        deliveryCard?.classList.remove('is-selected');
        selectedShippingCost = 0;

        // Adjust Payment Options for Pickup
        if (codCard) codCard.classList.add('is-hidden');
        if (cashCard) cashCard.classList.remove('is-hidden');

        if (selectedPaymentKey === 'cod') {
            selectPaymentCard('hitpay');
        } else {
            selectPaymentCard(selectedPaymentKey);
        }
    } else {
        pickupCard?.classList.remove('is-selected');
        deliveryCard?.classList.add('is-selected');

        updateDynamicShippingFee();

        // Adjust Payment Options for Delivery
        if (cashCard) cashCard.classList.add('is-hidden');
        if (codCard) codCard.classList.remove('is-hidden');

        if (selectedPaymentKey === 'cash') {
            selectPaymentCard('cod');
        } else {
            selectPaymentCard(selectedPaymentKey);
        }
    }

    renderSidebar();
    saveCheckoutState();
}

function selectPaymentCard(paymentKey) {
    document.querySelectorAll('.payment-method-card').forEach(c => c.classList.remove('is-selected'));
    const target = document.querySelector(`.payment-method-card[data-payment="${paymentKey}"]`);
    if (target) {
        target.classList.add('is-selected');
        selectedPaymentKey = paymentKey;
        selectedPaymentMethodName = target.querySelector('.shipping-card__title')?.textContent || 'Online Payment';
        saveCheckoutState();
    }
}

function setStep(step) {
    currentStep = step;
    saveCheckoutState();

    for (let i = 1; i <= 3; i++) {
        const node = document.getElementById(`step-node-${i}`);
        const circle = document.getElementById(`step-circle-${i}`);
        if (!node) continue;

        if (i < step) {
            node.className = 'step-node is-complete is-clickable';
            circle.innerHTML = `
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                    <polyline points="20 6 9 17 4 12"></polyline>
                </svg>
            `;
        } else if (i === step) {
            node.className = 'step-node is-active';
            circle.textContent = i;
        } else {
            node.className = 'step-node';
            circle.textContent = i;
        }
    }

    document.getElementById('step-connector-1')?.classList.toggle('is-filled', step >= 2);
    document.getElementById('step-connector-2')?.classList.toggle('is-filled', step >= 3);

    document.getElementById('panel-step-1')?.classList.toggle('is-active', step === 1);
    document.getElementById('panel-step-2')?.classList.toggle('is-active', step === 2);
    document.getElementById('panel-step-3')?.classList.toggle('is-active', step === 3);

    if (step === 3) {
        renderReviewItems();
    }

    window.scrollTo({ top: 120, behavior: 'smooth' });
}

function escapeHtml(str) {
    if (!str) return '';
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

// Bind interactive event listeners
function bindCheckoutEvents() {
    document.getElementById('checkout-voucher-apply')?.addEventListener('click', () => { if (!placingOrder) validateVoucher(); });
    document.getElementById('checkout-voucher-remove')?.addEventListener('click', removeVoucher);
    document.getElementById('checkout-voucher')?.addEventListener('blur', () => { if (!placingOrder) validateVoucher(); });
    document.getElementById('checkout-voucher')?.addEventListener('input', () => {
        ++voucherSequence; appliedVoucher = null; voucherPending = false; voucherError(''); renderSidebar();
    });
    document.getElementById('checkout-voucher')?.addEventListener('keydown', event => {
        if (event.key === 'Enter') { event.preventDefault(); if (!placingOrder) validateVoucher(); }
    });
    document.getElementById('checkout-print-receipt')?.addEventListener('click', () => printReceipt(document.getElementById('checkout-receipt-doc')));
    document.getElementById('btn-toggle-receipt')?.addEventListener('click', () => {
        const doc = document.getElementById('checkout-receipt-doc');
        const btn = document.getElementById('btn-toggle-receipt');
        const label = document.getElementById('btn-toggle-receipt-text');
        if (!doc || !btn) return;
        const isCollapsed = doc.classList.contains('is-collapsed');
        if (isCollapsed) {
            doc.classList.remove('is-collapsed');
            btn.classList.add('is-expanded');
            btn.setAttribute('aria-expanded', 'true');
            if (label) label.textContent = 'Collapse Receipt';
        } else {
            doc.classList.add('is-collapsed');
            btn.classList.remove('is-expanded');
            btn.setAttribute('aria-expanded', 'false');
            if (label) label.textContent = 'View Full Receipt';
        }
    });
    window.addEventListener('cartUpdated', () => { if (!checkoutComplete) { renderSidebar(); renderReviewItems(); } });
    window.addEventListener(APP_CONSTANTS.SIGNALR_EVENTS.STOCK_UPDATED, () => { if (!checkoutComplete && appliedVoucher) validateVoucher(); });
    document.getElementById('option-fulfillment-pickup')?.addEventListener('click', () => {
        selectedFulfillment = 'pickup';
        updateFulfillmentUI();
    });

    document.getElementById('option-fulfillment-delivery')?.addEventListener('click', () => {
        selectedFulfillment = 'delivery';
        updateFulfillmentUI();
    });

    document.querySelectorAll('.step-node').forEach(node => {
        node.addEventListener('click', () => {
            const step = parseInt(node.getAttribute('data-step'), 10);
            if (step < currentStep) {
                setStep(step);
            }
        });
    });

    document.getElementById('btn-goto-step-2')?.addEventListener('click', () => {
        if (!validateStep1()) {
            RealtimeManager.showToast('Please configure your delivery address before proceeding.', 'alert');
            return;
        }

        setStep(2);
    });

    document.querySelectorAll('.payment-method-card').forEach(card => {
        card.addEventListener('click', () => {
            const key = card.getAttribute('data-payment');
            if (key) selectPaymentCard(key);
        });
    });

    document.getElementById('chk-agree-terms')?.addEventListener('change', (event) => {
        if (event.target.checked) {
            event.target.classList.remove('is-invalid');
            const error = document.getElementById('checkout-order-error');
            if (error) error.textContent = '';
        }
        saveCheckoutState();
    });

    document.getElementById('btn-back-to-step-1')?.addEventListener('click', () => setStep(1));
    document.getElementById('btn-goto-step-3')?.addEventListener('click', () => {
        setStep(3);
    });

    document.getElementById('btn-back-to-step-2')?.addEventListener('click', () => setStep(2));

    // Place Order via live C# Web API (POST /api/v1/orders)
    document.getElementById('btn-place-order')?.addEventListener('click', async () => {
        const orderError = document.getElementById('checkout-order-error');
        if (orderError) orderError.textContent = '';
        if (!validateStep1()) { setStep(1); document.getElementById('checkout-address')?.focus(); return; }
        const termsCheckbox = document.getElementById('chk-agree-terms');
        const agreed = termsCheckbox ? termsCheckbox.checked : false;
        if (!agreed) {
            if (orderError) orderError.textContent = 'Agree to the Terms of Sale before placing your order.';
            termsCheckbox?.classList.add('is-invalid');
            termsCheckbox?.focus();
            RealtimeManager.showToast('Please agree to the Terms of Sale to proceed.', 'alert');
            return;
        }

        if (placingOrder) return;
        placingOrder = true;
        if (!await validateVoucher()) { placingOrder = false; document.getElementById('checkout-voucher')?.focus(); renderSidebar(); return; }
        document.getElementById('checkout-voucher').disabled = true;
        document.getElementById('checkout-voucher-remove').disabled = true;
        const btn = document.getElementById('btn-place-order');
        const textSpan = document.getElementById('btn-place-order-text');
        btn?.classList.add('btn--loading');
        btn?.classList.add('btn--disabled');
        if (btn) btn.disabled = true;
        if (textSpan) textSpan.textContent = "Processing Transaction...";

        const checkoutItems = getCheckoutItems();
        if (!checkoutItems.length || checkoutItems.some(item =>
            !Number.isSafeInteger(Number(item.variantId)) || Number(item.variantId) <= 0 ||
            Number(item.availableStock) < Number(item.quantity))) {
            placingOrder = false;
            document.getElementById('checkout-voucher').disabled = false;
            document.getElementById('checkout-voucher-remove').disabled = false;
            RealtimeManager.showToast('Review your cart: an item is unavailable or needs to be added again.', 'alert');
            btn?.classList.remove('btn--loading');
            btn?.classList.remove('btn--disabled');
            if (btn) btn.disabled = false;
            if (textSpan) textSpan.textContent = 'Place Order & Pay';
            renderSidebar();
            return;
        }

        const user = ApiClient.getCurrentUser();
        const customerName = selectedAddress?.recipientName || user?.fullName || 'Valued Customer';
        const email = user?.email || 'customer@helmetcartel.com';
        const phone = selectedAddress?.phoneNumber || user?.phoneNumber || '+63 917 123 4567';

        let paymentGateway = 'HitPay';
        if (selectedPaymentKey === 'cod') paymentGateway = 'CashOnDelivery';
        else if (selectedPaymentKey === 'cash' || selectedPaymentKey === 'bank') paymentGateway = 'Cash';

        const isDelivery = selectedFulfillment === 'delivery';
        const city = isDelivery ? (selectedAddress?.city || null) : null;
        const prov = isDelivery ? (selectedAddress?.province || null) : null;
        const shippingDetails = isDelivery ? computeShippingDetails(city, prov) : null;
        const regionName = isDelivery ? shippingDetails.region : null;
        const addr = isDelivery ? (selectedAddress?.streetAddress || null) : null;
        const brgy = isDelivery ? (selectedAddress?.barangay || null) : null;
        const zip = isDelivery ? (selectedAddress?.postalCode || null) : null;
        const notes = isDelivery ? (selectedAddress?.deliveryLandmark || null) : null;

        const { isFreeShipping, effectiveShipping } = calculateTotals();

        const payload = {
            customerName: customerName,
            customerEmail: email,
            customerPhone: phone,
            paymentMethod: paymentGateway,
            shippingMethod: isDelivery ? 'Delivery' : 'Pickup',
            shippingFee: isDelivery ? (isFreeShipping ? 0 : selectedShippingCost) : 0,
            shippingRegion: regionName,
            shippingAddress: addr,
            shippingBarangay: brgy,
            shippingCity: city,
            shippingProvince: prov,
            shippingPostalCode: zip,
            deliveryNotes: notes,
            notes: isDelivery ? `Door-to-Door Delivery (${regionName})` : 'Store Pickup at Flagship Hub (QC)',
            voucherCode: appliedVoucher?.code || null,
            items: checkoutItems.map(item => ({
                variantId: Number(item.variantId),
                quantity: Number(item.quantity)
            }))
        };

        try {
            const response = await ApiClient.createOrder(payload);
            const orderData = response?.data || response;
            if (!orderData?.orderNumber) throw new Error('The server did not return an order confirmation.');
            const orderNo = orderData.orderNumber;
            const totalPaid = Number(orderData.totalAmount);

            // Clear saved draft state upon successful order placement
            clearCheckoutState();

            const completeOrderDisplay = async () => {
                if (checkoutComplete) return;
                checkoutComplete = true;
                if (isBuyNowMode) {
                    clearBuyNowItem();
                    // Preserves cart items, but re-evaluates their stock from the server in case this buy-now depleted it
                    CartManager.refreshItems().catch(() => {});
                } else {
                    // Clear selected checked-out items from cart
                    const allItems = CartManager.getItems();
                    const remaining = allItems.filter(item => !checkoutItems.some(c => Number(c.variantId) === Number(item.variantId)));
                    try { await CartManager.saveItems(remaining); }
                    catch (error) { RealtimeManager.showToast(`Order saved, but cart cleanup failed: ${error.message}`, 'alert'); }
                    CartManager.updateCartBadge();
                }

                // Load persisted payment data after simulation; order creation already returns saved totals.
                let receiptOrder = orderData;
                try { receiptOrder = await ApiClient.getUserOrderDetails(orderData.id); }
                catch (error) { console.warn('Receipt refresh unavailable:', error.message); }
                document.getElementById('checkout-receipt-doc').innerHTML = renderReceipt(receiptOrder);
                document.getElementById('tracker-step-3-text').textContent = isDelivery ? 'In Transit / Dispatched' : 'Ready for Pickup';
                document.getElementById('tracker-step-4-text').textContent = isDelivery ? 'Delivered' : 'Collected';

                const stepperEl = document.getElementById('checkout-stepper');
                const gridEl = document.getElementById('checkout-interactive-grid');
                const successPanel = document.getElementById('checkout-success-panel');

                stepperEl?.classList.add('is-hidden');
                gridEl?.classList.add('is-hidden');
                if (stepperEl) stepperEl.hidden = true;
                if (gridEl) gridEl.hidden = true;
                if (successPanel) successPanel.classList.add('is-active');
                const confirmationTitle = successPanel?.querySelector('.success-title');
                confirmationTitle?.focus({ preventScroll: true });
                successPanel?.scrollIntoView({ block: 'start', behavior: 'smooth' });
                RealtimeManager.showToast(`Order ${orderNo} confirmed! Inventory reserved.`, 'success');
            };

            // HitPay Online Payment Routing
            if (paymentGateway === 'HitPay') {
                if (orderData?.checkoutUrl) {
                    RealtimeManager.showToast('Opening QRPh payment checkout...', 'info');
                    setTimeout(() => window.location.href = orderData.checkoutUrl, 800);
                    return;
                }

                // Interactive HitPay Simulation Modal
                btn?.classList.remove('btn--loading');
                btn?.classList.remove('btn--disabled');
                if (btn) btn.disabled = false;
                if (textSpan) textSpan.textContent = "Place Order & Pay";

                showSimulationModal(orderNo, totalPaid, async payment => {
                    if (payment) { orderData.paymentStatus = payment.paymentStatus; orderData.status = payment.status; orderData.gatewayReference = payment.paymentId; }
                    await completeOrderDisplay();
                }, async () => {
                    try {
                        await ApiClient.cancelOrder(orderData.id || orderNo, 'Customer cancelled QRPh payment during checkout.');
                    } catch (_) {}
                    RealtimeManager.showToast('Payment was cancelled. Your order was not placed.', 'alert');
                    btn?.classList.remove('btn--loading');
                    btn?.classList.remove('btn--disabled');
                    if (btn) btn.disabled = false;
                    if (textSpan) textSpan.textContent = "Place Order & Pay";
                    placingOrder = false;
                    document.getElementById('checkout-voucher').disabled = false;
                    document.getElementById('checkout-voucher-remove').disabled = false;
                    renderSidebar();
                });
                return;
            }

            // Direct fulfillment simulated processing delay (COD / Bank Transfer / Cash In-Store)
            const delay = ms => new Promise(res => setTimeout(res, ms));
            if (selectedPaymentKey === 'cod') {
                if (textSpan) textSpan.textContent = "Verifying COD booking...";
                await delay(900);
                if (textSpan) textSpan.textContent = "Reserving warehouse inventory...";
                await delay(800);
                if (textSpan) textSpan.textContent = "Order Placed Successfully!";
                await delay(500);
            } else if (selectedPaymentKey === 'bank') {
                if (textSpan) textSpan.textContent = "Logging bank transfer reference...";
                await delay(900);
                if (textSpan) textSpan.textContent = "Reserving inventory allocation...";
                await delay(800);
                if (textSpan) textSpan.textContent = "Transfer Registered Successfully!";
                await delay(500);
            } else {
                if (textSpan) textSpan.textContent = "Reserving in-store pickup item...";
                await delay(900);
                if (textSpan) textSpan.textContent = "Order Placed Successfully!";
                await delay(500);
            }

            await completeOrderDisplay();
        } catch (err) {
            if (orderError) orderError.textContent = err.message || 'Order could not be placed. Review your details and try again.';
            console.error('[Checkout Error]', err);
            if (err.errorCode === APP_CONSTANTS.ERROR_CODES.INVALID_VOUCHER) { appliedVoucher = null; voucherError(err.message); }
            RealtimeManager.showToast(err.message || 'Error processing order. Please check stock.', 'alert');
            btn?.classList.remove('btn--loading');
            btn?.classList.remove('btn--disabled');
            if (btn) btn.disabled = false;
            if (textSpan) textSpan.textContent = "Place Order & Pay";
            placingOrder = false;
            document.getElementById('checkout-voucher').disabled = false;
            document.getElementById('checkout-voucher-remove').disabled = false;
            renderSidebar();
        }
    });
}

/**
 * Handles Interactive QR Ph HitPay Simulation Modal (Minimal Design)
 */
function showSimulationModal(orderNo, totalAmount, onSuccessCallback, onCancelCallback) {
    const modal = document.getElementById('payment-simulation-modal');
    if (!modal) { onSuccessCallback(); return; }
    const amountEl = document.getElementById('sim-order-amount');
    const statusBanner = document.getElementById('sim-status-banner');
    const statusText = document.getElementById('sim-status-banner-text');
    const alertEl = document.getElementById('sim-status-alert');
    const alertMsg = document.getElementById('sim-status-message');
    const closeBtn = document.getElementById('btn-close-sim-modal');
    const cancelBtn = document.getElementById('btn-cancel-sim');
    const successBtn = document.getElementById('btn-success-sim');
    let confirming = false;

    if (amountEl) amountEl.innerHTML = `${APP_CONSTANTS.UI.CURRENCY_SYMBOL_HTML}${Number(totalAmount).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    statusBanner.hidden = true;
    statusText.textContent = '';
    alertEl?.classList.add('is-hidden');
    successBtn.disabled = false;
    successBtn.classList.remove('btn--loading');
    closeBtn.disabled = false;
    if (cancelBtn) cancelBtn.disabled = false;
    modal.classList.remove('is-hidden');

    const handleCancel = async () => {
        if (confirming) return;
        modal.classList.add('is-hidden');
        if (typeof onCancelCallback === 'function') {
            await onCancelCallback();
        }
    };

    closeBtn.onclick = handleCancel;
    if (cancelBtn) cancelBtn.onclick = handleCancel;

    successBtn.onclick = async () => {
        if (confirming) return;
        confirming = true;
        successBtn.disabled = true;
        closeBtn.disabled = true;
        if (cancelBtn) cancelBtn.disabled = true;
        successBtn.classList.add('btn--loading');
        alertEl?.classList.add('is-hidden');
        statusBanner.hidden = false;
        statusBanner.className = 'sim-status-banner is-processing';
        statusText.textContent = 'Connecting to QRPh network...';

        const delay = ms => new Promise(res => setTimeout(res, ms));
        try {
            await delay(900);
            statusText.textContent = 'Verifying payment with InstaPay switch...';

            const payment = await ApiClient.simulatePayment({
                orderNumber: orderNo,
                paymentChannel: APP_CONSTANTS.PAYMENT_CHANNELS.QRPH,
                outcome: 'SUCCESS'
            });
            if (payment?.paymentStatus !== APP_CONSTANTS.PAYMENT_STATUS.COMPLETED) {
                throw new Error('Payment has not been confirmed. Please try again.');
            }

            await delay(800);
            statusBanner.className = 'sim-status-banner is-success';
            statusText.textContent = 'Payment confirmed! Generating receipt...';

            await delay(900);
            modal.classList.add('is-hidden');
            await onSuccessCallback(payment);
        } catch (error) {
            if (alertEl && alertMsg) {
                alertMsg.textContent = error.message || 'Unable to confirm payment. Please try again.';
                alertEl.classList.remove('is-hidden');
            }
            statusBanner.hidden = true;
            successBtn.disabled = false;
            successBtn.classList.remove('btn--loading');
            if (cancelBtn) cancelBtn.disabled = false;
            confirming = false;
        } finally {
            closeBtn.disabled = false;
        }
    };
}

// Adapt UI when checking out a single Buy Now item directly
function adaptBuyNowUi() {
    if (!isBuyNowMode) return;
    const item = getBuyNowItem();
    const productUrl = item?.productId
        ? `/Pages/Storefront/ProductDetail/ProductDetail.aspx?id=${item.productId}`
        : APP_CONSTANTS.ROUTES.SHOP;

    // Adapt Breadcrumb: Home > [Product] > Checkout
    const breadcrumbLink = document.getElementById('breadcrumbCartLink');
    if (breadcrumbLink) {
        breadcrumbLink.href = productUrl;
        breadcrumbLink.textContent = item?.brand ? `${item.brand} Helmet` : 'Product';
        breadcrumbLink.title = 'Back to product details';
    }

    // Adapt Step 1 Back Button: "Back to Product"
    const backBtn = document.getElementById('btnCheckoutBack');
    const backText = document.getElementById('btn-checkout-back-text');
    if (backBtn) backBtn.href = productUrl;
    if (backText) backText.textContent = 'Back to Product';

    // Adapt Step 3 Review Header Edit Link: "Change Options"
    const editLink = document.getElementById('linkReviewEdit');
    if (editLink) {
        editLink.href = productUrl;
        editLink.textContent = 'Change Options';
        editLink.title = 'Change size, color, or quantity on product page';
    }
}

// Refresh Single Buy Now Item from server to confirm current stock and price
async function refreshBuyNowItem() {
    const item = getBuyNowItem();
    if (!item || !Number.isSafeInteger(Number(item.productId))) return item;
    try {
        const product = await ApiClient.getProductById(item.productId);
        if (!product) return item;
        const variant = product.variants?.find(v => Number(v.id) === Number(item.variantId));
        if (!variant) {
            item.availableStock = 0;
            saveBuyNowItem(item);
            return item;
        }
        const base = Number(product.basePrice) + Number(variant.priceAdjustment || 0);
        item.name = product.name;
        item.brand = product.brand;
        item.imageUrl = product.mainImageUrl;
        item.price = Math.round(base * (1 - Number(product.discountPercentage || 0) / 100) * 100) / 100;
        item.availableStock = Number(variant.availableStock ?? variant.currentStock ?? 0);
        saveBuyNowItem(item);
        return item;
    } catch {
        return item;
    }
}

// Authentication Check on Page Load
function initAuthCheck() {
    if (!ApiClient.isAuthenticated()) {
        const returnUrl = isBuyNowMode ? `${APP_CONSTANTS.ROUTES.CHECKOUT}?mode=buynow` : APP_CONSTANTS.ROUTES.CHECKOUT;
        window.showAuthPromptModal?.({
            title: 'Sign In Required for Checkout',
            message: 'You need an active Helmet Cartel account to checkout. Would you like to sign in or return to shopping?',
            returnUrl: returnUrl
        });
        document.getElementById('auth-modal-cancel-btn')?.addEventListener('click', () => {
            const item = getBuyNowItem();
            window.location.href = isBuyNowMode && item?.productId
                ? `/Pages/Storefront/ProductDetail/ProductDetail.aspx?id=${item.productId}`
                : APP_CONSTANTS.ROUTES.SHOP;
        });
    }
}

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    initAuthCheck();
    const checkoutUrl = window.location.pathname + window.location.search;
    sessionStorage.setItem('hc_checkout_return_url', checkoutUrl);
    const addressLink = document.getElementById('checkoutAddressComponent') || document.getElementById('checkout-address-component');
    if (addressLink) {
        addressLink.href = `/Pages/Storefront/Profile/Profile.aspx?tab=addresses&returnUrl=${encodeURIComponent(checkoutUrl)}`;
        addressLink.addEventListener('click', () => {
            sessionStorage.setItem('hc_checkout_return_url', checkoutUrl);
        });
    }

    bindCheckoutEvents();
    adaptBuyNowUi();
    loadSavedAddresses();
    updateFulfillmentUI();
    renderSidebar();

    if (isBuyNowMode) {
        refreshBuyNowItem().then(() => {
            adaptBuyNowUi();
            renderSidebar();
            renderReviewItems();
        }).catch(() => {
            renderSidebar();
            renderReviewItems();
        });
    } else {
        CartManager.refreshItems().then(() => {
            shoppingReady = true;
            renderSidebar();
            renderReviewItems();
        }).catch(error => { RealtimeManager.showToast(`Could not load cart: ${error.message}`, 'alert'); });
    }
});
