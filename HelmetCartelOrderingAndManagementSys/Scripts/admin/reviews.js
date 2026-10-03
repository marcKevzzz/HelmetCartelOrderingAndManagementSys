/**
 * HELMET CARTEL - ADMIN REVIEWS MODERATION (reviews.js)
 * Manages admin reviews fetching, search, filter tabs,
 * details modal, and toggling visibility (publishing / hiding).
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

    const tbody = document.getElementById('admin-reviews-tbody');
    const searchInput = document.getElementById('adminGlobalSearch');
    const countIndicator = document.getElementById('review-count-indicator');
    const filterTabs = document.querySelectorAll('#review-status-tabs .admin-tab-btn');

    // Check URL search param
    const urlParams = new URLSearchParams(window.location.search);
    const q = urlParams.get('q') || urlParams.get('search');
    if (q) {
        currentSearch = q.trim();
        if (searchInput && !searchInput.value) searchInput.value = currentSearch;
    }

    // Modal elements
    const modal = document.getElementById('admin-review-modal');
    const btnCloseModal = document.getElementById('btn-close-review-modal');
    const btnCancelModal = document.getElementById('btn-cancel-review-modal');
    const btnToggleAction = document.getElementById('btn-toggle-visibility-action');
    const armProductName = document.getElementById('arm-product-name');
    const armReviewer = document.getElementById('arm-reviewer');
    const armStars = document.getElementById('arm-stars');
    const armHeadline = document.getElementById('arm-headline');
    const armComment = document.getElementById('arm-comment');
    const armFlagsCount = document.getElementById('arm-flags-count');

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

    async function handleToggleVisibility(reviewId) {
        try {
            const res = await ApiClient.adminToggleReview(reviewId);
            if (res && res.success) {
                if (window.AdminToast) {
                    window.AdminToast.show(res.message || 'Review status updated.', 'success');
                }
                await loadReviews();
            } else {
                alert(res?.message || 'Failed to update review visibility.');
            }
        } catch (err) {
            console.error('[AdminReviews] Error toggling review:', err);
            alert('Error updating review status: ' + err.message);
        }
    }

    function escapeHtml(str) {
        if (!str) return '';
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }
}
