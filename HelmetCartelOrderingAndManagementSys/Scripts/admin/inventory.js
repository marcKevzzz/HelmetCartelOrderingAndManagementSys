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
