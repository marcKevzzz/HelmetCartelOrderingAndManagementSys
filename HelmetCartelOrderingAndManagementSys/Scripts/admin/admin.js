/**
 * Helmet Cartel Admin Portal - Client Presentation Script
 * Exclusively handles client-side DOM interactions (sidebar toggle, Ctrl+K shortcut, 
 * global search autocomplete dropdown, stock adjustment modal, variant matrix generator).
 * Persisted state and business logic reside strictly in C# code-behind and MSSQL stored procedures.
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Sidebar Collapse Toggle
  const sidebar = document.getElementById('admin-sidebar');
  const toggleBtn = document.getElementById('admin-sidebar-toggle-btn');
  const collapseKey = 'hc_admin_sidebar_collapsed';

  if (sidebar && toggleBtn) {
    if (localStorage.getItem(collapseKey) === 'true') {
      sidebar.classList.add('is-collapsed');
    }

    toggleBtn.addEventListener('click', () => {
      const isCollapsed = sidebar.classList.toggle('is-collapsed');
      localStorage.setItem(collapseKey, isCollapsed);
    });
  }

  // 2. Keyboard Shortcut (Ctrl+K or Cmd+K) to focus search
  const searchInput = document.getElementById('adminGlobalSearch') || document.querySelector('.admin-topbar-search-input');
  const searchDropdown = document.getElementById('adminSearchDropdown');

  if (searchInput) {
    const urlParams = new URLSearchParams(window.location.search);
    const activeSearchQuery = urlParams.get('q') || urlParams.get('search');
    if (activeSearchQuery && !searchInput.value) {
      searchInput.value = activeSearchQuery;
    }
  }

  window.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      searchInput?.focus();
      searchInput?.select();
    }
  });

  // 3. Global Admin Search with Autocomplete Dropdown
  if (searchInput && searchDropdown) {
    let debounceTimer = null;
    let selectedIndex = -1;

    const performSearch = async (query) => {
      const trimmed = query.trim();
      if (trimmed.length === 0) {
        searchDropdown.style.display = 'none';
        searchDropdown.innerHTML = '';
        return;
      }

      try {
        const response = await fetch(`/api/v1/admin/global-search?q=${encodeURIComponent(trimmed)}`);
        if (!response.ok) return;
        const resData = await response.json();
        const items = resData.data || [];

        if (items.length === 0) {
          searchDropdown.innerHTML = '<div class="admin-search-empty">No results found matching "' + escapeHtml(trimmed) + '"</div>';
          searchDropdown.classList.remove('is-hidden');
          searchDropdown.removeAttribute('hidden');
          searchDropdown.style.display = 'block';
          return;
        }

        // Group results by category
        const groups = {};
        items.forEach(item => {
          const cat = item.category || 'Results';
          if (!groups[cat]) groups[cat] = [];
          groups[cat].push(item);
        });

        let html = '';
        Object.keys(groups).forEach(cat => {
          html += `<div class="admin-search-group">
            <div class="admin-search-group-title">${escapeHtml(cat)}</div>`;
          groups[cat].forEach(it => {
            html += `<a href="${escapeHtml(it.url)}" class="admin-search-item" data-url="${escapeHtml(it.url)}">
              <div class="admin-search-item-info">
                <span class="admin-search-item-title">${escapeHtml(it.title)}</span>
                <span class="admin-search-item-sub">${escapeHtml(it.subtitle)}</span>
              </div>
              <span class="admin-search-badge">${escapeHtml(it.badge || '')}</span>
            </a>`;
          });
          html += `</div>`;
        });

        searchDropdown.innerHTML = html;
        searchDropdown.classList.remove('is-hidden');
        searchDropdown.removeAttribute('hidden');
        searchDropdown.style.display = 'block';
        selectedIndex = -1;
      } catch (err) {
        console.error('Admin global search error:', err);
      }
    };

    searchInput.addEventListener('input', (e) => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => performSearch(e.target.value), 220);
    });

    searchInput.addEventListener('focus', () => {
      if (searchInput.value.trim().length > 0 && searchDropdown.children.length > 0) {
        searchDropdown.classList.remove('is-hidden');
        searchDropdown.removeAttribute('hidden');
        searchDropdown.style.display = 'block';
      }
    });

    searchInput.addEventListener('keydown', (e) => {
      const visibleItems = searchDropdown.querySelectorAll('.admin-search-item');

      if (e.key === 'Enter') {
        e.preventDefault();
        if (selectedIndex >= 0 && selectedIndex < visibleItems.length) {
          window.location.href = visibleItems[selectedIndex].getAttribute('data-url');
          return;
        }

        const query = searchInput.value.trim();
        if (!query) return;

        const path = window.location.pathname.toLowerCase();
        if (path.includes('/admin/catalog')) {
          window.location.href = `/Admin/Catalog.aspx?q=${encodeURIComponent(query)}`;
        } else if (path.includes('/admin/orders')) {
          window.location.href = `/Admin/Orders.aspx?q=${encodeURIComponent(query)}`;
        } else if (path.includes('/admin/users')) {
          window.location.href = `/Admin/Users.aspx?q=${encodeURIComponent(query)}`;
        } else {
          window.location.href = `/Admin/Inventory.aspx?q=${encodeURIComponent(query)}`;
        }
        return;
      }

      if (searchDropdown.style.display === 'none' || visibleItems.length === 0) return;

      if (e.key === 'ArrowDown') {
        e.preventDefault();
        selectedIndex = (selectedIndex + 1) % visibleItems.length;
        updateSelection(visibleItems);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        selectedIndex = (selectedIndex - 1 + visibleItems.length) % visibleItems.length;
        updateSelection(visibleItems);
      } else if (e.key === 'Escape') {
        searchDropdown.style.display = 'none';
      }
    });

    const updateSelection = (items) => {
      items.forEach((item, idx) => {
        if (idx === selectedIndex) {
          item.classList.add('is-selected');
          item.scrollIntoView({ block: 'nearest' });
        } else {
          item.classList.remove('is-selected');
        }
      });
    };

    // Close dropdown on outside click
    document.addEventListener('click', (e) => {
      if (!searchInput.contains(e.target) && !searchDropdown.contains(e.target)) {
        searchDropdown.style.display = 'none';
      }
    });

    // Populate search bar from URL parameter if present
    try {
      const urlParams = new URLSearchParams(window.location.search);
      const activeQ = urlParams.get('q') || urlParams.get('search') || urlParams.get('brand');
      if (activeQ && searchInput) {
        searchInput.value = activeQ;
      }
    } catch (e) {}
  }

  // 4. Select All Checkbox Handling
  const chkSelectAll = document.getElementById('chk-select-all');
  if (chkSelectAll) {
    chkSelectAll.addEventListener('change', () => {
      const isChecked = chkSelectAll.checked;
      document.querySelectorAll('.admin-row-chk').forEach(chk => {
        chk.checked = isChecked;
      });
    });
  }

  // 5. Mobile Sidebar Navigation Drawer
  const mobileMenuBtn = document.getElementById('adminMobileMenuBtn');
  const sidebarBackdrop = document.getElementById('adminSidebarBackdrop');
  if (mobileMenuBtn && sidebar) {
    mobileMenuBtn.addEventListener('click', () => {
      sidebar.classList.toggle('is-mobile-open');
      sidebarBackdrop?.classList.toggle('active');
    });
  }
  if (sidebarBackdrop && sidebar) {
    sidebarBackdrop.addEventListener('click', () => {
      sidebar.classList.remove('is-mobile-open');
      sidebarBackdrop.classList.remove('active');
    });
  }

  // 6. Sign Out Modal
  window.openSignOutModal = () => {
    const modal = document.getElementById('adminSignOutModal');
    if (modal) {
      modal.classList.remove('is-hidden');
      modal.removeAttribute('hidden');
    }
  };

  window.closeSignOutModal = () => {
    const modal = document.getElementById('adminSignOutModal');
    if (modal) {
      modal.classList.add('is-hidden');
      modal.setAttribute('hidden', '');
    }
  };

  window.confirmSignOut = () => {
    window.showAdminToast('Signed out successfully. Redirecting...', 'success', 'Session Ended');
    try {
      localStorage.removeItem('jwt_token');
      localStorage.removeItem('auth_token');
      localStorage.removeItem('user_role');
      sessionStorage.clear();
      document.cookie = 'jwt_token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
    } catch (e) {}
    setTimeout(() => {
      window.location.href = '/Pages/Login.aspx?logout=1';
    }, 500);
  };

  const btnSignOutLink = document.getElementById('btnAdminSignOut');
  if (btnSignOutLink) btnSignOutLink.addEventListener('click', window.openSignOutModal);

  const userCapsule = document.getElementById('adminUserCapsule');
  if (userCapsule) userCapsule.addEventListener('click', window.openSignOutModal);

  const btnCancelSignOut = document.getElementById('btnCancelSignOut');
  if (btnCancelSignOut) btnCancelSignOut.addEventListener('click', window.closeSignOutModal);

  const btnConfirmSignOut = document.getElementById('btnConfirmSignOut');
  if (btnConfirmSignOut) btnConfirmSignOut.addEventListener('click', window.confirmSignOut);

  // 7. Toast Notification System
  window.showAdminToast = (message, type = 'info', title = null, duration = 4000) => {
    const container = document.getElementById('adminToastContainer');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `admin-toast admin-toast--${type}`;

    let iconSvg = '';
    let defaultTitle = 'Notice';
    if (type === 'success') {
      defaultTitle = 'Success';
      iconSvg = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    } else if (type === 'error') {
      defaultTitle = 'Error';
      iconSvg = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>';
    } else if (type === 'warning') {
      defaultTitle = 'Warning';
      iconSvg = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>';
    } else {
      defaultTitle = 'Information';
      iconSvg = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>';
    }

    toast.innerHTML = `
      <div class="admin-toast-icon">${iconSvg}</div>
      <div class="admin-toast-content">
        <div class="admin-toast-title">${escapeHtml(title || defaultTitle)}</div>
        <div class="admin-toast-message">${escapeHtml(message)}</div>
      </div>
      <button type="button" class="admin-toast-close" aria-label="Dismiss toast">&times;</button>
    `;

    toast.querySelector('.admin-toast-close').addEventListener('click', () => {
      dismissToast(toast);
    });

    container.appendChild(toast);

    if (duration > 0) {
      setTimeout(() => {
        dismissToast(toast);
      }, duration);
    }
  };

  window.showToast = window.showAdminToast;

  function dismissToast(toast) {
    if (!toast || !toast.parentNode) return;
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(-10px) scale(0.95)';
    setTimeout(() => {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 220);
  }

  // Handle URL query feedback toasts on initial page load
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.has('toast')) {
    const toastType = urlParams.get('toast') || 'info';
    const toastMsg = urlParams.get('msg') || (toastType === 'success' ? 'Operation completed successfully.' : 'Action notice.');
    window.showAdminToast(toastMsg, toastType);
  }

  // 8. Stock In Modal Handling (Inventory page - Stock In ONLY, with live preview)
  window.openStockAdjustModal = (variantId, title, currentStock) => {
    const modal = document.getElementById('stockAdjustModal');
    const hdnVariantId = document.getElementById('MainContent_hdnAdjustVariantId') || document.getElementById('hdnAdjustVariantId');
    const lblTitle = document.getElementById('adjustModalHelmetTitle');
    const lblCurrentStock = document.getElementById('adjustModalCurrentStock');
    const lblUpdatedStock = document.getElementById('adjustModalUpdatedStock');
    const txtDelta = document.getElementById('MainContent_txtAdjustQuantity') || document.getElementById('txtAdjustQuantity');

    if (modal && hdnVariantId) {
      hdnVariantId.value = variantId;
      if (lblTitle) lblTitle.textContent = title;
      const num = parseInt(currentStock, 10) || 0;
      if (lblCurrentStock) {
        lblCurrentStock.textContent = num < 1000 ? String(num).padStart(3, '0') : num.toLocaleString();
        lblCurrentStock.setAttribute('data-current', num);
      }
      if (txtDelta) {
        txtDelta.value = '5';
        const updateCalculatedStock = () => {
          const delta = Math.max(1, parseInt(txtDelta.value, 10) || 0);
          const updated = num + delta;
          if (lblUpdatedStock) {
            lblUpdatedStock.textContent = updated < 1000 ? String(updated).padStart(3, '0') : updated.toLocaleString();
          }
        };
        updateCalculatedStock();
        txtDelta.oninput = updateCalculatedStock;
      }
      modal.style.display = 'flex';
    }
  };

  window.closeStockAdjustModal = () => {
    const modal = document.getElementById('stockAdjustModal');
    if (modal) modal.style.display = 'none';
  };

  // 9. Add / Edit Helmet Model Modal & Tabbed Wizard (Catalog page)
  window.activeColors = [
    { name: 'Matte Black', type: 'solid', hex: '#18181B' },
    { name: 'Pearl White', type: 'solid', hex: '#FFFFFF' },
    { name: 'Racing Red', type: 'solid', hex: '#DC2626' }
  ];

  window.selectedFilesList = [];

  window.openAddProductModal = () => {
    const modal = document.getElementById('addProductModal');
    if (!modal) return;

    const hdnEditId = document.getElementById('MainContent_hdnEditProductId') || document.getElementById('hdnEditProductId');
    if (hdnEditId) hdnEditId.value = '0';

    const title = document.getElementById('modalProductTitle');
    if (title) title.textContent = 'Add Helmet Model';

    const subtitle = document.getElementById('modalProductSubtitle');
    if (subtitle) subtitle.textContent = 'Configure helmet specifications, variant matrix, color swatches, pricing discounts, and brand assets.';

    const submitBtn = document.getElementById('MainContent_btnSubmitNewProduct') || document.getElementById('btnSubmitNewProduct');
    if (submitBtn) submitBtn.value = 'Save Helmet Model';

    // Reset fields to defaults
    const nameInput = document.getElementById('MainContent_txtNewName') || document.getElementById('txtNewName');
    if (nameInput) nameInput.value = '';

    const descInput = document.getElementById('MainContent_txtNewDescription') || document.getElementById('txtNewDescription');
    if (descInput) descInput.value = '';

    window.activeColors = [
      { name: 'Matte Black', type: 'solid', hex: '#18181B' },
      { name: 'Pearl White', type: 'solid', hex: '#FFFFFF' },
      { name: 'Racing Red', type: 'solid', hex: '#DC2626' }
    ];
    window.selectedFilesList = [];
    renderImageTiles();

    modal.classList.remove('is-hidden');
    modal.removeAttribute('hidden');
    switchWizardTab(1);
    renderColorChips();
    updatePricingPreview();
  };

  window.openEditProductModal = (id, name, brandId, catId, style, price, discountType, discountVal, imgUrl, desc) => {
    const modal = document.getElementById('addProductModal');
    if (!modal) return;

    const hdnEditId = document.getElementById('MainContent_hdnEditProductId') || document.getElementById('hdnEditProductId');
    if (hdnEditId) hdnEditId.value = id;

    const title = document.getElementById('modalProductTitle');
    if (title) title.textContent = `Edit: ${name}`;

    const subtitle = document.getElementById('modalProductSubtitle');
    if (subtitle) subtitle.textContent = 'Update product specifications, manufacturer brand, retail pricing, discounts, and visual media.';

    const submitBtn = document.getElementById('MainContent_btnSubmitNewProduct') || document.getElementById('btnSubmitNewProduct');
    if (submitBtn) submitBtn.value = 'Save Product Changes';

    const nameInput = document.getElementById('MainContent_txtNewName') || document.getElementById('txtNewName');
    if (nameInput) nameInput.value = name || '';

    const brandDdl = document.getElementById('MainContent_ddlNewBrand') || document.getElementById('ddlNewBrand');
    if (brandDdl && brandId) brandDdl.value = brandId;

    const catDdl = document.getElementById('MainContent_ddlNewCategory') || document.getElementById('ddlNewCategory');
    if (catDdl && catId) catDdl.value = catId;

    const styleDdl = document.getElementById('MainContent_ddlNewStyle') || document.getElementById('ddlNewStyle');
    if (styleDdl && style) styleDdl.value = style;

    const priceInput = document.getElementById('MainContent_txtNewBasePrice') || document.getElementById('txtNewBasePrice');
    if (priceInput && price) priceInput.value = parseFloat(price).toFixed(2);

    const discTypeDdl = document.getElementById('MainContent_ddlNewDiscountType') || document.getElementById('ddlNewDiscountType');
    if (discTypeDdl && discountType) discTypeDdl.value = discountType;

    const discValInput = document.getElementById('MainContent_txtNewDiscountValue') || document.getElementById('txtNewDiscountValue');
    if (discValInput) discValInput.value = discountVal || 0;

    const imgUrlInput = document.getElementById('MainContent_txtNewImageUrl') || document.getElementById('txtNewImageUrl');
    if (imgUrlInput && imgUrl) imgUrl.value = imgUrl;

    const descInput = document.getElementById('MainContent_txtNewDescription') || document.getElementById('txtNewDescription');
    if (descInput) descInput.value = desc || '';

    window.selectedFilesList = [];
    renderImageTiles();

    modal.classList.remove('is-hidden');
    modal.removeAttribute('hidden');
    switchWizardTab(1);
    updatePricingPreview();
    updateImagePreview();
  };

  window.closeAddProductModal = () => {
    const modal = document.getElementById('addProductModal');
    if (modal) {
      modal.classList.add('is-hidden');
      modal.setAttribute('hidden', '');
    }
  };

  // Color Manager & Palette Builder
  window.renderColorChips = () => {
    const container = document.getElementById('colorChipsContainer');
    const hiddenInput = document.getElementById('txtNewColors');
    if (!container) return;

    if (!window.activeColors || window.activeColors.length === 0) {
      container.innerHTML = '<span class="admin-palette-empty">No colors added yet. Create at least one color below.</span>';
      if (hiddenInput) hiddenInput.value = '';
      return;
    }

    let chipsHtml = '';
    window.activeColors.forEach((c, idx) => {
      const swatchStyle = c.type === 'gradient' ? `background:${c.hex};` : `background-color:${c.hex};`;
      chipsHtml += `
        <span class="admin-palette-chip">
          <span class="admin-palette-chip-swatch" style="${swatchStyle}"></span>
          <span>${escapeHtml(c.name)}</span>
          <button type="button" class="admin-palette-chip-remove" onclick="removeColorFromPalette(${idx});" title="Remove color">&times;</button>
        </span>
      `;
    });
    container.innerHTML = chipsHtml;

    if (hiddenInput) {
      hiddenInput.value = window.activeColors.map(c => `${c.name}:${c.hex}`).join(', ');
    }
    renderVariantMatrix();
  };

  window.setColorMode = (mode) => {
    const btnSolid = document.getElementById('btnColorModeSolid');
    const btnGrad = document.getElementById('btnColorModeGradient');
    const solidBox = document.getElementById('solidColorControls');
    const gradBox = document.getElementById('gradientColorControls');

    if (mode === 'gradient') {
      btnSolid?.classList.remove('active');
      btnGrad?.classList.add('active');
      solidBox?.classList.add('is-hidden');
      gradBox?.classList.remove('is-hidden');
      updateGradientPreview();
    } else {
      btnSolid?.classList.add('active');
      btnGrad?.classList.remove('active');
      solidBox?.classList.remove('is-hidden');
      gradBox?.classList.add('is-hidden');
    }
  };

  window.syncSolidHex = (val) => {
    const hexInput = document.getElementById('txtSolidHex');
    if (hexInput) hexInput.value = val;
  };

  window.syncSolidPicker = (val) => {
    const picker = document.getElementById('pickerSolidColor');
    if (picker && /^#[0-9A-Fa-f]{6}$/.test(val)) picker.value = val;
  };

  window.updateGradientPreview = () => {
    const c1 = document.getElementById('pickerGrad1')?.value || '#DC2626';
    const c2 = document.getElementById('pickerGrad2')?.value || '#18181B';
    const deg = document.getElementById('numGradAngle')?.value || '135';
    const preview = document.getElementById('gradPreviewBox');
    if (preview) {
      preview.style.background = `linear-gradient(${deg}deg, ${c1}, ${c2})`;
    }
  };

  window.addColorToPalette = () => {
    const nameInput = document.getElementById('txtCustomColorName');
    const colorName = nameInput?.value?.trim();
    if (!colorName) {
      window.showAdminToast('Please provide a descriptive name for this color/finish.', 'warning', 'Color Name Required');
      nameInput?.focus();
      return;
    }

    const isGrad = document.getElementById('btnColorModeGradient')?.classList.contains('active');
    if (isGrad) {
      const c1 = document.getElementById('pickerGrad1')?.value || '#DC2626';
      const c2 = document.getElementById('pickerGrad2')?.value || '#18181B';
      const deg = document.getElementById('numGradAngle')?.value || '135';
      const gradientStr = `linear-gradient(${deg}deg, ${c1}, ${c2})`;
      window.activeColors.push({ name: colorName, type: 'gradient', hex: gradientStr });
    } else {
      const hex = document.getElementById('txtSolidHex')?.value || document.getElementById('pickerSolidColor')?.value || '#18181B';
      window.activeColors.push({ name: colorName, type: 'solid', hex });
    }

    if (nameInput) nameInput.value = '';
    renderColorChips();
  };

  window.removeColorFromPalette = (idx) => {
    if (window.activeColors && idx >= 0 && idx < window.activeColors.length) {
      window.activeColors.splice(idx, 1);
      renderColorChips();
    }
  };

  // Multi-Image Upload & Preview Grid
  window.handleMultipleImageSelection = (input) => {
    if (!input.files || input.files.length === 0) return;
    const validExts = ['.jpg', '.jpeg', '.png', '.webp'];
    const maxBytes = 5 * 1024 * 1024; // 5MB

    Array.from(input.files).forEach(file => {
      const ext = '.' + file.name.split('.').pop().toLowerCase();
      if (!validExts.includes(ext)) {
        window.showAdminToast(`File "${file.name}" is not a supported format (JPG, PNG, WEBP only).`, 'warning', 'Invalid File Type');
        return;
      }
      if (file.size > maxBytes) {
        window.showAdminToast(`File "${file.name}" exceeds the 5MB size limit.`, 'warning', 'File Too Large');
        return;
      }
      window.selectedFilesList.push(file);
    });

    renderImageTiles();
  };

  window.renderImageTiles = () => {
    const grid = document.getElementById('imageUploadGrid');
    if (!grid) return;

    if (!window.selectedFilesList || window.selectedFilesList.length === 0) {
      grid.innerHTML = '<span class="admin-palette-empty">No files uploaded yet. Select images above to preview.</span>';
      return;
    }

    let html = '';
    window.selectedFilesList.forEach((file, idx) => {
      const blobUrl = URL.createObjectURL(file);
      const isPrimary = idx === 0;
      html += `
        <div class="admin-upload-tile" data-idx="${idx}">
          <img src="${blobUrl}" alt="${escapeHtml(file.name)}" />
          <span class="admin-upload-tile-badge">${isPrimary ? 'Primary' : '#' + (idx + 1)}</span>
          <button type="button" class="admin-upload-tile-remove" onclick="removeImageTile(${idx});" title="Remove image">&times;</button>
        </div>
      `;
    });
    grid.innerHTML = html;

    if (window.selectedFilesList.length > 0) {
      const previewImg = document.getElementById('newProductImagePreview');
      if (previewImg) {
        previewImg.src = URL.createObjectURL(window.selectedFilesList[0]);
      }
    }
  };

  window.removeImageTile = (idx) => {
    if (window.selectedFilesList && idx >= 0 && idx < window.selectedFilesList.length) {
      window.selectedFilesList.splice(idx, 1);
      renderImageTiles();
    }
  };

  // Wizard tab switching
  window.switchWizardTab = (stepNumber) => {
    const currentTabBtn = document.querySelector('.admin-wizard-tab-btn.active');
    const currentStep = currentTabBtn ? parseInt(currentTabBtn.getAttribute('data-step'), 10) : 1;

    if (stepNumber > currentStep) {
      if (!validateWizardStep(currentStep)) return false;
    }

    document.querySelectorAll('.admin-wizard-tab-btn').forEach(btn => {
      const step = parseInt(btn.getAttribute('data-step'), 10);
      btn.classList.toggle('active', step === stepNumber);
    });

    document.querySelectorAll('.admin-wizard-pane').forEach(pane => {
      const step = parseInt(pane.getAttribute('data-pane'), 10);
      pane.classList.toggle('active', step === stepNumber);
    });

    if (stepNumber === 2) {
      renderColorChips();
    } else if (stepNumber === 3) {
      updatePricingPreview();
    } else if (stepNumber === 4) {
      updateImagePreview();
    } else if (stepNumber === 5) {
      renderReviewSummary();
    }

    return true;
  };

  window.validateWizardStep = (step) => {
    let isValid = true;
    if (step === 1) {
      const nameInput = document.getElementById('MainContent_txtNewName') || document.getElementById('txtNewName');
      const errSpan = document.getElementById('errNewName');
      if (!nameInput || !nameInput.value.trim()) {
        if (nameInput) nameInput.classList.add('is-invalid');
        if (errSpan) errSpan.style.display = 'block';
        isValid = false;
      } else {
        if (nameInput) nameInput.classList.remove('is-invalid');
        if (errSpan) errSpan.style.display = 'none';
      }
    } else if (step === 3) {
      const priceInput = document.getElementById('MainContent_txtNewBasePrice') || document.getElementById('txtNewBasePrice');
      const errPrice = document.getElementById('errNewPrice');
      const val = parseFloat(priceInput?.value || '0');
      if (isNaN(val) || val <= 0) {
        if (priceInput) priceInput.classList.add('is-invalid');
        if (errPrice) errPrice.style.display = 'block';
        isValid = false;
      } else {
        if (priceInput) priceInput.classList.remove('is-invalid');
        if (errPrice) errPrice.style.display = 'none';
      }
    }
    return isValid;
  };

  // Pricing & Discount preview calculation
  window.updatePricingPreview = () => {
    const priceInput = document.getElementById('MainContent_txtNewBasePrice') || document.getElementById('txtNewBasePrice');
    const discountTypeDdl = document.getElementById('MainContent_ddlNewDiscountType') || document.getElementById('ddlNewDiscountType');
    const discountValInput = document.getElementById('MainContent_txtNewDiscountValue') || document.getElementById('txtNewDiscountValue');
    const lblPreview = document.getElementById('pricingEffectivePreview');

    const basePrice = Math.max(0, parseFloat(priceInput?.value || '0'));
    const dType = discountTypeDdl?.value || 'Percentage';
    const dVal = Math.max(0, parseFloat(discountValInput?.value || '0'));

    let effective = basePrice;
    let badgeText = '0%';
    if (dType === 'FixedAmount') {
      effective = Math.max(0, basePrice - dVal);
      badgeText = `-₱${dVal.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`;
    } else if (dType === 'Percentage') {
      const pct = Math.min(90, dVal);
      effective = Math.round(basePrice * (1.0 - (pct / 100.0)) * 100) / 100;
      badgeText = `-${pct}%`;
    }

    if (lblPreview) {
      if (dVal > 0) {
        lblPreview.innerHTML = `Base: <strong>₱${basePrice.toLocaleString('en-US', { minimumFractionDigits: 2 })}</strong> &rarr; Discount (${badgeText}): <strong class="admin-stock-highlight">₱${effective.toLocaleString('en-US', { minimumFractionDigits: 2 })}</strong>`;
      } else {
        lblPreview.innerHTML = `Effective Price: <strong>₱${basePrice.toLocaleString('en-US', { minimumFractionDigits: 2 })}</strong> (No discount applied)`;
      }
    }
  };

  // Image preview
  window.updateImagePreview = () => {
    const imgUrlInput = document.getElementById('MainContent_txtNewImageUrl') || document.getElementById('txtNewImageUrl');
    const previewImg = document.getElementById('newProductImagePreview');
    if (previewImg && imgUrlInput) {
      const url = imgUrlInput.value.trim() || '/Content/images/products/helmets/agv/images.jpg';
      previewImg.src = url;
    }
  };

  // Review Summary (Tab 5)
  window.renderReviewSummary = () => {
    const brandInput = document.getElementById('MainContent_ddlNewBrand') || document.getElementById('ddlNewBrand');
    const catInput = document.getElementById('MainContent_ddlNewCategory') || document.getElementById('ddlNewCategory');
    const nameInput = document.getElementById('MainContent_txtNewName') || document.getElementById('txtNewName');
    const styleInput = document.getElementById('MainContent_ddlNewStyle') || document.getElementById('ddlNewStyle');
    const priceInput = document.getElementById('MainContent_txtNewBasePrice') || document.getElementById('txtNewBasePrice');
    const discountTypeDdl = document.getElementById('MainContent_ddlNewDiscountType') || document.getElementById('ddlNewDiscountType');
    const discountValInput = document.getElementById('MainContent_txtNewDiscountValue') || document.getElementById('txtNewDiscountValue');
    const imgUrlInput = document.getElementById('MainContent_txtNewImageUrl') || document.getElementById('txtNewImageUrl');

    const brandName = brandInput?.options[brandInput.selectedIndex]?.text || 'Shoei';
    const catName = catInput?.options[catInput.selectedIndex]?.text || 'Full Face';
    const modelName = nameInput?.value?.trim() || 'Helmet Model';
    const styleName = styleInput?.value || 'Sport / Street';
    const basePrice = parseFloat(priceInput?.value || '0');
    const dType = discountTypeDdl?.value || 'Percentage';
    const dVal = parseFloat(discountValInput?.value || '0');

    let effectivePrice = basePrice;
    let discountSummary = 'No Discount';
    if (dVal > 0) {
      if (dType === 'FixedAmount') {
        effectivePrice = Math.max(0, basePrice - dVal);
        discountSummary = `-₱${dVal.toLocaleString('en-US', { minimumFractionDigits: 2 })}`;
      } else {
        effectivePrice = Math.round(basePrice * (1.0 - (dVal / 100.0)) * 100) / 100;
        discountSummary = `-${dVal}% Off`;
      }
    }

    const rows = document.querySelectorAll('.matrix-row');
    let totalInitialStock = 0;
    let chipsHtml = '';
    rows.forEach(r => {
      const col = r.getAttribute('data-color') || '';
      const sz = r.getAttribute('data-size') || '';
      const sku = r.querySelector('.matrix-sku')?.value || '';
      const stock = parseInt(r.querySelector('.matrix-stock')?.value || '0', 10);
      totalInitialStock += stock;

      chipsHtml += `
        <div class="admin-review-variant-chip">
          <span class="admin-review-chip-badge">${escapeHtml(col)} &bull; ${escapeHtml(sz)}</span>
          <span class="admin-review-chip-sku">${escapeHtml(sku)}</span>
          <span class="admin-review-chip-stock">${stock} units</span>
        </div>
      `;
    });

    const setReviewVal = (id, text) => {
      const el = document.getElementById(id);
      if (el) el.textContent = text;
    };

    setReviewVal('reviewSummaryBrand', brandName);
    setReviewVal('reviewSummaryCategory', catName);
    setReviewVal('reviewSummaryName', modelName);
    setReviewVal('reviewSummaryStyle', styleName);
    setReviewVal('reviewSummaryBasePrice', `₱${basePrice.toLocaleString('en-US', { minimumFractionDigits: 2 })}`);
    setReviewVal('reviewSummaryDiscount', discountSummary);
    setReviewVal('reviewSummaryEffective', `₱${effectivePrice.toLocaleString('en-US', { minimumFractionDigits: 2 })}`);
    setReviewVal('reviewSummaryVariantsCount', `${rows.length} SKUs`);
    setReviewVal('reviewSummaryStockTotal', `${totalInitialStock.toLocaleString()} Units`);

    // Image preview in review
    const thumbImg = document.getElementById('reviewSummaryThumb');
    if (thumbImg) {
      if (window.selectedFilesList && window.selectedFilesList.length > 0) {
        thumbImg.src = URL.createObjectURL(window.selectedFilesList[0]);
      } else if (imgUrlInput && imgUrlInput.value.trim()) {
        thumbImg.src = imgUrlInput.value.trim();
      } else {
        thumbImg.src = '/Content/images/products/helmets/agv/images.jpg';
      }
    }

    const imagesCount = (window.selectedFilesList?.length || 0) + (imgUrlInput?.value.trim() ? 1 : 0);
    setReviewVal('reviewSummaryImagesCount', `${Math.max(1, imagesCount)} Image${Math.max(1, imagesCount) === 1 ? '' : 's'}`);

    const breakdownBox = document.getElementById('reviewVariantsBreakdown');
    if (breakdownBox) {
      breakdownBox.innerHTML = chipsHtml || '<span class="admin-cell-mono-muted">No variants configured.</span>';
    }
  };

  // Dynamic Variant Matrix Generation (Preserves all entered data across tab switches)
  window.renderVariantMatrix = () => {
    const tableBody = document.getElementById('matrixTableBody');
    if (!tableBody) return;

    // Snapshot existing inputs to preserve user customization across tab switches
    const existingValues = {};
    tableBody.querySelectorAll('.matrix-row').forEach(row => {
      const c = row.getAttribute('data-color');
      const s = row.getAttribute('data-size');
      if (c && s) {
        const key = `${c}___${s}`;
        existingValues[key] = {
          sku: row.querySelector('.matrix-sku')?.value,
          priceAdj: row.querySelector('.matrix-price-adj')?.value,
          stock: row.querySelector('.matrix-stock')?.value,
          reorder: row.querySelector('.matrix-reorder')?.value
        };
      }
    });

    const brandInput = document.getElementById('MainContent_ddlNewBrand') || document.getElementById('ddlNewBrand');
    const nameInput = document.getElementById('MainContent_txtNewName') || document.getElementById('txtNewName');
    const brandName = brandInput?.options[brandInput.selectedIndex]?.text || 'Brand';
    const modelName = nameInput?.value?.trim() || 'Model';

    const colors = window.activeColors && window.activeColors.length > 0
      ? window.activeColors
      : [{ name: 'Standard Black', type: 'solid', hex: '#18181B' }];

    // Selected sizes
    const sizes = [];
    document.querySelectorAll('.chk-new-size:checked').forEach(cb => {
      sizes.push(cb.value);
    });
    if (sizes.length === 0) sizes.push('M', 'L', 'XL');

    const brandCode = brandName.substring(0, 3).toUpperCase();
    const modelCode = modelName.replace(/[^a-zA-Z0-9]/g, '').substring(0, 6).toUpperCase() || 'MOD';

    let rowsHtml = '';
    colors.forEach(col => {
      sizes.forEach(sz => {
        const colorCode = col.name.replace(/[^a-zA-Z0-9]/g, '').substring(0, 3).toUpperCase();
        const autoSku = `${brandCode}-${modelCode}-${colorCode}-${sz}`;
        const swatchStyle = col.type === 'gradient' ? `background:${col.hex};` : `background-color:${col.hex};`;

        const existing = existingValues[`${col.name}___${sz}`];
        const skuVal = (existing && existing.sku) ? existing.sku : autoSku;
        const priceVal = (existing && existing.priceAdj !== undefined && existing.priceAdj !== '') ? existing.priceAdj : '0.00';
        const stockVal = (existing && existing.stock !== undefined && existing.stock !== '') ? existing.stock : '10';
        const reorderVal = (existing && existing.reorder !== undefined && existing.reorder !== '') ? existing.reorder : '3';

        rowsHtml += `
          <tr class="matrix-row" data-color="${escapeHtml(col.name)}" data-hex="${escapeHtml(col.hex)}" data-size="${escapeHtml(sz)}">
            <td>
              <div class="admin-matrix-cell-color">
                <span class="admin-color-swatch" style="${swatchStyle}"></span>
                <span>${escapeHtml(col.name)}</span>
              </div>
            </td>
            <td><strong>${escapeHtml(sz)}</strong></td>
            <td><input type="text" class="admin-matrix-input matrix-sku" value="${escapeHtml(skuVal)}" /></td>
            <td><input type="number" step="100" class="admin-matrix-input matrix-price-adj admin-matrix-input--price" value="${escapeHtml(priceVal)}" /></td>
            <td><input type="number" step="1" min="0" class="admin-matrix-input matrix-stock admin-matrix-input--stock" value="${escapeHtml(stockVal)}" /></td>
            <td><input type="number" step="1" min="1" class="admin-matrix-input matrix-reorder admin-matrix-input--reorder" value="${escapeHtml(reorderVal)}" /></td>
          </tr>
        `;
      });
    });

    tableBody.innerHTML = rowsHtml;
  };

  // Collect matrix and write to hidden input before submit
  window.prepareVariantMatrixSubmission = () => {
    if (!validateWizardStep(1) || !validateWizardStep(3)) {
      window.showAdminToast('Please complete required fields before saving.', 'warning', 'Validation');
      return false;
    }

    const hdnMatrix = document.getElementById('MainContent_hdnVariantsJson') || document.getElementById('hdnVariantsJson');
    if (!hdnMatrix) return true;

    const rows = document.querySelectorAll('.matrix-row');
    const variants = [];

    rows.forEach(r => {
      const color = r.getAttribute('data-color');
      const colorHex = r.getAttribute('data-hex');
      const size = r.getAttribute('data-size');
      const sku = r.querySelector('.matrix-sku')?.value?.trim();
      const priceAdj = parseFloat(r.querySelector('.matrix-price-adj')?.value || '0');
      const stock = parseInt(r.querySelector('.matrix-stock')?.value || '10', 10);
      const reorder = parseInt(r.querySelector('.matrix-reorder')?.value || '3', 10);

      variants.push({
        color,
        colorHex,
        size,
        sku,
        priceAdj,
        stock,
        reorder
      });
    });

    hdnMatrix.value = JSON.stringify(variants);
    return true;
  };

  function escapeHtml(text) {
    if (!text) return '';
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
});
