/**
 * HELMET CARTEL - ADMIN REVIEWS MODERATION (reviews.js)
 * Manages admin reviews fetching, search, filter tabs,
 * details modal, toggling visibility (publishing / hiding),
 * and admin-only permanent deletion with confirmation modal.
 */

import { ApiClient } from '../api.js';

document.addEventListener('DOMContentLoaded', () => {
    initAdminReviews();
});

function initAdminReviews() {
    let currentFilter = 'ALL';
    let currentSearch = '';
    let reviewsList = [];
    let selectedReview = null;
    let reviewToDelete = null;

    const tbody = document.getElementById('admin-reviews-tbody');
    const searchInput = document.getElementById('adminGlobalSearch');
    const countIndicator = document.getElementById('review-count-indicator');
    const filterTabs = document.querySelectorAll('#review-status-tabs .admin-tab-btn');

    // Toast helper: uses global window.showAdminToast
    function notifyAdminToast(message, type = 'info', title = null) {
        if (typeof window.showAdminToast === 'function') {
            window.showAdminToast(message, type, title);
        } else if (typeof window.showToast === 'function') {
            window.showToast(message, type, title);
        }
    }

    // Role check: Admin only actions
    function isCurrentAdmin() {
        if (typeof window.HC_IS_ADMIN === 'boolean') return window.HC_IS_ADMIN;
        const user = ApiClient.getCurrentUser();
        if (user && user.role) return user.role.toLowerCase() === 'admin';
        const token = localStorage.getItem('hc_auth_token') || localStorage.getItem('auth_token');
        if (token) {
            try {
                const encoded = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
                const payload = JSON.parse(atob(encoded.padEnd(Math.ceil(encoded.length / 4) * 4, '=')));
                const role = payload.role || payload['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'];
                if (role) return role.toLowerCase() === 'admin';
            } catch (_) {}
        }
        return false;
    }

    // Check URL search and target review params
    const urlParams = new URLSearchParams(window.location.search);
    const targetReviewId = parseInt(urlParams.get('reviewId') || urlParams.get('id'), 10);
    const q = urlParams.get('q') || urlParams.get('search');
    if (q) {
        currentSearch = q.trim();
        if (searchInput && !searchInput.value) searchInput.value = currentSearch;
    }

    // Inspect Details Modal elements
    const modal = document.getElementById('admin-review-modal');
    const btnCloseModal = document.getElementById('btn-close-review-modal');
    const btnCancelModal = document.getElementById('btn-cancel-review-modal');
    const btnToggleAction = document.getElementById('btn-toggle-visibility-action');
    const btnDeleteFromModal = document.getElementById('btn-delete-review-modal');
    const armProductName = document.getElementById('arm-product-name');
    const armReviewer = document.getElementById('arm-reviewer');
    const armStars = document.getElementById('arm-stars');
    const armHeadline = document.getElementById('arm-headline');
    const armComment = document.getElementById('arm-comment');
    const armFlagsCount = document.getElementById('arm-flags-count');

    // Delete Confirmation Modal elements
    const deleteModal = document.getElementById('adminDeleteReviewModal');
    const btnCloseDeleteModal = document.getElementById('btnCloseDeleteReviewModal');
    const btnCancelDelete = document.getElementById('btnCancelDeleteReview');
    const btnConfirmDelete = document.getElementById('btnConfirmDeleteReview');
    const delReviewProduct = document.getElementById('delReviewProduct');
    const delReviewRating = document.getElementById('delReviewRating');
    const delReviewAuthor = document.getElementById('delReviewAuthor');
    const delReviewSnippet = document.getElementById('delReviewSnippet');

    // Load initial reviews
    loadReviews();

    // Filter tabs
    filterTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            filterTabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            currentFilter = tab.dataset.filter || 'ALL';
            loadReviews();
        });
    });

    // Global Search input with debounce
    let searchTimeout = null;
    searchInput?.addEventListener('input', (e) => {
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => {
            currentSearch = e.target.value.trim();
            loadReviews();
        }, 200);
    });

    async function loadReviews() {
        if (!tbody) return;
        tbody.innerHTML = '<tr><td colspan="8"><div class="admin-empty-state">Loading customer reviews...</div></td></tr>';

        try {
            const data = await ApiClient.adminGetReviews(currentFilter, currentSearch);
            reviewsList = Array.isArray(data) ? data : (data?.data || []);
            renderReviewsTable();
        } catch (err) {
            console.error('[AdminReviews] Error loading reviews:', err);
            tbody.innerHTML = `<tr><td colspan="8"><div class="admin-empty-state admin-empty-state--error">Unable to load customer reviews<div class="admin-empty-detail">${escapeHtml(err.message || 'Server error')}</div></div></td></tr>`;
        }
    }

    function renderReviewsTable() {
        if (!tbody) return;

        if (countIndicator) {
            countIndicator.textContent = `Showing ${reviewsList.length} of ${reviewsList.length} reviews`;
        }

        if (reviewsList.length === 0) {
            tbody.innerHTML = '<tr><td colspan="8"><div class="admin-empty-state"><div class="admin-empty-title">No Reviews Found</div><p>No customer reviews match the current filters.</p></div></td></tr>';
            return;
        }

        const isAdmin = isCurrentAdmin();

        tbody.innerHTML = reviewsList.map(r => {
            const starsHtml = '&#9733;'.repeat(r.rating) + '&#9734;'.repeat(5 - r.rating);
            const statusBadge = r.isHidden
                ? '<span class="admin-badge admin-badge--inactive">Hidden</span>'
                : '<span class="admin-badge admin-badge--active">Published</span>';

            const flagBadge = r.flagCount > 0
                ? `<span class="admin-badge admin-badge--reported">${r.flagCount} reported</span>`
                : '<span class="admin-table-count">0</span>';

            const verifiedBadge = r.isVerifiedPurchase
                ? ' <span class="admin-badge admin-badge--verified">Verified buyer</span>'
                : '';

            const toggleBtnText = r.isHidden ? 'Unhide' : 'Hide';
            const toggleBtnClass = r.isHidden ? 'btn-pill--primary' : 'btn-pill--secondary';

            const deleteBtnHtml = isAdmin
                ? `<button type="button" class="btn-pill-sm btn-pill--outline btn-pill--danger btn-delete-review" data-id="${r.id}" title="Delete Customer Review">
                    <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                        <polyline points="3 6 5 6 21 6"></polyline>
                        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                    </svg>
                    <span>Delete</span>
                   </button>`
                : '';

            return `
                <tr data-review-id="${r.id}">
                    <td>
                        <span class="admin-cell-name">${escapeHtml(r.productName)}</span>
                        <span class="admin-cell-subtext">${escapeHtml(r.brandName)}</span>
                    </td>
                    <td>
                        <span class="admin-cell-name">${escapeHtml(r.reviewerName)}</span>
                        ${verifiedBadge}
                    </td>
                    <td>
                        <span class="admin-rating-stars" aria-label="${r.rating} out of 5 stars">${starsHtml}</span>
                    </td>
                    <td>
                        ${r.title ? `<span class="admin-cell-review-title">${escapeHtml(r.title)}</span>` : ''}
                        <span class="admin-cell-truncate" title="${escapeHtml(r.comment)}">${escapeHtml(r.comment)}</span>
                    </td>
                    <td class="admin-table-align-center">${flagBadge}</td>
                    <td>${statusBadge}</td>
                    <td><span class="admin-activity-time">${escapeHtml(r.formattedDate || new Date(r.createdAt).toLocaleDateString())}</span></td>
                    <td class="admin-table-align-right">
                        <div class="admin-actions-cell admin-actions-cell--right">
                            <button type="button" class="btn-pill-sm btn-pill--outline btn-inspect-review" data-id="${r.id}">View Review</button>
                            <button type="button" class="btn-pill-sm ${toggleBtnClass} btn-toggle-review" data-id="${r.id}">${toggleBtnText}</button>
                            ${deleteBtnHtml}
                        </div>
                    </td>
                </tr>
            `;
        }).join('');

        // Wire up inspect buttons
        tbody.querySelectorAll('.btn-inspect-review').forEach(btn => {
            btn.addEventListener('click', () => {
                const id = parseInt(btn.dataset.id, 10);
                const review = reviewsList.find(r => r.id === id);
                if (review) openReviewModal(review);
            });
        });

        // Wire up toggle buttons
        tbody.querySelectorAll('.btn-toggle-review').forEach(btn => {
            btn.addEventListener('click', async () => {
                const id = parseInt(btn.dataset.id, 10);
                await handleToggleVisibility(id);
            });
        });

        // Wire up delete buttons (Admin only)
        tbody.querySelectorAll('.btn-delete-review').forEach(btn => {
            btn.addEventListener('click', () => {
                const id = parseInt(btn.dataset.id, 10);
                const review = reviewsList.find(r => r.id === id);
                if (review) openDeleteModal(review);
            });
        });

        // Auto-open target review from activity log redirection if present
        if (targetReviewId && !isNaN(targetReviewId)) {
            const targetRow = tbody.querySelector(`tr[data-review-id="${targetReviewId}"]`);
            if (targetRow) {
                targetRow.classList.add('admin-row-highlighted');
                setTimeout(() => {
                    targetRow.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }, 100);
            }
            const targetReview = reviewsList.find(r => r.id === targetReviewId);
            if (targetReview) {
                openReviewModal(targetReview);
            }
        }
    }

    function openReviewModal(review) {
        selectedReview = review;
        if (armProductName) armProductName.textContent = `${review.productName} (${review.brandName})`;
        if (armReviewer) armReviewer.innerHTML = `${escapeHtml(review.reviewerName)} ${review.isVerifiedPurchase ? '<span style="color:#38bdf8;">(Verified Buyer)</span>' : ''}`;
        if (armStars) armStars.innerHTML = `${'&#9733;'.repeat(review.rating)}${'&#9734;'.repeat(5 - review.rating)} (${review.rating}/5)`;
        if (armHeadline) armHeadline.textContent = review.title || '(No headline)';
        if (armComment) armComment.textContent = `"${review.comment}"`;
        if (armFlagsCount) armFlagsCount.textContent = `${review.flagCount} user reports on this review`;

        if (btnToggleAction) {
            btnToggleAction.textContent = review.isHidden ? 'Publish Review (Unhide)' : 'Hide Review';
        }

        // Show/hide Delete button in inspect modal depending on Admin role
        if (btnDeleteFromModal) {
            if (isCurrentAdmin()) {
                btnDeleteFromModal.classList.remove('is-hidden');
            } else {
                btnDeleteFromModal.classList.add('is-hidden');
            }
        }

        modal?.classList.remove('is-hidden');
    }

    function closeModal() {
        modal?.classList.add('is-hidden');
        selectedReview = null;
    }

    btnCloseModal?.addEventListener('click', closeModal);
    btnCancelModal?.addEventListener('click', closeModal);
    modal?.addEventListener('click', (e) => {
        if (e.target === modal) closeModal();
    });

    btnToggleAction?.addEventListener('click', async () => {
        if (!selectedReview) return;
        await handleToggleVisibility(selectedReview.id);
        closeModal();
    });

    btnDeleteFromModal?.addEventListener('click', () => {
        if (!selectedReview) return;
        const target = selectedReview;
        openDeleteModal(target);
    });

    // Delete Confirmation Modal Handling
    function openDeleteModal(review) {
        reviewToDelete = review;
        if (delReviewProduct) delReviewProduct.textContent = `${review.productName} (${review.brandName})`;
        if (delReviewRating) delReviewRating.textContent = '★'.repeat(review.rating) + '☆'.repeat(5 - review.rating) + ` (${review.rating}/5)`;
        if (delReviewAuthor) delReviewAuthor.textContent = review.reviewerName || 'Customer';
        if (delReviewSnippet) {
            const headline = review.title ? `"${review.title}" - ` : '';
            delReviewSnippet.textContent = `${headline}"${review.comment}"`;
        }

        deleteModal?.classList.remove('is-hidden');
        deleteModal?.removeAttribute('hidden');
        btnConfirmDelete?.focus();
    }

    function closeDeleteModal() {
        deleteModal?.classList.add('is-hidden');
        deleteModal?.setAttribute('hidden', 'hidden');
        reviewToDelete = null;
    }

    btnCloseDeleteModal?.addEventListener('click', closeDeleteModal);
    btnCancelDelete?.addEventListener('click', closeDeleteModal);
    deleteModal?.addEventListener('click', (e) => {
        if (e.target === deleteModal) closeDeleteModal();
    });

    btnConfirmDelete?.addEventListener('click', async () => {
        if (!reviewToDelete) return;
        const id = reviewToDelete.id;

        try {
            btnConfirmDelete.disabled = true;
            btnConfirmDelete.textContent = 'Deleting...';

            const res = await ApiClient.adminDeleteReview(id);
            if (res && res.success !== false) {
                notifyAdminToast(res.message || 'Customer review deleted successfully.', 'success', 'Review Deleted');
                closeDeleteModal();
                closeModal();
                await loadReviews();
            } else {
                notifyAdminToast(res?.message || 'Failed to delete review.', 'error', 'Delete Failed');
            }
        } catch (err) {
            console.error('[AdminReviews] Error deleting review:', err);
            notifyAdminToast(err.message || 'Failed to delete review.', 'error', 'Delete Failed');
        } finally {
            btnConfirmDelete.disabled = false;
            btnConfirmDelete.textContent = 'Delete Review';
        }
    });

    async function handleToggleVisibility(reviewId) {
        try {
            const res = await ApiClient.adminToggleReview(reviewId);
            if (res && res.success) {
                notifyAdminToast(res.message || 'Review status updated.', 'success', 'Review Updated');
                await loadReviews();
            } else {
                notifyAdminToast(res?.message || 'Failed to update review visibility.', 'error', 'Update Failed');
            }
        } catch (err) {
            console.error('[AdminReviews] Error toggling review:', err);
            notifyAdminToast(err.message || 'Error updating review status.', 'error', 'Update Failed');
        }
    }

    function escapeHtml(str) {
        if (!str) return '';
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }
}
