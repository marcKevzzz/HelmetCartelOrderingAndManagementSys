/**
 * HELMET CARTEL - TRACK ORDER CONTROLLER (track-order.js)
 * Live order tracking page with horizontal stepper, 3-column metadata row layout,
 * gear breakdown, SignalR live updates, and printable digital receipts.
 */

import { ApiClient } from "../api.js";
import { RealtimeManager } from "../realtime.js";
import { APP_CONSTANTS } from "../constants.js";

export const TrackOrderController = {
  currentOrder: null,
  existingRmas: [],
  reviewedItems: new Set(),

  async init() {
    this.bindEvents();
    this.initSignalRListener();

    const urlParams = new URLSearchParams(window.location.search);
    const orderNumber = urlParams.get("orderNumber");
    const orderId = urlParams.get("id");

    if (orderNumber) {
      await this.loadOrder(orderNumber.trim());
    } else if (orderId) {
      await this.loadOrderById(orderId);
    } else {
      this.showError(
        "No Order Specified",
        "Please provide a valid order number to track your gear fulfillment.",
      );
    }
  },

  async loadOrder(orderNumber) {
    this.setLoading(true);
    try {
      const res = await ApiClient.trackOrder(orderNumber);
      const order = res && res.data ? res.data : res;
      if (!order || (!order.orderNumber && !order.id)) {
        throw new Error("Order record could not be found.");
      }
      this.currentOrder = order;

      // Load existing RMAs if order has ID
      if (order.id) {
        try {
          const rmas = await ApiClient.getOrderReturns(order.id);
          this.existingRmas = Array.isArray(rmas) ? rmas : rmas?.data || [];
        } catch (_) {
          this.existingRmas = [];
        }
      }

      this.renderOrder(order);
    } catch (err) {
      console.error("[TrackOrderController] Error loading order:", err);
      this.showError(
        "Order Not Found",
        `We could not locate order #${orderNumber}. Please check your order reference number.`,
      );
    } finally {
      this.setLoading(false);
    }
  },

  async loadOrderById(orderId) {
    this.setLoading(true);
    try {
      const res = await ApiClient.getUserOrderDetails(Number(orderId));
      const order = res && res.data ? res.data : res;
      if (!order || (!order.orderNumber && !order.id)) {
        throw new Error("Order record could not be found.");
      }
      this.currentOrder = order;

      try {
        const rmas = await ApiClient.getOrderReturns(Number(orderId));
        this.existingRmas = Array.isArray(rmas) ? rmas : rmas?.data || [];
      } catch (_) {
        this.existingRmas = [];
      }

      this.renderOrder(order);
    } catch (err) {
      console.error("[TrackOrderController] Error loading order by id:", err);
      this.showError(
        "Order Not Found",
        "The requested order could not be located in the database.",
      );
    } finally {
      this.setLoading(false);
    }
  },

  setLoading(isLoading) {
    const loadingEl = document.getElementById("track-loading-state");
    const contentEl = document.getElementById("track-order-content");
    const errorEl = document.getElementById("track-error-state");

    if (loadingEl) {
      loadingEl.classList.toggle("is-hidden", !isLoading);
      loadingEl.style.display = isLoading ? "flex" : "none";
    }
    if (isLoading) {
      if (contentEl) {
        contentEl.classList.add("is-hidden");
        contentEl.style.display = "none";
      }
      if (errorEl) {
        errorEl.classList.add("is-hidden");
        errorEl.style.display = "none";
      }
    }
  },

  showError(title, message) {
    const loadingEl = document.getElementById("track-loading-state");
    const contentEl = document.getElementById("track-order-content");
    const errorEl = document.getElementById("track-error-state");
    const titleEl = document.getElementById("track-error-title");
    const msgEl = document.getElementById("track-error-msg");

    if (loadingEl) {
      loadingEl.classList.add("is-hidden");
      loadingEl.style.display = "none";
    }
    if (contentEl) {
      contentEl.classList.add("is-hidden");
      contentEl.style.display = "none";
    }
    if (errorEl) {
      errorEl.classList.remove("is-hidden");
      errorEl.style.display = "flex";
    }
    if (titleEl) titleEl.textContent = title;
    if (msgEl) msgEl.textContent = message;
  },

  renderOrder(order) {
    const loadingEl = document.getElementById("track-loading-state");
    const contentEl = document.getElementById("track-order-content");
    const errorEl = document.getElementById("track-error-state");
    if (loadingEl) {
      loadingEl.classList.add("is-hidden");
      loadingEl.style.display = "none";
    }
    if (errorEl) {
      errorEl.classList.add("is-hidden");
      errorEl.style.display = "none";
    }
    if (contentEl) {
      contentEl.classList.remove("is-hidden");
      contentEl.style.display = "flex";
    }

    // Breadcrumb
    const breadcrumbEl = document.getElementById("track-breadcrumb-number");
    if (breadcrumbEl) breadcrumbEl.textContent = `#${order.orderNumber}`;

    // Header Row
    const orderNumEl = document.getElementById("track-order-number");
    if (orderNumEl) orderNumEl.textContent = `#${order.orderNumber}`;

    const dateFormatted = new Date(order.createdAt).toLocaleDateString(
      "en-US",
      {
        month: "short",
        day: "numeric",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      },
    );
    const orderDateEl = document.getElementById("track-order-date");
    if (orderDateEl) orderDateEl.textContent = dateFormatted;

    // Status Badge
    const status = order.orderStatus || order.status || "Processing";
    const statusBadge = document.getElementById("track-status-badge");
    const statusText = document.getElementById("track-status-text");
    if (statusBadge) {
      statusBadge.className = `order-status-badge status-badge--${status.toLowerCase()}`;
    }
    if (statusText) statusText.textContent = this.formatStatusLabel(status);

    // RMA / Refund / Exchange Banner
    const rmaBanner = document.getElementById("track-rma-banner");
    if (rmaBanner) {
      const isRefunded =
        (order.latestRmaType === "RETURN" &&
          (order.latestRmaStatus === "Completed" ||
            order.latestRmaStatus === "Approved")) ||
        this.existingRmas.some(
          (r) =>
            r.requestType === "RETURN" &&
            (r.status === "Completed" || r.status === "Approved"),
        );
      const isExchanged =
        (order.latestRmaType === "EXCHANGE" &&
          (order.latestRmaStatus === "Completed" ||
            order.latestRmaStatus === "Approved")) ||
        this.existingRmas.some(
          (r) =>
            r.requestType === "EXCHANGE" &&
            (r.status === "Completed" || r.status === "Approved"),
        );
      const isPendingRma =
        order.latestRmaStatus === "Pending" ||
        this.existingRmas.some((r) => r.status === "Pending");

      if (isRefunded) {
        rmaBanner.className = "track-rma-banner banner--refunded";
        rmaBanner.innerHTML = `
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 14 14"></polyline></svg>
          <span><strong>Return &bull; Refunded:</strong> A return request has been completed and payment refunded.</span>
        `;
        rmaBanner.classList.remove("is-hidden");
      } else if (isExchanged) {
        rmaBanner.className = "track-rma-banner banner--exchanged";
        rmaBanner.innerHTML = `
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><polyline points="1 4 1 10 7 10"></polyline><polyline points="23 20 23 14 17 14"></polyline><path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15"></path></svg>
          <span><strong>Exchange &bull; Completed:</strong> An exchange has been processed and replacement resolved.</span>
        `;
        rmaBanner.classList.remove("is-hidden");
      } else if (isPendingRma) {
        rmaBanner.className = "track-rma-banner banner--pending";
        rmaBanner.innerHTML = `
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
          <span><strong>Return / Exchange Pending:</strong> Your return/exchange request is under review by our operations staff.</span>
        `;
        rmaBanner.classList.remove("is-hidden");
      } else {
        rmaBanner.className = "track-rma-banner is-hidden";
        rmaBanner.innerHTML = "";
      }
    }

    // Toggle Cancel Order Button
    const btnCancelOrder = document.getElementById("btn-track-cancel-order");
    const orderStatusStr = (order.orderStatus || order.status || "").trim();
    const normStatus = orderStatusStr.toLowerCase();
    const canCancel =
      (normStatus === "pendingpayment" ||
        normStatus === "pending" ||
        normStatus === "processing") &&
      ![
        "shipped",
        "delivered",
        "completed",
        "cancelled",
        "returned",
        "readyforpickup",
      ].includes(normStatus);
    if (btnCancelOrder) {
      if (canCancel) {
        btnCancelOrder.classList.remove("is-hidden");
      } else {
        btnCancelOrder.classList.add("is-hidden");
      }
    }

    // Toggle Return / Exchange Button in track-actions-stack
    const btnTrackReturn = document.getElementById("btn-track-return-order");
    const canReturn = (normStatus === "completed" || normStatus === "delivered");
    if (btnTrackReturn) {
      if (canReturn) {
        btnTrackReturn.classList.remove("is-hidden");
      } else {
        btnTrackReturn.classList.add("is-hidden");
      }
    }

    // Stepper
    const isDelivery =
      String(order.shippingMethod).toLowerCase() === "delivery";
    const stepperContainer = document.getElementById("track-stepper-container");
    if (stepperContainer) {
      stepperContainer.innerHTML = this.createStepperHtml(
        order,
        isDelivery,
        status,
      );
    }

    // Info Card 1: Fulfillment
    const fulfillmentMethodEl = document.getElementById(
      "track-fulfillment-method",
    );
    if (fulfillmentMethodEl) {
      fulfillmentMethodEl.textContent = isDelivery
        ? "Door-to-Door Delivery"
        : "Store Pickup (QC Hub)";
    }

    const courierRow = document.getElementById("track-courier-row");
    const courierNameEl = document.getElementById("track-courier-name");
    const trackingNumEl = document.getElementById("track-tracking-num");
    const btnTrackCopy = document.getElementById("btn-track-copy");

    if (isDelivery) {
      if (courierRow) courierRow.style.display = "flex";
      const courierName = order.courier || "J&T Express";
      if (courierNameEl) courierNameEl.textContent = courierName;

      let trackingNumber = order.trackingNumber;
      if (!trackingNumber) {
        const digits = String(
          order.orderNumber || order.id || "20261002",
        ).replace(/\D/g, "");
        const pseudoRand = (digits.padEnd(8, "4") + "782910").slice(0, 10);
        trackingNumber = `JT${pseudoRand}`;
      }

      if (trackingNumEl) trackingNumEl.textContent = trackingNumber;
      if (btnTrackCopy) {
        btnTrackCopy.style.display = "inline-flex";
        btnTrackCopy.dataset.tracking = trackingNumber;
      }
    } else {
      if (courierRow) courierRow.style.display = "none";
    }

    // Info Card 2: Payment Gateway
    const paymentGatewayEl = document.getElementById("track-payment-gateway");
    const paymentStatusEl = document.getElementById("track-payment-status");
    const paymentRefEl = document.getElementById("track-payment-ref");

    const pGateway = order.paymentGateway || order.paymentMethod || "HitPay";
    const pStatus = order.paymentStatus || "Pending";
    if (paymentGatewayEl) paymentGatewayEl.textContent = pGateway;
    if (paymentStatusEl) {
      paymentStatusEl.textContent = pStatus.toUpperCase();
      paymentStatusEl.className = `payment-status-tag payment-status--${pStatus.toLowerCase()}`;
    }
    if (paymentRefEl) {
      paymentRefEl.textContent = order.gatewayReference
        ? `Ref: ${order.gatewayReference}`
        : `Method: ${pGateway}`;
    }

    // Info Card 3: Delivery Destination / Store Pickup
    const destinationLabelEl = document.getElementById(
      "track-destination-label",
    );
    const recipientEl = document.getElementById("track-recipient-name");
    const destinationEl = document.getElementById("track-delivery-destination");
    const landmarkEl = document.getElementById("track-delivery-landmark");

    if (destinationLabelEl) {
      destinationLabelEl.textContent = isDelivery
        ? "DELIVERY DESTINATION"
        : "STORE PICKUP LOCATION";
    }

    if (recipientEl)
      recipientEl.textContent = order.customerName || "Cartel Member";

    if (isDelivery) {
      const addressParts = [
        order.shippingAddress,
        order.shippingBarangay,
        order.shippingCity,
        order.shippingProvince,
        order.shippingPostalCode,
      ].filter(Boolean);

      if (destinationEl)
        destinationEl.textContent =
          addressParts.join(", ") || "Address on file";
      if (order.deliveryNotes || order.deliveryLandmark) {
        if (landmarkEl) {
          landmarkEl.classList.remove("is-hidden");
          landmarkEl.textContent = `Landmark: ${order.deliveryNotes || order.deliveryLandmark}`;
        }
      } else {
        if (landmarkEl) landmarkEl.classList.add("is-hidden");
      }
    } else {
      if (destinationEl)
        destinationEl.textContent =
          "Helmet Cartel Hub & Flagship: Katipunan Ave, Quezon City, Metro Manila";
      if (landmarkEl) {
        landmarkEl.classList.remove("is-hidden");
        landmarkEl.textContent = "Pickup Schedule: Mon-Sat, 9:00 AM - 7:00 PM";
      }
    }

    // Purchased Items List
    const itemsListEl = document.getElementById("track-gear-items-list");
    const gearCountEl = document.getElementById("track-gear-count");
    const items = Array.isArray(order.items) ? order.items : [];

    const totalQty = items.reduce(
      (sum, item) => sum + (Number(item.quantity) || 1),
      0,
    );
    if (gearCountEl)
      gearCountEl.textContent = `(${totalQty} ${totalQty === 1 ? "item" : "items"})`;

    if (itemsListEl) {
      if (items.length === 0) {
        itemsListEl.innerHTML =
          '<div class="track-gear-empty">Loading purchased items...</div>';
      } else {
        itemsListEl.innerHTML = items
          .map((item) => {
            const unitPrice = Number(item.unitPrice || 0);
            const totalPrice = Number(
              item.totalPrice || unitPrice * item.quantity,
            );
            const imgUrl =
              item.mainImageUrl ||
              item.imageUrl ||
              "/Content/images/placeholder-helmet.png";

            const itemRma =
              this.existingRmas.find((r) => r.orderItemId === item.id) ||
              (item.rmaNumber
                ? { rmaNumber: item.rmaNumber, status: item.rmaStatus }
                : null);
            let actionBadges = [];

            if (itemRma) {
              const rmaText = this.getRmaDescriptor(itemRma.requestType || itemRma.type || 'RETURN', itemRma.status);
              actionBadges.push(`
              <span class="track-rma-chip track-rma-chip--${(itemRma.status || "pending").toLowerCase()}">
                ${rmaText} &bull; #${this.escapeHtml(itemRma.rmaNumber)}
              </span>
            `);
            } else if (
              normStatus === "completed" ||
              normStatus === "delivered"
            ) {
              actionBadges.push(`
              <button type="button" class="btn btn--outline btn--sm btn-open-rma" data-item-id="${item.id}" data-item-name="${this.escapeHtml(item.productName)}" data-item-spec="${this.escapeHtml(item.color || "")} / ${this.escapeHtml(item.size || "")}">
                Request Return / Exchange
              </button>
            `);
            }

            if (normStatus === "completed") {
              const hasReviewed =
                item.reviewId || this.reviewedItems.has(item.id);
              if (hasReviewed) {
                actionBadges.push(`
                <span class="track-reviewed-chip">&#10003; Reviewed</span>
              `);
              } else {
                actionBadges.push(`
                <button type="button" class="btn btn--primary btn--sm btn-open-review" data-product-id="${item.productId || ""}" data-order-id="${order.id}" data-item-id="${item.id}" data-product-name="${this.escapeHtml(item.productName)}">
                  Write Review
                </button>
              `);
              }
            }

            const actionsHtml =
              actionBadges.length > 0
                ? `<div class="track-item-actions">${actionBadges.join("")}</div>`
                : "";

            return `
            <div class="track-item-row">
              <div class="track-item-main">
                <a href="/Pages/Storefront/ProductDetail/ProductDetail.aspx?id=${item.productId || 1}" class="track-item-img-link" title="View Product Details">
                  <img src="${this.escapeHtml(imgUrl)}" alt="${this.escapeHtml(item.productName)}" class="track-item-img" />
                </a>
                <div class="track-item-meta">
                  <h3 class="track-item-name">
                    <a href="/Pages/Storefront/ProductDetail/ProductDetail.aspx?id=${item.productId || 1}" class="track-item-title-link">
                      ${this.escapeHtml(item.productName)}
                    </a>
                  </h3>
                  <div class="track-item-specs">
                    ${item.color ? `<span>Color: <strong>${this.escapeHtml(item.color)}</strong></span>` : ""}
                    ${item.size ? `<span>Size: <strong>${this.escapeHtml(item.size)}</strong></span>` : ""}
                    ${item.sku ? `<span>SKU: <code>${this.escapeHtml(item.sku)}</code></span>` : ""}
                  </div>
                  ${actionsHtml}
                </div>
              </div>
              <div class="track-item-pricing">
                <span class="track-item-qty-sub">${item.quantity} pc${item.quantity > 1 ? "s" : ""} &times; &#8369;${unitPrice.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                <span class="track-item-total">&#8369;${totalPrice.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
              </div>
            </div>
          `;
          })
          .join("");
      }
    }

    // Financial Summary
    const subtotal = Number(order.subtotal || 0);
    const discount = Number(order.discountAmount || 0);
    const shipping = Number(order.shippingFee || 0);
    const totalAmount = Number(order.totalAmount || 0);

    const subtotalEl = document.getElementById("track-subtotal");
    const shippingEl = document.getElementById("track-shipping");
    const discountRow = document.getElementById("track-discount-row");
    const discountEl = document.getElementById("track-discount");
    const totalEl = document.getElementById("track-total-amount");

    if (subtotalEl)
      subtotalEl.innerHTML = `&#8369;${subtotal.toLocaleString("en-US", { minimumFractionDigits: 2 })}`;
    if (shippingEl)
      shippingEl.innerHTML = `&#8369;${shipping.toLocaleString("en-US", { minimumFractionDigits: 2 })}`;

    if (discount > 0 && discountRow && discountEl) {
      discountRow.classList.remove("is-hidden");
      discountEl.innerHTML = `-&#8369;${discount.toLocaleString("en-US", { minimumFractionDigits: 2 })}`;
    } else if (discountRow) {
      discountRow.classList.add("is-hidden");
    }

    if (totalEl)
      totalEl.innerHTML = `&#8369;${totalAmount.toLocaleString("en-US", { minimumFractionDigits: 2 })}`;
  },

  createStepperHtml(order, isDelivery, currentStatus) {
    if (currentStatus === "Cancelled") {
      return `
        <div class="order-stepper-cancelled" style="display: flex; gap: var(--space-2);">
          <svg viewBox="0 0 24 24" fill="none" stroke="#DC2626" stroke-width="2" width="20" height="20">
            <circle cx="12" cy="12" r="10"></circle>
            <line x1="15" y1="9" x2="9" y2="15"></line>
            <line x1="9" y1="9" x2="15" y2="15"></line>
          </svg>
          <span>This order was cancelled. Stock allocations have been restored to inventory.</span>
        </div>
      `;
    }

    const steps = isDelivery
      ? [
          {
            id: "placed",
            title: "Order Placed",
            match: [
              "PendingPayment",
              "Processing",
              "Shipped",
              "Delivered",
              "Completed",
            ],
          },
          {
            id: "processing",
            title: "Processing & Prep",
            match: ["Processing", "Shipped", "Delivered", "Completed"],
          },
          {
            id: "shipped",
            title: order.courier
              ? `Dispatched (${order.courier})`
              : "Dispatched / In Transit",
            match: ["Shipped", "Delivered", "Completed"],
          },
          {
            id: "delivered",
            title: "Delivered",
            match: ["Delivered", "Completed"],
          },
        ]
      : [
          {
            id: "placed",
            title: "Order Placed",
            match: [
              "PendingPayment",
              "Processing",
              "ReadyForPickup",
              "Completed",
            ],
          },
          {
            id: "processing",
            title: "Preparing at Hub",
            match: ["Processing", "ReadyForPickup", "Completed"],
          },
          {
            id: "ready",
            title: "Ready for Pickup",
            match: ["ReadyForPickup", "Completed"],
          },
          { id: "completed", title: "Picked Up", match: ["Completed"] },
        ];

    let currentStageIndex = 0;
    if (currentStatus === "Processing") currentStageIndex = 1;
    else if (currentStatus === "Shipped" || currentStatus === "ReadyForPickup")
      currentStageIndex = 2;
    else if (currentStatus === "Delivered" || currentStatus === "Completed")
      currentStageIndex = 3;

    return `
      <div class="order-stepper">
        ${steps
          .map((step, idx) => {
            const isCompleted =
              idx < currentStageIndex ||
              (idx === currentStageIndex &&
                (currentStatus === "Delivered" ||
                  currentStatus === "Completed"));
            const isActive =
              idx === currentStageIndex &&
              currentStatus !== "Delivered" &&
              currentStatus !== "Completed";
            const cssClass = isCompleted
              ? "completed"
              : isActive
                ? "active"
                : "";

            return `
            <div class="order-step ${cssClass}">
              <div class="order-step-bar"></div>
              <div class="order-step-dot">
                ${
                  isCompleted
                    ? `
                  <svg viewBox="0 0 24 24" fill="none" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="20 6 9 17 4 12"></polyline>
                  </svg>
                `
                    : idx + 1
                }
              </div>
              <span class="order-step-title">${step.title}</span>
            </div>
          `;
          })
          .join("")}
      </div>
    `;
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

  bindEvents() {
    // Copy tracking number button
    const btnCopy = document.getElementById("btn-track-copy");
    btnCopy?.addEventListener("click", async () => {
      const code = btnCopy.dataset.tracking;
      if (!code) return;
      try {
        await navigator.clipboard.writeText(code);
        RealtimeManager.showToast(
          `Tracking code #${code} copied to clipboard!`,
          "info",
        );
      } catch (_) {
        RealtimeManager.showToast(`Tracking Code: ${code}`, "info");
      }
    });

    // View Digital Receipt modal button
    const btnReceipt = document.getElementById("btn-track-view-receipt");
    btnReceipt?.addEventListener("click", () => {
      if (this.currentOrder) {
        this.openReceiptModal(this.currentOrder);
      }
    });

    // Modal close & print events
    const overlay = document.getElementById("receipt-modal-overlay");
    const closeBtn = document.getElementById("btn-receipt-modal-close");
    const printBtn = document.getElementById("btn-print-receipt");

    const closeModal = () => {
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
    printBtn?.addEventListener("click", () => window.print());

    // Customer RMA Request Modal Wiring
    const rmaModal = document.getElementById("customer-rma-modal");
    const rmaItemIdInput = document.getElementById("rma-target-item-id");
    const rmaItemNameEl = document.getElementById("rma-target-item-name");
    const rmaItemSpecEl = document.getElementById("rma-target-item-spec");
    const rmaNotesInput = document.getElementById("customer-rma-notes");
    const rmaReasonSelect = document.getElementById("customer-rma-reason");
    const rmaErrorEl = document.getElementById("customer-rma-error");
    const btnCloseRma = document.getElementById("btn-close-customer-rma");
    const btnCancelRma = document.getElementById("btn-cancel-customer-rma");
    const btnSubmitRma = document.getElementById("btn-submit-customer-rma");

    const openRmaModal = (itemId, itemName, itemSpec) => {
      if (rmaItemIdInput) rmaItemIdInput.value = itemId;
      if (rmaItemNameEl) rmaItemNameEl.textContent = itemName;
      if (rmaItemSpecEl) rmaItemSpecEl.textContent = itemSpec;
      if (rmaNotesInput) rmaNotesInput.value = "";
      if (rmaErrorEl) {
        rmaErrorEl.textContent = "";
        rmaErrorEl.classList.add("is-hidden");
      }

      const itemSelectorWrap = document.getElementById("rma-item-selector-wrap");
      const itemSingleWrap = document.getElementById("rma-target-item-single-wrap");
      const itemSelector = document.getElementById("rma-item-selector");

      if (itemSelectorWrap && itemSelector && this.currentOrder && this.currentOrder.items && this.currentOrder.items.length > 1) {
        itemSelector.innerHTML = this.currentOrder.items.map((it) => {
          const spec = [it.color, it.size].filter(Boolean).join(" / ");
          const selected = String(it.id) === String(itemId) ? "selected" : "";
          return `<option value="${it.id}" data-name="${this.escapeHtml(it.productName)}" data-spec="${this.escapeHtml(spec)}" ${selected}>${this.escapeHtml(it.productName)} (${this.escapeHtml(spec)})</option>`;
        }).join("");
        itemSelectorWrap.classList.remove("is-hidden");
        if (itemSingleWrap) itemSingleWrap.classList.add("is-hidden");
      } else {
        if (itemSelectorWrap) itemSelectorWrap.classList.add("is-hidden");
        if (itemSingleWrap) itemSingleWrap.classList.remove("is-hidden");
      }

      rmaModal?.classList.remove("is-hidden");
    };

    const closeRmaModal = () => {
      rmaModal?.classList.add("is-hidden");
    };

    document.getElementById("rma-item-selector")?.addEventListener("change", (e) => {
      const selectedOpt = e.target.selectedOptions?.[0];
      if (selectedOpt) {
        if (rmaItemIdInput) rmaItemIdInput.value = e.target.value;
        if (rmaItemNameEl) rmaItemNameEl.textContent = selectedOpt.dataset.name;
        if (rmaItemSpecEl) rmaItemSpecEl.textContent = selectedOpt.dataset.spec;
      }
    });

    const btnTrackReturnAction = document.getElementById("btn-track-return-order");
    btnTrackReturnAction?.addEventListener("click", () => {
      if (!this.currentOrder || !this.currentOrder.items || !this.currentOrder.items.length) {
        RealtimeManager.showToast("No items found in this order for return or exchange.", "alert");
        return;
      }
      const eligibleItem = this.currentOrder.items.find((item) => {
        const itemRma = this.existingRmas.find((r) => r.orderItemId === item.id) || (item.rmaNumber ? { rmaNumber: item.rmaNumber } : null);
        return !itemRma;
      }) || this.currentOrder.items[0];

      if (eligibleItem) {
        openRmaModal(
          eligibleItem.id,
          eligibleItem.productName,
          `${eligibleItem.color || ""} / ${eligibleItem.size || ""}`
        );
      } else {
        RealtimeManager.showToast("All items in this order already have active return or exchange requests.", "info");
      }
    });

    document.addEventListener("click", (e) => {
      const btnRma = e.target.closest(".btn-open-rma");
      if (btnRma) {
        const itemId = btnRma.dataset.itemId;
        const itemName = btnRma.dataset.itemName;
        const itemSpec = btnRma.dataset.itemSpec;
        openRmaModal(itemId, itemName, itemSpec);
      }
    });

    btnCloseRma?.addEventListener("click", closeRmaModal);
    btnCancelRma?.addEventListener("click", closeRmaModal);
    rmaModal?.addEventListener("click", (e) => {
      if (e.target === rmaModal) closeRmaModal();
    });

    btnSubmitRma?.addEventListener("click", async () => {
      if (!this.currentOrder) return;
      const itemId = parseInt(rmaItemIdInput?.value || "0", 10);
      const reqType =
        document.querySelector('input[name="customer-rma-type"]:checked')
          ?.value || "RETURN";
      const reason = rmaReasonSelect?.value || "WRONG_SIZE";
      const notes = rmaNotesInput?.value?.trim() || "";

      if (!itemId) {
        if (rmaErrorEl) {
          rmaErrorEl.textContent = "Invalid item selected.";
          rmaErrorEl.classList.remove("is-hidden");
        }
        return;
      }

      if (btnSubmitRma) {
        btnSubmitRma.disabled = true;
        btnSubmitRma.textContent = "Submitting...";
      }

      try {
        const res = await ApiClient.createReturnRequest({
          OrderId: this.currentOrder.id,
          OrderItemId: itemId,
          RequestType: reqType,
          Reason: reason,
          CustomerNotes: notes,
        });

        if (res && res.success) {
          RealtimeManager.showToast(
            res.message || "RMA Request submitted successfully!",
            "success",
          );
          closeRmaModal();
          // Reload order
          if (this.currentOrder.orderNumber) {
            await this.loadOrder(this.currentOrder.orderNumber);
          } else {
            await this.loadOrderById(this.currentOrder.id);
          }
        } else {
          if (rmaErrorEl) {
            rmaErrorEl.textContent =
              res?.message || "Could not submit request.";
            rmaErrorEl.classList.remove("is-hidden");
          }
        }
      } catch (err) {
        console.error("[TrackOrder] Error submitting RMA:", err);
        if (rmaErrorEl) {
          rmaErrorEl.textContent =
            err.message || "Server error while submitting request.";
          rmaErrorEl.classList.remove("is-hidden");
        }
      } finally {
        if (btnSubmitRma) {
          btnSubmitRma.disabled = false;
          btnSubmitRma.textContent = "Submit Request";
        }
      }
    });

    // -------------------------------------------------------------
    // Order Cancellation Modal Wiring
    // -------------------------------------------------------------
    const cancelModal = document.getElementById("track-cancel-modal");
    const btnTriggerCancel = document.getElementById("btn-track-cancel-order");
    const cancelNumEl = document.getElementById("track-cancel-order-num");
    const cancelReasonSelect = document.getElementById(
      "track-cancel-reason-select",
    );
    const cancelNotesInput = document.getElementById("track-cancel-notes");
    const cancelErrorEl = document.getElementById("track-cancel-error");
    const btnCloseCancel = document.getElementById("btn-close-track-cancel");
    const btnCancelClose = document.getElementById(
      "btn-cancel-track-cancel-close",
    );
    const btnConfirmCancel = document.getElementById(
      "btn-confirm-track-cancel",
    );

    const openCancelModal = () => {
      if (!this.currentOrder) return;
      if (cancelNumEl)
        cancelNumEl.textContent = `#${this.currentOrder.orderNumber}`;
      if (cancelNotesInput) cancelNotesInput.value = "";
      if (cancelErrorEl) {
        cancelErrorEl.textContent = "";
        cancelErrorEl.classList.add("is-hidden");
      }
      cancelModal?.classList.remove("is-hidden");
    };

    const closeCancelModal = () => {
      cancelModal?.classList.add("is-hidden");
    };

    btnTriggerCancel?.addEventListener("click", openCancelModal);
    btnCloseCancel?.addEventListener("click", closeCancelModal);
    btnCancelClose?.addEventListener("click", closeCancelModal);
    cancelModal?.addEventListener("click", (e) => {
      if (e.target === cancelModal) closeCancelModal();
    });

    btnConfirmCancel?.addEventListener("click", async () => {
      if (!this.currentOrder) return;
      const reasonVal = cancelReasonSelect?.value || "Changed mind";
      const notesVal = cancelNotesInput?.value?.trim() || "";
      const reason = [reasonVal, notesVal].filter(Boolean).join(" - ");

      btnConfirmCancel.disabled = true;
      btnConfirmCancel.textContent = "Cancelling...";

      try {
        const res = await ApiClient.cancelOrder(this.currentOrder.id, reason);
        if (res && (res.success || res.status === "Cancelled")) {
          RealtimeManager.showToast(
            "Order cancelled successfully. Reserved stock released.",
            "info",
          );
          closeCancelModal();
          if (this.currentOrder.orderNumber) {
            await this.loadOrder(this.currentOrder.orderNumber);
          } else {
            await this.loadOrderById(this.currentOrder.id);
          }
        } else {
          throw new Error(res?.message || "Failed to cancel order.");
        }
      } catch (err) {
        if (cancelErrorEl) {
          cancelErrorEl.textContent = err.message || "Failed to cancel order.";
          cancelErrorEl.classList.remove("is-hidden");
        } else {
          RealtimeManager.showToast(
            err.message || "Failed to cancel order.",
            "alert",
          );
        }
      } finally {
        btnConfirmCancel.disabled = false;
        btnConfirmCancel.textContent = "Confirm Cancellation";
      }
    });

    // -------------------------------------------------------------
    // Write Product Review Modal Wiring
    // -------------------------------------------------------------
    const reviewModal = document.getElementById("track-review-modal");
    const revProductIdInput = document.getElementById(
      "track-review-product-id",
    );
    const revOrderIdInput = document.getElementById("track-review-order-id");
    const revProductNameEl = document.getElementById(
      "track-review-product-name",
    );
    const revRatingInput = document.getElementById("track-review-rating-val");
    const revTitleInput = document.getElementById("track-review-title");
    const revCommentInput = document.getElementById("track-review-comment");
    const revErrorEl = document.getElementById("track-review-error");
    const btnCloseRev = document.getElementById("btn-close-track-review");
    const btnCancelRev = document.getElementById(
      "btn-cancel-track-review-close",
    );
    const btnSubmitRev = document.getElementById("btn-submit-track-review");
    let currentReviewingItemId = null;

    document.addEventListener("click", (e) => {
      const btnRev = e.target.closest(".btn-open-review");
      if (btnRev) {
        const prodId = btnRev.dataset.productId;
        const orderId = btnRev.dataset.orderId;
        const prodName = btnRev.dataset.productName;
        currentReviewingItemId = btnRev.dataset.itemId;

        if (revProductIdInput) revProductIdInput.value = prodId;
        if (revOrderIdInput) revOrderIdInput.value = orderId;
        if (revProductNameEl) revProductNameEl.textContent = prodName;
        if (revRatingInput) revRatingInput.value = "5";
        if (revTitleInput) revTitleInput.value = "";
        if (revCommentInput) revCommentInput.value = "";
        if (revErrorEl) {
          revErrorEl.textContent = "";
          revErrorEl.classList.add("is-hidden");
        }
        updateStarDisplay(5);
        reviewModal?.classList.remove("is-hidden");
      }
    });

    const closeReviewModal = () => {
      reviewModal?.classList.add("is-hidden");
    };

    btnCloseRev?.addEventListener("click", closeReviewModal);
    btnCancelRev?.addEventListener("click", closeReviewModal);
    reviewModal?.addEventListener("click", (e) => {
      if (e.target === reviewModal) closeReviewModal();
    });

    function updateStarDisplay(val) {
      document
        .querySelectorAll("#track-review-stars-picker .star-pick")
        .forEach((s) => {
          const starVal = parseInt(s.dataset.val, 10);
          if (starVal <= val) {
            s.style.color = "#f59e0b";
          } else {
            s.style.color = "#A3A3A3";
          }
        });
    }

    document
      .querySelectorAll("#track-review-stars-picker .star-pick")
      .forEach((star) => {
        star.addEventListener("click", () => {
          const val = parseInt(star.dataset.val, 10);
          if (revRatingInput) revRatingInput.value = String(val);
          updateStarDisplay(val);
        });
      });

    btnSubmitRev?.addEventListener("click", async () => {
      const prodId = parseInt(revProductIdInput?.value || "0", 10);
      const orderId = parseInt(revOrderIdInput?.value || "0", 10);
      const rating = parseInt(revRatingInput?.value || "5", 10);
      const title = revTitleInput?.value?.trim() || "";
      const comment = revCommentInput?.value?.trim() || "";
      const user =
        typeof ApiClient !== "undefined" && ApiClient.getCurrentUser
          ? ApiClient.getCurrentUser()
          : null;
      const reviewerName =
        user?.fullName || this.currentOrder?.customerName || "Rider";

      if (!comment) {
        if (revErrorEl) {
          revErrorEl.textContent = "Please enter your review comments.";
          revErrorEl.classList.remove("is-hidden");
        }
        return;
      }

      btnSubmitRev.disabled = true;
      btnSubmitRev.textContent = "Submitting...";

      try {
        const res = await ApiClient.addReview({
          ProductId: prodId,
          OrderId: orderId,
          ReviewerName: reviewerName,
          Rating: rating,
          Title: title,
          Comment: comment,
        });

        if (res && (res.success || res.reviewId)) {
          RealtimeManager.showToast(
            "Thank you! Your verified review has been submitted.",
            "success",
          );
          if (currentReviewingItemId) {
            this.reviewedItems.add(Number(currentReviewingItemId));
          }
          closeReviewModal();
          this.renderOrder(this.currentOrder);
        } else {
          throw new Error(res?.message || "Failed to submit review.");
        }
      } catch (err) {
        if (revErrorEl) {
          revErrorEl.textContent = err.message || "Failed to submit review.";
          revErrorEl.classList.remove("is-hidden");
        } else {
          RealtimeManager.showToast(
            err.message || "Failed to submit review.",
            "alert",
          );
        }
      } finally {
        btnSubmitRev.disabled = false;
        btnSubmitRev.textContent = "Submit Review";
      }
    });
  },

  openReceiptModal(order) {
    const overlay = document.getElementById("receipt-modal-overlay");
    const doc = document.getElementById("digital-receipt-doc");
    if (!overlay || !doc) return;

    overlay.classList.add("is-open");
    document.body.classList.add("modal-open");

    const dateFormatted = new Date(order.createdAt).toLocaleDateString(
      "en-US",
      {
        month: "long",
        day: "numeric",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      },
    );

    const isDelivery =
      String(order.shippingMethod).toLowerCase() === "delivery";
    const subtotal = Number(order.subtotal || 0);
    const discount = Number(order.discountAmount || 0);
    const shipping = Number(order.shippingFee || 0);
    const total = Number(order.totalAmount || 0);

    const itemsHtml = (order.items || [])
      .map(
        (item) => `
      <tr>
        <td>
          <strong>${this.escapeHtml(item.productName)}</strong><br />
          <span style="font-size: 0.75rem; color: #737373;">SKU: ${this.escapeHtml(item.sku || "N/A")} | ${this.escapeHtml(item.color || "")} / ${this.escapeHtml(item.size || "")}</span>
        </td>
        <td style="text-align: center;">${item.quantity}</td>
        <td style="text-align: right;">&#8369;${Number(item.unitPrice).toLocaleString("en-US", { minimumFractionDigits: 2 })}</td>
        <td style="text-align: right;">&#8369;${Number(item.totalPrice).toLocaleString("en-US", { minimumFractionDigits: 2 })}</td>
      </tr>
    `,
      )
      .join("");

    doc.innerHTML = `
      <div class="digital-receipt-top">
        <div>
          <div class="receipt-brand-logo">HELMET CARTEL</div>
          <div class="receipt-brand-hub">
            Flagship Store &amp; Fulfillment Hub<br />
            Katipunan Ave, Quezon City, Metro Manila, 1108<br />
            TIN: 420-691-888-000 &bull; support@helmetcartel.com
          </div>
        </div>
        <div class="receipt-doc-meta">
          <span class="receipt-doc-tag">Digital Transaction Receipt</span>
          <span class="receipt-doc-no">#REC-${order.id ? order.id.toString().padStart(6, "0") : "000000"}</span>
          <span class="receipt-doc-date">${dateFormatted}</span>
        </div>
      </div>

      <div class="receipt-parties-grid">
        <div>
          <div class="receipt-party-title">Billed To</div>
          <div class="receipt-party-val">
            <strong>${this.escapeHtml(order.customerName)}</strong><br />
            ${this.escapeHtml(order.customerEmail || "")}<br />
            ${this.escapeHtml(order.customerPhone || "")}
          </div>
        </div>
        <div>
          <div class="receipt-party-title">Fulfillment &amp; Payment</div>
          <div class="receipt-party-val">
            <strong>Method:</strong> ${isDelivery ? "Door-to-Door Delivery" : "Store Pickup (QC Hub)"}<br />
            <strong>Gateway:</strong> ${this.escapeHtml(order.paymentGateway || order.paymentMethod || "HitPay")}<br />
            <strong>Reference:</strong> ${this.escapeHtml(order.gatewayReference || "N/A")}<br />
            <strong>Payment Status:</strong> ${this.escapeHtml(order.paymentStatus || "Completed")}
          </div>
        </div>
      </div>

      <table class="receipt-items-table">
        <thead>
          <tr>
            <th>Item &amp; Specification</th>
            <th style="text-align: center; width: 60px;">Qty</th>
            <th style="text-align: right; width: 110px;">Unit Price</th>
            <th style="text-align: right; width: 110px;">Total</th>
          </tr>
        </thead>
        <tbody>
          ${itemsHtml}
        </tbody>
      </table>

      <div class="receipt-totals-list">
        <div class="receipt-total-row">
          <span>Subtotal</span>
          <span>&#8369;${subtotal.toLocaleString("en-US", { minimumFractionDigits: 2 })}</span>
        </div>
        ${
          discount > 0
            ? `
          <div class="receipt-total-row" style="color: #047857;">
            <span>Voucher Discount</span>
            <span>-&#8369;${discount.toLocaleString("en-US", { minimumFractionDigits: 2 })}</span>
          </div>
        `
            : ""
        }
        ${
          isDelivery
            ? `
          <div class="receipt-total-row">
            <span>Shipping Fee</span>
            <span>&#8369;${shipping.toLocaleString("en-US", { minimumFractionDigits: 2 })}</span>
          </div>
        `
            : ""
        }
        <div class="receipt-total-row receipt-total-row--grand">
          <span>Total Paid</span>
          <span>&#8369;${total.toLocaleString("en-US", { minimumFractionDigits: 2 })}</span>
        </div>
      </div>

      <div class="receipt-footer-seal">
        <span>Order Number: <strong>${this.escapeHtml(order.orderNumber)}</strong></span>
        <span>Verified Electronic Transaction</span>
      </div>
    `;
  },

  initSignalRListener() {
    try {
      RealtimeManager.init();
      window.addEventListener("orderStatusChanged", (e) => {
        const data = e.detail;
        if (!data || !this.currentOrder) return;

        if (
          data.orderNumber === this.currentOrder.orderNumber ||
          data.orderId === this.currentOrder.id
        ) {
          this.currentOrder.orderStatus = data.newStatus || data.status;
          this.currentOrder.status = this.currentOrder.orderStatus;
          if (data.courier) this.currentOrder.courier = data.courier;
          if (data.trackingNumber)
            this.currentOrder.trackingNumber = data.trackingNumber;

          this.renderOrder(this.currentOrder);
          RealtimeManager.showToast(
            `Order status updated to: ${this.formatStatusLabel(this.currentOrder.orderStatus)}!`,
            "info",
          );
        }
      });
    } catch (err) {
      console.warn("[TrackOrderController] Realtime registration:", err);
    }
  },

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
  TrackOrderController.init();
});
