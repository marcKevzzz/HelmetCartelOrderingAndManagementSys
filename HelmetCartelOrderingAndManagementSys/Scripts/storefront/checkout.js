/**
 * HELMET CARTEL - STOREFRONT CHECKOUT CONTROLLER (checkout.js)
 * Manages multi-step checkout workflow, shipping calculations, state restoration,
 * address selection, payment options, and live order submission.
 */

import { ApiClient } from '../api.js';
import { CartManager } from '../cart.js';
import { RealtimeManager } from '../realtime.js';
import { APP_CONSTANTS } from '../constants.js';

const CHECKOUT_STATE_KEY = 'hc_checkout_state';

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
let selectedPaymentMethodName = "HitPay Online Checkout (GCash / Maya / QR PH)";
let selectedPaymentKey = initialDraft?.paymentKey || "hitpay";
let savedAddressesList = [];
let selectedAddress = null;

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
        return { fee: 150, region: 'Metro Manila (NCR)', eta: '1\u20132 Business Days' };
    }

    const ncrCities = [
        'manila', 'quezon city', 'qc', 'caloocan', 'las pinas', 'las pi\u00F1as',
        'makati', 'malabon', 'mandaluyong', 'marikina', 'muntinlupa', 'navotas',
        'paranaque', 'para\u00F1aque', 'pasay', 'pasig', 'san juan', 'taguig',
        'valenzuela', 'pateros'
    ];
    const isNcr = ncrCities.some(c => city.includes(c)) ||
                  prov.includes('metro manila') || prov.includes('ncr');
    if (isNcr) {
        return { fee: 150, region: 'Metro Manila (NCR)', eta: '1\u20132 Business Days' };
    }

    const gmaProvinces = ['cavite', 'laguna', 'batangas', 'rizal', 'bulacan'];
    const isGma = gmaProvinces.some(p => prov.includes(p) || city.includes(p));
    if (isGma) {
        return { fee: 250, region: 'Greater Manila Area', eta: '2\u20133 Business Days' };
    }

    const luzonProvinces = [
        'pampanga', 'nueva ecija', 'tarlac', 'zambales', 'bataan', 'pangasinan',
        'ilocos', 'la union', 'benguet', 'baguio', 'cagayan', 'isabela',
        'nueva vizcaya', 'quirino', 'aurora', 'quezon', 'albay', 'camarines',
        'sorsogon', 'catanduanes', 'masbate', 'marinduque', 'occidental mindoro',
        'oriental mindoro', 'palawan', 'romblon', 'abra', 'apayao', 'ifugao',
        'kalinga', 'mountain province'
    ];
    const isLuzon = luzonProvinces.some(p => prov.includes(p) || city.includes(p));
    if (isLuzon) {
        return { fee: 350, region: 'Rest of Luzon', eta: '3\u20135 Business Days' };
    }

    const visayasProvinces = [
        'cebu', 'bohol', 'iloilo', 'negros', 'leyte', 'samar', 'panay',
        'capiz', 'aklan', 'boracay', 'antique', 'guimaras', 'biliran', 'siquijor'
    ];
    const isVisayas = visayasProvinces.some(p => prov.includes(p) || city.includes(p));
    if (isVisayas) {
        return { fee: 450, region: 'Visayas', eta: '5\u20137 Business Days' };
    }

    const mindanaoProvinces = [
        'davao', 'cagayan de oro', 'cdo', 'misamis', 'bukidnon', 'general santos',
        'gensan', 'south cotabato', 'cotabato', 'zamboanga', 'iligan', 'lanaw',
        'lanao', 'agusan', 'surigao', 'sultan kudarat', 'sarangani', 'basilan',
        'sulu', 'tawi-tawi', 'maguindanao'
    ];
    const isMindanao = mindanaoProvinces.some(p => prov.includes(p) || city.includes(p));
    if (isMindanao) {
        return { fee: 500, region: 'Mindanao', eta: '5\u20138 Business Days' };
    }

    return { fee: 175, region: 'Standard Nationwide Delivery', eta: '3\u20136 Business Days' };
}

// Determine Checkout Items
function getCheckoutItems() {
    return CartManager.getSelectedItems();
}

function calculateTotals() {
    const items = getCheckoutItems();
    const subtotal = items.reduce((sum, i) => sum + (i.price * i.quantity), 0);
    const total = subtotal + selectedShippingCost;

    return { subtotal, total };
}

function renderSidebar() {
    const items = getCheckoutItems();
    if (items.length === 0 && currentStep < 4) {
        RealtimeManager.showToast('Your cart is empty. Redirecting to Shop...', 'alert');
        setTimeout(() => window.location.href = APP_CONSTANTS.ROUTES.SHOP, 1500);
        return;
    }

    const { subtotal, total } = calculateTotals();

    const subtotalEl = document.getElementById('sidebar-subtotal');
    const shippingEl = document.getElementById('sidebar-shipping');
    const totalEl = document.getElementById('sidebar-total');

    if (subtotalEl) subtotalEl.innerHTML = `&#8369;${subtotal.toLocaleString()}`;
    if (shippingEl) {
        if (selectedFulfillment === 'pickup') {
            shippingEl.innerHTML = 'FREE (In-Store Pickup)';
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
    if (selectedFulfillment === 'pickup') {
        selectedShippingCost = 0;
    } else {
        const city = selectedAddress?.city || '';
        const prov = selectedAddress?.province || '';
        const details = computeShippingDetails(city, prov);
        selectedShippingCost = details.fee;

        const cardDeliveryPriceEl = document.getElementById('card-delivery-price-text');
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
        if (!selectedAddress || !selectedAddress.streetAddress || !selectedAddress.city) {
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
        RealtimeManager.showToast('Customer & fulfillment details confirmed. Select payment method.', 'info');
    });

    document.querySelectorAll('.payment-method-card').forEach(card => {
        card.addEventListener('click', () => {
            const key = card.getAttribute('data-payment');
            if (key) selectPaymentCard(key);
        });
    });

    document.getElementById('chk-agree-terms')?.addEventListener('change', () => {
        saveCheckoutState();
    });

    document.getElementById('btn-back-to-step-1')?.addEventListener('click', () => setStep(1));
    document.getElementById('btn-goto-step-3')?.addEventListener('click', () => {
        setStep(3);
        RealtimeManager.showToast('Review your order before final confirmation.', 'info');
    });

    document.getElementById('btn-back-to-step-2')?.addEventListener('click', () => setStep(2));

    // Place Order via live C# Web API (POST /api/v1/orders)
    document.getElementById('btn-place-order')?.addEventListener('click', async () => {
        const termsCheckbox = document.getElementById('chk-agree-terms');
        const agreed = termsCheckbox ? termsCheckbox.checked : false;
        if (!agreed) {
            RealtimeManager.showToast('Please agree to the Terms of Sale to proceed.', 'alert');
            return;
        }

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
            RealtimeManager.showToast('Review your cart: an item is unavailable or needs to be added again.', 'alert');
            btn?.classList.remove('btn--loading');
            btn?.classList.remove('btn--disabled');
            if (btn) btn.disabled = false;
            if (textSpan) textSpan.textContent = 'Place Order & Pay';
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

        const payload = {
            customerName: customerName,
            customerEmail: email,
            customerPhone: phone,
            paymentMethod: paymentGateway,
            shippingMethod: isDelivery ? 'Delivery' : 'Pickup',
            shippingFee: isDelivery ? selectedShippingCost : 0,
            shippingRegion: regionName,
            shippingAddress: addr,
            shippingBarangay: brgy,
            shippingCity: city,
            shippingProvince: prov,
            shippingPostalCode: zip,
            deliveryNotes: notes,
            notes: isDelivery ? `Door-to-Door Delivery (${regionName})` : 'Store Pickup at Flagship Hub (QC)',
            items: checkoutItems.map(item => ({
                variantId: Number(item.variantId),
                quantity: Number(item.quantity)
            }))
        };

        try {
            const response = await ApiClient.createOrder(payload);
            const orderData = response?.data || response;
            const orderNo = orderData?.orderNumber || `#HC-${new Date().getFullYear()}-${Math.floor(10000 + Math.random() * 90000)}`;
            const totalPaid = orderData?.totalAmount || calculateTotals().total;

            // Clear saved draft state upon successful order placement
            clearCheckoutState();

            // Clear selected items from cart
            const allItems = CartManager.getItems();
            const remaining = allItems.filter(item => !checkoutItems.some(c => c.variantId === item.variantId));
            CartManager.saveItems(remaining);
            CartManager.updateCartBadge();

            // Populate Receipt Card
            const receiptOrderNo = document.getElementById('receipt-order-no');
            const receiptDate = document.getElementById('receipt-date');
            const receiptPayment = document.getElementById('receipt-payment');
            const receiptTotal = document.getElementById('receipt-total');

            if (receiptOrderNo) receiptOrderNo.textContent = orderNo;
            if (receiptDate) {
                receiptDate.textContent = new Date().toLocaleDateString('en-US', {
                    month: 'long',
                    day: 'numeric',
                    year: 'numeric'
                }) + ' - ' + new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
            }
            if (receiptPayment) receiptPayment.textContent = selectedPaymentMethodName;
            if (receiptTotal) receiptTotal.innerHTML = `&#8369;${totalPaid.toLocaleString()}`;

            const addrLabel = document.getElementById('receipt-address-label');
            const addrVal = document.getElementById('receipt-address');
            const etaVal = document.getElementById('receipt-eta');
            const step3Text = document.getElementById('tracker-step-3-text');
            const step4Text = document.getElementById('tracker-step-4-text');

            if (isDelivery) {
                if (addrLabel) addrLabel.textContent = 'Delivery Address';
                if (addrVal) addrVal.textContent = `${addr || ''}${brgy ? `, Brgy. ${brgy}` : ''}, ${city || ''}, ${prov || ''} ${zip || ''}`;
                if (etaVal) etaVal.textContent = `Dispatched via Courier (Est. ${shippingDetails?.eta || '2\u20134 Days'})`;

                if (step3Text) step3Text.textContent = 'In Transit / Dispatched';
                if (step4Text) step4Text.textContent = 'Delivered';
            } else {
                if (addrLabel) addrLabel.textContent = 'Pickup Location';
                if (addrVal) addrVal.textContent = 'Helmet Cartel Flagship Hub \u2022 128 Commonwealth Ave, QC';
                if (etaVal) etaVal.textContent = 'Ready for Store Pickup in 1-2 Hours';

                if (step3Text) step3Text.textContent = 'Ready for Pickup';
                if (step4Text) step4Text.textContent = 'Collected';
            }

            if (paymentGateway === 'HitPay' && orderData?.checkoutUrl) {
                RealtimeManager.showToast('Redirecting to HitPay secure checkout...', 'info');
                setTimeout(() => window.location.href = orderData.checkoutUrl, 800);
                return;
            }

            const stepperEl = document.getElementById('checkout-stepper');
            const gridEl = document.getElementById('checkout-interactive-grid');
            const successPanel = document.getElementById('checkout-success-panel');

            if (stepperEl) stepperEl.style.display = 'none';
            if (gridEl) gridEl.style.display = 'none';
            if (successPanel) successPanel.classList.add('is-active');

            window.scrollTo({ top: 100, behavior: 'smooth' });
            RealtimeManager.showToast(`Order ${orderNo} confirmed! Inventory reserved.`, 'success');
        } catch (err) {
            console.error('[Checkout Error]', err);
            RealtimeManager.showToast(err.message || 'Error processing order. Please check stock.', 'alert');
            btn?.classList.remove('btn--loading');
            btn?.classList.remove('btn--disabled');
            if (btn) btn.disabled = false;
            if (textSpan) textSpan.textContent = "Place Order & Pay";
        }
    });
}

// Authentication Check on Page Load
function initAuthCheck() {
    if (!ApiClient.isAuthenticated()) {
        window.showAuthPromptModal?.({
            title: 'Sign In Required for Checkout',
            message: 'You need an active Helmet Cartel account to checkout. Would you like to sign in or return to shopping?',
            returnUrl: APP_CONSTANTS.ROUTES.CHECKOUT
        });
        document.getElementById('auth-modal-cancel-btn')?.addEventListener('click', () => {
            window.location.href = APP_CONSTANTS.ROUTES.SHOP;
        });
    }
}

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    initAuthCheck();
    bindCheckoutEvents();
    loadSavedAddresses();
    updateFulfillmentUI();
    renderSidebar();
    CartManager.refreshItems().then(() => {
        renderSidebar();
        renderReviewItems();
    }).catch(() => {});
});
