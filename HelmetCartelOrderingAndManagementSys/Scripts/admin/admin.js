/**
 * Helmet Cartel Admin Portal - Client Presentation Script
 * Exclusively handles client-side DOM interactions (sidebar toggle, Ctrl+K shortcut, 
 * global search autocomplete dropdown, stock adjustment modal, variant matrix generator).
 * Persisted state and business logic reside strictly in C# code-behind and MSSQL stored procedures.
 */

// Queue server-side notifications that can execute before DOMContentLoaded.
window.__adminToastQueue = window.__adminToastQueue || [];
if (typeof window.showAdminToast !== 'function') {
  window.showAdminToast = (...args) => window.__adminToastQueue.push(args);
}

document.addEventListener('DOMContentLoaded', () => {
  // 1. Sidebar Collapse Toggle
  const sidebar = document.getElementById('admin-sidebar');
  const toggleBtn = document.getElementById('admin-sidebar-toggle-btn');
  const collapseKey = 'hc_admin_sidebar_collapsed';

  const mobileBreakpoint = window.matchMedia('(max-width: 1024px)');
  const mobileMenuBtn = document.getElementById('adminMobileMenuBtn');
  const sidebarBackdrop = document.getElementById('adminSidebarBackdrop');
  const syncSidebarRootState = (collapsed) => {
    document.documentElement.classList.toggle('admin-sidebar-collapsed', collapsed);
  };
  const closeMobileSidebar = () => {
    if (!sidebar || !mobileBreakpoint.matches) return;
    sidebar.classList.remove('is-mobile-open');
    sidebarBackdrop?.classList.remove('active');
    mobileMenuBtn?.setAttribute('aria-expanded', 'false');
    toggleBtn?.setAttribute('aria-expanded', 'false');
    toggleBtn?.setAttribute('aria-label', 'Close navigation');
  };
  const setMobileSidebarOpen = (open) => {
    if (open) sidebar.classList.remove('is-collapsed');
    sidebar.classList.toggle('is-mobile-open', open);
    sidebarBackdrop?.classList.toggle('active', open);
    mobileMenuBtn?.setAttribute('aria-expanded', String(open));
    toggleBtn?.setAttribute('aria-expanded', String(open));
    toggleBtn?.setAttribute('aria-label', 'Close navigation');
    if (open) toggleBtn?.focus();
    else mobileMenuBtn?.focus();
  };
  if (sidebar && toggleBtn) {
    const storedCollapsed = localStorage.getItem(collapseKey) === 'true';
    sidebar.classList.toggle('is-collapsed', storedCollapsed);
    syncSidebarRootState(storedCollapsed && !mobileBreakpoint.matches);
    const updateDesktopToggle = () => {
      if (mobileBreakpoint.matches) return;
      const expanded = !sidebar.classList.contains('is-collapsed');
      toggleBtn.setAttribute('aria-expanded', String(expanded));
      toggleBtn.setAttribute('aria-label', expanded ? 'Collapse sidebar' : 'Expand sidebar');
      toggleBtn.title = expanded ? 'Collapse sidebar' : 'Expand sidebar';
    };
    if (mobileBreakpoint.matches) {
      sidebar.classList.remove('is-collapsed');
      syncSidebarRootState(false);
      closeMobileSidebar();
    }
    updateDesktopToggle();

    toggleBtn.addEventListener('click', () => {
      if (mobileBreakpoint.matches) {
        setMobileSidebarOpen(false);
        return;
      }
      const isCollapsed = sidebar.classList.toggle('is-collapsed');
      localStorage.setItem(collapseKey, isCollapsed);
      syncSidebarRootState(isCollapsed);
      updateDesktopToggle();
    });
    mobileBreakpoint.addEventListener('change', () => {
      if (mobileBreakpoint.matches) {
        sidebar.classList.remove('is-collapsed');
        syncSidebarRootState(false);
        closeMobileSidebar();
      } else {
        const isCollapsed = localStorage.getItem(collapseKey) === 'true';
        sidebar.classList.toggle('is-collapsed', isCollapsed);
        syncSidebarRootState(isCollapsed);
        sidebar.classList.remove('is-mobile-open');
        sidebarBackdrop?.classList.remove('active');
      }
      updateDesktopToggle();
    });
  }

  // 2. Keyboard Shortcut (Ctrl+K or Cmd+K) to focus search
  const searchInput = document.getElementById('adminGlobalSearch') || document.querySelector('.admin-topbar-search-input');
  const searchDropdown = document.getElementById('adminSearchDropdown');
  const searchClear = document.getElementById('adminSearchClear');
  const shortcutPill = document.getElementById('adminSearchShortcut') || document.querySelector('.admin-topbar-shortcut-pill');

  const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
  if (shortcutPill) {
    shortcutPill.textContent = isMac ? '\u2318+K' : 'Ctrl+K';
  }

  const syncAdminSearchButtons = () => {
    const hasVal = !!(searchInput && searchInput.value.trim().length > 0);
    if (searchClear) searchClear.style.display = hasVal ? 'inline-flex' : 'none';
    if (shortcutPill) shortcutPill.style.display = hasVal ? 'none' : 'inline-flex';
  };

  if (searchInput) {
    const urlParams = new URLSearchParams(window.location.search);
    const activeSearchQuery = urlParams.get('q') || urlParams.get('search');
    if (activeSearchQuery && !searchInput.value) {
      searchInput.value = activeSearchQuery;
    }
    syncAdminSearchButtons();
  }

  if (searchClear && searchInput) {
    searchClear.addEventListener('click', () => {
      searchInput.value = '';
      syncAdminSearchButtons();
      if (searchDropdown) {
        searchDropdown.style.display = 'none';
        searchDropdown.innerHTML = '';
      }
      // Dispatch input event to refresh table/POS search
      searchInput.dispatchEvent(new Event('input', { bubbles: true }));

      // Also reset any filter dropdowns on the active page (POS, Inventory, Catalog, Orders)
      const filterSelectors = ['#posBrand', '#posCategory', '#filterBrand', '#filterCategory', '#filterStatus', '#filterStockStatus', '#filterSource'];
      let hadFilters = false;
      filterSelectors.forEach(sel => {
        const el = document.querySelector(sel);
        if (el && el.value !== '') {
          el.value = '';
          el.dispatchEvent(new Event('change', { bubbles: true }));
          hadFilters = true;
        }
      });

      searchInput.focus();
    });
  }

  window.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      const activeEl = document.activeElement;
      const isOtherInput = activeEl && (activeEl.tagName === 'INPUT' || activeEl.tagName === 'TEXTAREA') && activeEl !== searchInput;
      if (!isOtherInput) {
        e.preventDefault();
        searchInput?.focus();
        searchInput?.select();
      }
    }
  });

  // 3. Global Admin Search with Autocomplete Dropdown
  if (searchInput && searchDropdown) {
    let debounceTimer = null;
    let selectedIndex = -1;

    const performSearch = async (query) => {
      const trimmed = query.trim();
      if (document.getElementById('posCounter')) {
        if (typeof window.posSearchHandler === 'function') {
          window.posSearchHandler(trimmed);
          return;
        }
        searchDropdown.style.display = 'none';
        return;
      }
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
            const isPos = it.category === 'Point of Sale';
            const badgeClass = isPos ? 'admin-search-badge is-pos' : 'admin-search-badge';
            html += `<a href="${escapeHtml(it.url)}" class="admin-search-item" data-url="${escapeHtml(it.url)}">
              <div class="admin-search-item-info">
                <span class="admin-search-item-title">${escapeHtml(it.title)}</span>
                <span class="admin-search-item-sub">${escapeHtml(it.subtitle)}</span>
              </div>
              <span class="${badgeClass}">${escapeHtml(it.badge || '')}</span>
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
      syncAdminSearchButtons();
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => performSearch(e.target.value), 220);
    });

    searchInput.addEventListener('focus', () => {
      if (document.getElementById('posCounter')) {
        if (typeof window.posSearchHandler === 'function' && searchInput.value.trim().length > 0) {
          window.posSearchHandler(searchInput.value.trim());
        }
        return;
      }
      if (searchInput.value.trim().length > 0 && searchDropdown.children.length > 0) {
        searchDropdown.classList.remove('is-hidden');
        searchDropdown.removeAttribute('hidden');
        searchDropdown.style.display = 'block';
      }
    });

    searchInput.addEventListener('keydown', (e) => {
      if (document.getElementById('posCounter')) {
        if (typeof window.posKeydownHandler === 'function') {
          window.posKeydownHandler(e);
        }
        return;
      }
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
  if (mobileMenuBtn && sidebar) {
    mobileMenuBtn.addEventListener('click', () => {
      setMobileSidebarOpen(!sidebar.classList.contains('is-mobile-open'));
    });
  }
  if (sidebarBackdrop && sidebar) {
    sidebarBackdrop.addEventListener('click', closeMobileSidebar);
  }
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && sidebar?.classList.contains('is-mobile-open')) closeMobileSidebar();
  });
  sidebar?.querySelectorAll('a[href]').forEach(link => link.addEventListener('click', closeMobileSidebar));

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

  window.confirmSignOut = async () => {
    try {
      const response = await fetch('/api/v1/auth/logout', { method: 'POST' });
      if (!response.ok) throw new Error('Sign out failed.');
    } catch (error) {
      window.showAdminToast('Unable to sign out. Please try again.', 'error');
      return;
    }
    window.showAdminToast('Signed out successfully. Redirecting...', 'success', 'Session Ended');
    try {
      localStorage.removeItem('jwt_token');
      localStorage.removeItem('auth_token');
      localStorage.removeItem('user_role');
      localStorage.removeItem('hc_auth_token');
      localStorage.removeItem('hc_user_profile');
      sessionStorage.clear();
      document.cookie = 'jwt_token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
    } catch (e) {}
    setTimeout(() => {
      window.location.href = '/Pages/Auth.aspx?logout=1';
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

  // 6b. Shared confirmation modal for actions that change admin data
  const actionConfirmModal = document.getElementById('adminActionConfirmModal');
  const actionConfirmTitle = document.getElementById('adminActionConfirmTitle');
  const actionConfirmMessage = document.getElementById('adminActionConfirmMessage');
  const btnCancelAdminAction = document.getElementById('btnCancelAdminAction');
  const btnConfirmAdminAction = document.getElementById('btnConfirmAdminAction');
  let pendingAdminAction = null;

  const closeAdminActionModal = () => {
    if (!actionConfirmModal) return;
    actionConfirmModal.classList.add('is-hidden');
    actionConfirmModal.setAttribute('hidden', 'hidden');
    pendingAdminAction = null;
  };

  const showAdminActionModal = (title, message, action) => {
    if (!actionConfirmModal) return;
    actionConfirmTitle.textContent = title || 'Confirm action';
    actionConfirmMessage.textContent = message || 'Are you sure you want to continue?';
    pendingAdminAction = action;
    actionConfirmModal.classList.remove('is-hidden');
    actionConfirmModal.removeAttribute('hidden');
    btnConfirmAdminAction?.focus();
  };

  const openAdminActionModal = (trigger) => {
    if (!trigger) return;
    showAdminActionModal(
      trigger.dataset.confirmTitle,
      trigger.dataset.confirmMessage,
      trigger
    );
  };

  window.requestAdminConfirmation = (title, message, onConfirm) => {
    if (typeof onConfirm !== 'function') return;
    showAdminActionModal(title, message, onConfirm);
  };

  btnCancelAdminAction?.addEventListener('click', closeAdminActionModal);
  btnConfirmAdminAction?.addEventListener('click', () => {
    const action = pendingAdminAction;
    closeAdminActionModal();
    if (typeof action === 'function') {
      action();
      return;
    }
    if (action) {
      action.dataset.confirmed = 'true';
      action.click();
      delete action.dataset.confirmed;
    }
  });
  actionConfirmModal?.addEventListener('click', (event) => {
    if (event.target === actionConfirmModal) closeAdminActionModal();
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && actionConfirmModal && !actionConfirmModal.hasAttribute('hidden')) {
      closeAdminActionModal();
    }
  });
  document.addEventListener('click', (event) => {
    const trigger = event.target.closest('[data-admin-confirm]');
    if (!trigger || trigger.dataset.confirmed === 'true') return;
    event.preventDefault();
    openAdminActionModal(trigger);
  }, true);

  // 7. Toast Notification System
  const queuedToasts = window.__adminToastQueue.splice(0);
  window.showAdminToast = (message, type = 'info', title = null, duration = 4000) => {
    const container = document.getElementById('adminToastContainer');
    if (!container) return;

    const toastType = type === 'error' ? 'error' :
      type === 'warning' || type === 'alert' ? 'warning' :
      type === 'success' ? 'success' : 'info';
    const toast = document.createElement('div');
    toast.className = `toast toast--${toastType}`;
    toast.setAttribute('role', toastType === 'error' ? 'alert' : 'status');
    if (title) toast.setAttribute('aria-label', `${title}: ${message}`);

    let iconSvg = '';
    if (toastType === 'success') {
      iconSvg = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>';
    } else if (toastType === 'error') {
      iconSvg = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>';
    } else if (toastType === 'warning') {
      iconSvg = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0Z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>';
    } else {
      iconSvg = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>';
    }

    const icon = document.createElement('span');
    icon.className = 'toast__icon';
    icon.innerHTML = iconSvg;
    const messageNode = document.createElement('span');
    messageNode.className = 'toast__message';
    messageNode.textContent = String(message ?? '');
    toast.append(icon, messageNode);

    container.appendChild(toast);

    if (duration > 0) {
      setTimeout(() => {
        toast.remove();
      }, duration);
    }
  };

  window.showToast = window.showAdminToast;
  queuedToasts.forEach(args => window.showAdminToast(...args));

  // Handle URL query feedback toasts on initial page load
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.has('toast')) {
    const toastType = urlParams.get('toast') || 'info';
    const toastMsg = urlParams.get('msg') || (toastType === 'success' ? 'Operation completed successfully.' : 'Action notice.');
    window.showAdminToast(toastMsg, toastType);
  }

  // 8. Stock In Modal Handling (Inventory page - Stock In ONLY, with live preview)
  let stockModalDirty = false;
  let stockModalSnapshot = '';

  const getStockModalSnapshot = () => {
    const modal = document.getElementById('stockAdjustModal');
    if (!modal) return '';
    return Array.from(modal.querySelectorAll('input, select, textarea'))
      .map(field => `${field.id}:${field.value}`)
      .join('|');
  };

  const resetStockModalFields = () => {
    const modal = document.getElementById('stockAdjustModal');
    if (!modal) return;
    const txtDelta = document.getElementById('MainContent_txtAdjustQuantity') || document.getElementById('txtAdjustQuantity');
    const reason = document.getElementById('MainContent_ddlAdjustReason') || document.getElementById('ddlAdjustReason');
    const reference = document.getElementById('MainContent_txtAdjustReference') || document.getElementById('txtAdjustReference');
    if (txtDelta) txtDelta.value = '5';
    if (reason) reason.selectedIndex = 0;
    if (reference) reference.value = '';
  };

  const hideStockAdjustModal = () => {
    const modal = document.getElementById('stockAdjustModal');
    if (!modal) return;
    stockModalDirty = false;
    modal.classList.add('is-hidden');
    modal.setAttribute('hidden', 'hidden');
    resetStockModalFields();
  };

  window.openStockAdjustModal = (variantId, title, currentStock) => {
    const modal = document.getElementById('stockAdjustModal');
    const hdnVariantId = document.getElementById('MainContent_hdnAdjustVariantId') || document.getElementById('hdnAdjustVariantId');
    const lblTitle = document.getElementById('adjustModalHelmetTitle');
    const lblCurrentStock = document.getElementById('adjustModalCurrentStock');
    const lblUpdatedStock = document.getElementById('adjustModalUpdatedStock');
    const txtDelta = document.getElementById('MainContent_txtAdjustQuantity') || document.getElementById('txtAdjustQuantity');

    if (modal && hdnVariantId) {
      resetStockModalFields();
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
      window.isStockAdjustSubmitting = false;
      const submitBtn = document.getElementById('MainContent_btnSubmitStockAdjust') || document.getElementById('btnSubmitStockAdjust');
      if (submitBtn) {
        submitBtn.style.pointerEvents = '';
        submitBtn.style.opacity = '';
        if (submitBtn.tagName === 'INPUT') submitBtn.value = 'Add Stock';
        else submitBtn.textContent = 'Add Stock';
      }
      stockModalSnapshot = getStockModalSnapshot();
      stockModalDirty = false;
      modal.classList.remove('is-hidden');
      modal.removeAttribute('hidden');
      txtDelta?.focus();
    }
  };

  window.closeStockAdjustModal = () => {
    const modal = document.getElementById('stockAdjustModal');
    if (!modal) return;
    if (stockModalDirty && typeof window.requestAdminConfirmation === 'function') {
      window.requestAdminConfirmation(
        'Discard stock changes?',
        'Your entered quantity, reason, and reference will be lost.',
        hideStockAdjustModal
      );
      return;
    }
    hideStockAdjustModal();
  };

  document.addEventListener('input', (event) => {
    if (event.target.closest('#stockAdjustModal')) {
      stockModalDirty = getStockModalSnapshot() !== stockModalSnapshot;
    }
  });
  document.addEventListener('change', (event) => {
    if (event.target.closest('#stockAdjustModal')) {
      stockModalDirty = getStockModalSnapshot() !== stockModalSnapshot;
    }
  });

  document.addEventListener('click', (event) => {
    const openButton = event.target.closest('.js-open-stock-modal');
    if (openButton) {
      window.openStockAdjustModal(
        openButton.dataset.variantId,
        openButton.dataset.title,
        openButton.dataset.currentStock
      );
      return;
    }

    if (event.target.closest('.js-close-stock-modal')) {
      window.closeStockAdjustModal();
      return;
    }

    const modal = document.getElementById('stockAdjustModal');
    if (modal && event.target === modal) {
      window.closeStockAdjustModal();
    }
  });

  document.addEventListener('keydown', (event) => {
    const modal = document.getElementById('stockAdjustModal');
    if (event.key === 'Escape' && modal && !modal.hasAttribute('hidden')) {
      window.closeStockAdjustModal();
    }
  });

  // 9. Add / Edit Helmet Model Modal & Tabbed Wizard (Legacy Catalog Modal)
  if (document.getElementById('addProductModal')) {
    window.activeColors = [
    { name: 'Matte Black', type: 'solid', hex: '#18181B' },
    { name: 'Pearl White', type: 'solid', hex: '#FFFFFF' },
    { name: 'Racing Red', type: 'solid', hex: '#DC2626' }
  ];

  window.selectedFilesList = [];
  let draggedImageIndex = null;

  const namedHelmetColors = [
    { name: 'Jet Black', hex: '#000000' },
    { name: 'Matte Black', hex: '#18181B' },
    { name: 'Graphite Gray', hex: '#52525B' },
    { name: 'Silver Gray', hex: '#A1A1AA' },
    { name: 'Pearl White', hex: '#FFFFFF' },
    { name: 'Racing Red', hex: '#DC2626' },
    { name: 'Burnt Orange', hex: '#EA580C' },
    { name: 'Sunburst Yellow', hex: '#EAB308' },
    { name: 'Lime Green', hex: '#65A30D' },
    { name: 'Emerald Green', hex: '#059669' },
    { name: 'Teal Blue', hex: '#0D9488' },
    { name: 'Sky Blue', hex: '#38BDF8' },
    { name: 'Racing Blue', hex: '#2563EB' },
    { name: 'Deep Navy', hex: '#1E3A8A' },
    { name: 'Royal Purple', hex: '#7E22CE' },
    { name: 'Vivid Pink', hex: '#DB2777' },
    { name: 'Rose Gold', hex: '#BE7C68' },
    { name: 'Chocolate Brown', hex: '#78350F' }
  ];

  function hexToRgb(hex) {
    const normalized = String(hex || '').replace('#', '');
    if (!/^[0-9A-Fa-f]{6}$/.test(normalized)) return null;
    return {
      r: parseInt(normalized.substring(0, 2), 16),
      g: parseInt(normalized.substring(2, 4), 16),
      b: parseInt(normalized.substring(4, 6), 16)
    };
  }

  function getNearestColorName(hex) {
    const target = hexToRgb(hex);
    if (!target) return 'Custom Color';
    return namedHelmetColors.reduce((closest, candidate) => {
      const rgb = hexToRgb(candidate.hex);
      const distance = Math.pow(target.r - rgb.r, 2) + Math.pow(target.g - rgb.g, 2) + Math.pow(target.b - rgb.b, 2);
      return distance < closest.distance ? { name: candidate.name, distance } : closest;
    }, { name: 'Custom Color', distance: Number.POSITIVE_INFINITY }).name;
  }

  function setSuggestedColorName(name, force) {
    const nameInput = document.getElementById('txtCustomColorName');
    if (!nameInput || (!force && nameInput.dataset.customized === 'true')) return;
    nameInput.value = name;
    nameInput.dataset.customized = 'false';
  }

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
    syncSelectedFilesToInput();
    renderImageTiles();
    setSuggestedColorName('Matte Black', true);

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
    if (imgUrlInput && imgUrl) imgUrlInput.value = imgUrl;

    const descInput = document.getElementById('MainContent_txtNewDescription') || document.getElementById('txtNewDescription');
    if (descInput) descInput.value = desc || '';

    window.selectedFilesList = [];
    syncSelectedFilesToInput();
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
      const first = document.getElementById('pickerGrad1')?.value || '#DC2626';
      const second = document.getElementById('pickerGrad2')?.value || '#18181B';
      setSuggestedColorName(`${getNearestColorName(first)} / ${getNearestColorName(second)}`, true);
      updateGradientPreview();
    } else {
      btnSolid?.classList.add('active');
      btnGrad?.classList.remove('active');
      solidBox?.classList.remove('is-hidden');
      gradBox?.classList.add('is-hidden');
      const solid = document.getElementById('pickerSolidColor')?.value || '#18181B';
      setSuggestedColorName(getNearestColorName(solid), true);
    }
  };

  window.syncSolidHex = (val) => {
    const hexInput = document.getElementById('txtSolidHex');
    if (hexInput) hexInput.value = String(val || '').toUpperCase();
    setSuggestedColorName(getNearestColorName(val), false);
  };

  window.syncSolidPicker = (val) => {
    const picker = document.getElementById('pickerSolidColor');
    if (picker && /^#[0-9A-Fa-f]{6}$/.test(val)) {
      picker.value = val;
      setSuggestedColorName(getNearestColorName(val), false);
    }
  };

  window.updateGradientPreview = () => {
    const c1 = document.getElementById('pickerGrad1')?.value || '#DC2626';
    const c2 = document.getElementById('pickerGrad2')?.value || '#18181B';
    const deg = document.getElementById('numGradAngle')?.value || '135';
    const preview = document.getElementById('gradPreviewBox');
    if (preview) {
      preview.style.background = `linear-gradient(${deg}deg, ${c1}, ${c2})`;
    }
    setSuggestedColorName(`${getNearestColorName(c1)} / ${getNearestColorName(c2)}`, false);
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

    if (nameInput) {
      nameInput.dataset.customized = 'false';
      if (isGrad) {
        const c1 = document.getElementById('pickerGrad1')?.value || '#DC2626';
        const c2 = document.getElementById('pickerGrad2')?.value || '#18181B';
        nameInput.value = `${getNearestColorName(c1)} / ${getNearestColorName(c2)}`;
      } else {
        nameInput.value = getNearestColorName(document.getElementById('pickerSolidColor')?.value || '#18181B');
      }
    }
    renderColorChips();
  };

  window.removeColorFromPalette = (idx) => {
    if (window.activeColors && idx >= 0 && idx < window.activeColors.length) {
      window.activeColors.splice(idx, 1);
      renderColorChips();
    }
  };

  const customColorNameInput = document.getElementById('txtCustomColorName');
  customColorNameInput?.addEventListener('input', () => {
    customColorNameInput.dataset.customized = 'true';
  });

  // Multi-Image Upload & Preview Grid
  function syncSelectedFilesToInput() {
    const input = document.getElementById('MainContent_fileUploadImages') || document.getElementById('fileUploadImages');
    if (!input || typeof DataTransfer === 'undefined') return;
    const transfer = new DataTransfer();
    window.selectedFilesList.forEach(file => transfer.items.add(file));
    input.files = transfer.files;
  }

  function addSelectedImageFiles(files) {
    const validExts = ['.jpg', '.jpeg', '.png', '.webp'];
    const maxBytes = 5 * 1024 * 1024;

    Array.from(files || []).forEach(file => {
      const ext = '.' + file.name.split('.').pop().toLowerCase();
      if (!validExts.includes(ext)) {
        window.showAdminToast(`File "${file.name}" is not a supported image.`, 'warning', 'Invalid File Type');
        return;
      }
      if (file.size > maxBytes) {
        window.showAdminToast(`File "${file.name}" exceeds the upload limit.`, 'warning', 'File Too Large');
        return;
      }
      const duplicate = window.selectedFilesList.some(existing =>
        existing.name === file.name && existing.size === file.size && existing.lastModified === file.lastModified);
      if (!duplicate) window.selectedFilesList.push(file);
    });

    syncSelectedFilesToInput();
    renderImageTiles();
  }

  window.handleMultipleImageSelection = (input) => {
    if (!input.files || input.files.length === 0) return;
    addSelectedImageFiles(input.files);
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
        <div class="admin-upload-tile" data-idx="${idx}" draggable="true" tabindex="0" aria-label="${escapeHtml(file.name)}, position ${idx + 1}. Drag to reorder.">
          <img src="${blobUrl}" alt="${escapeHtml(file.name)}" />
          <span class="admin-upload-tile-badge">${isPrimary ? 'Primary' : '#' + (idx + 1)}</span>
          <button type="button" class="admin-upload-tile-remove" onclick="removeImageTile(${idx});" title="Remove image" aria-label="Remove ${escapeHtml(file.name)}">&times;</button>
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
      syncSelectedFilesToInput();
      renderImageTiles();
    }
  };

  const imageGrid = document.getElementById('imageUploadGrid');
  imageGrid?.addEventListener('dragstart', event => {
    const tile = event.target.closest('.admin-upload-tile');
    if (!tile) return;
    draggedImageIndex = parseInt(tile.dataset.idx, 10);
    tile.classList.add('is-dragging');
    event.dataTransfer.effectAllowed = 'move';
  });
  imageGrid?.addEventListener('dragover', event => {
    const tile = event.target.closest('.admin-upload-tile');
    if (!tile || draggedImageIndex === null) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
    imageGrid.querySelectorAll('.admin-upload-tile').forEach(item => item.classList.remove('is-drop-target'));
    tile.classList.add('is-drop-target');
  });
  imageGrid?.addEventListener('drop', event => {
    const tile = event.target.closest('.admin-upload-tile');
    if (!tile || draggedImageIndex === null) return;
    event.preventDefault();
    const dropIndex = parseInt(tile.dataset.idx, 10);
    if (dropIndex !== draggedImageIndex) {
      const moved = window.selectedFilesList.splice(draggedImageIndex, 1)[0];
      window.selectedFilesList.splice(dropIndex, 0, moved);
      syncSelectedFilesToInput();
    }
    draggedImageIndex = null;
    renderImageTiles();
  });
  imageGrid?.addEventListener('dragend', () => {
    draggedImageIndex = null;
    imageGrid.querySelectorAll('.admin-upload-tile').forEach(item => item.classList.remove('is-dragging', 'is-drop-target'));
  });

  const imageDropzone = document.getElementById('imageDropzone');
  imageDropzone?.addEventListener('dragover', event => {
    event.preventDefault();
    imageDropzone.classList.add('is-dragover');
  });
  imageDropzone?.addEventListener('dragleave', () => imageDropzone.classList.remove('is-dragover'));
  imageDropzone?.addEventListener('drop', event => {
    event.preventDefault();
    imageDropzone.classList.remove('is-dragover');
    addSelectedImageFiles(event.dataTransfer.files);
  });

  // Wizard tab switching (Only for legacy #addProductModal on Catalog.aspx)
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
    const descriptionInput = document.getElementById('MainContent_txtNewDescription') || document.getElementById('txtNewDescription');

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
    setReviewVal('reviewSummaryDescription', descriptionInput?.value?.trim() || 'Product description will appear here.');

    const basePriceLabel = document.getElementById('reviewSummaryBasePrice');
    const discountLabel = document.getElementById('reviewSummaryDiscount');
    basePriceLabel?.classList.toggle('is-hidden', dVal <= 0);
    discountLabel?.classList.toggle('is-hidden', dVal <= 0);

    const colorSwatches = document.getElementById('reviewColorSwatches');
    if (colorSwatches) {
      colorSwatches.innerHTML = (window.activeColors || []).map(color => {
        const swatchStyle = color.type === 'gradient' ? `background:${color.hex};` : `background-color:${color.hex};`;
        return `<span class="admin-product-detail-mini__swatch" style="${swatchStyle}" title="${escapeHtml(color.name)}" aria-label="${escapeHtml(color.name)}"></span>`;
      }).join('');
    }

    const sizeOptions = document.getElementById('reviewSizeOptions');
    if (sizeOptions) {
      const selectedSizes = Array.from(document.querySelectorAll('.chk-new-size:checked')).map(input => input.value);
      sizeOptions.innerHTML = selectedSizes.map(size => `<span>${escapeHtml(size)}</span>`).join('');
    }

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

    const uploadedCount = window.selectedFilesList?.length || 0;
    const imagesCount = uploadedCount > 0 ? uploadedCount : (imgUrlInput?.value.trim() ? 1 : 0);
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
  }

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
