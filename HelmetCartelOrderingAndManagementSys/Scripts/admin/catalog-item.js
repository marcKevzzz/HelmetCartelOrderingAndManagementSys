/**
 * Helmet Cartel - Catalog Item Full-Page Management Script
 * Implements:
 * 1. Clean slate form initialization & dirty state tracking.
 * 2. Predefined motorcycle color shades auto-detection & quick suggestion pills.
 * 3. Segmented pill toggles (Discount Status & Color Finish Type).
 * 4. Joined promotional discount input (Amount + % or ₱ selector).
 * 5. Smooth between-tile image drag-and-drop reordering with vertical insertion indicator.
 * 6. Responsive inline input validation (borders & visible error messages).
 * 7. Real-time pricing preview and Review & Confirm storefront card synchronization.
 */

(function () {
  'use strict';

  // Global State
  let isDirty = false;
  let colors = [];
  let variants = [];
  let gallery = [];
  let draggedTileIndex = null;
  let dropInsertBeforeIndex = null;

  // DOM Elements Cache (populated in init)
  let dom = {};

  // Standard Motorcycle Helmet Shade Library
  const helmetShades = [
    { name: 'Matte Black', hex: '#18181B' },
    { name: 'Jet Black', hex: '#000000' },
    { name: 'Graphite Gray', hex: '#3F3F46' },
    { name: 'Nardo Gray', hex: '#71717A' },
    { name: 'Silver Frost', hex: '#A1A1AA' },
    { name: 'Pearl White', hex: '#FFFFFF' },
    { name: 'Racing Red', hex: '#DC2626' },
    { name: 'Crimson Burgundy', hex: '#991B1B' },
    { name: 'KTM Orange', hex: '#EA580C' },
    { name: 'Hi-Vis Yellow', hex: '#EAB308' },
    { name: 'Neon Chartreuse', hex: '#84CC16' },
    { name: 'Kawasaki Green', hex: '#16A34A' },
    { name: 'Teal Pearl', hex: '#0D9488' },
    { name: 'Sky Blue', hex: '#38BDF8' },
    { name: 'Yamaha Blue', hex: '#2563EB' },
    { name: 'Deep Navy', hex: '#1E3A8A' },
    { name: 'Royal Purple', hex: '#7E22CE' },
    { name: 'Rose Gold', hex: '#BE7C68' }
  ];

  /* ==========================================================================
     STARTUP LIFECYCLE
     ========================================================================== */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeCatalogManager);
  } else {
    initializeCatalogManager();
  }

  function initializeCatalogManager() {
    cacheDomElements();
    initExistingData();
    bindPillToggles();
    bindPublicationActiveToggle();
    bindColorShadeSystem();
    bindSpecificationsEvents();
    bindPricingLivePreview();
    bindSlugAutoGeneration();
    bindGalleryInteractions();
    bindQuickModals();
    bindValidationEvents();
    bindDirtyTracking();

    // Ensure pristine clean dirty state after initial load
    isDirty = false;

    // Toast feedback if redirected after saving draft
    const urlParams = new URLSearchParams(window.location.search);
    const msg = urlParams.get('msg');
    if (msg === 'draft_saved' || msg === 'unpublished_saved') {
      if (typeof window.showAdminToast === 'function') {
        window.showAdminToast('Draft helmet model saved successfully.', 'success', 'Saved');
      }
    }
  }

  function cacheDomElements() {
    dom = {
      // Hidden ASP.NET State Fields
      hdnProductId: document.getElementById('hdnProductId'),
      hdnIsActive: document.getElementById('hdnIsActive'),
      hdnDiscountType: document.getElementById('hdnDiscountType'),
      hdnDiscountIsActive: document.getElementById('hdnDiscountIsActive'),
      hdnColorType: document.getElementById('hdnColorType'),
      hdnColorsJson: document.getElementById('hdnColorsJson'),
      hdnVariantsJson: document.getElementById('hdnVariantsJson'),
      hdnSpecificationsJson: document.getElementById('hdnSpecificationsJson'),
      hdnGalleryJson: document.getElementById('hdnGalleryJson'),
      hdnRedirectAfterSave: document.getElementById('hdnRedirectAfterSave'),

      // Tab 1 Elements
      ddlBrand: document.getElementById('ddlBrand'),
      ddlCategory: document.getElementById('ddlCategory'),
      txtProductName: document.getElementById('txtProductName'),
      txtSlug: document.getElementById('txtSlug'),
      txtDescription: document.getElementById('txtDescription'),

      // Tab 2 Elements
      specShellMaterial: document.getElementById('spec_shell_material'),
      specSafetyCertifications: document.getElementById('spec_safety_certifications'),
      specWeight: document.getElementById('spec_weight'),

      // Tab 3 Elements
      pillColorType: document.getElementById('pillColorTypeToggle'),
      rowSolidControls: document.getElementById('rowSolidControls'),
      rowGradientControls: document.getElementById('rowGradientControls'),
      pickerSolidColor: document.getElementById('pickerSolidColor'),
      txtSolidHex: document.getElementById('txtSolidHex'),
      txtColorName: document.getElementById('txtColorName'),
      btnAddColor: document.getElementById('btnAddColorToPalette'),
      pickerGradStop1: document.getElementById('pickerGradStop1'),
      pickerGradStop2: document.getElementById('pickerGradStop2'),
      txtGradAngle: document.getElementById('txtGradAngle'),
      gradPreviewSwatch: document.getElementById('gradPreviewSwatch'),
      txtGradColorName: document.getElementById('txtGradColorName'),
      btnAddGradient: document.getElementById('btnAddGradientToPalette'),
      paletteChipsContainer: document.getElementById('paletteChipsContainer'),
      tbodyVariantMatrix: document.getElementById('tbodyVariantMatrix'),
      sizesSelector: document.getElementById('sizesSelector'),

      // Tab 4 Elements
      txtBasePrice: document.getElementById('txtBasePrice'),
      txtDiscountValue: document.getElementById('txtDiscountValue'),
      ddlDiscountUnit: document.getElementById('ddlDiscountUnit'),
      pillDiscountStatus: document.getElementById('pillDiscountStatusToggle'),
      lblPreviewBase: document.getElementById('lblPreviewBasePrice'),
      lblPreviewDiscount: document.getElementById('lblPreviewDiscount'),
      lblPreviewEffective: document.getElementById('lblPreviewEffectivePrice'),

      // Tab 5 Elements
      imageDropzone: document.getElementById('imageDropzone'),
      fileImagePicker: document.getElementById('fileImagePicker'),
      galleryTilesGrid: document.getElementById('galleryTilesGrid'),
      galleryDropIndicator: document.getElementById('galleryDropIndicator'),
      galleryEmptyNotice: document.getElementById('galleryEmptyNotice'),
      txtMainImageUrl: document.getElementById('txtMainImageUrl'),
      btnToggleUrlInput: document.getElementById('btnToggleUrlInput'),
      rowAddByUrl: document.getElementById('rowAddByUrl'),
      txtAddImageUrl: document.getElementById('txtAddImageUrl'),
      btnConfirmAddUrl: document.getElementById('btnConfirmAddUrl'),
      btnCancelAddUrl: document.getElementById('btnCancelAddUrl'),

      // Top Actions & Navigation
      btnBackToCatalog: document.getElementById('btnBackToCatalog'),
      btnDiscard: document.getElementById('btnDiscard'),
      btnSaveDraft: document.getElementById('btnSaveDraft'),
      btnPublish: document.getElementById('btnPublish'),
      itemActiveToggle: document.getElementById('itemActiveToggle'),
      btnStatusActive: document.getElementById('btnStatusActive'),
      btnStatusInactive: document.getElementById('btnStatusInactive'),

      // Quick Modals & Unsaved Changes Confirmation Modal
      modalQuickBrand: document.getElementById('modalQuickBrand'),
      modalQuickCategory: document.getElementById('modalQuickCategory'),
      modalUnsavedChanges: document.getElementById('modalUnsavedChanges'),
      btnDiscardAndLeave: document.getElementById('btnDiscardAndLeave'),
      btnModalSaveDraft: document.getElementById('btnModalSaveDraft'),
      btnCancelLeave: document.getElementById('btnCancelLeave'),
      btnCloseUnsavedModal: document.getElementById('btnCloseUnsavedModal')
    };
  }

  /* ==========================================================================
     1. DATA INITIALIZATION FROM HIDDEN JSON FIELDS
     ========================================================================== */
  function initExistingData() {
    // 1. Technical Specs
    if (dom.hdnSpecificationsJson && dom.hdnSpecificationsJson.value) {
      try {
        const specs = JSON.parse(dom.hdnSpecificationsJson.value || '[]');
        if (Array.isArray(specs) && specs.length > 0) {
          specs.forEach((s) => {
            const key = (s.SpecificationKey || s.specificationKey || s.key || s.Key || '').toLowerCase();
            const val = s.SpecificationValue || s.specificationValue || s.value || s.Value || '';
            const input = document.querySelector(`.spec-field[data-spec-key="${key}"]`);
            if (input) {
              input.value = val;
            } else if (val) {
              addCustomSpecRow(s.DisplayName || s.displayName || key, val, key);
            }
          });
          serializeSpecifications();
        }
      } catch (e) {
        console.warn('Could not parse specifications:', e);
      }
    }

    // 2. Colors
    if (dom.hdnColorsJson && dom.hdnColorsJson.value) {
      try {
        const loadedColors = JSON.parse(dom.hdnColorsJson.value || '[]');
        if (Array.isArray(loadedColors) && loadedColors.length > 0) {
          colors = loadedColors.map((c) => ({
            id: c.Id || c.id || 0,
            name: c.Color || c.color || c.name || 'Standard',
            colorType: c.ColorType || c.colorType || 'SOLID',
            solidHex: c.SolidHex || c.solidHex || c.ColorHex || '#18181B',
            gradientAngle: c.GradientAngle || c.gradientAngle || 135,
            stops: c.Stops || c.stops || []
          }));
          renderPaletteChips();
        }
      } catch (e) {
        console.warn('Could not parse colors:', e);
      }
    }

    // 3. Variants
    if (dom.hdnVariantsJson && dom.hdnVariantsJson.value) {
      try {
        const loadedVariants = JSON.parse(dom.hdnVariantsJson.value || '[]');
        if (Array.isArray(loadedVariants) && loadedVariants.length > 0) {
          const currentBase = parseFloat(dom.txtBasePrice ? dom.txtBasePrice.value : 0) || 0;
          variants = loadedVariants.map((v) => {
            const adj = v.PriceAdjustment || v.priceAdjustment || 0;
            const itemPrice = (v.Price || v.price) ? (v.Price || v.price) : (currentBase + adj);
            return {
              id: v.Id || v.id || 0,
              productColorId: v.ProductColorId || v.productColorId || 0,
              color: v.Color || v.color || '',
              colorHex: v.ColorHex || v.colorHex || '',
              size: v.Size || v.size || 'M',
              sku: v.SKU || v.sku || '',
              price: itemPrice,
              priceAdjustment: adj,
              initialStock: v.CurrentStock || v.currentStock || v.initialStock || 0,
              reorderPoint: v.ReorderPoint || v.reorderPoint || 3,
              isActive: (v.IsActive !== false && v.isActive !== false)
            };
          });
          const existingSizes = new Set(variants.map((v) => v.size));
          document.querySelectorAll('.admin-size-pill').forEach((pill) => {
            const hasSize = existingSizes.has(pill.dataset.size);
            pill.classList.toggle('is-active', hasSize);
            pill.setAttribute('aria-pressed', hasSize ? 'true' : 'false');
          });
          renderVariantMatrix();
          renderPricingMatrix();
        }
      } catch (e) {
        console.warn('Could not parse variants:', e);
      }
    }

    // 4. Gallery Images
    if (dom.hdnGalleryJson && dom.hdnGalleryJson.value) {
      try {
        const loadedGallery = JSON.parse(dom.hdnGalleryJson.value || '[]');
        if (Array.isArray(loadedGallery) && loadedGallery.length > 0) {
          gallery = loadedGallery.map((g) => ({
            id: g.Id || g.id || 0,
            url: g.ImageUrl || g.imageUrl || g.url || '',
            alt: g.AltText || g.altText || ''
          }));
        }
      } catch (e) {
        console.warn('Could not parse gallery:', e);
      }
    }

    // Ensure all size pills start unselected on a clean slate if no variants
    if (variants.length === 0) {
      document.querySelectorAll('.admin-size-pill').forEach((pill) => {
        pill.classList.remove('is-active');
        pill.setAttribute('aria-pressed', 'false');
      });
    }

    updateStatusBadge();
    renderGalleryTiles();
    renderPricingMatrix();
    updatePricingPreview();
  }

  function resetFormState() {
    isDirty = false;

    // Reset standard form inputs
    if (dom.txtProductName) dom.txtProductName.value = '';
    if (dom.txtSlug) dom.txtSlug.value = '';
    if (dom.txtDescription) dom.txtDescription.value = '';
    if (dom.ddlBrand) dom.ddlBrand.selectedIndex = 0;
    if (dom.ddlCategory) dom.ddlCategory.selectedIndex = 0;

    // Reset specs
    document.querySelectorAll('.spec-field').forEach((input) => {
      input.value = '';
      input.classList.remove('is-invalid');
    });
    const customContainer = document.getElementById('customSpecsContainer');
    if (customContainer) customContainer.innerHTML = '';

    // Reset pricing
    if (dom.txtBasePrice) dom.txtBasePrice.value = '';
    if (dom.txtDiscountValue) dom.txtDiscountValue.value = '0';
    if (dom.ddlDiscountUnit) dom.ddlDiscountUnit.value = 'Percentage';

    // Reset arrays
    colors = [];
    variants = [];
    gallery = [];

    // Reset size pills to unselected
    document.querySelectorAll('.admin-size-pill').forEach((pill) => {
      pill.classList.remove('is-active');
      pill.setAttribute('aria-pressed', 'false');
    });

    renderPaletteChips();
    syncVariantsWithColors();
    renderGalleryTiles();
    updatePricingPreview();

    // Reset main image & hidden json payloads
    if (dom.txtMainImageUrl) dom.txtMainImageUrl.value = '';
    if (dom.hdnSpecificationsJson) dom.hdnSpecificationsJson.value = '[]';
    if (dom.hdnColorsJson) dom.hdnColorsJson.value = '[]';
    if (dom.hdnVariantsJson) dom.hdnVariantsJson.value = '[]';
    if (dom.hdnGalleryJson) dom.hdnGalleryJson.value = '[]';
    if (dom.hdnProductId) dom.hdnProductId.value = '0';

    // Clear all inline errors
    document.querySelectorAll('.inline-error-msg').forEach((span) => {
      span.style.display = 'none';
    });
    document.querySelectorAll('.is-invalid').forEach((el) => {
      el.classList.remove('is-invalid');
    });

    updateStatusBadge('not_saved');

    // Reset to step 1
    if (window.switchWizardTab) window.switchWizardTab(1);
  }

  function updateStatusBadge(overrideState) {
    const badge = document.getElementById('badgePublishStatus');
    if (!badge) return;

    const isActive = dom.hdnIsActive && dom.hdnIsActive.value === '1';

    if (overrideState === 'published') {
      badge.className = 'admin-item-status-pill is-published';
      badge.textContent = isActive ? 'PUBLISHED' : 'PUBLISHED (Inactive)';
      return;
    }
    if (overrideState === 'saved') {
      badge.className = 'admin-item-status-pill is-draft';
      badge.textContent = 'DRAFT (Saved)';
      return;
    }
    if (overrideState === 'not_saved') {
      badge.className = 'admin-item-status-pill is-draft';
      badge.textContent = 'DRAFT (Not Saved)';
      return;
    }

    const pid = dom.hdnProductId ? parseInt(dom.hdnProductId.value, 10) : 0;
    const isDraftItem = (window.isCatalogItemDraft !== undefined)
      ? window.isCatalogItemDraft
      : (pid === 0 || !dom.btnStatusActive);

    if (!isDraftItem) {
      badge.className = 'admin-item-status-pill is-published';
      badge.textContent = isActive ? 'PUBLISHED' : 'PUBLISHED (Inactive)';
    } else if (pid > 0 && !isDirty) {
      badge.className = 'admin-item-status-pill is-draft';
      badge.textContent = 'DRAFT (Saved)';
    } else {
      badge.className = 'admin-item-status-pill is-draft';
      badge.textContent = 'DRAFT (Not Saved)';
    }
  }

  function bindPublicationActiveToggle() {
    if (!dom.btnStatusActive || !dom.btnStatusInactive) return;

    dom.btnStatusActive.addEventListener('click', () => {
      dom.btnStatusActive.classList.add('is-active');
      dom.btnStatusInactive.classList.remove('is-active');
      if (dom.hdnIsActive) dom.hdnIsActive.value = '1';
      isDirty = true;
      updateStatusBadge('published');
    });

    dom.btnStatusInactive.addEventListener('click', () => {
      dom.btnStatusInactive.classList.add('is-active');
      dom.btnStatusActive.classList.remove('is-active');
      if (dom.hdnIsActive) dom.hdnIsActive.value = '0';
      isDirty = true;
      updateStatusBadge('published');
    });
  }

  /* ==========================================================================
     2. DIRTY STATE & DISCARD GUARD
     ========================================================================== */
  function bindDirtyTracking() {
    const markDirty = () => {
      isDirty = true;
      const isActive = dom.hdnIsActive && dom.hdnIsActive.value === '1';
      if (!isActive) {
        updateStatusBadge('not_saved');
      }
    };
    document.querySelectorAll('.admin-wizard-page input, .admin-wizard-page select, .admin-wizard-page textarea').forEach((el) => {
      el.addEventListener('input', markDirty);
      el.addEventListener('change', markDirty);
    });

    let pendingLeaveUrl = '/Pages/Admin/Catalog/Catalog.aspx';

    const getCatalogUrl = () => {
      if (document.referrer && document.referrer.includes('/Catalog/Catalog.aspx')) {
        return document.referrer;
      }
      return '/Pages/Admin/Catalog/Catalog.aspx' + (window.isCatalogItemDraft ? '?tab=drafts' : '');
    };

    const attemptLeavePage = (targetUrl, e) => {
      if (e && e.preventDefault) e.preventDefault();
      pendingLeaveUrl = targetUrl || getCatalogUrl();
      if (isDirty) {
        if (dom.modalUnsavedChanges) dom.modalUnsavedChanges.classList.remove('is-hidden');
      } else {
        window.location.href = pendingLeaveUrl;
      }
    };

    if (dom.btnBackToCatalog) {
      dom.btnBackToCatalog.addEventListener('click', (e) => {
        if (e && e.preventDefault) e.preventDefault();
        window.location.href = getCatalogUrl();
      });
    }

    if (dom.btnDiscard) {
      dom.btnDiscard.addEventListener('click', (e) => {
        if (e && e.preventDefault) e.preventDefault();
        window.location.href = getCatalogUrl();
      });
    }

    // Intercept sidebar navigation links and topbar links if changes are unsaved
    document.querySelectorAll('.admin-nav-link, .admin-sidebar a, .admin-topbar-breadcrumb a, .admin-user-menu a').forEach((link) => {
      link.addEventListener('click', (e) => {
        const href = link.getAttribute('href');
        if (href && !href.startsWith('#') && !href.startsWith('javascript:')) {
          if (isDirty) {
            attemptLeavePage(href, e);
          }
        }
      });
    });

    if (dom.btnCancelLeave) {
      dom.btnCancelLeave.addEventListener('click', () => {
        if (dom.modalUnsavedChanges) dom.modalUnsavedChanges.classList.add('is-hidden');
      });
    }
    if (dom.btnCloseUnsavedModal) {
      dom.btnCloseUnsavedModal.addEventListener('click', () => {
        if (dom.modalUnsavedChanges) dom.modalUnsavedChanges.classList.add('is-hidden');
      });
    }
    if (dom.btnDiscardAndLeave) {
      dom.btnDiscardAndLeave.addEventListener('click', () => {
        isDirty = false;
        window.location.href = pendingLeaveUrl || '/Pages/Admin/Catalog/Catalog.aspx';
      });
    }
    if (dom.btnModalSaveDraft) {
      dom.btnModalSaveDraft.addEventListener('click', (e) => {
        if (dom.modalUnsavedChanges) dom.modalUnsavedChanges.classList.add('is-hidden');
        isDirty = false;
        if (dom.hdnRedirectAfterSave) dom.hdnRedirectAfterSave.value = pendingLeaveUrl || '/Pages/Admin/Catalog/Catalog.aspx';
        window.triggerDraftSubmit();
      });
    }

    if (dom.btnSaveDraft) {
      dom.btnSaveDraft.addEventListener('click', () => {
        isDirty = false;
        if (dom.hdnRedirectAfterSave) dom.hdnRedirectAfterSave.value = '';
      });
    }
    if (dom.btnPublish) {
      dom.btnPublish.addEventListener('click', () => {
        isDirty = false;
        if (dom.hdnRedirectAfterSave) dom.hdnRedirectAfterSave.value = '';
      });
    }

    window.addEventListener('beforeunload', (e) => {
      if (isDirty) {
        e.preventDefault();
        e.returnValue = '';
      }
    });
  }

  /* ==========================================================================
     3. SEGMENTED PILL TOGGLES (Discount Status & Color Finish Type)
     ========================================================================== */
  function bindPillToggles() {
    // 1. Finish Type Toggle: SOLID / GRADIENT
    if (dom.pillColorType) {
      const segments = dom.pillColorType.querySelectorAll('.admin-pill-segment');
      segments.forEach((btn) => {
        btn.addEventListener('click', () => {
          segments.forEach((s) => {
            s.classList.remove('is-active');
            s.setAttribute('aria-checked', 'false');
          });
          btn.classList.add('is-active');
          btn.setAttribute('aria-checked', 'true');

          const val = btn.dataset.val;
          if (dom.hdnColorType) dom.hdnColorType.value = val;

          if (val === 'LinearGradient') {
            if (dom.rowSolidControls) dom.rowSolidControls.classList.add('is-hidden');
            if (dom.rowGradientControls) dom.rowGradientControls.classList.remove('is-hidden');
            updateGradColorName();
          } else {
            if (dom.rowSolidControls) dom.rowSolidControls.classList.remove('is-hidden');
            if (dom.rowGradientControls) dom.rowGradientControls.classList.add('is-hidden');
          }
          isDirty = true;
        });
      });
    }

    // 2. Discount Status Toggle: ACTIVE / INACTIVE
    if (dom.pillDiscountStatus) {
      const segments = dom.pillDiscountStatus.querySelectorAll('.admin-pill-segment');
      segments.forEach((btn) => {
        btn.addEventListener('click', () => {
          segments.forEach((s) => {
            s.classList.remove('is-active');
            s.setAttribute('aria-checked', 'false');
          });
          btn.classList.add('is-active');
          btn.setAttribute('aria-checked', 'true');

          const val = btn.dataset.val;
          if (dom.hdnDiscountIsActive) dom.hdnDiscountIsActive.value = val;
          updatePricingPreview();
          isDirty = true;
        });
      });
    }
  }

  /* ==========================================================================
     4. PREDEFINED COLOR SHADES & AUTO-SUGGESTION SYSTEM
     ========================================================================== */
  function bindColorShadeSystem() {
    // Solid Color Picker & Hex Sync
    if (dom.pickerSolidColor && dom.txtSolidHex) {
      dom.pickerSolidColor.addEventListener('input', () => {
        const hex = dom.pickerSolidColor.value.toUpperCase();
        dom.txtSolidHex.value = hex;
        autoSuggestColorName(hex);
      });

      dom.txtSolidHex.addEventListener('input', () => {
        let val = dom.txtSolidHex.value.trim().toUpperCase();
        if (!val.startsWith('#') && val.length > 0) val = '#' + val;
        if (/^#[0-9A-F]{6}$/i.test(val)) {
          dom.pickerSolidColor.value = val;
          autoSuggestColorName(val);
        }
      });
    }

    // Gradient Stops Sync
    const updateGradPreview = () => {
      if (dom.gradPreviewSwatch && dom.pickerGradStop1 && dom.pickerGradStop2 && dom.txtGradAngle) {
        const angle = dom.txtGradAngle.value || 135;
        dom.gradPreviewSwatch.style.background = `linear-gradient(${angle}deg, ${dom.pickerGradStop1.value}, ${dom.pickerGradStop2.value})`;
        updateGradColorName();
      }
    };

    if (dom.pickerGradStop1) dom.pickerGradStop1.addEventListener('input', updateGradPreview);
    if (dom.pickerGradStop2) dom.pickerGradStop2.addEventListener('input', updateGradPreview);
    if (dom.txtGradAngle) dom.txtGradAngle.addEventListener('input', updateGradPreview);

    // Add Solid Color to Palette
    if (dom.btnAddColor) {
      dom.btnAddColor.addEventListener('click', () => {
        const colorName = dom.txtColorName ? dom.txtColorName.value.trim() : '';
        const hex = dom.txtSolidHex ? dom.txtSolidHex.value.trim().toUpperCase() : '#18181B';

        if (!colorName) {
          showAdminToast('Please enter or select a colorway name (e.g. Matte Black).', 'warning', 'Color Name Required');
          if (dom.txtColorName) dom.txtColorName.focus();
          return;
        }

        if (colors.some((c) => c.name.toLowerCase() === colorName.toLowerCase())) {
          showAdminToast(`Colorway "${colorName}" is already in the palette.`, 'warning', 'Duplicate Colorway');
          return;
        }

        colors.push({
          id: 0,
          name: colorName,
          colorType: 'SOLID',
          solidHex: hex,
          stops: []
        });

        if (dom.txtColorName) dom.txtColorName.value = '';
        renderPaletteChips();
        syncVariantsWithColors();
        clearInlineError('errColors');
        isDirty = true;
      });
    }

    // Add Gradient Color to Palette
    if (dom.btnAddGradient) {
      dom.btnAddGradient.addEventListener('click', () => {
        const colorName = dom.txtGradColorName ? dom.txtGradColorName.value.trim() : '';
        const hex1 = dom.pickerGradStop1 ? dom.pickerGradStop1.value.toUpperCase() : '#DC2626';
        const hex2 = dom.pickerGradStop2 ? dom.pickerGradStop2.value.toUpperCase() : '#18181B';
        const angle = dom.txtGradAngle ? parseInt(dom.txtGradAngle.value, 10) || 135 : 135;

        if (!colorName) {
          showAdminToast('Please enter a gradient colorway name (e.g. Crimson to Stealth Fade).', 'warning', 'Color Name Required');
          if (dom.txtGradColorName) dom.txtGradColorName.focus();
          return;
        }

        if (colors.some((c) => c.name.toLowerCase() === colorName.toLowerCase())) {
          showAdminToast(`Colorway "${colorName}" is already in the palette.`, 'warning', 'Duplicate Colorway');
          return;
        }

        colors.push({
          id: 0,
          name: colorName,
          colorType: 'LINEAR_GRADIENT',
          solidHex: hex1,
          gradientAngle: angle,
          stops: [hex1, hex2]
        });

        if (dom.txtGradColorName) dom.txtGradColorName.value = '';
        renderPaletteChips();
        syncVariantsWithColors();
        clearInlineError('errColors');
        isDirty = true;
      });
    }

    // Size Selector Pill Toggles (Black pill when on, muted when off)
    document.querySelectorAll('.admin-size-pill').forEach((pill) => {
      pill.addEventListener('click', () => {
        const isActive = pill.classList.toggle('is-active');
        pill.setAttribute('aria-pressed', isActive ? 'true' : 'false');
        syncVariantsWithColors();
        clearInlineError('errVariants');
        if (document.querySelectorAll('.admin-size-pill.is-active').length > 0) {
          clearInlineError('errSizes');
        }
        isDirty = true;
      });
    });
  }

  function autoSuggestColorName(hex) {
    if (!dom.txtColorName) return;
    const suggested = getNearestShadeName(hex);
    dom.txtColorName.value = suggested;
  }

  function updateGradColorName() {
    if (!dom.txtGradColorName || !dom.pickerGradStop1 || !dom.pickerGradStop2) return;
    const name1 = getNearestShadeName(dom.pickerGradStop1.value);
    const name2 = getNearestShadeName(dom.pickerGradStop2.value);
    dom.txtGradColorName.value = `${name1} to ${name2} Fade`;
  }

  function getNearestShadeName(hex) {
    const rgb = hexToRgb(hex);
    if (!rgb) return 'Custom Shade';

    let nearestName = 'Matte Black';
    let minDistance = Infinity;

    helmetShades.forEach((shade) => {
      const sRgb = hexToRgb(shade.hex);
      if (sRgb) {
        const dist = Math.pow(rgb.r - sRgb.r, 2) + Math.pow(rgb.g - sRgb.g, 2) + Math.pow(rgb.b - sRgb.b, 2);
        if (dist < minDistance) {
          minDistance = dist;
          nearestName = shade.name;
        }
      }
    });

    return nearestName;
  }

  function hexToRgb(hex) {
    const clean = String(hex || '').replace('#', '');
    if (!/^[0-9A-Fa-f]{6}$/.test(clean)) return null;
    return {
      r: parseInt(clean.substring(0, 2), 16),
      g: parseInt(clean.substring(2, 4), 16),
      b: parseInt(clean.substring(4, 6), 16)
    };
  }

  function renderPaletteChips() {
    if (!dom.paletteChipsContainer) return;
    dom.paletteChipsContainer.innerHTML = '';

    if (colors.length === 0) {
      dom.paletteChipsContainer.innerHTML = '<span class="admin-palette-empty" id="msgEmptyPalette">No colors added yet. Select a shade or create a custom colorway below.</span>';
      serializeColors();
      return;
    }

    colors.forEach((c, idx) => {
      const chip = document.createElement('div');
      chip.className = 'admin-palette-chip';

      const swatch = document.createElement('span');
      swatch.className = 'admin-palette-chip-swatch';
      if (c.colorType === 'LINEAR_GRADIENT' && c.stops && c.stops.length >= 2) {
        swatch.style.background = `linear-gradient(${c.gradientAngle || 135}deg, ${c.stops[0]}, ${c.stops[1]})`;
      } else {
        swatch.style.background = c.solidHex || '#18181B';
      }

      const text = document.createElement('span');
      text.className = 'admin-palette-chip-name';
      text.textContent = c.name;

      const removeBtn = document.createElement('button');
      removeBtn.type = 'button';
      removeBtn.className = 'admin-palette-chip-remove';
      removeBtn.innerHTML = '&times;';
      removeBtn.title = `Remove ${c.name}`;
      removeBtn.addEventListener('click', () => {
        colors.splice(idx, 1);
        renderPaletteChips();
        syncVariantsWithColors();
        isDirty = true;
      });

      chip.appendChild(swatch);
      chip.appendChild(text);
      chip.appendChild(removeBtn);
      dom.paletteChipsContainer.appendChild(chip);
    });

    serializeColors();
  }

  function syncVariantsWithColors() {
    const activeSizes = Array.from(document.querySelectorAll('.admin-size-pill.is-active')).map((p) => p.dataset.size);
    const brandText = dom.ddlBrand && dom.ddlBrand.selectedIndex > 0 ? dom.ddlBrand.options[dom.ddlBrand.selectedIndex].text : 'HC';
    const modelText = dom.txtProductName ? dom.txtProductName.value : 'HELMET';

    const brandCode = brandText.replace(/[^A-Za-z0-9]/g, '').substring(0, 3).toUpperCase() || 'HC';
    const modelCode = modelText.replace(/[^A-Za-z0-9]/g, '').substring(0, 4).toUpperCase() || 'MOD';

    const updatedVariants = [];

    colors.forEach((color) => {
      const colorCode = color.name.replace(/[^A-Za-z0-9]/g, '').substring(0, 3).toUpperCase();

      activeSizes.forEach((size) => {
        const existing = variants.find((v) => v.color.toLowerCase() === color.name.toLowerCase() && v.size === size);

        if (existing) {
          updatedVariants.push(existing);
        } else {
          const autoSku = `${brandCode}-${modelCode}-${colorCode}-${size}`;
          const currentBase = parseFloat(dom.txtBasePrice ? dom.txtBasePrice.value : 0) || 0;
          updatedVariants.push({
            id: 0,
            productColorId: color.id || 0,
            color: color.name,
            colorHex: color.colorType === 'LINEAR_GRADIENT' && color.stops && color.stops.length > 0 ? color.stops[0] : (color.solidHex || '#18181B'),
            size: size,
            sku: autoSku,
            price: currentBase,
            priceAdjustment: 0.00,
            initialStock: 0,
            reorderPoint: 3,
            isActive: true
          });
        }
      });
    });

    variants = updatedVariants;
    renderVariantMatrix();
    renderPricingMatrix();
  }

  function renderVariantMatrix() {
    const container = document.getElementById('variantPillsContainer') || dom.tbodyVariantMatrix;
    if (!container) return;
    container.innerHTML = '';

    const countBadge = document.getElementById('lblVariantMatrixCount');
    if (countBadge) {
      countBadge.textContent = `${variants.length} combinations`;
    }

    if (variants.length === 0) {
      container.innerHTML = `
        <span class="admin-empty-cell-msg" id="msgEmptyVariants">
          Add at least one color and select sizes above to generate variant pills.
        </span>`;
      serializeVariants();
      return;
    }

    variants.forEach((v, index) => {
      const pill = document.createElement('div');
      pill.className = 'admin-variant-item-pill';

      // Color Swatch
      const swatch = document.createElement('span');
      swatch.className = 'admin-variant-pill-swatch';
      swatch.style.background = v.colorHex || '#18181B';

      // Color Name
      const label = document.createElement('span');
      label.className = 'admin-variant-pill-label';
      label.textContent = v.color;

      // Size Badge
      const sizeBadge = document.createElement('span');
      sizeBadge.className = 'admin-variant-pill-size';
      sizeBadge.textContent = v.size;

      // SKU Input
      const inputSku = document.createElement('input');
      inputSku.type = 'text';
      inputSku.className = 'admin-variant-pill-sku-input';
      inputSku.value = v.sku;
      inputSku.title = 'SKU (Auto-generated or custom)';
      inputSku.placeholder = 'SKU...';
      inputSku.required = true;
      inputSku.addEventListener('input', () => {
        v.sku = inputSku.value.trim();
        if (v.sku) inputSku.classList.remove('is-invalid');
        isDirty = true;
        serializeVariants();
        renderPricingMatrix();
      });

      // Remove Button
      const btnRemove = document.createElement('button');
      btnRemove.type = 'button';
      btnRemove.className = 'admin-variant-pill-remove';
      btnRemove.innerHTML = '&times;';
      btnRemove.title = `Remove ${v.color} - ${v.size}`;
      btnRemove.addEventListener('click', () => {
        variants.splice(index, 1);
        renderVariantMatrix();
        renderPricingMatrix();
        isDirty = true;
      });


      const isVarActive = v.isActive !== false;
      if (!isVarActive) {
        pill.classList.add('is-inactive');
      }

      pill.appendChild(swatch);
      pill.appendChild(label);
      pill.appendChild(sizeBadge);
      pill.appendChild(inputSku);
      pill.appendChild(btnRemove);

      container.appendChild(pill);
    });

    serializeVariants();
  }

  function renderPricingMatrix() {
    const tbody = document.getElementById('tbodyPricingMatrix');
    if (!tbody) return;
    tbody.innerHTML = '';

    if (variants.length === 0) {
      tbody.innerHTML = `
        <tr id="rowEmptyPricingMatrix">
          <td colspan="6" class="admin-empty-cell-msg">
            Configure colors and sizes in the Variants step to generate pricing matrix.
          </td>
        </tr>`;
      return;
    }

    const currentBasePrice = parseFloat(dom.txtBasePrice ? dom.txtBasePrice.value : 0) || 0;

    variants.forEach((v) => {
      if (typeof v.price === 'undefined' || v.price === null || v.price === 0) {
        v.price = (currentBasePrice > 0 ? currentBasePrice : 0) + (v.priceAdjustment || 0);
      }

      const tr = document.createElement('tr');
      const isVarActive = v.isActive !== false;
      if (!isVarActive) {
        tr.classList.add('is-row-inactive');
      }

      // Variant (Color & Size)
      const tdVariant = document.createElement('td');
      tdVariant.innerHTML = `
        <div class="admin-matrix-cell-color">
          <span style="display:inline-block;width:14px;height:14px;border-radius:var(--radius-pill);background:${v.colorHex || '#18181B'};border:1px solid var(--color-border-subtle);"></span>
          <span style="font-weight:var(--weight-medium);">${escapeHtml(v.color)} &bull; <strong>${v.size}</strong></span>
        </div>`;

      // SKU Readonly/Display
      const tdSku = document.createElement('td');
      tdSku.innerHTML = `<code style="font-size:var(--font-xs);font-weight:var(--weight-semibold);">${escapeHtml(v.sku)}</code>`;

      // Price Input
      const tdPrice = document.createElement('td');
      const inputPrice = document.createElement('input');
      inputPrice.type = 'number';
      inputPrice.step = '0.01';
      inputPrice.min = '0';
      inputPrice.className = 'admin-form-input admin-matrix-input admin-matrix-input--price';
      inputPrice.value = (v.price || 0) > 0 ? v.price : '';
      inputPrice.placeholder = '0.00';
      inputPrice.addEventListener('input', () => {
        v.price = parseFloat(inputPrice.value) || 0;
        syncBasePriceFromVariants();
        if (v.price > 0) inputPrice.classList.remove('is-invalid');
        isDirty = true;
        serializeVariants();
        updatePricingPreview();
      });
      tdPrice.appendChild(inputPrice);

      // Initial Stock Input
      const tdStock = document.createElement('td');
      const inputStock = document.createElement('input');
      inputStock.type = 'number';
      inputStock.min = '0';
      inputStock.className = 'admin-form-input admin-matrix-input admin-matrix-input--stock';
      inputStock.value = v.initialStock || 0;
      inputStock.style.width = '90px';
      inputStock.addEventListener('input', () => {
        v.initialStock = parseInt(inputStock.value, 10) || 0;
        isDirty = true;
        serializeVariants();
        updateReviewSummary();
      });
      tdStock.appendChild(inputStock);

      // Reorder Point Input
      const tdReorder = document.createElement('td');
      const inputReorder = document.createElement('input');
      inputReorder.type = 'number';
      inputReorder.min = '0';
      inputReorder.className = 'admin-form-input admin-matrix-input admin-matrix-input--reorder';
      inputReorder.value = v.reorderPoint || 3;
      inputReorder.style.width = '90px';
      inputReorder.addEventListener('input', () => {
        v.reorderPoint = parseInt(inputReorder.value, 10) || 3;
        isDirty = true;
        serializeVariants();
      });
      tdReorder.appendChild(inputReorder);

      // Status Toggle (Single Click)
      const tdStatus = document.createElement('td');
      const btnStatus = document.createElement('button');
      btnStatus.type = 'button';
      btnStatus.className = `admin-variant-status-btn ${isVarActive ? 'is-active' : 'is-inactive'}`;
      btnStatus.innerHTML = isVarActive
        ? '<span>Active</span>'
        : '<span>Inactive</span>';
      btnStatus.title = isVarActive ? 'Click to deactivate variant' : 'Click to activate variant';
      btnStatus.addEventListener('click', () => {
        v.isActive = !isVarActive;
        isDirty = true;
        serializeVariants();
        renderPricingMatrix();
        renderVariantMatrix();
        updateReviewSummary();
      });
      tdStatus.appendChild(btnStatus);

      tr.appendChild(tdVariant);
      tr.appendChild(tdSku);
      tr.appendChild(tdPrice);
      tr.appendChild(tdStock);
      tr.appendChild(tdReorder);
      tr.appendChild(tdStatus);

      tbody.appendChild(tr);
    });

    syncBasePriceFromVariants();
  }

  function syncBasePriceFromVariants() {
    if (!variants || variants.length === 0) return;
    const activeVariants = variants.filter(v => v.isActive !== false);
    const candidateVariants = activeVariants.length > 0 ? activeVariants : variants;
    const validPrices = candidateVariants.map(v => v.price || 0).filter(p => p > 0);
    if (validPrices.length > 0) {
      const minPrice = Math.min(...validPrices);
      if (dom.txtBasePrice) {
        dom.txtBasePrice.value = minPrice.toFixed(2);
      }
      variants.forEach(v => {
        v.priceAdjustment = Math.max(0, (v.price || minPrice) - minPrice);
      });
    }
  }

  function serializeColors() {
    if (dom.hdnColorsJson) dom.hdnColorsJson.value = JSON.stringify(colors);
  }

  function serializeVariants() {
    if (dom.hdnVariantsJson) dom.hdnVariantsJson.value = JSON.stringify(variants);
  }

  /* ==========================================================================
     5. TECHNICAL SPECIFICATIONS & CUSTOM SPECS
     ========================================================================== */
  function bindSpecificationsEvents() {
    const btnAddCustom = document.getElementById('btnAddCustomSpec');
    if (btnAddCustom) {
      btnAddCustom.addEventListener('click', () => {
        addCustomSpecRow('', '', '');
        isDirty = true;
      });
    }

    document.querySelectorAll('.spec-field').forEach((input) => {
      const handler = () => {
        serializeSpecifications();
        isDirty = true;
      };
      input.addEventListener('input', handler);
      input.addEventListener('change', handler);
    });
  }

  function addCustomSpecRow(name, val, key) {
    const container = document.getElementById('customSpecsContainer');
    if (!container) return;

    const row = document.createElement('div');
    row.className = 'admin-custom-spec-row';
    if (key) {
      row.setAttribute('data-spec-key', key);
    }

    const inputName = document.createElement('input');
    inputName.type = 'text';
    inputName.className = 'admin-form-input custom-spec-name';
    inputName.placeholder = 'Specification Label (e.g. Pinlock System)';
    inputName.value = name || '';

    const inputValue = document.createElement('input');
    inputValue.type = 'text';
    inputValue.className = 'admin-form-input custom-spec-val';
    inputValue.placeholder = 'Specification Value (e.g. Pinlock 120 MaxVision Included)';
    inputValue.value = val || '';

    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.className = 'admin-spec-remove-btn';
    removeBtn.innerHTML = '&times;';
    removeBtn.title = 'Remove specification';

    const updateHandler = () => {
      if (inputName.value.trim() && inputValue.value.trim()) {
        inputName.classList.remove('is-invalid');
        inputValue.classList.remove('is-invalid');
        clearInlineError('errCustomSpecs');
      }
      serializeSpecifications();
      isDirty = true;
    };
    inputName.addEventListener('input', () => {
      row.removeAttribute('data-spec-key');
      updateHandler();
    });
    inputValue.addEventListener('input', updateHandler);

    inputName.addEventListener('blur', () => {
      if (inputValue.value.trim() && !inputName.value.trim()) {
        inputName.classList.add('is-invalid');
        showInlineError('errCustomSpecs');
      }
    });

    inputValue.addEventListener('blur', () => {
      if (inputName.value.trim() && !inputValue.value.trim()) {
        inputValue.classList.add('is-invalid');
        showInlineError('errCustomSpecs');
      }
    });

    removeBtn.addEventListener('click', () => {
      row.remove();
      serializeSpecifications();
      const anyInvalid = document.querySelector('.admin-custom-spec-row .is-invalid');
      if (!anyInvalid) clearInlineError('errCustomSpecs');
      isDirty = true;
    });

    row.appendChild(inputName);
    row.appendChild(inputValue);
    row.appendChild(removeBtn);
    container.appendChild(row);

    serializeSpecifications();
  }

  function serializeSpecifications() {
    const list = [];

    document.querySelectorAll('.spec-field').forEach((input) => {
      const v = input.value.trim();
      if (v) {
        const specKey = input.getAttribute('data-spec-key') || (input.dataset ? input.dataset.specKey : null) || '';
        const displayName = input.getAttribute('data-display-name') || (input.dataset ? input.dataset.displayName : null) || specKey;
        list.push({
          key: specKey,
          SpecificationKey: specKey,
          name: displayName,
          DisplayName: displayName,
          value: v,
          SpecificationValue: v
        });
      }
    });

    document.querySelectorAll('.admin-custom-spec-row').forEach((row) => {
      const nInput = row.querySelector('.custom-spec-name');
      const vInput = row.querySelector('.custom-spec-val');
      const n = nInput ? nInput.value.trim() : '';
      const v = vInput ? vInput.value.trim() : '';
      if (n && v) {
        const specKey = row.getAttribute('data-spec-key') || generateSlug(n).replace(/-/g, '_') || 'custom_spec';
        list.push({
          key: specKey,
          SpecificationKey: specKey,
          name: n,
          DisplayName: n,
          value: v,
          SpecificationValue: v
        });
      }
    });

    if (dom.hdnSpecificationsJson) {
      dom.hdnSpecificationsJson.value = JSON.stringify(list);
    }
  }

  /* ==========================================================================
     6. PRICING & PROMOTION LIVE PREVIEW
     ========================================================================== */
  function bindPricingLivePreview() {
    if (dom.txtBasePrice) dom.txtBasePrice.addEventListener('input', updatePricingPreview);
    if (dom.txtDiscountValue) dom.txtDiscountValue.addEventListener('input', updatePricingPreview);
    if (dom.ddlDiscountUnit) {
      dom.ddlDiscountUnit.addEventListener('change', () => {
        if (dom.hdnDiscountType) dom.hdnDiscountType.value = dom.ddlDiscountUnit.value;
        updatePricingPreview();
      });
    }
  }

  function updatePricingPreview() {
    const base = parseFloat(dom.txtBasePrice ? dom.txtBasePrice.value : 0) || 0;
    const discountVal = parseFloat(dom.txtDiscountValue ? dom.txtDiscountValue.value : 0) || 0;
    const unit = dom.ddlDiscountUnit ? dom.ddlDiscountUnit.value : 'Percentage';
    const isActive = dom.hdnDiscountIsActive ? (dom.hdnDiscountIsActive.value === 'Active' || dom.hdnDiscountIsActive.value === 'True') : true;

    let discountDisplay = '(No discount applied)';
    let effective = base;

    if (isActive && discountVal > 0) {
      if (unit === 'FixedAmount') {
        effective = Math.max(0, base - discountVal);
        discountDisplay = `(-₱${discountVal.toLocaleString('en-PH', { minimumFractionDigits: 0, maximumFractionDigits: 0 })})`;
      } else {
        const pct = Math.min(90, Math.max(0, discountVal));
        effective = Math.max(0, base * (1 - (pct / 100)));
        discountDisplay = `(-${pct}%)`;
      }
    }

    if (dom.lblPreviewDiscount) dom.lblPreviewDiscount.textContent = discountDisplay;
    if (dom.lblPreviewEffective) dom.lblPreviewEffective.textContent = `₱${effective.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  }

  /* ==========================================================================
     7. SLUG AUTO-GENERATION
     ========================================================================== */
  function bindSlugAutoGeneration() {
    let slugManualEdit = Boolean(dom.txtSlug && dom.txtSlug.value.trim().length > 0 && dom.hdnProductId && dom.hdnProductId.value !== '0');

    if (dom.txtSlug) {
      dom.txtSlug.addEventListener('input', () => {
        slugManualEdit = dom.txtSlug.value.trim().length > 0;
      });
    }

    if (dom.txtProductName) {
      dom.txtProductName.addEventListener('input', () => {
        if (!slugManualEdit && dom.txtSlug) {
          dom.txtSlug.value = generateSlug(dom.txtProductName.value);
        }
      });
    }
  }

  function generateSlug(text) {
    if (!text) return '';
    return text.toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .trim();
  }

  /* ==========================================================================
     8. MEDIA GALLERY & SMOOTH BETWEEN-TILE DRAG-AND-DROP
     ========================================================================== */
  function bindGalleryInteractions() {
    // 1. Dropzone click to trigger hidden file input
    if (dom.imageDropzone && dom.fileImagePicker) {
      dom.imageDropzone.addEventListener('click', () => {
        dom.fileImagePicker.click();
      });

      dom.fileImagePicker.addEventListener('change', (e) => {
        if (e.target.files && e.target.files.length > 0) {
          handleIncomingFiles(e.target.files);
        }
      });
    }

    // 2. Dropzone drag & drop
    if (dom.imageDropzone) {
      dom.imageDropzone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dom.imageDropzone.classList.add('is-dragover');
      });

      dom.imageDropzone.addEventListener('dragleave', () => {
        dom.imageDropzone.classList.remove('is-dragover');
      });

      dom.imageDropzone.addEventListener('drop', (e) => {
        e.preventDefault();
        dom.imageDropzone.classList.remove('is-dragover');
        if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
          handleIncomingFiles(e.dataTransfer.files);
        }
      });
    }

    // 3. Optional Add Image from URL Toggle & Actions
    if (dom.btnToggleUrlInput && dom.rowAddByUrl) {
      dom.btnToggleUrlInput.addEventListener('click', () => {
        dom.rowAddByUrl.classList.toggle('is-hidden');
        if (!dom.rowAddByUrl.classList.contains('is-hidden') && dom.txtAddImageUrl) {
          dom.txtAddImageUrl.focus();
        }
      });
    }

    if (dom.btnCancelAddUrl && dom.rowAddByUrl) {
      dom.btnCancelAddUrl.addEventListener('click', () => {
        dom.rowAddByUrl.classList.add('is-hidden');
      });
    }

    if (dom.btnConfirmAddUrl && dom.txtAddImageUrl) {
      dom.btnConfirmAddUrl.addEventListener('click', () => {
        const url = dom.txtAddImageUrl.value.trim();
        if (!url) {
          showAdminToast('Please enter a valid image web URL.', 'warning', 'Invalid Image URL');
          dom.txtAddImageUrl.focus();
          return;
        }

        gallery.push({
          id: 0,
          url: url,
          alt: `Gallery View #${gallery.length + 1}`
        });

        dom.txtAddImageUrl.value = '';
        if (dom.rowAddByUrl) dom.rowAddByUrl.classList.add('is-hidden');
        renderGalleryTiles();
        clearInlineError('errGalleryImages');
        isDirty = true;
      });
    }

    // 4. Smooth Between-Tile Insertion Drag-and-Drop
    if (dom.galleryTilesGrid && dom.galleryDropIndicator) {
      const resetTileTransforms = () => {
        if (!dom.galleryTilesGrid) return;
        dom.galleryTilesGrid.querySelectorAll('.admin-upload-tile').forEach((t) => {
          t.classList.remove('is-shifted-right');
        });
      };

      dom.galleryTilesGrid.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';

        const tiles = Array.from(dom.galleryTilesGrid.querySelectorAll('.admin-upload-tile'));
        if (tiles.length === 0 || draggedTileIndex === null) {
          dom.galleryDropIndicator.classList.remove('is-visible');
          resetTileTransforms();
          return;
        }

        const gridRect = dom.galleryTilesGrid.getBoundingClientRect();
        let closestTile = null;
        let closestDist = Infinity;
        let insertBefore = true;

        tiles.forEach((tile) => {
          const idx = parseInt(tile.dataset.index, 10);
          if (idx === draggedTileIndex) return;

          const rect = tile.getBoundingClientRect();
          const midX = rect.left + rect.width / 2;
          const midY = rect.top + rect.height / 2;
          const dist = Math.hypot(e.clientX - midX, e.clientY - midY);

          if (dist < closestDist) {
            closestDist = dist;
            closestTile = tile;
            insertBefore = e.clientX < midX;
          }
        });

        if (closestTile) {
          const cIdx = parseInt(closestTile.dataset.index, 10);
          const targetSlot = insertBefore ? cIdx : cIdx + 1;
          dropInsertBeforeIndex = targetSlot;

          const rect = closestTile.getBoundingClientRect();
          const indicatorY = rect.top - gridRect.top;
          const indicatorH = rect.height;
          const indicatorX = insertBefore
            ? (rect.left - gridRect.left - 6)
            : (rect.right - gridRect.left + 2);

          dom.galleryDropIndicator.style.top = `${indicatorY}px`;
          dom.galleryDropIndicator.style.height = `${indicatorH}px`;
          dom.galleryDropIndicator.style.left = `${Math.max(2, indicatorX)}px`;
          dom.galleryDropIndicator.classList.add('is-visible');

          // Smoothly shift subsequent tiles right to visually open up space for the indicator
          tiles.forEach((t) => {
            const tIdx = parseInt(t.dataset.index, 10);
            if (tIdx === draggedTileIndex) return;

            if (tIdx >= targetSlot) {
              t.classList.add('is-shifted-right');
            } else {
              t.classList.remove('is-shifted-right');
            }
          });
        }
      });

      dom.galleryTilesGrid.addEventListener('dragleave', (e) => {
        if (!dom.galleryTilesGrid.contains(e.relatedTarget)) {
          if (dom.galleryDropIndicator) dom.galleryDropIndicator.classList.remove('is-visible');
          resetTileTransforms();
        }
      });

      dom.galleryTilesGrid.addEventListener('drop', (e) => {
        e.preventDefault();
        if (dom.galleryDropIndicator) dom.galleryDropIndicator.classList.remove('is-visible');
        resetTileTransforms();

        // Handle image tile reordering
        if (draggedTileIndex !== null && dropInsertBeforeIndex !== null) {
          const fromIdx = draggedTileIndex;
          let toIdx = dropInsertBeforeIndex;
          if (fromIdx < toIdx) {
            toIdx--;
          }
          if (fromIdx !== toIdx && fromIdx >= 0 && fromIdx < gallery.length && toIdx >= 0 && toIdx < gallery.length) {
            const movedItem = gallery.splice(fromIdx, 1)[0];
            gallery.splice(toIdx, 0, movedItem);
            renderGalleryTiles();
            isDirty = true;
          }
        }

        draggedTileIndex = null;
        dropInsertBeforeIndex = null;
      });
    }
  }

  function optimizeImageFile(file, maxWidth = 1600, maxHeight = 1600, quality = 0.85) {
    return new Promise((resolve) => {
      if (file.type === 'image/gif' || file.type === 'image/svg+xml') {
        const reader = new FileReader();
        reader.onload = (e) => resolve(e.target.result);
        reader.readAsDataURL(file);
        return;
      }

      const img = new Image();
      const objectUrl = URL.createObjectURL(file);
      img.onload = () => {
        URL.revokeObjectURL(objectUrl);
        let width = img.naturalWidth || img.width;
        let height = img.naturalHeight || img.height;

        if (width > maxWidth || height > maxHeight) {
          if (width > height) {
            height = Math.round((height * maxWidth) / width);
            width = maxWidth;
          } else {
            width = Math.round((width * maxHeight) / height);
            height = maxHeight;
          }
        }

        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, width, height);

        const outType = file.type === 'image/png' ? 'image/png' : 'image/jpeg';
        const dataUrl = canvas.toDataURL(outType, quality);
        resolve(dataUrl);
      };
      img.onerror = () => {
        URL.revokeObjectURL(objectUrl);
        const reader = new FileReader();
        reader.onload = (e) => resolve(e.target.result);
        reader.readAsDataURL(file);
      };
      img.src = objectUrl;
    });
  }

  async function handleIncomingFiles(fileList) {
    for (const file of Array.from(fileList)) {
      if (!file.type || !file.type.startsWith('image/')) continue;
      try {
        const optimizedUrl = await optimizeImageFile(file);
        gallery.push({
          id: 0,
          url: optimizedUrl,
          alt: file.name
        });
        renderGalleryTiles();
        clearInlineError('errGalleryImages');
        isDirty = true;
      } catch (err) {
        console.warn('Error optimizing image:', err);
      }
    }
  }

  function renderGalleryTiles() {
    if (!dom.galleryTilesGrid) return;

    // Remove existing tiles
    dom.galleryTilesGrid.querySelectorAll('.admin-upload-tile').forEach((t) => t.remove());

    if (gallery.length === 0) {
      if (dom.galleryEmptyNotice) dom.galleryEmptyNotice.style.display = 'block';
      if (dom.txtMainImageUrl) dom.txtMainImageUrl.value = '';
      serializeGallery();
      updateReviewSummary();
      return;
    }

    if (dom.galleryEmptyNotice) dom.galleryEmptyNotice.style.display = 'none';

    // The first image is always designated as primary
    if (dom.txtMainImageUrl) dom.txtMainImageUrl.value = gallery[0].url;

    gallery.forEach((img, idx) => {
      const tile = document.createElement('div');
      tile.className = `admin-upload-tile ${idx === 0 ? 'is-primary' : ''}`;
      tile.draggable = true;
      tile.dataset.index = idx;

      const imgEl = document.createElement('img');
      imgEl.src = img.url;
      imgEl.alt = img.alt || `Gallery angle ${idx + 1}`;
      imgEl.onerror = () => { imgEl.src = '/Content/images/placeholder-helmet.png'; };

      const badge = document.createElement('span');
      badge.className = 'admin-upload-tile-badge';
      badge.textContent = idx === 0 ? 'Primary' : `#${idx + 1}`;

      const removeBtn = document.createElement('button');
      removeBtn.type = 'button';
      removeBtn.className = 'admin-upload-tile-remove';
      removeBtn.innerHTML = '&times;';
      removeBtn.title = 'Remove image';
      removeBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        gallery.splice(idx, 1);
        renderGalleryTiles();
        isDirty = true;
      });

      // Drag Events
      tile.addEventListener('dragstart', (e) => {
        draggedTileIndex = idx;
        tile.classList.add('is-dragging');
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', idx);
      });

      tile.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
      });

      tile.addEventListener('dragenter', (e) => {
        e.preventDefault();
      });

      tile.addEventListener('dragend', () => {
        tile.classList.remove('is-dragging');
        if (dom.galleryDropIndicator) dom.galleryDropIndicator.classList.remove('is-visible');
        if (dom.galleryTilesGrid) {
          dom.galleryTilesGrid.querySelectorAll('.admin-upload-tile').forEach((t) => t.classList.remove('is-shifted-right'));
        }
        draggedTileIndex = null;
        dropInsertBeforeIndex = null;
      });

      tile.appendChild(imgEl);
      tile.appendChild(badge);
      tile.appendChild(removeBtn);
      dom.galleryTilesGrid.appendChild(tile);
    });

    serializeGallery();
    updateReviewSummary();
  }

  function serializeGallery() {
    if (dom.hdnGalleryJson) dom.hdnGalleryJson.value = JSON.stringify(gallery);
  }

  /* ==========================================================================
     9. QUICK ADD BRAND & CATEGORY MODALS
     ========================================================================== */
  function bindQuickModals() {
    // Quick Add Brand
    const btnOpenBrand = document.getElementById('btnOpenAddBrandModal');
    const btnCloseBrand = document.getElementById('btnCloseQuickBrand');
    const btnCancelBrand = document.getElementById('btnCancelQuickBrand');
    const btnSaveBrand = document.getElementById('btnSaveQuickBrand');
    const txtBrandName = document.getElementById('txtQuickBrandName');
    const txtBrandWeb = document.getElementById('txtQuickBrandWebsite');
    const errBrandName = document.getElementById('errQuickBrandName');

    if (btnOpenBrand && dom.modalQuickBrand) {
      btnOpenBrand.addEventListener('click', () => {
        dom.modalQuickBrand.classList.remove('is-hidden');
        if (txtBrandName) {
          txtBrandName.value = '';
          txtBrandName.classList.remove('is-invalid');
          txtBrandName.focus();
        }
        if (txtBrandWeb) txtBrandWeb.value = '';
        if (errBrandName) errBrandName.style.display = 'none';
      });
    }

    const closeBrandModal = () => {
      if (dom.modalQuickBrand) dom.modalQuickBrand.classList.add('is-hidden');
    };
    if (btnCloseBrand) btnCloseBrand.addEventListener('click', closeBrandModal);
    if (btnCancelBrand) btnCancelBrand.addEventListener('click', closeBrandModal);

    if (btnSaveBrand) {
      btnSaveBrand.addEventListener('click', async () => {
        const name = txtBrandName ? txtBrandName.value.trim() : '';
        if (!name) {
          if (txtBrandName) txtBrandName.classList.add('is-invalid');
          if (errBrandName) errBrandName.style.display = 'block';
          return;
        }

        btnSaveBrand.disabled = true;
        btnSaveBrand.textContent = 'Saving...';

        try {
          const res = await fetch('/api/v1/admin/catalog/brands', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-Requested-With': 'XMLHttpRequest'
            },
            body: JSON.stringify({
              Id: 0,
              Name: name,
              Website: txtBrandWeb ? txtBrandWeb.value.trim() : '',
              IsActive: true
            })
          });

          if (!res.ok) {
            const errText = await res.text();
            throw new Error(errText || 'Failed to create brand.');
          }

          const data = await res.json();
          const newBrandId = (data && data.data && data.data[0] && data.data[0].id) || data.id || 'NEW';

          if (dom.ddlBrand) {
            const opt = document.createElement('option');
            opt.value = newBrandId;
            opt.textContent = name;
            opt.selected = true;
            dom.ddlBrand.appendChild(opt);
            clearInlineError('errBrand');
          }

          closeBrandModal();
          showAdminToast(`Brand "${name}" added successfully.`);
        } catch (err) {
          showAdminToast(err.message || 'Error saving brand.', 'error', 'Brand Save Failed');
        } finally {
          btnSaveBrand.disabled = false;
          btnSaveBrand.textContent = 'Save Brand';
        }
      });
    }

    // Quick Add Category
    const btnOpenCat = document.getElementById('btnOpenAddCategoryModal');
    const btnCloseCat = document.getElementById('btnCloseQuickCategory');
    const btnCancelCat = document.getElementById('btnCancelQuickCategory');
    const btnSaveCat = document.getElementById('btnSaveQuickCategory');
    const txtCatName = document.getElementById('txtQuickCategoryName');
    const txtCatSlug = document.getElementById('txtQuickCategorySlug');
    const txtCatDesc = document.getElementById('txtQuickCategoryDesc');
    const errCatName = document.getElementById('errQuickCategoryName');

    if (btnOpenCat && dom.modalQuickCategory) {
      btnOpenCat.addEventListener('click', () => {
        dom.modalQuickCategory.classList.remove('is-hidden');
        if (txtCatName) {
          txtCatName.value = '';
          txtCatName.classList.remove('is-invalid');
          txtCatName.focus();
        }
        if (txtCatSlug) txtCatSlug.value = '';
        if (txtCatDesc) txtCatDesc.value = '';
        if (errCatName) errCatName.style.display = 'none';
      });
    }

    if (txtCatName && txtCatSlug) {
      txtCatName.addEventListener('input', () => {
        txtCatSlug.value = generateSlug(txtCatName.value);
      });
    }

    const closeCatModal = () => {
      if (dom.modalQuickCategory) dom.modalQuickCategory.classList.add('is-hidden');
    };
    if (btnCloseCat) btnCloseCat.addEventListener('click', closeCatModal);
    if (btnCancelCat) btnCancelCat.addEventListener('click', closeCatModal);

    if (btnSaveCat) {
      btnSaveCat.addEventListener('click', async () => {
        const name = txtCatName ? txtCatName.value.trim() : '';
        if (!name) {
          if (txtCatName) txtCatName.classList.add('is-invalid');
          if (errCatName) errCatName.style.display = 'block';
          return;
        }

        btnSaveCat.disabled = true;
        btnSaveCat.textContent = 'Saving...';

        try {
          const res = await fetch('/api/v1/admin/catalog/categories', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-Requested-With': 'XMLHttpRequest'
            },
            body: JSON.stringify({
              Id: 0,
              Name: name,
              Slug: txtCatSlug ? txtCatSlug.value.trim() : generateSlug(name),
              Description: txtCatDesc ? txtCatDesc.value.trim() : '',
              DisplayOrder: 99,
              IsActive: true
            })
          });

          if (!res.ok) {
            const errText = await res.text();
            throw new Error(errText || 'Failed to create category.');
          }

          const data = await res.json();
          const newCatId = (data && data.data && data.data[0] && data.data[0].id) || data.id || 'NEW';

          if (dom.ddlCategory) {
            const opt = document.createElement('option');
            opt.value = newCatId;
            opt.textContent = name;
            opt.selected = true;
            dom.ddlCategory.appendChild(opt);
            clearInlineError('errCategory');
          }

          closeCatModal();
          showAdminToast(`Category "${name}" added successfully.`);
        } catch (err) {
          showAdminToast(err.message || 'Error saving category.', 'error', 'Category Save Failed');
        } finally {
          btnSaveCat.disabled = false;
          btnSaveCat.textContent = 'Save Category';
        }
      });
    }
  }

  /* ==========================================================================
     10. COMPREHENSIVE INLINE VALIDATION & FORM SUBMISSION
     ========================================================================== */
  function bindValidationEvents() {
    // Tab 1 field blur/input clearers
    if (dom.ddlBrand) {
      dom.ddlBrand.addEventListener('change', () => {
        if (dom.ddlBrand.value) clearInlineError('errBrand');
      });
    }
    if (dom.ddlCategory) {
      dom.ddlCategory.addEventListener('change', () => {
        if (dom.ddlCategory.value) clearInlineError('errCategory');
      });
    }
    if (dom.txtProductName) {
      dom.txtProductName.addEventListener('input', () => {
        if (dom.txtProductName.value.trim()) clearInlineError('errProductName');
      });
    }
    if (dom.txtDescription) {
      dom.txtDescription.addEventListener('input', () => {
        if (dom.txtDescription.value.trim()) clearInlineError('errDescription');
      });
    }

    // Tab 2 Spec clearers
    if (dom.specShellMaterial) {
      dom.specShellMaterial.addEventListener('input', () => {
        if (dom.specShellMaterial.value.trim()) clearInlineError('errSpecShellMaterial');
      });
    }
    if (dom.specSafetyCertifications) {
      dom.specSafetyCertifications.addEventListener('input', () => {
        if (dom.specSafetyCertifications.value.trim()) clearInlineError('errSpecSafetyCertifications');
      });
    }
    if (dom.specWeight) {
      dom.specWeight.addEventListener('input', () => {
        if (dom.specWeight.value.trim()) clearInlineError('errSpecWeight');
      });
    }

    // Tab 4 Base Price clearer
    if (dom.txtBasePrice) {
      dom.txtBasePrice.addEventListener('input', () => {
        const val = parseFloat(dom.txtBasePrice.value);
        if (!isNaN(val) && val > 0) clearInlineError('errBasePrice');
      });
    }

    // Submission handlers
    if (dom.btnSaveDraft) dom.btnSaveDraft.addEventListener('click', (e) => handleFormSubmit(e, true));
    if (dom.btnPublish) dom.btnPublish.addEventListener('click', (e) => handleFormSubmit(e, false));
  }

  function validateStep(stepNumber) {
    let isValid = true;
    let firstInvalidEl = null;

    if (stepNumber === 1) {
      // 1. Brand
      if (!dom.ddlBrand || !dom.ddlBrand.value) {
        showInlineError('errBrand', dom.ddlBrand);
        isValid = false;
        if (!firstInvalidEl) firstInvalidEl = dom.ddlBrand;
      } else {
        clearInlineError('errBrand');
      }

      // 2. Category
      if (!dom.ddlCategory || !dom.ddlCategory.value) {
        showInlineError('errCategory', dom.ddlCategory);
        isValid = false;
        if (!firstInvalidEl) firstInvalidEl = dom.ddlCategory;
      } else {
        clearInlineError('errCategory');
      }

      // 3. Name
      if (!dom.txtProductName || !dom.txtProductName.value.trim()) {
        showInlineError('errProductName', dom.txtProductName);
        isValid = false;
        if (!firstInvalidEl) firstInvalidEl = dom.txtProductName;
      } else {
        clearInlineError('errProductName');
      }

      // 4. Description
      if (!dom.txtDescription || !dom.txtDescription.value.trim()) {
        showInlineError('errDescription', dom.txtDescription);
        isValid = false;
        if (!firstInvalidEl) firstInvalidEl = dom.txtDescription;
      } else {
        clearInlineError('errDescription');
      }
    } else if (stepNumber === 2) {
      // 1. Shell Material
      if (!dom.specShellMaterial || !dom.specShellMaterial.value.trim()) {
        showInlineError('errSpecShellMaterial', dom.specShellMaterial);
        isValid = false;
        if (!firstInvalidEl) firstInvalidEl = dom.specShellMaterial;
      } else {
        clearInlineError('errSpecShellMaterial');
      }

      // 2. Safety Certifications
      if (!dom.specSafetyCertifications || !dom.specSafetyCertifications.value.trim()) {
        showInlineError('errSpecSafetyCertifications', dom.specSafetyCertifications);
        isValid = false;
        if (!firstInvalidEl) firstInvalidEl = dom.specSafetyCertifications;
      } else {
        clearInlineError('errSpecSafetyCertifications');
      }

      // 3. Weight
      if (!dom.specWeight || !dom.specWeight.value.trim()) {
        showInlineError('errSpecWeight', dom.specWeight);
        isValid = false;
        if (!firstInvalidEl) firstInvalidEl = dom.specWeight;
      } else {
        clearInlineError('errSpecWeight');
      }

      // 4. Custom Specifications Validation
      const customRows = document.querySelectorAll('.admin-custom-spec-row');
      let hasInvalidCustom = false;
      customRows.forEach((row) => {
        const nInput = row.querySelector('.custom-spec-name');
        const vInput = row.querySelector('.custom-spec-val');
        const n = nInput ? nInput.value.trim() : '';
        const v = vInput ? vInput.value.trim() : '';

        if (!n || !v) {
          hasInvalidCustom = true;
          if (!n && nInput) {
            nInput.classList.add('is-invalid');
            if (!firstInvalidEl) firstInvalidEl = nInput;
          }
          if (!v && vInput) {
            vInput.classList.add('is-invalid');
            if (!firstInvalidEl) firstInvalidEl = vInput;
          }
        } else {
          if (nInput) nInput.classList.remove('is-invalid');
          if (vInput) vInput.classList.remove('is-invalid');
        }
      });

      if (hasInvalidCustom) {
        showInlineError('errCustomSpecs');
        isValid = false;
      } else {
        clearInlineError('errCustomSpecs');
      }
    } else if (stepNumber === 3) {
      // Colors Palette
      if (colors.length === 0) {
        showInlineError('errColors');
        isValid = false;
      } else {
        clearInlineError('errColors');
      }

      // Sizes Selector
      const activeSizes = document.querySelectorAll('.admin-size-pill.is-active');
      if (activeSizes.length === 0) {
        showInlineError('errSizes');
        isValid = false;
        if (!firstInvalidEl) firstInvalidEl = dom.sizesSelector;
      } else {
        clearInlineError('errSizes');
      }

      // Variants & SKUs
      if (variants.length === 0) {
        showInlineError('errVariants');
        isValid = false;
      } else {
        const missingSkuInput = dom.tbodyVariantMatrix ? dom.tbodyVariantMatrix.querySelector('.admin-matrix-input[value=""]') : null;
        const hasEmptySku = variants.some((v) => !v.sku || !v.sku.trim());
        if (hasEmptySku) {
          showInlineError('errVariants');
          isValid = false;
          if (missingSkuInput) {
            missingSkuInput.classList.add('is-invalid');
            if (!firstInvalidEl) firstInvalidEl = missingSkuInput;
          }
        } else {
          clearInlineError('errVariants');
        }
      }
    } else if (stepNumber === 4) {
      // Pricing Matrix Validation (every configured variant must have price > 0)
      syncBasePriceFromVariants();
      const basePrice = parseFloat(dom.txtBasePrice ? dom.txtBasePrice.value : 0);
      const invalidVariantPrice = variants.some(v => typeof v.price === 'undefined' || v.price === null || isNaN(v.price) || v.price <= 0);

      if (variants.length === 0 || invalidVariantPrice || isNaN(basePrice) || basePrice <= 0) {
        showInlineError('errPricingMatrix');
        isValid = false;
        const invalidInput = document.querySelector('#tablePricingMatrix .admin-matrix-input--price');
        if (!firstInvalidEl) firstInvalidEl = invalidInput;
      } else {
        clearInlineError('errPricingMatrix');
      }
    } else if (stepNumber === 5) {
      // Images
      if (gallery.length === 0) {
        showInlineError('errGalleryImages', dom.imageDropzone);
        isValid = false;
        if (!firstInvalidEl) firstInvalidEl = dom.imageDropzone;
      } else {
        clearInlineError('errGalleryImages');
      }
    }

    if (!isValid && firstInvalidEl) {
      firstInvalidEl.focus();
    }

    return isValid;
  }

  function showInlineError(errorSpanId, inputEl) {
    const span = document.getElementById(errorSpanId);
    if (span) span.style.display = 'block';
    if (inputEl) inputEl.classList.add('is-invalid');
  }

  function clearInlineError(errorSpanId) {
    const span = document.getElementById(errorSpanId);
    if (span) span.style.display = 'none';

    if (errorSpanId === 'errBrand' && dom.ddlBrand) dom.ddlBrand.classList.remove('is-invalid');
    if (errorSpanId === 'errCategory' && dom.ddlCategory) dom.ddlCategory.classList.remove('is-invalid');
    if (errorSpanId === 'errProductName' && dom.txtProductName) dom.txtProductName.classList.remove('is-invalid');
    if (errorSpanId === 'errDescription' && dom.txtDescription) dom.txtDescription.classList.remove('is-invalid');
    if (errorSpanId === 'errSpecShellMaterial' && dom.specShellMaterial) dom.specShellMaterial.classList.remove('is-invalid');
    if (errorSpanId === 'errSpecSafetyCertifications' && dom.specSafetyCertifications) dom.specSafetyCertifications.classList.remove('is-invalid');
    if (errorSpanId === 'errSpecWeight' && dom.specWeight) dom.specWeight.classList.remove('is-invalid');
    if (errorSpanId === 'errCustomSpecs') {
      const span = document.getElementById('errCustomSpecs');
      if (span) span.style.display = 'none';
      document.querySelectorAll('.admin-custom-spec-row input').forEach((inp) => inp.classList.remove('is-invalid'));
    }
    if (errorSpanId === 'errSizes') {
      const span = document.getElementById('errSizes');
      if (span) span.style.display = 'none';
    }
    if (errorSpanId === 'errBasePrice' && dom.txtBasePrice) dom.txtBasePrice.classList.remove('is-invalid');
    if (errorSpanId === 'errGalleryImages' && dom.imageDropzone) dom.imageDropzone.classList.remove('is-invalid');
  }

  function handleFormSubmit(e, isDraftMode) {
    // In Draft mode, require at least Helmet Name and Brand
    if (isDraftMode) {
      if (!dom.txtProductName || !dom.txtProductName.value.trim()) {
        e.preventDefault();
        window.switchWizardTab(1);
        showInlineError('errProductName', dom.txtProductName);
        dom.txtProductName.focus();
        return false;
      }
    } else {
      // Full publish requires all steps 1, 2, 3, 4, 5
      for (let s of [1, 2, 3, 4, 5]) {
        if (!validateStep(s)) {
          e.preventDefault();
          window.switchWizardTab(s);
          return false;
        }
      }
    }

    // Serialize all data
    serializeColors();
    serializeVariants();
    serializeSpecifications();
    serializeGallery();

    if (gallery.length > 0 && dom.txtMainImageUrl) {
      dom.txtMainImageUrl.value = gallery[0].url;
    }

    isDirty = false;
    return true;
  }

  window.triggerDraftSubmit = function () {
    if (!handleFormSubmit(null, true)) return;
    isDirty = false;
    const target = dom.btnSaveDraft;
    if (typeof __doPostBack === 'function' && target) {
      __doPostBack(target.id, '');
    } else if (target) {
      target.click();
    }
  };

  window.triggerPublishSubmit = function () {
    if (!handleFormSubmit(null, false)) return;
    isDirty = false;
    if (typeof __doPostBack === 'function' && dom.btnPublish) {
      __doPostBack(dom.btnPublish.id, '');
    } else if (dom.btnPublish) {
      dom.btnPublish.click();
    }
  };

  /* ==========================================================================
     11. WIZARD STEP NAVIGATION & TAB SWITCHING
     ========================================================================== */
  window.switchWizardTab = function (stepNumber) {
    const currentTabBtn = document.querySelector('.admin-wizard-tab-btn.active');
    const currentStep = currentTabBtn ? parseInt(currentTabBtn.getAttribute('data-step'), 10) : 1;

    // Moving forward requires passing validation for prior steps
    if (stepNumber > currentStep) {
      for (let s = currentStep; s < stepNumber; s++) {
        if (!validateStep(s)) {
          return false;
        }
      }
    }

    // Re-serialize specifications whenever moving steps
    serializeSpecifications();

    // Switch active buttons
    document.querySelectorAll('.admin-wizard-tab-btn').forEach((btn) => {
      const step = parseInt(btn.getAttribute('data-step'), 10);
      btn.classList.toggle('active', step === stepNumber);
      btn.setAttribute('aria-selected', step === stepNumber ? 'true' : 'false');
    });

    // Switch active panes
    document.querySelectorAll('.admin-wizard-pane').forEach((pane) => {
      const paneStep = parseInt(pane.getAttribute('data-pane'), 10);
      pane.classList.toggle('active', paneStep === stepNumber);
    });

    // Re-render pricing matrix if switching to step 4
    if (stepNumber === 4) {
      renderPricingMatrix();
      updatePricingPreview();
    }

    // Update review summary if moving to step 6
    if (stepNumber === 6) {
      updateReviewSummary();
    }

    const header = document.querySelector('.admin-item-sticky-header');
    if (header) {
      header.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }

    return true;
  };

  /* ==========================================================================
     12. REVIEW & CONFIRM TAB SUMMARY SYNCHRONIZATION
     ========================================================================== */
  function updateReviewSummary() {
    const name = dom.txtProductName ? dom.txtProductName.value.trim() : 'Helmet Model';
    const brandName = dom.ddlBrand && dom.ddlBrand.selectedIndex > 0 ? dom.ddlBrand.options[dom.ddlBrand.selectedIndex].text : 'Brand';
    const categoryName = dom.ddlCategory && dom.ddlCategory.selectedIndex > 0 ? dom.ddlCategory.options[dom.ddlCategory.selectedIndex].text : 'Category';
    const desc = dom.txtDescription ? dom.txtDescription.value.trim() : '';

    const elName = document.getElementById('reviewSummaryName');
    const elBrand = document.getElementById('reviewSummaryBrand');
    const elCat = document.getElementById('reviewSummaryCategory');
    const elDesc = document.getElementById('reviewSummaryDescription');

    if (elName) elName.textContent = name || 'New Helmet Model';
    if (elBrand) elBrand.textContent = brandName;
    if (elCat) elCat.textContent = categoryName;
    if (elDesc) elDesc.textContent = desc || 'No description provided yet.';

    // Pricing
    const base = parseFloat(dom.txtBasePrice ? dom.txtBasePrice.value : 0) || 0;
    const discountVal = parseFloat(dom.txtDiscountValue ? dom.txtDiscountValue.value : 0) || 0;
    const unit = dom.ddlDiscountUnit ? dom.ddlDiscountUnit.value : 'Percentage';
    const isActive = dom.hdnDiscountIsActive ? (dom.hdnDiscountIsActive.value === 'Active' || dom.hdnDiscountIsActive.value === 'True') : true;

    let effective = base;
    let discountTagText = 'No Discount';

    if (isActive && discountVal > 0) {
      if (unit === 'FixedAmount') {
        effective = Math.max(0, base - discountVal);
        discountTagText = `-₱${discountVal.toLocaleString('en-PH', { minimumFractionDigits: 0 })}`;
      } else {
        const pct = Math.min(90, Math.max(0, discountVal));
        effective = Math.max(0, base * (1 - (pct / 100)));
        discountTagText = `-${pct}% OFF`;
      }
    }

    const elEffective = document.getElementById('reviewSummaryEffective');
    const elBase = document.getElementById('reviewSummaryBasePrice');
    const elDisc = document.getElementById('reviewSummaryDiscount');

    if (elEffective) elEffective.textContent = `₱${effective.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    if (elBase) {
      if (isActive && discountVal > 0) {
        elBase.style.display = 'inline';
        elBase.textContent = `₱${base.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
      } else {
        elBase.style.display = 'none';
      }
    }
    if (elDisc) {
      if (isActive && discountVal > 0) {
        elDisc.style.display = 'inline-block';
        elDisc.textContent = discountTagText;
      } else {
        elDisc.style.display = 'none';
      }
    }

    // Media Thumbnail
    const thumbImg = document.getElementById('reviewSummaryThumb');
    const thumbEmpty = document.getElementById('reviewSummaryThumbEmpty');
    if (thumbImg) {
      if (gallery.length > 0 && gallery[0].url) {
        thumbImg.src = gallery[0].url;
        thumbImg.classList.remove('is-hidden');
        if (thumbEmpty) thumbEmpty.classList.add('is-hidden');
      } else {
        thumbImg.src = '';
        thumbImg.classList.add('is-hidden');
        if (thumbEmpty) thumbEmpty.classList.remove('is-hidden');
      }
    }

    // Swatches
    const swatchesContainer = document.getElementById('reviewColorSwatches');
    if (swatchesContainer) {
      swatchesContainer.innerHTML = '';
      if (colors.length === 0) {
        swatchesContainer.innerHTML = '<span class="admin-palette-empty">None added</span>';
      } else {
        colors.forEach((c) => {
          const s = document.createElement('span');
          s.className = 'admin-product-detail-mini__swatch';
          s.title = c.name;
          if (c.colorType === 'LINEAR_GRADIENT' && c.stops && c.stops.length >= 2) {
            s.style.background = `linear-gradient(${c.gradientAngle || 135}deg, ${c.stops[0]}, ${c.stops[1]})`;
          } else {
            s.style.backgroundColor = c.solidHex || '#18181B';
          }
          swatchesContainer.appendChild(s);
        });
      }
    }

    // Sizes
    const sizesContainer = document.getElementById('reviewSizeOptions');
    if (sizesContainer) {
      sizesContainer.innerHTML = '';
      const checkedSizes = Array.from(document.querySelectorAll('.admin-size-pill.is-active')).map((p) => p.dataset.size);
      if (checkedSizes.length === 0) {
        sizesContainer.innerHTML = '<span class="admin-palette-empty">None selected</span>';
      } else {
        checkedSizes.forEach((sz) => {
          const span = document.createElement('span');
          span.textContent = sz;
          sizesContainer.appendChild(span);
        });
      }
    }

    // Summary Counts
    let totalStock = 0;
    let activeVariantsCount = 0;
    variants.forEach((v) => { 
      totalStock += (v.initialStock || 0); 
      if (v.isActive !== false) activeVariantsCount++;
    });

    const elVariantsCount = document.getElementById('reviewSummaryVariantsCount');
    const elStockTotal = document.getElementById('reviewSummaryStockTotal');
    const elSpecsCount = document.getElementById('reviewSummarySpecsCount');
    const elImagesCount = document.getElementById('reviewSummaryImagesCount');

    if (elVariantsCount) {
      elVariantsCount.textContent = variants.length === activeVariantsCount 
        ? `${variants.length} SKUs` 
        : `${activeVariantsCount}/${variants.length} Active SKUs`;
    }
    if (elStockTotal) elStockTotal.textContent = `${totalStock.toLocaleString()} Units`;

    let specsCount = 0;
    document.querySelectorAll('.spec-field').forEach((input) => {
      if (input.value.trim()) specsCount++;
    });
    document.querySelectorAll('.admin-custom-spec-row').forEach((row) => {
      const v = row.querySelector('.custom-spec-val');
      if (v && v.value.trim()) specsCount++;
    });
    if (elSpecsCount) elSpecsCount.textContent = `${specsCount} Specifications`;
    if (elImagesCount) elImagesCount.textContent = `${gallery.length} Images`;
  }

  /* ==========================================================================
     13. HELPER UTILITIES
     ========================================================================== */
  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function showAdminToast(msg, type = 'info', title = null) {
    if (typeof window.showAdminToast === 'function') {
      window.showAdminToast(msg, type, title);
      return;
    }
    const container = document.getElementById('adminToastContainer');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `admin-toast admin-toast--${type}`;
    toast.textContent = msg;
    container.appendChild(toast);

    setTimeout(() => {
      toast.classList.add('is-fading');
      setTimeout(() => toast.remove(), 300);
    }, 3500);
  }

})();
