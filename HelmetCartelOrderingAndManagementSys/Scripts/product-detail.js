/**
 * HELMET CARTEL - PRODUCT DETAIL PAGE CONTROLLER (product-detail.js)
 * Manages gallery switching, attribute selectors (color/size/qty),
 * expandable specifications, review filtering/sorting,
 * review reporting & submission modals, and cart/wishlist actions.
 */

import { CartManager } from './cart.js';
import { FavoritesManager } from './favorites.js';
import { RealtimeManager } from './realtime.js';

document.addEventListener('DOMContentLoaded', () => {
    initProductDetailPage();
});

function initProductDetailPage() {
    // -------------------------------------------------------------
    // 1. DATA INITIALIZATION
    // -------------------------------------------------------------
    let serverProduct = null;
    const dataScript = document.getElementById('product-detail-data');
    if (dataScript) {
        try {
            serverProduct = JSON.parse(dataScript.textContent.trim());
        } catch (e) {
            console.warn('[ProductDetail] Could not parse product-detail-data JSON:', e);
        }
    }

    let activeStarFilter = 'all';
    let activeSort = 'latest';

    // -------------------------------------------------------------
    // 2. GALLERY THUMBNAIL SWITCHER
    // -------------------------------------------------------------
    const mainImg = document.getElementById('main-product-img');
    const thumbs = document.querySelectorAll('.gallery-thumb');
    const galleryModal = document.getElementById('gallery-modal');
    const modalCloseBtn = document.getElementById('gallery-modal-close');
    const modalBackdrop = document.getElementById('gallery-modal-backdrop');
    const modalItems = document.querySelectorAll('.gallery-modal__item');

    function openGalleryModal() {
        if (!galleryModal) return;
        galleryModal.classList.add('is-open');
        galleryModal.setAttribute('aria-hidden', 'false');
        document.body.classList.add('modal-open');
    }

    function closeGalleryModal() {
        if (!galleryModal) return;
        galleryModal.classList.remove('is-open');
        galleryModal.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('modal-open');
    }

    if (modalCloseBtn) {
        modalCloseBtn.addEventListener('click', closeGalleryModal);
    }
    if (modalBackdrop) {
        modalBackdrop.addEventListener('click', closeGalleryModal);
    }
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && galleryModal && galleryModal.classList.contains('is-open')) {
            closeGalleryModal();
        }
    });

    thumbs.forEach(thumb => {
        thumb.addEventListener('click', () => {
            const hasMore = thumb.dataset.hasMore === 'true';
            const img = thumb.querySelector('img');
            if (img && mainImg) {
                mainImg.src = img.src;
            }
            thumbs.forEach(t => t.classList.remove('active'));
            thumb.classList.add('active');

            const index = thumb.dataset.index;
            modalItems.forEach(mi => {
                mi.classList.toggle('is-active', mi.dataset.index === index);
            });

            if (hasMore) {
                openGalleryModal();
            }
        });
    });

    modalItems.forEach(item => {
        item.addEventListener('click', () => {
            const src = item.dataset.src;
            const index = parseInt(item.dataset.index, 10);
            if (src && mainImg) {
                mainImg.src = src;
            }

            modalItems.forEach(mi => mi.classList.remove('is-active'));
            item.classList.add('is-active');

            thumbs.forEach(t => t.classList.remove('active'));
            if (index < 4) {
                const targetThumb = document.querySelector(`.gallery-thumb[data-index="${index}"]`);
                if (targetThumb) targetThumb.classList.add('active');
            } else {
                const fifthThumb = document.querySelector('.gallery-thumb[data-has-more="true"]') || document.querySelector('.gallery-thumb[data-index="4"]');
                if (fifthThumb) {
                    fifthThumb.classList.add('active');
                    const fifthImg = fifthThumb.querySelector('img');
                    if (fifthImg && src) {
                        fifthImg.src = src;
                    }
                }
            }

            setTimeout(closeGalleryModal, 180);
        });
    });

    // -------------------------------------------------------------
    // 3. COLOR SWATCH SELECTOR
    // -------------------------------------------------------------
    const swatches = document.querySelectorAll('.color-swatch');
    const swatchRules = [];
    swatches.forEach((swatch, index) => {
        const value = swatch.getAttribute('data-color-hex') || '';
        const validSolid = /^#[0-9a-fA-F]{6}$/.test(value);
        const validGradient = /^linear-gradient\((?:[0-9]{1,3})deg,\s*#[0-9a-fA-F]{6}(?:,\s*#[0-9a-fA-F]{6}){1,3}\)$/.test(value);
        const validLegacyStops = /^#[0-9a-fA-F]{6}(?:,\s*#[0-9a-fA-F]{6}){1,3}$/.test(value);
        if (validSolid || validGradient || validLegacyStops) {
            const className = `swatch-value-${index}`;
            swatch.classList.add(className);
            const background = validLegacyStops ? `linear-gradient(90deg,${value})` : value;
            swatchRules.push(`.${className}{background:${background}}`);
        }
    });
    if (swatchRules.length) {
        const sheet = document.createElement('style');
        sheet.textContent = swatchRules.join('\n');
        document.head.append(sheet);
    }
    swatches.forEach(swatch => {
        swatch.addEventListener('click', () => {
            swatches.forEach(s => {
                s.classList.remove('active');
                s.innerHTML = '';
            });
            swatch.classList.add('active');
            swatch.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>';
            updateSelectedVariantUi();
        });
    });

    // -------------------------------------------------------------
    // 4. SIZE PILL SELECTOR
    // -------------------------------------------------------------
    const sizePills = document.querySelectorAll('.size-pill');
    sizePills.forEach(pill => {
        pill.addEventListener('click', () => {
            sizePills.forEach(p => p.classList.remove('active'));
            pill.classList.add('active');
            updateSelectedVariantUi();
        });
    });

    // -------------------------------------------------------------
    // 5. QUANTITY STEPPER (+ / -)
    // -------------------------------------------------------------
    const qtyDisplay = document.getElementById('detail-qty');
    const btnQtyDec = document.getElementById('btn-qty-dec');
    const btnQtyInc = document.getElementById('btn-qty-inc');

    if (btnQtyDec && qtyDisplay) {
        btnQtyDec.addEventListener('click', () => {
            const current = parseInt(qtyDisplay.textContent, 10) || 1;
            if (current > 1) {
                qtyDisplay.textContent = current - 1;
                updateSelectedVariantUi();
            }
        });
    }

    if (btnQtyInc && qtyDisplay) {
        btnQtyInc.addEventListener('click', () => {
            const current = parseInt(qtyDisplay.textContent, 10) || 1;
            qtyDisplay.textContent = current + 1;
            updateSelectedVariantUi();
        });
    }

    // -------------------------------------------------------------
    // 6. PRODUCT DETAILS EXPANSION
    // -------------------------------------------------------------
    const detailsSection = document.getElementById('product-details');
    const detailsToggle = document.getElementById('btn-toggle-details');
    detailsToggle?.addEventListener('click', () => {
        const expanded = detailsSection?.classList.toggle('is-expanded') || false;
        detailsToggle.setAttribute('aria-expanded', String(expanded));
        detailsToggle.textContent = expanded ? 'Show less' : 'Show more';
    });

    // -------------------------------------------------------------
    // 7. REVIEW FILTERING & SORTING
    // -------------------------------------------------------------
    const btnReviewFilter = document.getElementById('btn-review-filter');
    const reviewFilterMenu = document.getElementById('review-filter-menu');
    const btnReviewSort = document.getElementById('btn-review-sort');
    const reviewSortMenu = document.getElementById('review-sort-menu');
    const chkVerifiedOnly = document.getElementById('chk-verified-only');
    const btnResetFilters = document.getElementById('btn-reset-filters');
    const btnLoadMoreReviews = document.getElementById('btn-load-more-reviews');
    let visibleReviewLimit = 3;

    btnReviewFilter?.addEventListener('click', (e) => {
        e.stopPropagation();
        reviewSortMenu?.classList.remove('is-open');
        reviewFilterMenu?.classList.toggle('is-open');
    });

    btnReviewSort?.addEventListener('click', (e) => {
        e.stopPropagation();
        reviewFilterMenu?.classList.remove('is-open');
        reviewSortMenu?.classList.toggle('is-open');
    });

    // Filter options click
    document.querySelectorAll('.review-filter-option').forEach(opt => {
        opt.addEventListener('click', () => {
            document.querySelectorAll('.review-filter-option').forEach(o => o.classList.remove('active'));
            opt.classList.add('active');
            activeStarFilter = opt.getAttribute('data-filter') || 'all';
            reviewFilterMenu?.classList.remove('is-open');
            applyReviewFilters();
        });
    });

    // Verified filter checkbox
    chkVerifiedOnly?.addEventListener('change', () => {
        applyReviewFilters();
    });

    // Sort options click
    document.querySelectorAll('.review-sort-option').forEach(opt => {
        opt.addEventListener('click', () => {
            document.querySelectorAll('.review-sort-option').forEach(o => o.classList.remove('active'));
            opt.classList.add('active');
            activeSort = opt.getAttribute('data-sort') || 'latest';
            const label = document.getElementById('review-sort-label');
            if (label) label.textContent = opt.textContent.trim();
            reviewSortMenu?.classList.remove('is-open');
            applyReviewSort();
        });
    });

    // Reset filters button
    btnResetFilters?.addEventListener('click', () => {
        resetReviewFilters();
    });

    function applyReviewFilters(resetLimit = true) {
        if (resetLimit) visibleReviewLimit = 3;
        const cards = Array.from(document.querySelectorAll('#reviews-grid .review-card-full'));
        const verifiedOnly = chkVerifiedOnly ? chkVerifiedOnly.checked : false;
        let matchingCount = 0;

        cards.forEach(card => {
            const rating = card.getAttribute('data-rating');
            const verified = card.getAttribute('data-verified') === 'true';

            const matchesRating = (activeStarFilter === 'all' || rating === activeStarFilter);
            const matchesVerified = (!verifiedOnly || verified);

            const matches = matchesRating && matchesVerified;
            card.classList.toggle('is-review-filter-hidden', !matches);
            if (matches) matchingCount++;
            card.classList.toggle('is-review-page-hidden', !matches || matchingCount > visibleReviewLimit);
        });

        const countDisplay = document.getElementById('reviews-count-display');
        if (countDisplay) {
            countDisplay.textContent = `(${matchingCount})`;
        }

        const noMatchMsg = document.getElementById('reviews-no-filter-match');
        if (noMatchMsg) {
            noMatchMsg.classList.toggle('is-hidden', matchingCount !== 0 || cards.length === 0);
        }
        btnLoadMoreReviews?.parentElement?.classList.toggle('is-hidden', matchingCount <= visibleReviewLimit);
    }

    function applyReviewSort() {
        const grid = document.getElementById('reviews-grid');
        if (!grid) return;
        const cards = Array.from(grid.querySelectorAll('.review-card-full'));

        cards.sort((a, b) => {
            if (activeSort === 'highest') {
                const rA = parseInt(a.getAttribute('data-rating') || '0', 10);
                const rB = parseInt(b.getAttribute('data-rating') || '0', 10);
                return rB - rA;
            } else if (activeSort === 'lowest') {
                const rA = parseInt(a.getAttribute('data-rating') || '0', 10);
                const rB = parseInt(b.getAttribute('data-rating') || '0', 10);
                return rA - rB;
            } else {
                // Latest first
                const dA = new Date(a.getAttribute('data-date') || 0);
                const dB = new Date(b.getAttribute('data-date') || 0);
                return dB - dA;
            }
        });

        cards.forEach(c => grid.appendChild(c));
        applyReviewFilters();
    }

    function resetReviewFilters() {
        activeStarFilter = 'all';
        document.querySelectorAll('.review-filter-option').forEach(o => {
            o.classList.toggle('active', o.getAttribute('data-filter') === 'all');
        });
        if (chkVerifiedOnly) chkVerifiedOnly.checked = false;
        applyReviewFilters();
    }
    btnLoadMoreReviews?.addEventListener('click', () => {
        visibleReviewLimit += 3;
        applyReviewFilters(false);
    });
    applyReviewFilters();

    // -------------------------------------------------------------
    // 9. REVIEW ACTIONS (POPOVER & REPORT MODAL)
    // -------------------------------------------------------------
    const reportModal = document.getElementById('report-review-modal');
    const targetIdInput = document.getElementById('report-target-review-id');
    const authorSpan = document.getElementById('report-target-author');
    const reportNotes = document.getElementById('report-notes');
    const reportErrorMsg = document.getElementById('report-error-msg');
    const btnSubmitReport = document.getElementById('btn-submit-report');
    const btnCloseReport = document.getElementById('btn-close-report-modal');
    const btnCancelReport = document.getElementById('btn-cancel-report-modal');

    // Delegation for review more actions and report triggers
    document.addEventListener('click', (e) => {
        // Toggle popover
        const moreBtn = e.target.closest('.review-more-btn');
        if (moreBtn) {
            e.stopPropagation();
            const reviewId = moreBtn.getAttribute('data-review-id');
            const popover = document.getElementById(`review-popover-${reviewId}`);
            const isOpen = popover?.classList.contains('is-open');
            document.querySelectorAll('.review-action-popover.is-open').forEach(p => p.classList.remove('is-open'));
            if (!isOpen && popover) {
                popover.classList.add('is-open');
            }
            return;
        }

        // Click report inside popover
        const reportTrigger = e.target.closest('.btn-report-review');
        if (reportTrigger) {
            e.stopPropagation();
            document.querySelectorAll('.review-action-popover.is-open').forEach(p => p.classList.remove('is-open'));
            const reviewId = reportTrigger.getAttribute('data-review-id');
            const author = reportTrigger.getAttribute('data-reviewer');
            openReportModal(reviewId, author);
            return;
        }

        // Close dropdowns and popovers on outside click
        if (!e.target.closest('.review-filter-dropdown-wrap')) {
            reviewFilterMenu?.classList.remove('is-open');
        }
        if (!e.target.closest('.review-sort-wrap')) {
            reviewSortMenu?.classList.remove('is-open');
        }
        if (!e.target.closest('.review-actions-wrap')) {
            document.querySelectorAll('.review-action-popover.is-open').forEach(p => p.classList.remove('is-open'));
        }
    });

    function openReportModal(reviewId, authorName) {
        if (targetIdInput) targetIdInput.value = reviewId || '';
        if (authorSpan) authorSpan.textContent = authorName || 'Customer';
        if (reportNotes) reportNotes.value = '';
        if (reportErrorMsg) {
            reportErrorMsg.classList.add('is-hidden');
            reportErrorMsg.textContent = '';
        }
        const defaultRadio = document.querySelector('input[name="report-reason"][value="SPAM"]');
        if (defaultRadio) defaultRadio.checked = true;

        if (btnSubmitReport) {
            btnSubmitReport.disabled = false;
            btnSubmitReport.textContent = 'Submit Report';
        }

        reportModal?.classList.remove('is-hidden');
    }

    function closeReportModal() {
        reportModal?.classList.add('is-hidden');
    }

    btnCloseReport?.addEventListener('click', closeReportModal);
    btnCancelReport?.addEventListener('click', closeReportModal);
    reportModal?.addEventListener('click', (e) => {
        if (e.target === reportModal) closeReportModal();
    });

    btnSubmitReport?.addEventListener('click', async () => {
        const reviewId = parseInt(targetIdInput?.value || '0', 10);
        const reasonRadio = document.querySelector('input[name="report-reason"]:checked');
        const reason = reasonRadio ? reasonRadio.value : 'SPAM';
        const notes = reportNotes?.value?.trim() || '';

        if (!reviewId) {
            if (reportErrorMsg) {
                reportErrorMsg.textContent = 'Invalid review selected.';
                reportErrorMsg.classList.remove('is-hidden');
            }
            return;
        }

        if (btnSubmitReport) {
            btnSubmitReport.disabled = true;
            btnSubmitReport.textContent = 'Submitting...';
        }

        try {
            const response = await fetch('/api/v1/reviews/report', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    ReviewId: reviewId,
                    Reason: reason,
                    Notes: notes
                })
            });

            const data = await response.json();

            if (data && data.success) {
                closeReportModal();

                // Update the review card UI
                const card = document.querySelector(`.review-card-full[data-review-id="${reviewId}"]`);
                if (card) {
                    card.classList.add('is-reported');
                    const moreBtn = card.querySelector('.review-more-btn');
                    moreBtn?.classList.add('is-hidden');
                }

                const statusContainer = document.getElementById(`report-status-${reviewId}`);
                if (statusContainer) {
                    statusContainer.innerHTML = '<span class="review-reported-badge"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"></path><line x1="4" y1="22" x2="4" y2="15"></line></svg> Reported</span>';
                }

                RealtimeManager.showToast(data.message || 'Review reported for community moderation.', 'info');
            } else {
                if (reportErrorMsg) {
                    reportErrorMsg.textContent = data.message || 'Failed to submit report.';
                    reportErrorMsg.classList.remove('is-hidden');
                }
                if (btnSubmitReport) {
                    btnSubmitReport.disabled = false;
                    btnSubmitReport.textContent = 'Submit Report';
                }
            }
        } catch (err) {
            console.error('[ReviewReport] Error submitting report:', err);
            if (reportErrorMsg) {
                reportErrorMsg.textContent = 'Network or server error while submitting report.';
                reportErrorMsg.classList.remove('is-hidden');
            }
            if (btnSubmitReport) {
                btnSubmitReport.disabled = false;
                btnSubmitReport.textContent = 'Submit Report';
            }
        }
    });

    // -------------------------------------------------------------
    // 10. WRITE REVIEW MODAL & SUBMISSION
    // -------------------------------------------------------------
    const writeModal = document.getElementById('write-review-modal');
    const writeErrorMsg = document.getElementById('write-error-msg');
    const writeRatingVal = document.getElementById('write-rating-val');
    const writeReviewerName = document.getElementById('write-reviewer-name');
    const writeReviewTitle = document.getElementById('write-review-title');
    const writeReviewComment = document.getElementById('write-review-comment');
    const btnSubmitReview = document.getElementById('btn-submit-review');
    const btnCloseWrite = document.getElementById('btn-close-write-modal');
    const btnCancelWrite = document.getElementById('btn-cancel-write-modal');

    // Open write review modal triggers
    document.querySelectorAll('.btn-open-write-review').forEach(btn => {
        btn.addEventListener('click', () => {
            if (writeErrorMsg) {
                writeErrorMsg.classList.add('is-hidden');
                writeErrorMsg.textContent = '';
            }
            writeModal?.classList.remove('is-hidden');
        });
    });

    function closeWriteReviewModal() {
        writeModal?.classList.add('is-hidden');
    }

    btnCloseWrite?.addEventListener('click', closeWriteReviewModal);
    btnCancelWrite?.addEventListener('click', closeWriteReviewModal);
    writeModal?.addEventListener('click', (e) => {
        if (e.target === writeModal) closeWriteReviewModal();
    });

    // Star rating picker
    const starPickers = document.querySelectorAll('#write-star-picker .star-pick');
    starPickers.forEach(star => {
        star.addEventListener('click', () => {
            const val = parseInt(star.getAttribute('data-val'), 10) || 5;
            if (writeRatingVal) writeRatingVal.value = val;
            starPickers.forEach(s => {
                const sVal = parseInt(s.getAttribute('data-val'), 10) || 5;
                s.classList.toggle('active', sVal <= val);
                s.classList.toggle('inactive', sVal > val);
            });
        });
    });

    // Submit new review
    btnSubmitReview?.addEventListener('click', async () => {
        const urlParams = new URLSearchParams(window.location.search);
        const currentProdId = parseInt(serverProduct?.id ? String(serverProduct.id) : (urlParams.get('id') || '1'), 10);
        const rating = parseInt(writeRatingVal?.value || '5', 10);
        const name = writeReviewerName?.value?.trim();
        const title = writeReviewTitle?.value?.trim();
        const comment = writeReviewComment?.value?.trim();

        if (!name) {
            if (writeErrorMsg) {
                writeErrorMsg.textContent = 'Please enter your name or handle.';
                writeErrorMsg.classList.remove('is-hidden');
            }
            return;
        }

        if (!comment) {
            if (writeErrorMsg) {
                writeErrorMsg.textContent = 'Please write a review comment.';
                writeErrorMsg.classList.remove('is-hidden');
            }
            return;
        }

        if (btnSubmitReview) {
            btnSubmitReview.disabled = true;
            btnSubmitReview.textContent = 'Posting Review...';
        }

        try {
            const response = await fetch('/api/v1/reviews', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    ProductId: currentProdId,
                    ReviewerName: name,
                    Rating: rating,
                    Title: title,
                    Comment: comment
                })
            });

            if (response.ok) {
                RealtimeManager.showToast('Your review has been posted successfully!', 'success');
                closeWriteReviewModal();
                setTimeout(() => window.location.reload(), 800);
            } else {
                const err = await response.json();
                if (writeErrorMsg) {
                    writeErrorMsg.textContent = err.message || 'Could not save review.';
                    writeErrorMsg.classList.remove('is-hidden');
                }
                if (btnSubmitReview) {
                    btnSubmitReview.disabled = false;
                    btnSubmitReview.textContent = 'Post Review';
                }
            }
        } catch (ex) {
            console.error('[ProductDetail] Error submitting review:', ex);
            if (writeErrorMsg) {
                writeErrorMsg.textContent = 'Failed to submit review.';
                writeErrorMsg.classList.remove('is-hidden');
            }
            if (btnSubmitReview) {
                btnSubmitReview.disabled = false;
                btnSubmitReview.textContent = 'Post Review';
            }
        }
    });

    // -------------------------------------------------------------
    // 11. CART, WISHLIST, BUY NOW ACTIONS
    // -------------------------------------------------------------
    function getSelectedProductDetails() {
        const urlParams = new URLSearchParams(window.location.search);
        const currentProdId = parseInt(serverProduct?.id ? String(serverProduct.id) : (urlParams.get('id') || '1'), 10);
        const qty = parseInt(qtyDisplay?.textContent || '1', 10) || 1;
        const activeSizeBtn = document.querySelector('.size-pill.active');
        const selectedSize = activeSizeBtn ? activeSizeBtn.textContent.trim() : serverProduct?.variants?.[0]?.size;
        const activeSwatch = document.querySelector('.color-swatch.active');
        const selectedColor = activeSwatch ? (activeSwatch.getAttribute('data-color') || activeSwatch.getAttribute('title')) : serverProduct?.variants?.[0]?.color;

        let matchedVariant = null;
        if (serverProduct && serverProduct.variants && serverProduct.variants.length > 0) {
            matchedVariant = serverProduct.variants.find(v =>
                v.size?.toLowerCase() === selectedSize?.toLowerCase() &&
                v.color?.toLowerCase() === selectedColor?.toLowerCase()
            );
        }

        if (!serverProduct || !matchedVariant || Number(matchedVariant.currentStock) < qty) return null;
        const name = serverProduct.name;
        const brand = serverProduct.brand;
        const basePrice = Number(serverProduct.basePrice);
        const originalPrice = basePrice + Number(matchedVariant.priceAdjustment || 0);
        const discPercent = serverProduct?.discountPercentage || 0;
        const price = Math.round(originalPrice * (1 - discPercent / 100) * 100) / 100;
        const img = serverProduct.mainImageUrl;
        const rating = serverProduct.rating;
        const variantId = matchedVariant.id;

        return {
            productId: currentProdId,
            variantId: variantId,
            name: name,
            brand: brand,
            size: selectedSize,
            color: selectedColor,
            price: price,
            originalPrice,
            discountPercentage: discPercent,
            imageUrl: img,
            rating: rating,
            availableStock: Number(matchedVariant.currentStock),
            quantity: qty
        };
    }

    function updateSelectedVariantUi() {
        if (!serverProduct) return;
        const size = document.querySelector('.size-pill.active')?.textContent.trim();
        const color = document.querySelector('.color-swatch.active')?.getAttribute('data-color');
        const variant = serverProduct.variants?.find(v =>
            v.size?.toLowerCase() === size?.toLowerCase() &&
            v.color?.toLowerCase() === color?.toLowerCase()
        );
        const qty = Number(qtyDisplay?.textContent || 1);
        const available = variant && Number(variant.currentStock) >= qty;
        const message = document.getElementById('detail-stock-message');
        if (message) message.textContent = available ? '' : 'This size and color is unavailable at the selected quantity.';
        document.getElementById('btn-add-detail').disabled = !available;
        document.getElementById('btn-buy-now').disabled = !available;
        if (!variant) return;
        const original = Number(serverProduct.basePrice) + Number(variant.priceAdjustment || 0);
        const current = original * (1 - Number(serverProduct.discountPercentage || 0) / 100);
        const formatPrice = amount => `\u20B1${amount.toLocaleString('en-PH', { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;
        const priceLabel = document.getElementById('detail-price');
        const originalLabel = document.getElementById('detail-orig-price');
        if (priceLabel) priceLabel.textContent = formatPrice(current);
        if (originalLabel) originalLabel.textContent = formatPrice(original);
    }

    // Add to Cart
    document.getElementById('btn-add-detail')?.addEventListener('click', () => {
        const item = getSelectedProductDetails();
        if (!item || !CartManager.addItem(item)) {
            RealtimeManager.showToast('Select an available size and color before adding to cart.', 'alert');
            return;
        }
        CartManager.updateCartBadge();
        RealtimeManager.showToast(`${item.name} (${item.size} / ${item.color}) x${item.quantity} added to cart.`, 'cart');
    });

    // Toggle Favorite Wishlist
    const favBtn = document.getElementById('btn-detail-favorite');
    const updateFavBtnState = () => {
        if (!favBtn) return;
        const urlParams = new URLSearchParams(window.location.search);
        const currentProdId = parseInt(urlParams.get('id') || (serverProduct?.id ? String(serverProduct.id) : '1'), 10);
        const isFav = FavoritesManager.isFavorite(currentProdId);
        favBtn.classList.toggle('active', isFav);
        const icon = favBtn.querySelector('.heart-icon');
        if (icon) icon.setAttribute('fill', isFav ? 'currentColor' : 'none');
    };

    favBtn?.addEventListener('click', () => {
        if (!serverProduct) return;
        const added = FavoritesManager.toggleFavorite(serverProduct);
        updateFavBtnState();
        favBtn.classList.add('heart-pop');
        setTimeout(() => favBtn.classList.remove('heart-pop'), 400);
        RealtimeManager.showToast(added ? `${serverProduct.name} added to your Wishlist!` : `${serverProduct.name} removed from your Wishlist.`, added ? 'wishlist' : 'delete');
    });

    updateFavBtnState();
    updateSelectedVariantUi();

    // Buy Now
    document.getElementById('btn-buy-now')?.addEventListener('click', () => {
        const item = getSelectedProductDetails();
        if (!item || !CartManager.addItem(item)) {
            RealtimeManager.showToast('Select an available size and color before checkout.', 'alert');
            return;
        }
        CartManager.updateCartBadge();
        window.location.href = '/Pages/Checkout.aspx';
    });
}
