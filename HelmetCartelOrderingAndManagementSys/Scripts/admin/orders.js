/**
 * HELMET CARTEL - ADMIN ORDERS MANAGEMENT CONTROLLER (orders.js)
 * Handles dispatch modal interactions, tracking number verification, and courier dispatch APIs.
 */

function openDispatchModal(orderId, orderNo, customerName, city) {
    const orderIdInput = document.getElementById('dispatchOrderId');
    const summaryText = document.getElementById('dispatchOrderSummaryText');
    const trackingInput = document.getElementById('dispatchTrackingNumber');
    const notesInput = document.getElementById('dispatchNotes');
    const errSpan = document.getElementById('err-dispatch-tracking');
    const modalBackdrop = document.getElementById('dispatchModalBackdrop');

    if (orderIdInput) orderIdInput.value = orderId;
    if (summaryText) summaryText.textContent = `Order: ${orderNo} \u2022 Customer: ${customerName} \u2022 Destination: ${city}`;
    if (trackingInput) trackingInput.value = '';
    if (notesInput) notesInput.value = '';
    if (errSpan) {
        errSpan.textContent = '';
        errSpan.style.display = 'none';
    }
    if (modalBackdrop) modalBackdrop.style.display = 'flex';
}

function closeDispatchModal() {
    const modalBackdrop = document.getElementById('dispatchModalBackdrop');
    if (modalBackdrop) modalBackdrop.style.display = 'none';
}

async function confirmDispatch() {
    const orderIdEl = document.getElementById('dispatchOrderId');
    const courierEl = document.getElementById('dispatchCourier');
    const trackingEl = document.getElementById('dispatchTrackingNumber');
    const notesEl = document.getElementById('dispatchNotes');

    const orderId = orderIdEl ? orderIdEl.value : '';
    const courier = courierEl ? courierEl.value : 'J&T Express';
    const tracking = trackingEl ? trackingEl.value.trim() : '';
    const notes = notesEl ? notesEl.value.trim() : '';

    if (!tracking) {
        const errSpan = document.getElementById('err-dispatch-tracking');
        if (errSpan) {
            errSpan.textContent = 'Waybill or tracking number is required.';
            errSpan.style.display = 'block';
        }
        trackingEl?.focus();
        return;
    }

    const btn = document.getElementById('btnConfirmDispatch');
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<span>Dispatching...</span>';
    }

    try {
        const token = localStorage.getItem('hc_auth_token') || sessionStorage.getItem('hc_auth_token');
        const headers = { 'Content-Type': 'application/json' };
        if (token) headers['Authorization'] = 'Bearer ' + token;

        const response = await fetch(`/api/v1/admin/orders/${orderId}/dispatch`, {
            method: 'POST',
            headers: headers,
            body: JSON.stringify({ courier: courier, trackingNumber: tracking, notes: notes })
        });

        if (!response.ok) {
            const errData = await response.json().catch(() => ({}));
            throw new Error(errData.message || 'Failed to dispatch order.');
        }

        closeDispatchModal();
        if (window.AdminToast) {
            AdminToast.show(`Order dispatched via ${courier} (${tracking})`, 'success');
        } else if (typeof window.showAdminToast === 'function') {
            window.showAdminToast(`Order dispatched via ${courier} (${tracking})`, 'success');
        }
        setTimeout(() => window.location.reload(), 600);
    } catch (err) {
        alert(err.message || 'Dispatch error');
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = '<span>Confirm Dispatch</span>';
        }
    }
}

// Expose functions globally for ASPX onclick bindings
window.openDispatchModal = openDispatchModal;
window.closeDispatchModal = closeDispatchModal;
window.confirmDispatch = confirmDispatch;
