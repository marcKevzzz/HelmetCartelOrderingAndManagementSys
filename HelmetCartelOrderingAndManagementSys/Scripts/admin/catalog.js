/**
 * Helmet Cartel - Catalog Management Script
 * Handles Add/Edit Helmet Model 5-tab wizard, dynamic variant matrix,
 * and Delete Confirmation Preview Modal without inline scripts.
 */

(function () {
  'use strict';

  document.addEventListener('DOMContentLoaded', () => {
    // 1. Delete Confirmation Preview Modal
    const deleteModal = document.getElementById('adminDeleteProductModal');
    const delModalImage = document.getElementById('delModalImage');
    const delModalName = document.getElementById('delModalName');
    const delModalBrand = document.getElementById('delModalBrand');
    const delModalCategory = document.getElementById('delModalCategory');
    const delModalSku = document.getElementById('delModalSku');
    const delModalSummary = document.getElementById('delModalVariantsSummary');
    const hfDeleteProductId = document.getElementById('hfDeleteProductId');
    const btnCancelDelete = document.getElementById('btnCancelDelete');
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

    // Event delegation for delete buttons
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

    if (btnCancelDelete && deleteModal) {
      btnCancelDelete.addEventListener('click', () => {
        deleteModal.classList.add('is-hidden');
        deleteModal.setAttribute('hidden', '');
        if (hfDeleteProductId) hfDeleteProductId.value = '';
      });
    }

    // 2. Open Add Helmet Model Modal Button
    const btnAddHelmet = document.getElementById('btnOpenAddHelmetModal');
    if (btnAddHelmet) {
      btnAddHelmet.addEventListener('click', () => {
        if (typeof window.openAddProductModal === 'function') {
          window.openAddProductModal();
        }
      });
    }

    // 3. Edit Helmet Model Buttons (Event Delegation)
    document.addEventListener('click', (e) => {
      const editBtn = e.target.closest('.btn-edit-product');
      if (editBtn) {
        e.preventDefault();
        const id = parseInt(editBtn.getAttribute('data-id'), 10);
        const name = editBtn.getAttribute('data-name') || '';
        const brandId = parseInt(editBtn.getAttribute('data-brandid'), 10) || 1;
        const catId = parseInt(editBtn.getAttribute('data-catid'), 10) || 1;
        const style = editBtn.getAttribute('data-style') || '';
        const price = parseFloat(editBtn.getAttribute('data-price')) || 0;
        const disType = editBtn.getAttribute('data-distype') || 'Percentage';
        const disAmt = parseFloat(editBtn.getAttribute('data-disamt')) || 0;
        const img = editBtn.getAttribute('data-img') || '';
        const desc = editBtn.getAttribute('data-desc') || '';

        if (typeof window.openEditProductModal === 'function') {
          window.openEditProductModal(id, name, brandId, catId, style, price, disType, disAmt, img, desc);
        }
      }
    });
  });
})();
