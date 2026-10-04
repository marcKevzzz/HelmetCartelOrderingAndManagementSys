/**
 * HELMET CARTEL - STOREFRONT INTERACTIONS
 * Balanced product grid rendering, wishlist heart favorites,
 * interactive Shop filters, and dynamic sorting dropdown.
 */

import { ApiClient } from '../api.js';
import { CartManager } from '../cart.js?v=20261004';
import { ShoppingState } from '../shopping-state.js?v=20261004';
import { FavoritesManager } from '../favorites.js?v=20261004';
import { RealtimeManager } from '../realtime.js';
import { APP_CONSTANTS } from '../constants.js';

export const Storefront = {
  allProducts: [],
  currentProducts: [],
  activeFilters: {
    brand: 'all',
    category: 'all',
    style: 'all',
    minPrice: 0,
    maxPrice: 100000
  },
  currentSort: 'popular',

  async init() {
    CartManager.updateCartBadge();
    FavoritesManager.updateFavoritesBadge();
    RealtimeManager.init();
    await this.loadLiveProducts();
    this.setupEventListeners();
    this.setupShopFiltersAndSort();
    this.applyInitialUrlFilters();
  },

  async loadLiveProducts() {
    const newArrivalsContainer = document.getElementById('new-arrivals-grid');
    const topSellingContainer = document.getElementById('top-selling-grid');
    if (!newArrivalsContainer && !topSellingContainer) return;

    // If ASP.NET server components already rendered products into DOM, preserve them
    const hasServerCards = (newArrivalsContainer && newArrivalsContainer.querySelectorAll('.product-card').length > 0) ||
                           (topSellingContainer && topSellingContainer.querySelectorAll('.product-card').length > 0);

    if (hasServerCards) {
      return;
    }

    let products = [];

    try {
      const response = await ApiClient.getProducts({ pageSize: 50 });
      const items = Array.isArray(response) ? response : (response?.items || response?.data?.items || response?.data);
      if (items && items.length > 0) {
        products = items;
      }
    } catch (err) {
      console.error('[Storefront] Error loading live products from API:', err);
    }

    this.allProducts = [...products];
    this.currentProducts = [...products];

    if (newArrivalsContainer) {
      newArrivalsContainer.innerHTML = products
        .slice(0, 4)
        .map(p => this.createProductCardHtml(p))
        .join('');
    }

    if (topSellingContainer) {
      topSellingContainer.innerHTML = products
        .slice(4, 8)
        .map(p => this.createProductCardHtml(p))
        .join('');
    }

  },

  renderCatalogGrid(products) {
    const catalogContainer = document.getElementById('catalog-products-grid');
    const productsCount = document.getElementById('shop-products-count');
    if (!catalogContainer) return;

    if (!products || products.length === 0) {
      catalogContainer.innerHTML = `
        <div class="shop-empty-state">
          <div class="shop-empty-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <circle cx="11" cy="11" r="8"></circle>
              <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
            </svg>
          </div>
          <h3 class="shop-empty-title">No products found</h3>
          <p class="shop-empty-desc">We couldn't find any products matching your current filters.</p>
          <button type="button" class="btn btn--outline btn--reset-filters" id="btn-reset-filters">
            <span>Reset All Filters</span>
          </button>
        </div>
      `;

      if (productsCount) {
        productsCount.textContent = `Showing 0 of ${this.allProducts.length} Products`;
      }

      document.getElementById('btn-reset-filters')?.addEventListener('click', () => {
        this.resetFilters();
      });
      return;
    }

    catalogContainer.innerHTML = products
      .map(p => this.createProductCardHtml(p))
      .join('');

    if (productsCount) {
      const isFiltered = (this.activeFilters.brand !== 'all' || this.activeFilters.category !== 'all');
      const brandLabel = this.activeFilters.brand !== 'all' ? this.activeFilters.brand : '';
      const catLabel = this.activeFilters.category !== 'all' ? this.activeFilters.category : '';
      const filterLabel = isFiltered ? ` (Filtered: ${brandLabel} ${catLabel})`.trim() : '';
      productsCount.textContent = `Showing 1-${products.length} of ${this.allProducts.length} Products${filterLabel}`;
    }
  },

  createProductCardHtml(p) {
    const starsHtml = this.generateStarsSvg(Number(p.rating || 0));
    const originalPrice = Number(p.basePrice ?? 0);
    const price = Number(p.effectivePrice ?? originalPrice * (1 - Number(p.discountPercentage || 0) / 100));
    const priceFormatted = `&#8369;${price.toLocaleString()}`;
    const origPrice = p.discountPercentage > 0 ? originalPrice : null;
    const origPriceHtml = origPrice 
      ? `<span class="price-original">&#8369;${origPrice.toLocaleString()}</span>` 
      : '';
    const discountHtml = p.discountPercentage > 0 
      ? `<span class="discount-badge">-${p.discountPercentage}%</span>` 
      : '';

    const img = p.mainImageUrl || p.imageUrl || "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=500&auto=format&fit=crop&q=80";

    const detailUrl = APP_CONSTANTS.ROUTES.PRODUCT_DETAIL(p.id);

    const isFav = FavoritesManager.isFavorite(p.id);

    return `
      <a href="${detailUrl}" class="product-card" data-product-id="${p.id}">
        <div class="product-card__image-box">
          <img src="${img}" alt="${p.name}" class="product-card__img" loading="lazy" />
          <button type="button" class="product-card__fav-btn ${isFav ? 'active' : ''}" data-fav-id="${p.id}" aria-label="Toggle Wishlist" title="Save to Wishlist">
            <svg class="heart-icon" viewBox="0 0 24 24" fill="${isFav ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="2">
              <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>
            </svg>
          </button>
        </div>
        <h3 class="product-card__title" title="${p.name}">${p.name}</h3>
        <div class="product-card__rating">
          <div class="stars">${starsHtml}</div>
          <span class="rating-score"><span>${Number(p.rating || 0)}</span>/5</span>
        </div>
        <div class="product-card__pricing">
          <span class="price-current">${priceFormatted}</span>
          ${origPriceHtml}
          ${discountHtml}
        </div>
      </a>
    `;
  },

  generateStarsSvg(rating) {
    let svgs = '';
    const full = Math.floor(rating);
    for (let i = 0; i < 5; i++) {
      if (i < full) {
        svgs += `<svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;
      } else {
        svgs += `<svg viewBox="0 0 24 24" class="star--empty"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;
      }
    }
    return svgs;
  },

  setupEventListeners() {
    const syncFavoriteButtons = () => {
      document.querySelectorAll('.product-card__fav-btn[data-fav-id]').forEach(button => {
        const active = FavoritesManager.isFavorite(button.dataset.favId);
        button.classList.toggle('active', active);
        button.querySelector('.heart-icon')?.setAttribute('fill', active ? 'currentColor' : 'none');
      });
    };
    syncFavoriteButtons();
    window.addEventListener('favoritesUpdated', syncFavoriteButtons);
    // 1. Wishlist Favorite Heart Click Delegation
    document.addEventListener('click', async (e) => {
      const favBtn = e.target.closest('.product-card__fav-btn');
      if (favBtn) {
        e.preventDefault();
        e.stopPropagation();

        if (!ApiClient.isAuthenticated()) {
          window.showAuthPromptModal?.({
            title: 'Sign In to Save Favorites',
            message: 'Please sign in or create an account to save helmets to your wishlist.',
            returnUrl: window.location.pathname + window.location.search
          });
          return;
        }

        const id = parseInt(favBtn.getAttribute('data-fav-id'), 10);
        const card = favBtn.closest('.product-card');
        const product = { id, name: card?.querySelector('.product-card__title')?.textContent || 'Helmet' };
        const name = product.name;
        const added = await ShoppingState.run(() => FavoritesManager.toggleFavorite(product));
        if (added === undefined) return;
        favBtn.classList.toggle('active', added);
        const heartSvg = favBtn.querySelector('.heart-icon');
        if (heartSvg) heartSvg.setAttribute('fill', added ? 'currentColor' : 'none');

        // Play micro-scale bounce
        favBtn.classList.add('heart-pop');
        setTimeout(() => favBtn.classList.remove('heart-pop'), 350);

        RealtimeManager.showToast(added ? `${name} added to your Wishlist!` : `${name} removed from Wishlist.`, added ? 'wishlist' : 'delete');
      }
    });

    // 2. Testimonials Carousel
    this.initTestimonialsCarousel();

    // 3. User Profile Header State
    const userBtn = document.getElementById('nav-user-btn') || document.getElementById('navUserBtn');
    if (userBtn) {
      try {
        const profileStr = localStorage.getItem('hc_user_profile');
        if (profileStr) {
          const profile = JSON.parse(profileStr);
          if (profile && profile.fullName) {
            userBtn.setAttribute('title', `${profile.fullName} (${profile.role})`);
            if (profile.role === 'Admin' || profile.role === 'Staff') {
              userBtn.setAttribute('href', APP_CONSTANTS.ROUTES.ADMIN_DASHBOARD);
            } else {
              userBtn.setAttribute('href', APP_CONSTANTS.ROUTES.PROFILE);
            }
          }
        }
      } catch (e) {
        // Fallback
      }
    }
  },

  /* ==========================================================================
     TESTIMONIALS SLIDER CONTROLLER (Non-Scrollable, 3-Card Responsive & Button Driven)
     ========================================================================== */
  initTestimonialsCarousel() {
    const track = document.getElementById('testimonials-track');
    const prevBtn = document.getElementById('prev-testimonial');
    const nextBtn = document.getElementById('next-testimonial');

    if (!track) return;

    const cards = Array.from(track.querySelectorAll('.testimonial-card'));
    if (!cards || cards.length === 0) return;

    let currentIndex = 0;

    // Helper: determine visible cards per viewport
    const getVisibleCount = () => {
      const w = window.innerWidth;
      if (w > 1024) return 3;
      if (w > 640) return 2;
      return 1;
    };

    // Helper: calculate step (card width + column gap)
    const getStep = () => {
      const firstCard = cards[0];
      const gap = parseFloat(getComputedStyle(track).columnGap || getComputedStyle(track).gap) || 24;
      return (firstCard ? firstCard.getBoundingClientRect().width : 320) + gap;
    };

    const getMaxIndex = () => {
      const visibleCount = getVisibleCount();
      return Math.max(0, cards.length - visibleCount);
    };

    const updateSlider = (smooth = true) => {
      const maxIndex = getMaxIndex();
      if (currentIndex > maxIndex) currentIndex = maxIndex;
      if (currentIndex < 0) currentIndex = 0;

      const step = getStep();
      const offset = currentIndex * step;

      track.style.transition = smooth ? 'transform 450ms cubic-bezier(0.16, 1, 0.3, 1)' : 'none';
      track.style.transform = `translateX(-${offset}px)`;
    };

    const handleNext = () => {
      const maxIndex = getMaxIndex();
      if (currentIndex >= maxIndex) {
        currentIndex = 0; // Loop back to start
      } else {
        currentIndex++;
      }
      updateSlider(true);
    };

    const handlePrev = () => {
      const maxIndex = getMaxIndex();
      if (currentIndex <= 0) {
        currentIndex = maxIndex; // Loop back to end
      } else {
        currentIndex--;
      }
      updateSlider(true);
    };

    if (nextBtn) {
      nextBtn.onclick = (e) => {
        e.preventDefault();
        handleNext();
      };
    }

    if (prevBtn) {
      prevBtn.onclick = (e) => {
        e.preventDefault();
        handlePrev();
      };
    }

    let resizeTimer = null;
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => {
        updateSlider(false);
      }, 100);
    }, { passive: true });

    // Initial positioning
    updateSlider(false);
  },

  /* ==========================================================================
     SHOP PAGE FILTERS, URL SYNC & SORT DROPDOWN CONTROLS
     ========================================================================== */
  applyInitialUrlFilters() {
    if (document.getElementById('catalog-products-grid')) return;
    const params = new URLSearchParams(window.location.search);
    const brandParam = params.get('brand');
    const categoryParam = params.get('category');
    const styleParam = params.get('style');

    let hasFilter = false;

    if (brandParam) {
      this.activeFilters.brand = brandParam;
      document.querySelectorAll('#filter-brands-container .filter-brand-btn').forEach(btn => {
        const b = btn.getAttribute('data-brand');
        if (b && b.toLowerCase() === brandParam.toLowerCase()) {
          btn.classList.add('active');
        } else {
          btn.classList.remove('active');
        }
      });
      hasFilter = true;
    }

    if (categoryParam) {
      this.activeFilters.category = categoryParam;
      document.querySelectorAll('#filter-categories-container .filter-category-item').forEach(item => {
        const cat = item.getAttribute('data-category');
        if (cat && cat.toLowerCase() === categoryParam.toLowerCase()) {
          item.classList.add('active');
        } else {
          item.classList.remove('active');
        }
      });
      hasFilter = true;
    }

    if (styleParam) {
      this.activeFilters.style = styleParam;
      hasFilter = true;
    }

    if (hasFilter) {
      this.filterCatalogProducts();
    }
  },

  setupShopFiltersAndSort() {
    if (document.getElementById('catalog-products-grid')) {
      this.setupServerShopFilters();
      return;
    }
    // 1. Accordion Collapsing
    document.querySelectorAll('.filter-accordion-header').forEach(header => {
      header.addEventListener('click', () => {
        header.classList.toggle('is-collapsed');
        const content = header.nextElementSibling;
        if (content && !content.classList.contains('filter-section-divider')) {
          content.classList.toggle('is-hidden');
        }
      });
    });

    // 2. Category selection
    document.querySelectorAll('#filter-categories-container .filter-category-item').forEach(item => {
      item.addEventListener('click', () => {
        const cat = item.getAttribute('data-category') || 'all';
        document.querySelectorAll('#filter-categories-container .filter-category-item').forEach(i => i.classList.remove('active'));
        item.classList.add('active');
        this.activeFilters.category = cat;

        const url = new URL(window.location);
        if (cat === 'all') {
          url.searchParams.delete('category');
        } else {
          url.searchParams.set('category', cat);
        }
        window.history.replaceState({}, '', url);

        this.filterCatalogProducts();
      });
    });

    // 3. Brand selection
    document.querySelectorAll('#filter-brands-container .filter-brand-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const brand = btn.getAttribute('data-brand') || 'all';
        document.querySelectorAll('#filter-brands-container .filter-brand-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        this.activeFilters.brand = brand;

        const url = new URL(window.location);
        if (brand === 'all') {
          url.searchParams.delete('brand');
        } else {
          url.searchParams.set('brand', brand);
        }
        window.history.replaceState({}, '', url);

        this.filterCatalogProducts();
      });
    });

    // 4. Color swatches selection
    const checkmarkSvg = '<svg viewBox="0 0 24 24" fill="none"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    document.querySelectorAll('.filter-colors-grid .filter-color-swatch').forEach(swatch => {
      swatch.addEventListener('click', () => {
        const isActive = swatch.classList.toggle('active');
        if (isActive) {
          swatch.innerHTML = checkmarkSvg;
        } else {
          swatch.innerHTML = '';
        }
      });
    });

    // 5. Size pills toggle
    document.querySelectorAll('.filter-sizes-grid .filter-size-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        pill.classList.toggle('active');
      });
    });

    // 6. Dual Price range slider (single track with 2 draggable balls, 0 to 100k + editable inputs)
    const minSlider = document.getElementById('price-range-min');
    const maxSlider = document.getElementById('price-range-max');
    const minInput = document.getElementById('price-min-input');
    const maxInput = document.getElementById('price-max-input');
    const progressEl = document.getElementById('dual-range-progress');

    const parseClientMin = () => {
      if (!minSlider) return 0;
      const v = Number(minSlider.value);
      return Number.isFinite(v) ? Math.max(0, Math.min(99999, v)) : 0;
    };

    const parseClientMax = () => {
      if (!maxSlider) return 100000;
      const v = Number(maxSlider.value);
      return Number.isFinite(v) && maxSlider.value !== '' ? Math.max(1, Math.min(100000, v)) : 100000;
    };

    const updatePriceDisplay = (e) => {
      let minVal = parseClientMin();
      let maxVal = parseClientMax();
      const gap = 1;

      if (maxVal - minVal < gap) {
        if (e && e.target === minSlider) {
          minSlider.value = maxVal - gap;
          minVal = maxVal - gap;
        } else if (e && e.target === maxSlider) {
          maxSlider.value = minVal + gap;
          maxVal = minVal + gap;
        }
      }

      const minPercent = (minVal / 100000) * 100;
      const maxPercent = (maxVal / 100000) * 100;

      if (progressEl) {
        progressEl.style.left = `${minPercent}%`;
        progressEl.style.right = `${100 - maxPercent}%`;
      }

      if (minInput && document.activeElement !== minInput) {
        minInput.value = minVal;
      }
      if (maxInput && document.activeElement !== maxInput) {
        maxInput.value = maxVal;
      }

      if (e?.target === minSlider) {
        minSlider.style.zIndex = '4';
        if (maxSlider) maxSlider.style.zIndex = '3';
      } else if (e?.target === maxSlider) {
        maxSlider.style.zIndex = '4';
        if (minSlider) minSlider.style.zIndex = '3';
      }
    };

    minSlider?.addEventListener('input', updatePriceDisplay);
    maxSlider?.addEventListener('input', updatePriceDisplay);
    minSlider?.addEventListener('change', () => {
      this.activeFilters.minPrice = parseClientMin();
      this.filterCatalogProducts();
    });
    maxSlider?.addEventListener('change', () => {
      this.activeFilters.maxPrice = parseClientMax();
      this.filterCatalogProducts();
    });

    const handleMinInputChange = () => {
      let val = parseInt(minInput.value, 10);
      if (isNaN(val) || val < 0) val = 0;
      const currentMax = parseClientMax();
      if (val >= currentMax) val = Math.max(0, currentMax - 1);
      minInput.value = val;
      if (minSlider) minSlider.value = val;
      updatePriceDisplay();
      this.activeFilters.minPrice = val;
      this.filterCatalogProducts();
    };

    const handleMaxInputChange = () => {
      let val = parseInt(maxInput.value, 10);
      if (isNaN(val) || val > 100000) val = 100000;
      const currentMin = parseInt(minSlider?.value || 0, 10);
      if (val <= currentMin) val = Math.min(100000, currentMin + 1);
      maxInput.value = val;
      if (maxSlider) maxSlider.value = val;
      updatePriceDisplay();
      this.activeFilters.maxPrice = val;
      this.filterCatalogProducts();
    };

    minInput?.addEventListener('input', handleMinInputChange);
    minInput?.addEventListener('change', handleMinInputChange);
    minInput?.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); handleMinInputChange(); } });
    maxInput?.addEventListener('input', handleMaxInputChange);
    maxInput?.addEventListener('change', handleMaxInputChange);
    maxInput?.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); handleMaxInputChange(); } });

    if (minSlider && maxSlider) {
      updatePriceDisplay();
    }

    // 7. Apply Filter Button
    const applyBtn = document.querySelector('.btn--apply-filters');
    if (applyBtn) {
      applyBtn.addEventListener('click', () => {
        this.activeFilters.minPrice = parseInt(minSlider?.value || 0, 10);
        this.activeFilters.maxPrice = parseInt(maxSlider?.value || 100000, 10);
        this.filterCatalogProducts();
        applyBtn.classList.add('btn--applied');
        applyBtn.querySelector('span').textContent = 'Filters Active';
        RealtimeManager.showToast('Filter parameters applied.', 'info');
        setTimeout(() => {
          applyBtn.classList.remove('btn--applied');
          applyBtn.querySelector('span').textContent = 'Apply Filter';
        }, 2000);
      });
    }

    // 8. Dynamic "Sort by: Most Popular" Dropdown
    const sortBtn = document.getElementById('shop-sort-btn');
    const sortMenu = document.getElementById('shop-sort-menu');
    const sortLabel = document.getElementById('current-sort-label');
    const sortWrap = document.getElementById('shop-sort-dropdown-wrap');

    if (sortBtn && sortMenu && sortLabel) {
      sortBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        sortMenu.classList.toggle('is-open');
        sortBtn.classList.toggle('active');
      });

      sortMenu.querySelectorAll('.shop-sort-option').forEach(opt => {
        opt.addEventListener('click', () => {
          const sortType = opt.getAttribute('data-sort');
          const sortText = opt.textContent.trim();

          sortMenu.querySelectorAll('.shop-sort-option').forEach(o => o.classList.remove('active'));
          opt.classList.add('active');
          sortLabel.textContent = sortText;
          sortMenu.classList.remove('is-open');
          sortBtn.classList.remove('active');

          this.sortCatalogProducts(sortType);
        });
      });

      document.addEventListener('click', (e) => {
        if (!sortWrap?.contains(e.target)) {
          sortMenu.classList.remove('is-open');
          sortBtn.classList.remove('active');
        }
      });
    }
  },

  setupServerShopFilters() {
    const filterPanel = document.getElementById('shop-filter-panel');
    const mobileFilterToggle = document.getElementById('shop-mobile-filter-toggle');
    if (filterPanel && mobileFilterToggle) {
      filterPanel.classList.add('is-collapsible');
      mobileFilterToggle.addEventListener('click', () => {
        const isOpen = filterPanel.classList.toggle('is-open');
        mobileFilterToggle.setAttribute('aria-expanded', String(isOpen));
      });
    }
    const params = new URLSearchParams(window.location.search);
    const selected = key => new Set(params.getAll(key).flatMap(value => value.split(',')).map(value => value.trim().toLowerCase()).filter(v => v.length > 0));
    const colors = selected('color');
    const sizes = selected('size');
    const category = (params.get('category') || 'all').toLowerCase();
    const selectedBrands = selected('brand');
    selectedBrands.delete('all');
    let selectedCategory = params.get('category') || 'all';

    document.querySelectorAll('.filter-accordion-header').forEach(header => {
      const sectionName = header.textContent.trim().toLowerCase();
      const storageKey = `hc_filter_collapsed_${sectionName}`;
      if (sessionStorage.getItem(storageKey) === 'true') {
        header.classList.add('is-collapsed');
        header.nextElementSibling?.classList.add('is-hidden');
        header.setAttribute('aria-expanded', 'false');
      } else {
        header.setAttribute('aria-expanded', 'true');
      }

      const toggleSection = () => {
        const isCollapsed = header.classList.toggle('is-collapsed');
        header.nextElementSibling?.classList.toggle('is-hidden', isCollapsed);
        header.setAttribute('aria-expanded', String(!isCollapsed));
        sessionStorage.setItem(storageKey, String(isCollapsed));
      };

      header.addEventListener('click', toggleSection);
      header.addEventListener('keydown', e => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          toggleSection();
        }
      });
    });

    const colorButtons = [...document.querySelectorAll('.filter-color-swatch[data-color]')];
    const sizeButtons = [...document.querySelectorAll('.filter-size-pill[data-size]')];
    const toggle = button => {
      const active = button.classList.toggle('active');
      button.setAttribute('aria-pressed', String(active));
    };
    colorButtons.forEach(button => {
      if (colors.has(button.dataset.color.toLowerCase())) toggle(button);
      button.addEventListener('click', () => toggle(button));
    });
    sizeButtons.forEach(button => {
      if (sizes.has(button.dataset.size.toLowerCase())) toggle(button);
      button.addEventListener('click', () => toggle(button));
    });

    // Match the picker to the shades actually displayed in the filter.
    let pickerMatchedSwatch = null;
    const nearestColorSwatch = hex => {
      if (!/^#[0-9a-f]{6}$/i.test(hex)) return null;
      const target = [1, 3, 5].map(offset => parseInt(hex.slice(offset, offset + 2), 16));
      let nearest = null;
      let minimumDistance = Infinity;
      colorButtons.forEach(button => {
        const channels = getComputedStyle(button).backgroundColor.match(/[\d.]+/g);
        if (!channels || channels.length < 3) return;
        const distance = target.reduce((sum, channel, index) => sum + (channel - Number(channels[index])) ** 2, 0);
        if (distance < minimumDistance) { minimumDistance = distance; nearest = button; }
      });
      return nearest;
    };

    const colorPickerInput = document.getElementById('filter-color-picker-input');
    const colorPickerLabel = document.getElementById('swatch-color-picker-label');
    if (colorPickerInput && colorPickerLabel) {
      colorPickerInput.addEventListener('input', e => {
        const match = nearestColorSwatch(e.target.value);
        if (!match) return;
        if (pickerMatchedSwatch && pickerMatchedSwatch !== match) {
          pickerMatchedSwatch.classList.remove('active');
          pickerMatchedSwatch.setAttribute('aria-pressed', 'false');
        }
        match.classList.add('active');
        match.setAttribute('aria-pressed', 'true');
        pickerMatchedSwatch = match;
        // Only the standard swatch is selected; the picker keeps its normal appearance.
        colorPickerLabel.classList.remove('active');
        colorPickerLabel.removeAttribute('data-color');
        colorPickerLabel.removeAttribute('aria-pressed');
        colorPickerLabel.title = 'Custom Color Picker';
      });
    }

    const minSlider = document.getElementById('price-range-min');
    const maxSlider = document.getElementById('price-range-max');
    const minInput = document.getElementById('price-min-input');
    const maxInput = document.getElementById('price-max-input');
    const progressEl = document.getElementById('dual-range-progress');
    const initialMin = Number(params.get('minPrice'));
    const initialMax = Number(params.get('maxPrice'));
    if (minSlider && Number.isFinite(initialMin) && initialMin >= 0) minSlider.value = Math.min(initialMin, 99999);
    if (maxSlider && params.has('maxPrice') && Number.isFinite(initialMax)) maxSlider.value = Math.min(Math.max(initialMax, 1), 100000);

    const minGap = 1;

    const parseMin = () => {
      if (!minSlider) return 0;
      const v = Number(minSlider.value);
      return Number.isFinite(v) ? Math.max(0, Math.min(99999, v)) : 0;
    };

    const parseMax = () => {
      if (!maxSlider) return 100000;
      const v = Number(maxSlider.value);
      return Number.isFinite(v) && maxSlider.value !== '' ? Math.max(1, Math.min(100000, v)) : 100000;
    };

    const updateServerSliderProgress = () => {
      if (!minSlider || !maxSlider) return;
      let minVal = parseMin();
      let maxVal = parseMax();

      if (minVal >= maxVal) {
        minVal = Math.max(0, maxVal - minGap);
        minSlider.value = minVal;
      }

      const minPercent = Math.max(0, Math.min(100, (minVal / 100000) * 100));
      const maxPercent = Math.max(0, Math.min(100, (maxVal / 100000) * 100));

      if (progressEl) {
        progressEl.style.left = `${minPercent}%`;
        progressEl.style.right = `${100 - maxPercent}%`;
      }

      if (minInput && document.activeElement !== minInput) minInput.value = minVal;
      if (maxInput && document.activeElement !== maxInput) maxInput.value = maxVal;

      const minTitle = `Minimum Price: \u20B1${minVal.toLocaleString()}`;
      const maxTitle = `Maximum Price: \u20B1${maxVal.toLocaleString()}`;
      if (minSlider) minSlider.title = minTitle;
      if (maxSlider) maxSlider.title = maxTitle;
      if (minInput) minInput.title = minTitle;
      if (maxInput) maxInput.title = maxTitle;
    };

    minSlider?.addEventListener('input', () => {
      let minVal = parseMin();
      let maxVal = parseMax();
      if (minVal >= maxVal) {
        minVal = Math.max(0, maxVal - minGap);
        minSlider.value = minVal;
      }
      minSlider.style.zIndex = '4';
      if (maxSlider) maxSlider.style.zIndex = '3';
      updateServerSliderProgress();
    });

    maxSlider?.addEventListener('input', () => {
      let minVal = parseMin();
      let maxVal = parseMax();
      if (maxVal <= minVal) {
        maxVal = Math.min(100000, minVal + minGap);
        maxSlider.value = maxVal;
      }
      maxSlider.style.zIndex = '4';
      if (minSlider) minSlider.style.zIndex = '3';
      updateServerSliderProgress();
    });

    minInput?.addEventListener('input', () => {
      let val = Number(minInput.value);
      if (Number.isFinite(val) && minInput.value !== '') {
        let maxVal = parseMax();
        if (val >= maxVal) {
          val = Math.max(0, maxVal - minGap);
        }
        if (val < 0) val = 0;
        if (minSlider) minSlider.value = val;
        updateServerSliderProgress();
      }
    });

    minInput?.addEventListener('blur', () => {
      let val = Number(minInput.value);
      let maxVal = parseMax();
      if (isNaN(val) || val < 0 || minInput.value === '') val = 0;
      if (val >= maxVal) val = Math.max(0, maxVal - minGap);
      minInput.value = val;
      if (minSlider) minSlider.value = val;
      updateServerSliderProgress();
    });

    maxInput?.addEventListener('input', () => {
      let val = Number(maxInput.value);
      if (Number.isFinite(val) && maxInput.value !== '') {
        let minVal = parseMin();
        if (val <= minVal) {
          val = Math.min(100000, minVal + minGap);
        }
        if (val > 100000) val = 100000;
        if (maxSlider) maxSlider.value = val;
        updateServerSliderProgress();
      }
    });

    maxInput?.addEventListener('blur', () => {
      let val = Number(maxInput.value);
      let minVal = parseMin();
      if (isNaN(val) || val > 100000 || maxInput.value === '') val = 100000;
      if (val <= minVal) val = Math.min(100000, minVal + minGap);
      maxInput.value = val;
      if (maxSlider) maxSlider.value = val;
      updateServerSliderProgress();
    });

    updateServerSliderProgress();

    const buildUrl = () => {
      const url = new URL(window.location.href);
      if (selectedCategory.toLowerCase() === 'all') url.searchParams.delete('category');
      else url.searchParams.set('category', selectedCategory);

      url.searchParams.delete('brand');
      if (selectedBrands.size > 0 && !selectedBrands.has('all')) {
        selectedBrands.forEach(b => url.searchParams.append('brand', b));
      }

      url.searchParams.delete('color');
      url.searchParams.delete('size');
      const allActiveColors = [...document.querySelectorAll('.filter-color-swatch.active[data-color]')];
      allActiveColors.forEach(button => url.searchParams.append('color', button.dataset.color));
      sizeButtons.filter(button => button.classList.contains('active')).forEach(button => url.searchParams.append('size', button.dataset.size));
      if (minSlider && Number(minSlider.value) > 0) url.searchParams.set('minPrice', minSlider.value);
      else url.searchParams.delete('minPrice');
      if (maxSlider && Number(maxSlider.value) < 100000) url.searchParams.set('maxPrice', maxSlider.value);
      else url.searchParams.delete('maxPrice');
      url.searchParams.delete('page');
      return url;
    };
    const navigate = url => { window.location.href = url.toString(); };

    const categoryLinks = [...document.querySelectorAll('#filter-categories-container .filter-category-item')];
    const brandLinks = [...document.querySelectorAll('#filter-brands-container .filter-brand-btn')];
    const isAllBrands = () => selectedBrands.size === 0 || selectedBrands.has('all');

    const updateFilterSelection = () => {
      categoryLinks.forEach(link => link.classList.toggle('active', (link.dataset.category || 'all').toLowerCase() === selectedCategory.toLowerCase()));
      brandLinks.forEach(link => {
        const b = (link.dataset.brand || 'all').toLowerCase();
        if (b === 'all') {
          link.classList.toggle('active', isAllBrands());
        } else {
          link.classList.toggle('active', selectedBrands.has(b));
        }
      });
    };

    categoryLinks.forEach(link => {
      link.classList.toggle('active', (link.dataset.category || 'all').toLowerCase() === category);
      link.addEventListener('click', event => {
        event.preventDefault();
        selectedCategory = link.dataset.category || 'all';
        updateFilterSelection();
      });
    });

    brandLinks.forEach(link => {
      const b = (link.dataset.brand || 'all').toLowerCase();
      link.classList.toggle('active', b === 'all' ? isAllBrands() : selectedBrands.has(b));
      link.addEventListener('click', event => {
        event.preventDefault();
        if (b === 'all') {
          selectedBrands.clear();
        } else {
          if (selectedBrands.has(b)) {
            selectedBrands.delete(b);
          } else {
            selectedBrands.add(b);
          }
        }
        updateFilterSelection();
      });
    });

    document.getElementById('btn-apply-filters')?.addEventListener('click', () => navigate(buildUrl()));
    document.getElementById('btn-clear-all-filters')?.addEventListener('click', () => {
      selectedCategory = 'all';
      selectedBrands.clear();
      colorButtons.forEach(button => { button.classList.remove('active'); button.setAttribute('aria-pressed', 'false'); });
      if (colorPickerLabel) {
        colorPickerLabel.classList.remove('active');
        colorPickerLabel.removeAttribute('data-color');
        pickerMatchedSwatch = null;
        colorPickerLabel.title = 'Custom Color Picker';
      }
      sizeButtons.forEach(button => { button.classList.remove('active'); button.setAttribute('aria-pressed', 'false'); });
      if (minSlider) minSlider.value = minSlider.min;
      if (maxSlider) maxSlider.value = maxSlider.max;
      updateFilterSelection();
      updateServerSliderProgress();
      const url = buildUrl();
      url.searchParams.delete('ridingStyle');
      url.searchParams.delete('style');
      url.searchParams.delete('onSale');
      navigate(url);
    });

    const sortMenu = document.getElementById('shop-sort-menu');
    const sortBtn = document.getElementById('shop-sort-btn');
    const sortLabel = document.getElementById('current-sort-label');
    const activeSort = params.get('sortBy') || params.get('sort') || 'popular';
    sortMenu?.querySelectorAll('.shop-sort-option').forEach(option => {
      const active = option.dataset.sort === activeSort;
      option.classList.toggle('active', active);
      if (active && sortLabel) sortLabel.textContent = option.textContent.trim();
      option.addEventListener('click', () => {
        const url = new URL(window.location.href);
        if (option.dataset.sort === 'popular') url.searchParams.delete('sortBy');
        else url.searchParams.set('sortBy', option.dataset.sort);
        url.searchParams.delete('sort');
        url.searchParams.delete('page');
        navigate(url);
      });
    });
    sortBtn?.addEventListener('click', event => {
      event.stopPropagation();
      sortMenu?.classList.toggle('is-open');
      sortBtn.classList.toggle('active');
    });
    document.addEventListener('click', event => {
      if (!document.getElementById('shop-sort-dropdown-wrap')?.contains(event.target)) {
        sortMenu?.classList.remove('is-open');
        sortBtn?.classList.remove('active');
      }
    });
  },

  filterCatalogProducts() {
    let filtered = [...this.allProducts];

    // Filter Brand
    if (this.activeFilters.brand && this.activeFilters.brand.toLowerCase() !== 'all') {
      const targetBrand = this.activeFilters.brand.toLowerCase();
      filtered = filtered.filter(p => (p.brand || '').toLowerCase() === targetBrand);
    }

    // Filter Category
    if (this.activeFilters.category && this.activeFilters.category.toLowerCase() !== 'all') {
      const targetCat = this.activeFilters.category.toLowerCase();
      filtered = filtered.filter(p => {
        const cat = (p.category || '').toLowerCase();
        return cat.includes(targetCat) || targetCat.includes(cat);
      });
    }

    // Filter Riding Style
    if (this.activeFilters.style && this.activeFilters.style.toLowerCase() !== 'all') {
      const targetStyle = this.activeFilters.style.toLowerCase();
      filtered = filtered.filter(p => {
        const s = (p.ridingStyle || '').toLowerCase();
        return s.includes(targetStyle) || targetStyle.includes(s);
      });
    }

    // Filter Price
    const minP = this.activeFilters.minPrice || 0;
    const maxP = this.activeFilters.maxPrice || 100000;
    filtered = filtered.filter(p => {
      const price = p.basePrice || p.price || 0;
      return price >= minP && price <= maxP;
    });

    // Apply active sort
    filtered = this.sortProductArray(filtered, this.currentSort);

    this.currentProducts = filtered;
    this.renderCatalogGrid(filtered);
  },

  resetFilters() {
    this.activeFilters = {
      brand: 'all',
      category: 'all',
      style: 'all',
      minPrice: 0,
      maxPrice: 100000
    };

    document.querySelectorAll('#filter-brands-container .filter-brand-btn').forEach(b => {
      if (b.getAttribute('data-brand') === 'all') b.classList.add('active');
      else b.classList.remove('active');
    });

    document.querySelectorAll('#filter-categories-container .filter-category-item').forEach(i => {
      if (i.getAttribute('data-category') === 'all') i.classList.add('active');
      else i.classList.remove('active');
    });

    const minSlider = document.getElementById('price-range-min');
    const maxSlider = document.getElementById('price-range-max');
    const minInput = document.getElementById('price-min-input');
    const maxInput = document.getElementById('price-max-input');
    if (minSlider) minSlider.value = 0;
    if (maxSlider) maxSlider.value = 100000;
    if (minInput) minInput.value = 0;
    if (maxInput) maxInput.value = 100000;
    const progressEl = document.getElementById('dual-range-progress');
    if (progressEl) {
      progressEl.style.left = '0%';
      progressEl.style.right = '0%';
    }

    const url = new URL(window.location);
    url.searchParams.delete('brand');
    url.searchParams.delete('category');
    url.searchParams.delete('style');
    window.history.replaceState({}, '', url);

    this.filterCatalogProducts();
  },

  sortCatalogProducts(sortType) {
    this.currentSort = sortType;
    this.filterCatalogProducts();
    const sortText = document.getElementById('current-sort-label')?.textContent || sortType;
  },

  sortProductArray(items, sortType) {
    const list = [...items];
    switch (sortType) {
      case 'price-low':
        list.sort((a, b) => (a.basePrice || a.price || 0) - (b.basePrice || b.price || 0));
        break;
      case 'price-high':
        list.sort((a, b) => (b.basePrice || b.price || 0) - (a.basePrice || a.price || 0));
        break;
      case 'rating':
        list.sort((a, b) => (b.rating || 0) - (a.rating || 0));
        break;
      case 'newest':
        list.sort((a, b) => (b.id || 0) - (a.id || 0));
        break;
      case 'popular':
      default:
        list.sort((a, b) => (b.reviewCount || 0) - (a.reviewCount || 0));
        break;
    }
    return list;
  }
};

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    Storefront.init();
  });
} else {
  Storefront.init();
}
