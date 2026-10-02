/**
 * Helmet Cartel - Catalog Management Script
 * Handles Storefront Preview Modal and Delete Confirmation Preview Modal.
 */

(function () {
  'use strict';

  document.addEventListener('DOMContentLoaded', () => {
    // 1. Storefront Product Preview Modal
    const previewModal = document.getElementById('adminProductPreviewModal');
    const previewFrame = document.getElementById('productPreviewFrame');
    const previewTitle = document.getElementById('productPreviewTitle');

    const closeProductPreview = () => {
      if (!previewModal) return;
      previewModal.classList.add('is-hidden');
      previewModal.setAttribute('hidden', 'hidden');
      if (previewFrame) previewFrame.src = 'about:blank';
    };

    document.addEventListener('click', (e) => {
      const previewBtn = e.target.closest('.btn-preview-product');
      if (previewBtn) {
        e.preventDefault();
        if (previewTitle) previewTitle.textContent = `Preview: ${previewBtn.dataset.name || 'Product Detail'}`;
        if (previewFrame) previewFrame.src = previewBtn.dataset.previewUrl || 'about:blank';
        if (previewModal) {
          previewModal.classList.remove('is-hidden');
          previewModal.removeAttribute('hidden');
        }
        return;
      }

      if (e.target.closest('.js-close-product-preview') || e.target === previewModal) {
        closeProductPreview();
      }
    });

    document.addEventListener('keydown', e => {
      if (e.key === 'Escape' && previewModal && !previewModal.hasAttribute('hidden')) {
        closeProductPreview();
      }
    });

    // 2. Delete Confirmation Preview Modal
    const deleteModal = document.getElementById('adminDeleteProductModal');
    const delModalImage = document.getElementById('delModalImage');
    const delModalName = document.getElementById('delModalName');
    const delModalBrand = document.getElementById('delModalBrand');
    const delModalCategory = document.getElementById('delModalCategory');
    const delModalSku = document.getElementById('delModalSku');
    const delModalSummary = document.getElementById('delModalVariantsSummary');
    const hfDeleteProductId = document.getElementById('hfDeleteProductId');
    const btnCancelDelete = document.getElementById('btnCancelDelete');

    document.addEventListener('click', (e) => {
      const delBtn = e.target.closest('.btn-delete-product');
      if (delBtn) {
        e.preventDefault();
        const id = delBtn.getAttribute('data-id');
        const name = delBtn.getAttribute('data-name') || 'Helmet Model';
        const brand = delBtn.getAttribute('data-brand') || 'Brand';
        const category = delBtn.getAttribute('data-category') || 'Category';
        const sku = delBtn.getAttribute('data-sku') || '';
        const img = delBtn.getAttribute('data-img') || '/Content/images/products/helmets/agv/images.jpg';
        const variants = delBtn.getAttribute('data-variants') || '0';

        if (delModalImage) delModalImage.src = img;
        if (delModalName) delModalName.textContent = name;
        if (delModalBrand) delModalBrand.textContent = brand;
        if (delModalCategory) delModalCategory.textContent = category;
        if (delModalSku) delModalSku.textContent = sku;
        if (delModalSummary) delModalSummary.textContent = `${variants} Variant SKU(s) configured in stock database`;
        if (hfDeleteProductId) hfDeleteProductId.value = id;

        if (deleteModal) {
          deleteModal.classList.remove('is-hidden');
          deleteModal.removeAttribute('hidden');
        }
      }
    });

    const btnCloseDelete = document.getElementById('btnCloseDeleteModal');

    const closeDeleteModal = () => {
      if (deleteModal) {
        deleteModal.classList.add('is-hidden');
        deleteModal.setAttribute('hidden', '');
      }
      if (hfDeleteProductId) hfDeleteProductId.value = '';
    };

    if (btnCancelDelete) btnCancelDelete.addEventListener('click', closeDeleteModal);
    if (btnCloseDelete) btnCloseDelete.addEventListener('click', closeDeleteModal);
    if (deleteModal) {
      deleteModal.addEventListener('click', (e) => {
        if (e.target === deleteModal) closeDeleteModal();
      });
    }

    // 3. Status Query Parameter Toasts
    const urlParams = new URLSearchParams(window.location.search);
    const msg = urlParams.get('msg');
    if (msg === 'draft_saved') {
      if (typeof window.showAdminToast === 'function') {
        window.showAdminToast('Draft saved successfully. Item is listed in your catalog table.', 'success', 'Draft Saved');
      }
      window.history.replaceState({}, document.title, window.location.pathname);
    } else if (msg === 'published') {
      if (typeof window.showAdminToast === 'function') {
        window.showAdminToast('Helmet model published successfully.', 'success', 'Published');
      }
      window.history.replaceState({}, document.title, window.location.pathname);
    }
  });
})();
