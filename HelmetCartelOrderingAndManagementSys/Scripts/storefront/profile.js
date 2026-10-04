import { renderReceipt, printReceipt, focusReceiptDialog } from '../receipt.js?v=20261003-3';
/**
 * HELMET CARTEL - USER PROFILE, ORDER TRACKING & WISHLIST CONTROLLER (profile.js)
 * Features:
 * - Admin-inspired sidebar navigation with live item counters
 * - Order History with navbar-style search and sort-by filters
 * - Stacking deck image layout matching 4th screenshot
 * - Collapsible order items accordion with specs, quantities, line totals
 * - Integrated Wishlist management panel with real-time sync
 * - Saved Delivery Addresses management with modal CRUD
 * - Payment Transactions history & official printable digital receipts
 * - Profile details & security forms with inline validation
 * - Real-time SignalR order updates
 */

import { ApiClient } from "../api.js";
import { ShoppingState } from "../shopping-state.js?v=20261004";
import { APP_CONSTANTS } from "../constants.js";
import { RealtimeManager } from "../realtime.js";
import { FavoritesManager } from "../favorites.js?v=20261004";

export const ProfileController = {
  currentUser: null,
  orders: [],
  payments: [],
  addresses: [],
  orderDetailsCache: new Map(),
  activeTab: "orders",
  activeSort: "newest",
  searchQuery: "",

  async init() {
    this.bindSidebarTabEvents();
    this.bindSearchAndSortEvents();
    this.bindFormEvents();
    this.bindAddressEvents();
    this.bindReceiptModalEvents();
    this.bindCancelOrderEvents();
    this.bindRmaEvents();
    this.bindWishlistEvents();
    this.bindLogoutEvent();
    this.initSignalRListener();

    // Check query params or session storage for tab (e.g. ?tab=wishlist)
    const urlParams = new URLSearchParams(window.location.search);
    const requestedTab =
      urlParams.get("tab") || sessionStorage.getItem("hc_profile_active_tab");
    if (requestedTab) {
      this.switchTab(requestedTab);
    }

    await this.loadUserProfile();
    await Promise.all([
      this.loadUserOrders(),
      this.loadUserPayments(),
      this.loadUserAddresses(),
    ]);

    this.updateWishlistCount();
    this.renderWishlist();
  },

  /* ==========================================================================
     1. AUTH & USER PROFILE
     ========================================================================== */
  async loadUserProfile() {
    try {
      const res = await ApiClient.getProfile();
      const profile = res && res.data ? res.data : res;
      if (!profile || (!profile.id && !profile.email)) {
        this.redirectToLogin();
        return;
      }

      this.currentUser = profile;
      localStorage.setItem(
        APP_CONSTANTS.STORAGE_KEYS.USER_PROFILE,
        JSON.stringify(this.currentUser),
      );
      this.renderUserProfileSidebar();
      this.populateEditProfileForm();
    } catch (err) {
      console.warn("[ProfileController] Session check notice:", err);
      this.redirectToLogin();
    }
  },

  redirectToLogin() {
    const returnUrl = encodeURIComponent(
      window.location.pathname + window.location.search,
    );
    window.location.href = `${APP_CONSTANTS.ROUTES.AUTH}?returnUrl=${returnUrl}&authRequired=1`;
  },

  renderUserProfileSidebar() {
    const u = this.currentUser;
    if (!u) return;

    // Avatar initials
    const initials =
      ((u.firstName?.[0] || "") + (u.lastName?.[0] || "")).toUpperCase() ||
      "HC";
    const avatarEl = document.getElementById("profile-avatar");
    if (avatarEl) avatarEl.textContent = initials;

    // Sidebar full name & verified text
    const nameEl = document.getElementById("profile-user-name");
    if (nameEl)
      nameEl.textContent =
        u.fullName ||
        `${u.firstName || ""} ${u.lastName || ""}`.trim() ||
        "Cartel Member";

    const roleEl = document.getElementById("profile-role-text");
    if (roleEl) {
      if (u.createdAt) {
        const createdDate = new Date(u.createdAt);
        const formattedDate = createdDate.toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
          year: "numeric",
        });
        roleEl.textContent = `Created: ${formattedDate}`;
      } else {
        roleEl.textContent = "Created: Cartel Member";
      }
    }

    // Populate edit profile inputs
    const fName = document.getElementById("edit-first-name");
    const lName = document.getElementById("edit-last-name");
    const email = document.getElementById("edit-email");
    const phone = document.getElementById("edit-phone");

    if (fName) fName.value = u.firstName || "";
    if (lName) lName.value = u.lastName || "";
    if (email) email.value = u.email || "";
    if (phone) phone.value = u.phoneNumber || "";
  },

  populateEditProfileForm() {
    if (!this.currentUser) return;
    const fName = document.getElementById("edit-first-name");
    const lName = document.getElementById("edit-last-name");
    const email = document.getElementById("edit-email");
    const phone = document.getElementById("edit-phone");

    if (fName && !fName.value) fName.value = this.currentUser.firstName || "";
    if (lName && !lName.value) lName.value = this.currentUser.lastName || "";
    if (email && !email.value) email.value = this.currentUser.email || "";
    if (phone && !phone.value) phone.value = this.currentUser.phoneNumber || "";
  },

  /* ==========================================================================
     2. SIDEBAR TAB NAVIGATION & COUNTERS
     ========================================================================== */
  bindSidebarTabEvents() {
    const navLinks = document.querySelectorAll(".profile-nav-link[data-tab]");
    navLinks.forEach((link) => {
      link.addEventListener("click", (e) => {
        e.preventDefault();
        const tab = link.dataset.tab;
        this.switchTab(tab);
      });
    });

    // Listen to mobile nav drawer tab links when on Profile page
    document
      .querySelectorAll('#mobile-nav-drawer a[href*="tab="]')
      .forEach((link) => {
        link.addEventListener("click", (e) => {
          try {
            const url = new URL(link.href, window.location.origin);
            const tab = url.searchParams.get("tab");
            if (tab) {
              e.preventDefault();
              this.switchTab(tab);
              const drawer = document.getElementById("mobile-nav-drawer");
              const overlay = document.getElementById("mobile-nav-overlay");
              drawer?.classList.remove("is-open");
              overlay?.classList.remove("is-open");
              drawer?.setAttribute("aria-hidden", "true");
              document.body.classList.remove("drawer-locked");
              window.history.pushState(null, "", `?tab=${tab}`);
            }
          } catch (_) {}
        });
      });

    // Listen to favorites changes
    window.addEventListener("favoritesUpdated", () => {
      this.updateWishlistCount();
      if (this.activeTab === "wishlist") {
        this.renderWishlist();
      }
    });
  },

  switchTab(tabName) {
    if (!tabName) return;
    this.activeTab = tabName;

    try {
      sessionStorage.setItem("hc_profile_active_tab", tabName);
      const url = new URL(window.location.href);
      if (url.searchParams.get("tab") !== tabName) {
        url.searchParams.set("tab", tabName);
        window.history.replaceState(null, "", url.toString());
      }
    } catch (_) {}

    // Update active tab buttons
    document.querySelectorAll(".profile-nav-link[data-tab]").forEach((btn) => {
      const isActive = btn.dataset.tab === tabName;
      btn.classList.toggle("active", isActive);
      btn.setAttribute("aria-selected", isActive ? "true" : "false");
    });

    // Update active content panes
    document.querySelectorAll(".profile-tab-pane").forEach((pane) => {
      pane.classList.toggle("active", pane.id === `tab-pane-${tabName}`);
    });

    // Update breadcrumb label
    const breadcrumbLabel = document.getElementById("profile-breadcrumb-label");
    if (breadcrumbLabel) {
      const labels = {
        orders: "Order history",
        details: "Account details",
        wishlist: "Wishlist",
        addresses: "Addresses",
        payments: "Payment history",
        security: "Security & Password",
      };
      breadcrumbLabel.textContent = labels[tabName] || "Account";
    }

    // If wishlist tab selected, ensure fresh render
    if (tabName === "wishlist") {
      this.renderWishlist();
    }

    // Scroll to top of content area on small screens
    if (window.innerWidth <= 992) {
      const mainContent = document.querySelector(".profile-content-area");
      mainContent?.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  },

  updateCounters() {
    const ordersCount = this.orders.length;
    const ordersCountEl = document.getElementById("nav-count-orders");
    if (ordersCountEl) {
      ordersCountEl.textContent = ordersCount > 0 ? String(ordersCount) : "";
      ordersCountEl.style.display = ordersCount > 0 ? "inline-block" : "none";
    }

    const addressesCount = this.addresses.length;
    const addressesCountEl = document.getElementById("nav-count-addresses");
    if (addressesCountEl) {
      addressesCountEl.textContent =
        addressesCount > 0 ? String(addressesCount) : "";
      addressesCountEl.style.display =
        addressesCount > 0 ? "inline-block" : "none";
    }

    const paymentsCount = this.payments.length;
    const paymentsCountEl = document.getElementById("nav-count-payments");
    if (paymentsCountEl) {
      paymentsCountEl.textContent =
        paymentsCount > 0 ? String(paymentsCount) : "";
      paymentsCountEl.style.display =
        paymentsCount > 0 ? "inline-block" : "none";
    }

    this.updateWishlistCount();
  },

  updateWishlistCount() {
    const wishlistItems = FavoritesManager.getItems();
    const count = wishlistItems.length;
    const countEl = document.getElementById("nav-count-wishlist");
    if (countEl) {
      countEl.textContent = count > 0 ? String(count) : "";
      countEl.style.display = count > 0 ? "inline-block" : "none";
    }

    const descEl = document.getElementById("profile-wishlist-count-desc");
    if (descEl) {
      descEl.textContent =
        count === 0
          ? "You don't have any saved helmets yet."
          : `${count} ${count === 1 ? "helmet" : "helmets"} saved to your personal wishlist.`;
    }

    const clearBtn = document.getElementById("btn-clear-profile-wishlist");
    if (clearBtn) clearBtn.style.display = count > 0 ? "inline-block" : "none";
  },

  /* ==========================================================================
     3. ORDER HISTORY TAB WITH SEARCH & SORT
     ========================================================================== */
  async loadUserOrders() {
    const loadingEl = document.getElementById("orders-loading-state");
    const emptyEl = document.getElementById("orders-empty-state");
    const listEl = document.getElementById("order-cards-container");

    if (loadingEl) loadingEl.style.display = "flex";
    if (emptyEl) emptyEl.style.display = "none";
    if (listEl) listEl.style.display = "none";

    try {
      const response = await ApiClient.getUserOrders();
      const list = Array.isArray(response)
        ? response
        : response?.data && Array.isArray(response.data)
          ? response.data
          : [];
      this.orders = list;
      // Pre-populate order details cache instantly from preloaded order items
      for (const ord of list) {
        if (ord && ord.id && Array.isArray(ord.items) && ord.items.length > 0) {
          this.orderDetailsCache.set(ord.id, ord);
        }
      }
      this.updateCounters();
      this.renderOrders();
    } catch (err) {
      console.error("[ProfileController] Failed to load orders:", err);
      this.orders = [];
      this.updateCounters();
      this.renderOrders();
    } finally {
      if (loadingEl) loadingEl.style.display = "none";
    }
  },

  async prefetchOrderDetails(_orders) {
    // Deprecated: orders are now pre-loaded with ItemsJson from dbo.sp_GetUserOrders
  },

  bindSearchAndSortEvents() {
    const sortBtn = document.getElementById("order-sort-btn");
    const sortMenu = document.getElementById("order-sort-menu");
    const sortLabel = document.getElementById("current-order-sort-label");
    const sortWrap = document.getElementById("order-sort-dropdown-wrap");

    if (sortBtn && sortMenu && sortLabel) {
      sortBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        const isOpen = sortMenu.classList.toggle("is-open");
        sortBtn.classList.toggle("active", isOpen);
        sortBtn.setAttribute("aria-expanded", String(isOpen));
      });

      sortMenu.querySelectorAll(".shop-sort-option").forEach((opt) => {
        opt.addEventListener("click", (e) => {
          e.stopPropagation();
          const sortType = opt.getAttribute("data-sort");
          const sortText = opt.textContent.trim();

          sortMenu
            .querySelectorAll(".shop-sort-option")
            .forEach((o) => o.classList.remove("active"));
          opt.classList.add("active");
          sortLabel.textContent = sortText;
          sortMenu.classList.remove("is-open");
          sortBtn.classList.remove("active");
          sortBtn.setAttribute("aria-expanded", "false");

          this.activeSort = sortType;
          this.renderOrders();
        });
      });

      document.addEventListener("click", (e) => {
        if (!sortWrap?.contains(e.target)) {
          sortMenu.classList.remove("is-open");
          sortBtn.classList.remove("active");
          sortBtn.setAttribute("aria-expanded", "false");
        }
      });
    }
  },

  renderOrders() {
    const listEl = document.getElementById("order-cards-container");
    const emptyEl = document.getElementById("orders-empty-state");
    if (!listEl || !emptyEl) return;

    let result = [...this.orders];

    // Filter by search query
    if (this.searchQuery) {
      const q = this.searchQuery;
      result = result.filter((o) => {
        const numMatch = (o.orderNumber || "").toLowerCase().includes(q);
        const statusMatch = (o.orderStatus || "").toLowerCase().includes(q);
        const courierMatch = (o.courier || "").toLowerCase().includes(q);
        const gatewayMatch = (o.paymentGateway || "").toLowerCase().includes(q);
        return numMatch || statusMatch || courierMatch || gatewayMatch;
      });
    }

    // Filter or sort by dropdown
    switch (this.activeSort) {
      case "newest":
        result.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        break;
      case "oldest":
        result.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
        break;
      case "amount-high":
        result.sort(
          (a, b) => (Number(b.totalAmount) || 0) - (Number(a.totalAmount) || 0),
        );
        break;
      case "amount-low":
        result.sort(
          (a, b) => (Number(a.totalAmount) || 0) - (Number(b.totalAmount) || 0),
        );
        break;
      case "status-active":
        result = result.filter((o) =>
          [
            "PendingPayment",
            "Processing",
            "ReadyForPickup",
            "Shipped",
          ].includes(o.orderStatus),
        );
        result.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        break;
      case "status-completed":
        result = result.filter((o) =>
          ["Delivered", "Completed"].includes(o.orderStatus),
        );
        result.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        break;
      case "status-cancelled":
        result = result.filter((o) => o.orderStatus === "Cancelled");
        result.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        break;
    }

    if (result.length === 0) {
      listEl.innerHTML = "";
      listEl.style.display = "none";
      emptyEl.style.display = "flex";
      return;
    }

    emptyEl.style.display = "none";
    listEl.style.display = "flex";
    listEl.innerHTML = result
      .map((order) => this.createOrderCardHtml(order))
      .join("");

    this.bindOrderCardEvents();
  },

  createOrderCardHtml(order) {
    const status = order.orderStatus || "Processing";
    const statusLabel = this.formatStatusLabel(status);
    const dateFormatted = new Date(order.createdAt).toLocaleDateString(
      "en-US",
      {
        month: "short",
        day: "numeric",
        year: "numeric",
      },
    );
    const totalFormatted = Number(order.totalAmount || 0).toLocaleString(
      "en-US",
      {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      },
    );

    const isDelivery =
      String(order.shippingMethod).toLowerCase() === "delivery";
    const trackOrderUrl = `${APP_CONSTANTS.ROUTES.TRACK_ORDER}?orderNumber=${encodeURIComponent(order.orderNumber)}`;

    // Stacking image deck placeholder / items if cached or from preview list
    const cachedDetails = this.orderDetailsCache.get(order.id);
    const items = cachedDetails ? cachedDetails.items : (Array.isArray(order.items) ? order.items : []);
    const deckHtml = this.createStackingDeckHtml(order, items);

    const canCancel = ["PendingPayment", "Processing"].includes(status);
    const canReturn = ["Delivered", "Completed"].includes(status);

    // Evaluate if there are items eligible for return (not already in an active/completed RMA)
    let eligibleItemsCount = 0;
    if (items && items.length > 0) {
      eligibleItemsCount = items.filter((item) => {
        const st = String(item.rmaStatus || '').trim().toLowerCase();
        return !item.rmaNumber || st === 'rejected' || st === 'cancelled';
      }).length;
    } else {
      const rmaCount = Number(order.rmaCount || 0);
      const itemCount = Number(order.itemCount || 1);
      eligibleItemsCount = Math.max(0, itemCount - rmaCount);
    }
    const hasEligibleItems = eligibleItemsCount > 0;

    return `
      <article class="order-row-card" data-order-id="${order.id}" data-order-number="${this.escapeHtml(order.orderNumber)}">
        <!-- Order Header Row (Matching 1st Screenshot) -->
        <div class="order-row-card__header">
          <div class="order-row-card__meta-left">
            <div class="order-row-card__title-line">
              <span class="order-num-label">Order Number:</span>
              <strong class="order-num-value">${this.escapeHtml(order.orderNumber)}</strong>
              <span class="order-date-text">${dateFormatted}</span>
            </div>
            <div class="order-row-card__status-line">
              <span class="order-pill-badge status--${status.toLowerCase()}">${statusLabel}</span>
              ${
                order.latestRmaStatus
                  ? `<span class="order-pill-badge status--rma-${order.latestRmaStatus.toLowerCase()}">${this.getRmaDescriptor(order.latestRmaType, order.latestRmaStatus)}</span>`
                  : ''
              }
            </div>
          </div>

          <div class="order-row-card__summary-right">
            <!-- 4th Screenshot: Stacking Deck Layout Preview -->
            <div class="order-deck-stack" id="deck-stack-${order.id}" aria-label="Purchased item preview">
              ${deckHtml}
            </div>

            <div class="order-total-block">
              <span class="order-total-caption">Total</span>
              <span class="order-total-figure">&#8369;${totalFormatted}</span>
            </div>

            <button type="button" class="order-accordion-toggle-btn" data-order-id="${order.id}" aria-label="Toggle purchased items details" aria-expanded="false">
              <svg class="order-toggle-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="6 9 12 15 18 9"></polyline>
              </svg>
            </button>
          </div>
        </div>

        <!-- Collapsible Dropdown for Items Details, Quantity, Price, etc. -->
        <div class="order-row-card__dropdown" id="order-details-dropdown-${order.id}">
          <div class="order-items-body" id="order-items-body-${order.id}">
            <div class="order-items-loading">Loading purchased item details...</div>
          </div>

          <div class="order-dropdown-footer">
            <div class="order-dropdown-secondary-actions">
              ${
                canCancel
                  ? `
                <button type="button" class="btn btn--outline btn--sm btn-cancel-order" data-order-id="${order.id}" data-order-number="${this.escapeHtml(order.orderNumber)}">
                  <span>Cancel Order</span>
                </button>
              `
                  : ""
              }
              ${
                canReturn && hasEligibleItems && (!order.rmaCount || order.rmaCount === 0)
                  ? `
                <button type="button" class="btn btn--outline btn--sm btn-return-order" data-order-id="${order.id}" data-order-number="${this.escapeHtml(order.orderNumber)}">
                  <span>Return / Exchange</span>
                </button>
              `
                  : canReturn && hasEligibleItems && order.rmaCount > 0
                  ? `
                <button type="button" class="btn btn--outline btn--sm btn-return-order" data-order-id="${order.id}" data-order-number="${this.escapeHtml(order.orderNumber)}">
                  <span>Return Remaining Items</span>
                </button>
                <span class="order-status-hint order-status-hint--rma order-status-hint--rma-${(order.latestRmaStatus || 'pending').toLowerCase()}">
                  ${this.getRmaDescriptor(order.latestRmaType, order.latestRmaStatus)}
                </span>
              `
                  : order.rmaCount > 0
                  ? `
                <span class="order-status-hint order-status-hint--rma order-status-hint--rma-${(order.latestRmaStatus || 'pending').toLowerCase()}">
                  ${this.getRmaDescriptor(order.latestRmaType, order.latestRmaStatus)}
                </span>
              `
                  : ""
              }
              ${
                !canCancel && !canReturn
                  ? `
                <span class="order-status-hint ${status === "Cancelled" ? "order-status-hint--cancelled" : ""}">
                  ${status === "Cancelled" ? "Order Cancelled &mdash; Reserved stock released" : "Order in transit &mdash; Return available upon delivery"}
                </span>
              `
                  : ""
              }
            </div>
            <div class="order-dropdown-actions">
              <a href="${trackOrderUrl}" class="btn btn--outline btn--sm">
                <span>Track Full Status</span>
              </a>
              <button type="button" class="btn btn--primary btn--sm btn-view-receipt" data-order-id="${order.id}">
                <span>View Digital Receipt</span>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                  <line x1="7" y1="17" x2="17" y2="7"></line>
                  <polyline points="7 7 17 7 17 17"></polyline>
                </svg>
              </button>
            </div>
          </div>
        </div>
      </article>
    `;
  },

  /**
   * Stacking card deck preview matching 4th screenshot
   */
  createStackingDeckHtml(order, items) {
    let images = [];
    if (items && items.length > 0) {
      images = items.map((i) => i.mainImageUrl || i.imageUrl).filter(Boolean);
    } else if (
      order &&
      order.previewImageList &&
      order.previewImageList.length > 0
    ) {
      images = order.previewImageList;
    } else if (order && order.previewImages) {
      images = order.previewImages.split(";").filter(Boolean);
    }

    if (images.length === 0) {
      return `
        <div class="deck-item deck-item--0">
          <img src="/Content/images/placeholder-helmet.png" alt="Gear thumbnail" />
        </div>
      `;
    }

    const previewImages = images.slice(0, 3);
    const totalCount = order?.itemCount || items?.length || images.length;
    const extraCount = Math.max(0, totalCount - previewImages.length);

    return `
      ${previewImages
        .map(
          (imgUrl, idx) => `
          <div class="deck-item deck-item--${idx}">
            <img src="${this.escapeHtml(imgUrl)}" alt="Gear thumbnail" />
          </div>
        `,
        )
        .join("")}
      ${extraCount > 0 ? `<span class="deck-badge">+${extraCount}</span>` : ""}
    `;
  },

  updateOrderCardDeck(orderId, items) {
    const deckEl = document.getElementById(`deck-stack-${orderId}`);
    if (deckEl) {
      deckEl.innerHTML = this.createStackingDeckHtml({ id: orderId }, items);
    }
  },

  bindOrderCardEvents() {
    // Accordion expand/collapse
    document.querySelectorAll(".order-accordion-toggle-btn").forEach((btn) => {
      btn.addEventListener("click", async (e) => {
        e.stopPropagation();
        const orderId = Number(btn.dataset.orderId);
        const card = btn.closest(".order-row-card");
        const dropdown = document.getElementById(
          `order-details-dropdown-${orderId}`,
        );
        const body = document.getElementById(`order-items-body-${orderId}`);
        if (!dropdown || !body) return;

        const isOpen = dropdown.classList.toggle("is-open");
        card?.classList.toggle("is-expanded", isOpen);
        btn.setAttribute("aria-expanded", isOpen ? "true" : "false");

        // Load items if not loaded yet
        if (isOpen && !body.dataset.loaded) {
          try {
            let orderData = this.orderDetailsCache.get(orderId);
            if (!orderData) {
              const res = await ApiClient.getUserOrderDetails(orderId);
              orderData = res?.data || res;
              if (orderData) this.orderDetailsCache.set(orderId, orderData);
            }

            if (orderData && Array.isArray(orderData.items)) {
              this.updateOrderCardDeck(orderId, orderData.items);
              body.innerHTML = orderData.items
                .map((item) => {
                  const imgUrl =
                    item.mainImageUrl ||
                    item.imageUrl ||
                    "/Content/images/placeholder-helmet.png";
                  const unitPrice = Number(item.unitPrice || 0);
                  const totalPrice = Number(
                    item.totalPrice || unitPrice * item.quantity,
                  );

                  return `
                  <div class="order-item-detail-row">
                    <a href="/Pages/Storefront/ProductDetail/ProductDetail.aspx?id=${item.productId || 1}" class="order-item-detail-img-link" title="View Product Details">
                      <img src="${this.escapeHtml(imgUrl)}" alt="${this.escapeHtml(item.productName)}" class="order-item-detail-img" />
                    </a>
                    <div class="order-item-detail-info">
                      <h4 class="order-item-detail-title" title="${this.escapeHtml(item.productName)}">
                        <a href="/Pages/Storefront/ProductDetail/ProductDetail.aspx?id=${item.productId || 1}" class="order-item-title-link">${this.escapeHtml(item.productName)}</a>
                      </h4>
                      <div class="order-item-detail-specs">
                        ${item.size ? `<span>Size: <strong>${this.escapeHtml(item.size)}</strong></span>` : ""}
                        ${item.color ? `<span>Color: <strong>${this.escapeHtml(item.color)}</strong></span>` : ""}
                        ${item.sku ? `<span>SKU: <code>${this.escapeHtml(item.sku)}</code></span>` : ""}
                      </div>
                    </div>
                    <div class="order-item-detail-pricing">
                      <span class="order-item-qty-tag">${item.quantity} pc${item.quantity > 1 ? "s" : ""} &times; &#8369;${unitPrice.toLocaleString("en-US", { minimumFractionDigits: 2 })}</span>
                      <strong class="order-item-line-total">&#8369;${totalPrice.toLocaleString("en-US", { minimumFractionDigits: 2 })}</strong>
                      ${
                        item.rmaNumber
                          ? `<div class="order-item-action-wrap"><span class="track-rma-chip track-rma-chip--${(item.rmaStatus || 'pending').toLowerCase()}">${this.getRmaDescriptor(item.rmaType, item.rmaStatus)} &bull; #${this.escapeHtml(item.rmaNumber)}</span></div>`
                          : ''
                      }
                    </div>
                  </div>
                `;
                })
                .join("");
              body.dataset.loaded = "true";
            } else {
              body.innerHTML =
                '<div class="order-items-empty">No item records found for this order.</div>';
            }
          } catch (err) {
            body.innerHTML =
              '<div class="order-items-error">Failed to load order items.</div>';
          }
        }
      });
    });

    // View Digital Receipt buttons
    document.querySelectorAll(".btn-view-receipt").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const orderId = Number(btn.dataset.orderId);
        this.openReceiptModal(orderId);
      });
    });

    // Cancel Order buttons
    document.querySelectorAll(".btn-cancel-order").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const orderId = Number(btn.dataset.orderId);
        const orderNumber = btn.dataset.orderNumber;
        this.openCancelOrderModal(orderId, orderNumber);
      });
    });

    // Return Item buttons
    document.querySelectorAll(".btn-return-order").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const orderId = Number(btn.dataset.orderId);
        const orderNumber = btn.dataset.orderNumber;
        this.openRmaModal(orderId, orderNumber);
      });
    });
  },

  /* ==========================================================================
     ORDER CANCELLATION MODAL
     ========================================================================== */
  currentCancelOrderId: null,

  openCancelOrderModal(orderId, orderNumber) {
    this.currentCancelOrderId = orderId;
    const modal = document.getElementById("profileCancelOrderModal");
    const numEl = document.getElementById("cancel-order-num-text");
    const errEl = document.getElementById("profileCancelOrderError");
    const notesEl = document.getElementById("cancel-order-notes");
    if (numEl) numEl.textContent = `#${orderNumber}`;
    if (errEl) {
      errEl.textContent = "";
      errEl.classList.add("is-hidden");
    }
    if (notesEl) notesEl.value = "";
    if (modal) {
      modal.classList.remove("is-hidden");
      modal.removeAttribute("hidden");
    }
  },

  closeCancelOrderModal() {
    this.currentCancelOrderId = null;
    const modal = document.getElementById("profileCancelOrderModal");
    if (modal) {
      modal.classList.add("is-hidden");
      modal.setAttribute("hidden", "");
    }
  },

  bindCancelOrderEvents() {
    const modal = document.getElementById("profileCancelOrderModal");
    const dismissBtn = document.getElementById("btnDismissCancelOrder");
    const confirmBtn = document.getElementById("btnConfirmCancelOrder");

    dismissBtn?.addEventListener("click", () => this.closeCancelOrderModal());
    modal?.addEventListener("click", (e) => {
      if (e.target === modal) this.closeCancelOrderModal();
    });

    confirmBtn?.addEventListener("click", async () => {
      if (!this.currentCancelOrderId) return;
      const reasonSelect = document.getElementById(
        "cancel-order-reason-select",
      );
      const notesInput = document.getElementById("cancel-order-notes");
      const errEl = document.getElementById("profileCancelOrderError");

      const reason = [reasonSelect?.value, notesInput?.value?.trim()]
        .filter(Boolean)
        .join(" - ");

      confirmBtn.disabled = true;
      confirmBtn.textContent = "Cancelling...";

      try {
        const res = await ApiClient.cancelOrder(
          this.currentCancelOrderId,
          reason,
        );
        if (res && (res.success || res.status === "Cancelled")) {
          RealtimeManager.showToast(
            "Order has been cancelled and reserved stock released.",
            "info",
          );
          this.closeCancelOrderModal();
          this.orderDetailsCache.delete(this.currentCancelOrderId);
          await this.loadUserOrders();
        } else {
          throw new Error(res?.message || "Failed to cancel order.");
        }
      } catch (err) {
        if (errEl) {
          errEl.textContent = err.message || "Failed to cancel order.";
          errEl.classList.remove("is-hidden");
        } else {
          RealtimeManager.showToast(
            err.message || "Failed to cancel order.",
            "alert",
          );
        }
      } finally {
        confirmBtn.disabled = false;
        confirmBtn.textContent = "Confirm Cancellation";
      }
    });
  },

  /* ==========================================================================
     ORDER RETURN / EXCHANGE (RMA) MODAL & MULTI-ITEM SUPPORT
     ========================================================================== */
  currentRmaOrderId: null,

  getRmaDescriptor(type, status) {
    const normType = String(type || 'RETURN').trim().toUpperCase();
    const normStatus = String(status || 'PENDING').trim().toUpperCase();
    const isExchange = normType === 'EXCHANGE';
    const prefix = isExchange ? 'Exchange' : 'Return';

    switch (normStatus) {
      case 'PENDING':
        return `${prefix}: Pending Staff Review`;
      case 'APPROVED':
        return isExchange 
          ? 'Exchange: Approved &bull; Awaiting Item Handover' 
          : 'Return: Approved &bull; Awaiting Item Handover';
      case 'RECEIVED':
        return `${prefix}: Item Received &bull; Inspection in Progress`;
      case 'COMPLETED':
        return isExchange 
          ? 'Exchange: Completed &bull; Replacement Dispatched' 
          : 'Return: Completed &bull; Refund Processed';
      case 'REJECTED':
        return `${prefix}: Request Declined`;
      case 'CANCELLED':
        return `${prefix}: Request Cancelled`;
      default:
        return `${prefix}: ${this.escapeHtml(status || 'Under Review')}`;
    }
  },

  async openRmaModal(orderId, orderNumber, preselectedItemId = null) {
    this.currentRmaOrderId = orderId;
    const modal = document.getElementById("profileRmaModal");
    const checklistEl = document.getElementById("profile-rma-items-checklist");
    const selectAllBtn = document.getElementById("btn-select-all-rma");
    const errEl = document.getElementById("profile-rma-error");
    const notesEl = document.getElementById("profile-rma-notes");
    if (errEl) {
      errEl.textContent = "";
      errEl.classList.add("is-hidden");
    }
    if (notesEl) notesEl.value = "";

    const orderIdInput = document.getElementById("profile-rma-order-id");
    if (orderIdInput) orderIdInput.value = orderId;

    if (modal) {
      modal.classList.add("is-open");
      document.body.classList.add("modal-open");
    }

    if (checklistEl) {
      const renderChecklist = (orderObj) => {
        if (orderObj && Array.isArray(orderObj.items) && orderObj.items.length > 0) {
          const eligibleItems = orderObj.items.filter((item) => {
            const st = String(item.rmaStatus || '').trim().toLowerCase();
            return !item.rmaNumber || st === 'rejected' || st === 'cancelled';
          });

          if (selectAllBtn) {
            selectAllBtn.classList.toggle("is-hidden", eligibleItems.length < 2);
            selectAllBtn.textContent = "Select All Eligible Items";
            selectAllBtn.dataset.allSelected = "false";
          }

          checklistEl.innerHTML = orderObj.items
            .map((item) => {
              const itemId = item.orderItemId || item.id;
              const st = String(item.rmaStatus || '').trim().toLowerCase();
              const hasActiveRma = item.rmaNumber && !['rejected', 'cancelled'].includes(st);
              const imgUrl = item.mainImageUrl || item.imageUrl || "/Content/images/placeholder-helmet.png";
              const unitPrice = Number(item.unitPrice || 0);
              const totalPrice = Number(item.totalPrice || unitPrice * item.quantity);
              const isChecked = !hasActiveRma && (preselectedItemId ? (Number(itemId) === Number(preselectedItemId)) : (eligibleItems.length === 1));

              if (hasActiveRma) {
                return `
                  <div class="rma-item-checkbox-row is-disabled">
                    <input type="checkbox" disabled />
                    <img src="${this.escapeHtml(imgUrl)}" alt="${this.escapeHtml(item.productName)}" class="rma-item-thumb" />
                    <div class="rma-item-details">
                      <div class="rma-item-name">${this.escapeHtml(item.productName)}</div>
                      <div class="rma-item-specs">
                        <span>Size: <strong>${this.escapeHtml(item.size || 'N/A')}</strong></span>
                        <span>Color: <strong>${this.escapeHtml(item.color || 'N/A')}</strong></span>
                        <span>Qty: <strong>${item.quantity}</strong></span>
                      </div>
                      <div>
                        <span class="track-rma-chip track-rma-chip--${st}">${this.getRmaDescriptor(item.rmaType, item.rmaStatus)} &bull; #${this.escapeHtml(item.rmaNumber)}</span>
                      </div>
                    </div>
                    <div class="rma-item-price">&#8369;${totalPrice.toLocaleString("en-US", { minimumFractionDigits: 2 })}</div>
                  </div>
                `;
              }

              return `
                <label class="rma-item-checkbox-row ${isChecked ? 'is-selected' : ''}">
                  <input type="checkbox" name="profile-rma-selected-item" value="${itemId}" ${isChecked ? 'checked' : ''} class="rma-checkbox" />
                  <img src="${this.escapeHtml(imgUrl)}" alt="${this.escapeHtml(item.productName)}" class="rma-item-thumb" />
                  <div class="rma-item-details">
                    <div class="rma-item-name">${this.escapeHtml(item.productName)}</div>
                    <div class="rma-item-specs">
                      <span>Size: <strong>${this.escapeHtml(item.size || 'N/A')}</strong></span>
                      <span>Color: <strong>${this.escapeHtml(item.color || 'N/A')}</strong></span>
                      <span>Qty: <strong>${item.quantity}</strong></span>
                    </div>
                  </div>
                  <div class="rma-item-price">&#8369;${totalPrice.toLocaleString("en-US", { minimumFractionDigits: 2 })}</div>
                </label>
              `;
            })
            .join("");

          checklistEl.querySelectorAll('input[name="profile-rma-selected-item"]').forEach((chk) => {
            chk.addEventListener('change', () => {
              chk.closest('.rma-item-checkbox-row')?.classList.toggle('is-selected', chk.checked);
              if (errEl) errEl.classList.add('is-hidden');
            });
          });
        } else {
          checklistEl.innerHTML = '<div class="order-items-empty">No items found for this order.</div>';
        }
      };

      let order = this.orderDetailsCache.get(orderId);
      if (order && Array.isArray(order.items) && order.items.length > 0) {
        // Immediate synchronous render from preloaded order details
        renderChecklist(order);
      } else {
        // Asynchronous fallback in case order was not in cache
        checklistEl.innerHTML = '<div class="rma-item-loading">Loading purchased items...</div>';
        try {
          const res = await ApiClient.getUserOrderDetails(orderId);
          order = res?.data || res;
          if (order) this.orderDetailsCache.set(orderId, order);
          renderChecklist(order);
        } catch (err) {
          checklistEl.innerHTML = '<div class="order-items-error">Error loading order items.</div>';
        }
      }
    }
  },

  closeRmaModal() {
    this.currentRmaOrderId = null;
    const modal = document.getElementById("profileRmaModal");
    if (modal) {
      modal.classList.remove("is-open");
      document.body.classList.remove("modal-open");
    }
  },

  bindRmaEvents() {
    const modal = document.getElementById("profileRmaModal");
    const closeBtn = document.getElementById("btn-close-profile-rma");
    const cancelBtn = document.getElementById("btn-cancel-profile-rma");
    const submitBtn = document.getElementById("btn-submit-profile-rma");
    const selectAllBtn = document.getElementById("btn-select-all-rma");

    const close = () => this.closeRmaModal();
    closeBtn?.addEventListener("click", close);
    cancelBtn?.addEventListener("click", close);
    modal?.addEventListener("click", (e) => {
      if (e.target === modal) close();
    });

    selectAllBtn?.addEventListener("click", () => {
      const checkboxes = Array.from(document.querySelectorAll('input[name="profile-rma-selected-item"]:not(:disabled)'));
      const isAll = selectAllBtn.dataset.allSelected === "true";
      checkboxes.forEach((cb) => {
        cb.checked = !isAll;
        cb.closest('.rma-item-checkbox-row')?.classList.toggle('is-selected', !isAll);
      });
      selectAllBtn.dataset.allSelected = isAll ? "false" : "true";
      selectAllBtn.textContent = isAll ? "Select All Eligible Items" : "Deselect All";
    });

    submitBtn?.addEventListener("click", async () => {
      if (!this.currentRmaOrderId) return;
      const checkedBoxes = Array.from(
        document.querySelectorAll('input[name="profile-rma-selected-item"]:checked:not(:disabled)'),
      );
      const typeRadio = document.querySelector(
        'input[name="profile-rma-type"]:checked',
      );
      const reasonSelect = document.getElementById("profile-rma-reason");
      const notesInput = document.getElementById("profile-rma-notes");
      const errEl = document.getElementById("profile-rma-error");

      if (checkedBoxes.length === 0) {
        if (errEl) {
          errEl.textContent = "Please select at least one item to return or exchange.";
          errEl.classList.remove("is-hidden");
        }
        return;
      }

      submitBtn.disabled = true;
      submitBtn.textContent = checkedBoxes.length > 1 ? `Submitting (${checkedBoxes.length} items)...` : "Submitting...";

      const itemIds = checkedBoxes.map((cb) => parseInt(cb.value, 10));
      const requestType = typeRadio?.value || "RETURN";
      const reason = reasonSelect?.value || "WRONG_SIZE";
      const customerNotes = notesInput?.value?.trim() || "";

      let successCount = 0;
      const errors = [];

      for (const orderItemId of itemIds) {
        try {
          const payload = {
            OrderId: this.currentRmaOrderId,
            OrderItemId: orderItemId,
            RequestType: requestType,
            Reason: reason,
            CustomerNotes: customerNotes,
          };

          const res = await ApiClient.createReturnRequest(payload);
          if (res && res.success) {
            successCount++;
          } else {
            errors.push(res?.message || `Item #${orderItemId} request could not be completed.`);
          }
        } catch (itemErr) {
          errors.push(itemErr.message || `Item #${orderItemId} request failed.`);
        }
      }

      if (successCount > 0) {
        RealtimeManager.showToast(
          successCount === 1
            ? "Return / Exchange request submitted successfully!"
            : `Successfully submitted ${successCount} return/exchange requests!`,
          "info",
        );
        close();
        this.orderDetailsCache.delete(this.currentRmaOrderId);
        await this.loadUserOrders();
      } else {
        if (errEl) {
          errEl.textContent = errors.join("; ") || "Failed to submit return request.";
          errEl.classList.remove("is-hidden");
        } else {
          RealtimeManager.showToast(
            errors.join("; ") || "Failed to submit return request.",
            "alert",
          );
        }
      }

      submitBtn.disabled = false;
      submitBtn.textContent = "Submit Request";
    });
  },

  formatStatusLabel(status) {
    switch (status) {
      case "PendingPayment":
        return "Pending Payment";
      case "Processing":
        return "Preparing Order";
      case "ReadyForPickup":
        return "Ready for Pickup";
      case "Shipped":
        return "In Transit";
      case "Delivered":
        return "Delivered";
      case "Completed":
        return "Completed";
      case "Cancelled":
        return "Cancelled";
      default:
        return status || "Preparing Order";
    }
  },

  /* ==========================================================================
     4. WISHLIST MANAGEMENT TAB
     ========================================================================== */
  bindWishlistEvents() {
    const clearBtn = document.getElementById("btn-clear-profile-wishlist");
    clearBtn?.addEventListener("click", () => ShoppingState.run(async () => {
      if (
        confirm("Are you sure you want to clear all items from your wishlist?")
      ) {
        await FavoritesManager.clear();
        RealtimeManager.showToast("Your wishlist has been cleared.", "info");
      }
    }));

    const contentEl = document.getElementById("profile-wishlist-content");
    contentEl?.addEventListener("click", (e) => ShoppingState.run(async () => {
      const removeBtn = e.target.closest(".fav-card__remove-btn");
      if (removeBtn) {
        const prodId = Number(removeBtn.dataset.removeId);
        if (prodId) {
          await FavoritesManager.removeFavorite(prodId);
          RealtimeManager.showToast(
            "Helmet removed from your wishlist.",
            "info",
          );
        }
      }
    }));
  },

  renderWishlist() {
    const container = document.getElementById("profile-wishlist-content");
    if (!container) return;

    const items = FavoritesManager.getItems();
    this.updateWishlistCount();

    if (items.length === 0) {
      container.innerHTML = `
        <div class="empty-orders-card">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="empty-orders-icon">
            <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>
          </svg>
          <h3>Your Wishlist is Empty</h3>
          <p>Explore our motorcycle helmet catalog and tap the heart icon on gear you wish to bookmark.</p>
          <a href="${APP_CONSTANTS.ROUTES.SHOP}" class="btn btn--primary btn--sm">Explore Shop</a>
        </div>
      `;
      return;
    }

    container.innerHTML = `
      <div class="profile-wishlist-grid">
        ${items
          .map((item) => {
            const origPrice = Number(item.originalPrice ?? item.price ?? 0);
            const discount = Number(item.discountPercentage ?? 0);
            const price = Number(item.price ?? origPrice);
            const rating = Number(item.rating ?? 5);

            return `
            <div class="fav-card" data-id="${item.productId}">
              <div class="fav-card__media">
                <img src="${this.escapeHtml(item.imageUrl || "/Content/images/placeholder-helmet.png")}" alt="${this.escapeHtml(item.name)}" class="fav-card__img" />
                <button type="button" class="fav-card__remove-btn" data-remove-id="${item.productId}" aria-label="Remove from wishlist" title="Remove">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="18" y1="6" x2="6" y2="18"></line>
                    <line x1="6" y1="6" x2="18" y2="18"></line>
                  </svg>
                </button>
              </div>
              <div class="fav-card__body">
                <h3 class="fav-card__title">
                  <a href="${APP_CONSTANTS.ROUTES.PRODUCT_DETAIL(item.productId)}">${this.escapeHtml(item.name)}</a>
                </h3>
                <div class="product-card__pricing">
                  <span class="price-current">&#8369;${price.toLocaleString("en-US", { minimumFractionDigits: 2 })}</span>
                  ${discount > 0 ? `<span class="price-original">&#8369;${origPrice.toLocaleString()}</span><span class="discount-badge">-${discount}%</span>` : ""}
                </div>
                <div class="fav-card__footer">
                  <a href="${APP_CONSTANTS.ROUTES.PRODUCT_DETAIL(item.productId)}" class="btn btn--primary btn--sm btn--block">
                    <span>View Helmet</span>
                  </a>
                </div>
              </div>
            </div>
          `;
          })
          .join("")}
      </div>
    `;
  },

  /* ==========================================================================
     5. ADDRESS MANAGEMENT
     ========================================================================== */
  async loadUserAddresses() {
    const listContainer = document.getElementById("addresses-cards-container");
    const emptyContainer = document.getElementById("addresses-empty-state");
    const loadingContainer = document.getElementById("addresses-loading-state");

    if (loadingContainer) loadingContainer.style.display = "flex";
    if (listContainer) listContainer.style.display = "none";
    if (emptyContainer) emptyContainer.style.display = "none";

    try {
      const response = await ApiClient.getUserAddresses();
      const list = Array.isArray(response)
        ? response
        : response?.data && Array.isArray(response.data)
          ? response.data
          : [];
      this.addresses = list;
      this.updateCounters();
      this.renderAddresses();
    } catch (err) {
      console.warn("[ProfileController] Error loading addresses:", err);
      this.addresses = [];
      this.updateCounters();
      this.renderAddresses();
    } finally {
      if (loadingContainer) loadingContainer.style.display = "none";
    }
  },

  renderAddresses() {
    const listContainer = document.getElementById("addresses-cards-container");
    const emptyContainer = document.getElementById("addresses-empty-state");
    if (!listContainer || !emptyContainer) return;

    if (!this.addresses || this.addresses.length === 0) {
      listContainer.style.display = "none";
      emptyContainer.style.display = "flex";
      return;
    }

    emptyContainer.style.display = "none";
    listContainer.style.display = "grid";
    listContainer.innerHTML = this.addresses
      .map((addr) => {
        const isDefault = Boolean(addr.isDefault);
        const fullStreet = [addr.streetAddress, addr.barangay]
          .filter(Boolean)
          .join(", ");
        const fullCity = [addr.city, addr.province, addr.postalCode]
          .filter(Boolean)
          .join(", ");

        return `
        <div class="address-card ${isDefault ? "address-card--default" : ""}" data-address-id="${addr.id}">
          <div class="address-card-top">
            <span class="address-label-badge">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12">
                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                <circle cx="12" cy="10" r="3"></circle>
              </svg>
              ${this.escapeHtml(addr.addressLabel || "Address")}
            </span>
            ${
              isDefault
                ? `
              <span class="address-default-badge">
                <svg viewBox="0 0 24 24" fill="currentColor" width="10" height="10"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
                Default
              </span>
            `
                : ""
            }
          </div>

          <div class="address-card-body">
            <strong class="address-recipient-name">
              ${this.escapeHtml(addr.recipientName || this.currentUser?.fullName || "Account Holder")}${addr.phoneNumber ? ` <span class="address-recipient-phone">(${this.escapeHtml(addr.phoneNumber)})</span>` : ""}
            </strong>
            <p class="address-full-text">${this.escapeHtml(fullStreet)}<br />${this.escapeHtml(fullCity)}</p>
            ${
              addr.deliveryLandmark
                ? `
              <div class="address-landmark-note">
                <span>Landmark:</span> ${this.escapeHtml(addr.deliveryLandmark)}
              </div>
            `
                : ""
            }
          </div>

          <div class="address-card-actions">
            ${
              !isDefault
                ? `
              <button type="button" class="btn-address-action btn-address-action--default" data-action="set-default" data-address-id="${addr.id}">
                Set Default
              </button>
            `
                : ""
            }
            <button type="button" class="btn-address-action" data-action="edit" data-address-id="${addr.id}">
              Edit
            </button>
            <button type="button" class="btn-address-action btn-address-action--delete" data-action="delete" data-address-id="${addr.id}">
              Delete
            </button>
          </div>
        </div>
      `;
      })
      .join("");
  },

  bindAddressEvents() {
    const btnAdd = document.getElementById("btn-add-new-address");
    const btnEmptyAdd = document.getElementById("btn-empty-add-address");
    const overlay = document.getElementById("address-modal-overlay");
    const btnClose = document.getElementById("btn-address-modal-close");
    const btnCancel = document.getElementById("btn-cancel-address-modal");
    const form = document.getElementById("form-address-modal");
    const container = document.getElementById("addresses-cards-container");

    const openModal = () => this.openAddressModal();
    btnAdd?.addEventListener("click", openModal);
    btnEmptyAdd?.addEventListener("click", openModal);

    const closeModal = () => this.closeAddressModal();
    btnClose?.addEventListener("click", closeModal);
    btnCancel?.addEventListener("click", closeModal);

    overlay?.addEventListener("click", (e) => {
      if (e.target === overlay) closeModal();
    });

    [
      "addr-recipient-name",
      "addr-phone",
      "addr-label",
      "addr-street",
      "addr-city",
      "addr-province",
    ].forEach((id) => {
      const el = document.getElementById(id);
      el?.addEventListener("input", () =>
        this.clearFieldError(id, `err-${id}`),
      );
    });

    form?.addEventListener("submit", (e) => this.handleAddressFormSubmit(e));

    container?.addEventListener("click", async (e) => {
      const btn = e.target.closest("button[data-action]");
      if (!btn) return;

      const action = btn.dataset.action;
      const addrId = parseInt(btn.dataset.addressId, 10);
      const addr = this.addresses.find((a) => a.id === addrId);

      if (action === "edit" && addr) {
        this.openAddressModal(addr);
      } else if (action === "delete" && addr) {
        if (
          confirm(`Remove saved address "${addr.addressLabel || "Address"}"?`)
        ) {
          await this.deleteUserAddress(addrId);
        }
      } else if (action === "set-default" && addr) {
        await this.setDefaultUserAddress(addr);
      }
    });
  },

  openAddressModal(addr = null) {
    const overlay = document.getElementById("address-modal-overlay");
    const title = document.getElementById("address-modal-title");
    const form = document.getElementById("form-address-modal");
    if (!overlay || !form) return;

    [
      "addr-recipient-name",
      "addr-phone",
      "addr-label",
      "addr-street",
      "addr-city",
      "addr-province",
    ].forEach((id) => {
      this.clearFieldError(id, `err-${id}`);
    });

    if (addr) {
      if (title) title.textContent = "Edit Delivery Address";
      document.getElementById("addr-id").value = addr.id;
      const rName = document.getElementById("addr-recipient-name");
      if (rName)
        rName.value = addr.recipientName || this.currentUser?.fullName || "";
      const rPhone = document.getElementById("addr-phone");
      if (rPhone)
        rPhone.value = addr.phoneNumber || this.currentUser?.phoneNumber || "";
      document.getElementById("addr-label").value = addr.addressLabel || "";
      document.getElementById("addr-street").value = addr.streetAddress || "";
      document.getElementById("addr-brgy").value = addr.barangay || "";
      document.getElementById("addr-city").value = addr.city || "";
      document.getElementById("addr-province").value = addr.province || "";
      document.getElementById("addr-postal").value = addr.postalCode || "";
      document.getElementById("addr-landmark").value =
        addr.deliveryLandmark || "";
      document.getElementById("addr-is-default").checked = Boolean(
        addr.isDefault,
      );
    } else {
      if (title) title.textContent = "Add Delivery Address";
      form.reset();
      document.getElementById("addr-id").value = "0";
      const rName = document.getElementById("addr-recipient-name");
      if (rName) rName.value = this.currentUser?.fullName || "";
      const rPhone = document.getElementById("addr-phone");
      if (rPhone) rPhone.value = this.currentUser?.phoneNumber || "";
      document.getElementById("addr-is-default").checked =
        this.addresses.length === 0;
    }

    overlay.classList.add("is-open");
    document.body.classList.add("modal-open");
  },

  closeAddressModal() {
    const overlay = document.getElementById("address-modal-overlay");
    overlay?.classList.remove("is-open");
    document.body.classList.remove("modal-open");
  },

  async handleAddressFormSubmit(e) {
    e.preventDefault();

    const idVal = parseInt(
      document.getElementById("addr-id")?.value || "0",
      10,
    );
    const recipientName = document
      .getElementById("addr-recipient-name")
      ?.value.trim();
    const phoneNumber = document.getElementById("addr-phone")?.value.trim();
    const label = document.getElementById("addr-label")?.value.trim();
    const street = document.getElementById("addr-street")?.value.trim();
    const brgy = document.getElementById("addr-brgy")?.value.trim();
    const city = document.getElementById("addr-city")?.value.trim();
    const province = document.getElementById("addr-province")?.value.trim();
    const postal = document.getElementById("addr-postal")?.value.trim();
    const landmark = document.getElementById("addr-landmark")?.value.trim();
    const isDefault = document.getElementById("addr-is-default")?.checked;

    let valid = true;
    if (!recipientName) {
      this.setFieldError(
        "addr-recipient-name",
        "err-addr-recipient-name",
        "Recipient full name is required.",
      );
      valid = false;
    }
    if (!phoneNumber) {
      this.setFieldError(
        "addr-phone",
        "err-addr-phone",
        "Recipient phone number is required.",
      );
      valid = false;
    }
    if (!label) {
      this.setFieldError(
        "addr-label",
        "err-addr-label",
        "Address label is required.",
      );
      valid = false;
    }
    if (!street) {
      this.setFieldError(
        "addr-street",
        "err-addr-street",
        "Street address is required.",
      );
      valid = false;
    }
    if (!city) {
      this.setFieldError(
        "addr-city",
        "err-addr-city",
        "City / Municipality is required.",
      );
      valid = false;
    }
    if (!province) {
      this.setFieldError(
        "addr-province",
        "err-addr-province",
        "Province is required.",
      );
      valid = false;
    }

    if (!valid) return;

    const btnSubmit = document.getElementById("btn-save-address-modal");
    const originalText = btnSubmit?.textContent || "Save Address";
    if (btnSubmit) {
      btnSubmit.disabled = true;
      btnSubmit.textContent = "Saving...";
    }

    try {
      const payload = {
        id: idVal > 0 ? idVal : null,
        recipientName: recipientName,
        phoneNumber: phoneNumber,
        addressLabel: label,
        streetAddress: street,
        barangay: brgy || null,
        city: city,
        province: province,
        postalCode: postal || null,
        deliveryLandmark: landmark || null,
        isDefault: Boolean(isDefault),
      };

      const res = await ApiClient.saveUserAddress(payload);
      if (res && res.success !== false) {
        RealtimeManager.showToast(
          "Delivery address saved successfully.",
          "info",
        );
        this.closeAddressModal();
        await this.loadUserAddresses();
      } else {
        throw new Error(res?.message || "Failed to save address.");
      }
    } catch (err) {
      RealtimeManager.showToast(
        err.message || "Error saving address.",
        "alert",
      );
    } finally {
      if (btnSubmit) {
        btnSubmit.disabled = false;
        btnSubmit.textContent = originalText;
      }
    }
  },

  async setDefaultUserAddress(addr) {
    try {
      const payload = {
        id: addr.id,
        recipientName: addr.recipientName,
        phoneNumber: addr.phoneNumber,
        addressLabel: addr.addressLabel,
        streetAddress: addr.streetAddress,
        barangay: addr.barangay,
        city: addr.city,
        province: addr.province,
        postalCode: addr.postalCode,
        deliveryLandmark: addr.deliveryLandmark,
        isDefault: true,
      };
      await ApiClient.saveUserAddress(payload);
      RealtimeManager.showToast(
        `"${addr.addressLabel || "Address"}" set as default delivery address.`,
        "info",
      );
      await this.loadUserAddresses();
    } catch (err) {
      RealtimeManager.showToast(
        err.message || "Error updating default address.",
        "alert",
      );
    }
  },

  async deleteUserAddress(id) {
    try {
      await ApiClient.deleteUserAddress(id);
      RealtimeManager.showToast("Delivery address removed.", "info");
      await this.loadUserAddresses();
    } catch (err) {
      RealtimeManager.showToast(
        err.message || "Error deleting address.",
        "alert",
      );
    }
  },

  /* ==========================================================================
     6. PAYMENT TRANSACTIONS TAB
     ========================================================================== */
  async loadUserPayments() {
    const listBody = document.getElementById("payments-table-body");
    const emptyContainer = document.getElementById("payments-empty-state");
    const loadingContainer = document.getElementById("payments-loading-state");
    const tableContainer = document.getElementById("payments-table-container");

    if (loadingContainer) loadingContainer.style.display = "flex";
    if (listBody) listBody.innerHTML = "";
    if (emptyContainer) emptyContainer.style.display = "none";

    try {
      const response = await ApiClient.getUserPayments();
      const list = Array.isArray(response)
        ? response
        : response?.data && Array.isArray(response.data)
          ? response.data
          : [];
      this.payments = list;
      this.updateCounters();
      this.renderPayments();
    } catch (err) {
      console.error("[ProfileController] Failed to load payments:", err);
      this.payments = [];
      this.updateCounters();
      this.renderPayments();
    } finally {
      if (loadingContainer) loadingContainer.style.display = "none";
    }
  },

  renderPayments() {
    const listBody = document.getElementById("payments-table-body");
    const emptyContainer = document.getElementById("payments-empty-state");
    const tableContainer = document.getElementById("payments-table-container");
    if (!listBody || !emptyContainer) return;

    if (this.payments.length === 0) {
      listBody.innerHTML = "";
      if (tableContainer) tableContainer.style.display = "none";
      emptyContainer.style.display = "flex";
      return;
    }

    emptyContainer.style.display = "none";
    if (tableContainer) tableContainer.style.display = "block";

    listBody.innerHTML = this.payments
      .map((p) => {
        const date = p.paidAt
          ? new Date(p.paidAt)
          : new Date(p.paymentCreatedAt);
        const dateStr = date.toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
          year: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        });
        const amountStr = Number(p.amount || 0).toLocaleString("en-US", {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2,
        });

        return `
        <tr>
          <td><span class="payment-ref-badge">${this.escapeHtml(p.gatewayReference || `#PAY-${p.paymentId}`)}</span></td>
          <td>
            <a href="${APP_CONSTANTS.ROUTES.TRACK_ORDER}?orderNumber=${encodeURIComponent(p.orderNumber)}" class="profile-order-link">#${this.escapeHtml(p.orderNumber)}</a>
          </td>
          <td><span class="payment-gateway-pill">${this.escapeHtml(p.paymentGateway || "HitPay")}</span></td>
          <td><span class="payment-status-tag payment-status--${String(p.paymentStatus || "Pending").toLowerCase()}">${this.escapeHtml(p.paymentStatus || "Pending")}</span></td>
          <td class="payment-amount-cell">&#8369;${amountStr}</td>
          <td>${dateStr}</td>
          <td>
            <button type="button" class="btn btn--primary btn-table-receipt" data-order-id="${p.orderId}">
              View Receipt
            </button>
          </td>
        </tr>
      `;
      })
      .join("");

    listBody.querySelectorAll(".btn-table-receipt").forEach((btn) => {
      btn.addEventListener("click", () => {
        const orderId = Number(btn.dataset.orderId);
        this.openReceiptModal(orderId);
      });
    });
  },

  /* ==========================================================================
     7. OFFICIAL DIGITAL RECEIPT MODAL
     ========================================================================== */
  async openReceiptModal(orderId) {
    const overlay = document.getElementById("receipt-modal-overlay");
    if (!overlay) return;

    overlay.classList.add("is-open");
    document.body.classList.add("modal-open");
    this.receiptFocusCleanup?.();
    this.receiptFocusCleanup = focusReceiptDialog(overlay, () => document.getElementById('btn-receipt-modal-close')?.click());

    try {
      let order = this.orderDetailsCache.get(orderId);
      if (!order) {
        const res = await ApiClient.getUserOrderDetails(orderId);
        order = res?.data || res;
        if (order) this.orderDetailsCache.set(orderId, order);
      }
      if (!order) throw new Error("Order record not found.");

      this.renderReceiptDocument(order);
    } catch (err) {
      const doc = document.getElementById("digital-receipt-doc");
      if (doc)
        doc.innerHTML = `<div class="receipt-error">Unable to load receipt: ${this.escapeHtml(err.message)}</div>`;
    }
  },

  renderReceiptDocument(order) {
    const doc = document.getElementById('digital-receipt-doc');
    if (doc) doc.innerHTML = renderReceipt(order);
  },

  bindReceiptModalEvents() {
    const overlay = document.getElementById("receipt-modal-overlay");
    const closeBtn = document.getElementById("btn-receipt-modal-close");
    const printBtn = document.getElementById("btn-print-receipt");

    const closeModal = () => {
      this.receiptFocusCleanup?.();
      this.receiptFocusCleanup = null;
      overlay?.classList.remove("is-open");
      document.body.classList.remove("modal-open");
    };

    closeBtn?.addEventListener("click", closeModal);
    overlay?.addEventListener("click", (e) => {
      if (e.target === overlay) closeModal();
    });

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && overlay?.classList.contains("is-open"))
        closeModal();
    });

    printBtn?.addEventListener("click", () => {
      printReceipt(document.getElementById('digital-receipt-doc'));
    });
  },

  /* ==========================================================================
     8. PROFILE & SECURITY FORMS WITH INLINE VALIDATION
     ========================================================================== */
  bindFormEvents() {
    // 1. Edit Profile Form
    const profileForm = document.getElementById("form-edit-profile");
    if (profileForm) {
      const fName = document.getElementById("edit-first-name");
      const lName = document.getElementById("edit-last-name");
      const phone = document.getElementById("edit-phone");

      fName?.addEventListener("input", () =>
        this.clearFieldError("edit-first-name", "err-first-name"),
      );
      lName?.addEventListener("input", () =>
        this.clearFieldError("edit-last-name", "err-last-name"),
      );

      profileForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        let valid = true;

        if (!fName?.value.trim()) {
          this.setFieldError(
            "edit-first-name",
            "err-first-name",
            "First name is required.",
          );
          valid = false;
        }
        if (!lName?.value.trim()) {
          this.setFieldError(
            "edit-last-name",
            "err-last-name",
            "Last name is required.",
          );
          valid = false;
        }

        if (!valid) return;

        const btn = document.getElementById("btn-save-profile");
        const originalText = btn ? btn.textContent : "Save Profile Changes";
        if (btn) {
          btn.disabled = true;
          btn.textContent = "Saving...";
        }

        try {
          const res = await ApiClient.updateProfile({
            firstName: fName.value.trim(),
            lastName: lName.value.trim(),
            phoneNumber: phone?.value.trim() || null,
          });

          const updated = res && res.data ? res.data : res;
          if (updated && (updated.id || updated.email)) {
            this.currentUser = updated;
            localStorage.setItem(
              APP_CONSTANTS.STORAGE_KEYS.USER_PROFILE,
              JSON.stringify(this.currentUser),
            );
            this.renderUserProfileSidebar();
            RealtimeManager.showToast(
              "Profile information updated successfully.",
              "info",
            );
          } else {
            throw new Error(res?.message || "Update failed.");
          }
        } catch (err) {
          RealtimeManager.showToast(
            err.message || "Error updating profile.",
            "alert",
          );
        } finally {
          if (btn) {
            btn.disabled = false;
            btn.textContent = originalText;
          }
        }
      });
    }

    // 2. Change Password Form
    const pwdForm = document.getElementById("form-change-password");
    if (pwdForm) {
      const currentPwd = document.getElementById("pwd-current");
      const newPwd = document.getElementById("pwd-new");
      const confirmPwd = document.getElementById("pwd-confirm");

      currentPwd?.addEventListener("input", () =>
        this.clearFieldError("pwd-current", "err-pwd-current"),
      );
      newPwd?.addEventListener("input", () =>
        this.clearFieldError("pwd-new", "err-pwd-new"),
      );
      confirmPwd?.addEventListener("input", () =>
        this.clearFieldError("pwd-confirm", "err-pwd-confirm"),
      );

      pwdForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        let valid = true;

        if (!currentPwd?.value) {
          this.setFieldError(
            "pwd-current",
            "err-pwd-current",
            "Enter your current password.",
          );
          valid = false;
        }
        if (!newPwd?.value || newPwd.value.length < 6) {
          this.setFieldError(
            "pwd-new",
            "err-pwd-new",
            "New password must be at least 6 characters.",
          );
          valid = false;
        }
        if (newPwd?.value !== confirmPwd?.value) {
          this.setFieldError(
            "pwd-confirm",
            "err-pwd-confirm",
            "Passwords do not match.",
          );
          valid = false;
        }

        if (!valid) return;

        const btn = document.getElementById("btn-save-password");
        const originalText = btn ? btn.textContent : "Update Password";
        if (btn) {
          btn.disabled = true;
          btn.textContent = "Updating...";
        }

        try {
          const res = await ApiClient.changePassword({
            currentPassword: currentPwd.value,
            newPassword: newPwd.value,
            confirmNewPassword: confirmPwd.value,
          });

          if (res === true || res?.success || res?.data === true) {
            pwdForm.reset();
            RealtimeManager.showToast("Password changed successfully.", "info");
          } else {
            throw new Error(res?.message || "Password update failed.");
          }
        } catch (err) {
          RealtimeManager.showToast(
            err.message || "Error updating password.",
            "alert",
          );
          if (err.message && err.message.toLowerCase().includes("current")) {
            this.setFieldError("pwd-current", "err-pwd-current", err.message);
          }
        } finally {
          if (btn) {
            btn.disabled = false;
            btn.textContent = originalText;
          }
        }
      });
    }
  },

  setFieldError(inputId, errorId, message) {
    const input = document.getElementById(inputId);
    const err = document.getElementById(errorId);
    if (input) input.classList.add("is-invalid");
    if (err) {
      err.textContent = message;
      err.classList.add("is-visible");
    }
  },

  clearFieldError(inputId, errorId) {
    const input = document.getElementById(inputId);
    const err = document.getElementById(errorId);
    if (input) input.classList.remove("is-invalid");
    if (err) {
      err.textContent = "";
      err.classList.remove("is-visible");
    }
  },

  /* ==========================================================================
     9. LOGOUT & REAL-TIME SIGNALR LISTENER
     ========================================================================== */
  bindLogoutEvent() {
    const logoutBtn = document.getElementById("btn-profile-logout");
    const modal = document.getElementById("profileSignOutModal");
    const cancelBtn = document.getElementById("btnCancelProfileSignOut");
    const confirmBtn = document.getElementById("btnConfirmProfileSignOut");

    const openModal = () => {
      if (modal) {
        modal.classList.remove("is-hidden");
        modal.removeAttribute("hidden");
      }
    };

    const closeModal = () => {
      if (modal) {
        modal.classList.add("is-hidden");
        modal.setAttribute("hidden", "");
      }
    };

    logoutBtn?.addEventListener("click", (e) => {
      e.preventDefault();
      openModal();
    });

    cancelBtn?.addEventListener("click", (e) => {
      e.preventDefault();
      closeModal();
    });

    modal?.addEventListener("click", (e) => {
      if (e.target === modal) {
        closeModal();
      }
    });

    document.addEventListener("keydown", (e) => {
      if (
        e.key === "Escape" &&
        modal &&
        !modal.classList.contains("is-hidden")
      ) {
        closeModal();
      }
    });

    confirmBtn?.addEventListener("click", async () => {
      confirmBtn.disabled = true;
      confirmBtn.textContent = "Signing out...";
      try {
        await ApiClient.logout();
      } catch (_) {}
      try {
        localStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.AUTH_TOKEN);
        localStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.USER_PROFILE);
        localStorage.removeItem("jwt_token");
        localStorage.removeItem("auth_token");
        localStorage.removeItem("user_role");
        localStorage.removeItem("hc_auth_token");
        localStorage.removeItem("hc_user_profile");
        sessionStorage.clear();
        document.cookie =
          "jwt_token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT;";
      } catch (_) {}
      RealtimeManager.showToast("You have been signed out.", "info");
      setTimeout(() => {
        window.location.href = "/Default.aspx";
      }, 400);
    });
  },

  initSignalRListener() {
    try {
      RealtimeManager.init();
      window.addEventListener("orderStatusChanged", (e) => {
        const data = e.detail;
        if (!data || !data.orderNumber) return;

        const order = this.orders.find(
          (o) => o.orderNumber === data.orderNumber || o.id === data.orderId,
        );
        if (order) {
          order.orderStatus = data.newStatus || data.status;
          this.renderOrders();
          RealtimeManager.showToast(
            `Order #${data.orderNumber} status updated to: ${this.formatStatusLabel(order.orderStatus)}!`,
            "info",
          );
        }
      });
    } catch (err) {
      console.warn("[ProfileController] Realtime registration:", err);
    }
  },

  escapeHtml(str) {
    if (!str) return "";
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  },
};

document.addEventListener("DOMContentLoaded", () => {
  ProfileController.init();
});
