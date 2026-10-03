/**
 * HELMET CARTEL - ADMIN INVENTORY MANAGEMENT CONTROLLER (inventory.js)
 * Manages modal stock adjustments, validation, and submission state protection.
 */

window.isStockAdjustSubmitting = false;

function handleStockAdjustSubmit(btn) {
    if (window.isStockAdjustSubmitting) {
        return false;
    }
    const txtQty = document.querySelector('[id$="txtAdjustQuantity"]') || document.getElementById('txtAdjustQuantity');
    const qty = parseInt(txtQty ? txtQty.value : '0', 10);
    if (!qty || qty <= 0) {
        if (typeof window.showAdminToast === 'function') {
            window.showAdminToast('Please specify a positive unit quantity to add.', 'warning', 'Invalid Quantity');
        } else if (window.AdminToast) {
            window.AdminToast.show('Please specify a positive unit quantity to add.', 'warning');
        } else {
            alert('Please specify a positive unit quantity to add.');
        }
        return false;
    }
    window.isStockAdjustSubmitting = true;
    if (btn) {
        btn.style.pointerEvents = 'none';
        btn.style.opacity = '0.65';
        if (btn.tagName === 'INPUT') {
            btn.value = 'Adding Stock...';
        } else {
            btn.textContent = 'Adding Stock...';
        }
    }
    return true;
}

window.handleStockAdjustSubmit = handleStockAdjustSubmit;

/**
 * Single-click Variant Active / Inactive Toggle Handler
 */
document.addEventListener('DOMContentLoaded', () => {
    initVariantActiveToggle();
});

function initVariantActiveToggle() {
    document.addEventListener('click', async (e) => {
        const btn = e.target.closest('.js-toggle-inventory-active');
        if (!btn || btn.disabled) return;

        e.preventDefault();
        e.stopPropagation();

        const variantId = parseInt(btn.dataset.variantId, 10);
        if (!variantId) return;

        const isCurrentlyActive = btn.dataset.active === 'true';
        const nextState = !isCurrentlyActive;

        // Optimistic UI update
        btn.disabled = true;
        btn.classList.remove('is-active', 'is-inactive');
        btn.classList.add(nextState ? 'is-active' : 'is-inactive');
        const textEl = btn.querySelector('.status-text');
        if (textEl) textEl.textContent = nextState ? 'Active' : 'Inactive';
        btn.dataset.active = nextState ? 'true' : 'false';
        btn.title = nextState ? 'Click to deactivate variant' : 'Click to activate variant';

        const row = btn.closest('tr');
        if (row) {
            row.classList.toggle('is-row-inactive', !nextState);
        }

        try {
            let success = false;
            let finalActiveState = nextState;

            // Try Web API endpoint first
            try {
                const res = await fetch(`/api/v1/admin/inventory/variants/${variantId}/toggle-active`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json'
                    }
                });
                if (res.ok) {
                    const data = await res.json();
                    if (data && data.data && typeof data.data.isActive !== 'undefined') {
                        finalActiveState = data.data.isActive;
                        success = true;
                    } else if (data && typeof data.isActive !== 'undefined') {
                        finalActiveState = data.isActive;
                        success = true;
                    }
                }
            } catch (apiErr) {
                console.warn('API route failed, trying WebMethod fallback:', apiErr);
            }

            // Fallback to page WebMethod if needed
            if (!success) {
                const resWm = await fetch(window.location.pathname.split('?')[0] + '/ToggleVariantStatus', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=utf-8' },
                    body: JSON.stringify({ variantId: variantId })
                });
                if (resWm.ok) {
                    const d = (dataWm.d && dataWm.d.Result) ? dataWm.d.Result : (dataWm.d || dataWm);
                    if (d && typeof d.isActive !== 'undefined') {
                        finalActiveState = d.isActive;
                        success = true;
                    }
                }
            }

            if (success) {
                // Ensure UI reflects confirmed status
                btn.classList.remove('is-active', 'is-inactive');
                btn.classList.add(finalActiveState ? 'is-active' : 'is-inactive');
                if (textEl) textEl.textContent = finalActiveState ? 'Active' : 'Inactive';
                btn.dataset.active = finalActiveState ? 'true' : 'false';
                btn.title = finalActiveState ? 'Click to deactivate variant' : 'Click to activate variant';
                if (row) {
                    row.classList.toggle('is-row-inactive', !finalActiveState);
                }

                if (typeof window.showAdminToast === 'function') {
                    window.showAdminToast(
                        finalActiveState ? 'Variant is now active in storefront.' : 'Variant deactivated and hidden from storefront.',
                        'success',
                        'Variant Status Updated'
                    );
                }
            } else {
                throw new Error('Server returned unconfirmed response');
            }
        } catch (err) {
            console.error('Failed to toggle variant status:', err);
            // Revert UI on failure
            btn.classList.remove('is-active', 'is-inactive');
            btn.classList.add(isCurrentlyActive ? 'is-active' : 'is-inactive');
            if (textEl) textEl.textContent = isCurrentlyActive ? 'Active' : 'Inactive';
            btn.dataset.active = isCurrentlyActive ? 'true' : 'false';
            btn.title = isCurrentlyActive ? 'Click to deactivate variant' : 'Click to activate variant';
            if (row) {
                row.classList.toggle('is-row-inactive', !isCurrentlyActive);
            }

            if (typeof window.showAdminToast === 'function') {
                window.showAdminToast('Could not update variant status. Please try again.', 'error', 'Update Failed');
            }
        } finally {
            btn.disabled = false;
        }
    });
}
