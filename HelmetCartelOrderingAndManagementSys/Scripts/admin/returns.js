/**
 * HELMET CARTEL - ADMIN RETURNS & EXCHANGES (returns.js)
 * Manages RMA requests list, search, status filtering,
 * and RMA processing (approval, restock, settlement).
 */

import { ApiClient } from "../api.js";

document.addEventListener("DOMContentLoaded", () => {
  initAdminReturns();
});

function initAdminReturns() {
  let currentStatus = "ALL";
  let currentSearch = "";
  let rmaList = [];
  let selectedRma = null;

  const tbody = document.getElementById("admin-rma-tbody");
  const searchInput = document.getElementById("adminGlobalSearch");
  const countIndicator = document.getElementById("rma-count-indicator");
  const statusTabs = document.querySelectorAll(
    "#rma-status-tabs .admin-tab-btn",
  );

  // Check URL search param
  const urlParams = new URLSearchParams(window.location.search);
  const q = urlParams.get("q") || urlParams.get("search");
  if (q) {
    currentSearch = q.trim();
    if (searchInput && !searchInput.value) searchInput.value = currentSearch;
  }

  // Modal elements
  const modal = document.getElementById("admin-rma-modal");
  const btnCloseModal = document.getElementById("btn-close-rma-modal");
  const btnCancelModal = document.getElementById("btn-cancel-rma-modal");
  const btnSaveDecision = document.getElementById("btn-save-rma-decision");
  const rmaModalRefs = document.getElementById("rma-modal-refs");
  const rmaModalCustomer = document.getElementById("rma-modal-customer");
  const rmaModalItem = document.getElementById("rma-modal-item");
  const rmaModalNotes = document.getElementById("rma-modal-notes");
  const rmaDecisionStatus = document.getElementById("rma-decision-status");
  const rmaDecisionResolution = document.getElementById(
    "rma-decision-resolution",
  );
  const rmaDecisionRefund = document.getElementById("rma-decision-refund");
  const rmaDecisionRestock = document.getElementById("rma-decision-restock");
  const rmaDecisionNotes = document.getElementById("rma-decision-notes");
  const rmaErrorMsg = document.getElementById("rma-error-msg");
  const restockGroup = document.getElementById("rma-restock-group");

  loadReturns();

  // Tabs
  statusTabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      statusTabs.forEach((t) => t.classList.remove("active"));
      tab.classList.add("active");
      currentStatus = tab.dataset.status || "ALL";
      loadReturns();
    });
  });

  // Global Search with debounce
  let searchTimeout = null;
  searchInput?.addEventListener("input", (e) => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      currentSearch = e.target.value.trim();
      loadReturns();
    }, 200);
  });

  async function loadReturns() {
    if (!tbody) return;
    tbody.innerHTML =
      '<tr><td colspan="10"><div class="admin-empty-state">Loading return and exchange requests...</div></td></tr>';

    try {
      const data = await ApiClient.adminGetReturns(
        currentStatus,
        currentSearch,
      );
      rmaList = Array.isArray(data) ? data : data?.data || [];
      renderRmaTable();
    } catch (err) {
      console.error("[AdminReturns] Error loading RMAs:", err);
      tbody.innerHTML = `<tr><td colspan="10"><div class="admin-empty-state admin-empty-state--error">Unable to load return requests<div class="admin-empty-detail">${escapeHtml(err.message || "Server error")}</div></div></td></tr>`;
    }
  }

  function renderRmaTable() {
    if (!tbody) return;

    if (countIndicator) {
      countIndicator.textContent = `Showing ${rmaList.length} of ${rmaList.length} requests`;
    }

    if (rmaList.length === 0) {
      tbody.innerHTML =
        '<tr><td colspan="10"><div class="admin-empty-state"><div class="admin-empty-title">No Return Requests Found</div><p>No return or exchange requests match the current filters.</p></div></td></tr>';
      return;
    }

    tbody.innerHTML = rmaList
      .map((r) => {
        const statusClass =
          {
            Pending: "admin-badge--pending",
            Approved: "admin-badge--approved",
            Received: "admin-badge--received",
            Completed: "admin-badge--completed",
            Rejected: "admin-badge--rejected",
            Cancelled: "admin-badge--cancelled",
          }[r.status] || "admin-badge--pending";
        const statusBadge = `<span class="admin-badge ${statusClass}">${escapeHtml(r.status)}</span>`;

        const typeBadge =
          r.requestType === "EXCHANGE"
            ? '<span class="admin-badge admin-badge--exchange">Exchange</span>'
            : '<span class="admin-badge admin-badge--return">Return</span>';

        const restockedIndicator = r.restocked
          ? '<span class="admin-table-check admin-table-check--yes">Restocked</span>'
          : '<span class="admin-table-check admin-table-check--no">Not restocked</span>';

        return `
                <tr data-rma-id="${r.id}">
                    <td><span class="admin-cell-sku admin-cell-code">${escapeHtml(r.rmaNumber)}</span></td>
                    <td><span class="admin-cell-sku admin-cell-code">${escapeHtml(r.orderNumber)}</span></td>
                    <td>
                        <span class="admin-cell-name">${escapeHtml(r.customerName)}</span>
                        <span class="admin-cell-subtext">${escapeHtml(r.customerEmail)}</span>
                    </td>
                    <td>
                        <span class="admin-cell-name">${escapeHtml(r.productName)}</span>
                        <span class="admin-cell-subtext">${escapeHtml(r.colorName || "Default")} &bull; ${escapeHtml(r.size || "STD")} &bull; Qty ${r.quantity}</span>
                    </td>
                    <td>${typeBadge}</td>
                    <td>
                        <span class="admin-cell-truncate" title="${escapeHtml(r.reason)}">${escapeHtml(r.reason)}</span>
                    </td>
                    <td>${statusBadge}</td>
                    <td class="admin-table-align-center">${restockedIndicator}</td>
                    <td><span class="admin-activity-time">${escapeHtml(r.formattedDate || new Date(r.createdAt).toLocaleDateString())}</span></td>
                    <td class="admin-table-align-right">
                        <div class="admin-actions-cell admin-actions-cell--right">
                            <button type="button" class="btn-pill-sm btn-pill--outline btn-process-rma" data-id="${r.id}">Review Request</button>
                        </div>
                    </td>
                </tr>
            `;
      })
      .join("");

    // Wire buttons
    tbody.querySelectorAll(".btn-process-rma").forEach((btn) => {
      btn.addEventListener("click", () => {
        const id = parseInt(btn.dataset.id, 10);
        const rma = rmaList.find((r) => r.id === id);
        if (rma) openProcessModal(rma);
      });
    });
  }

  function openProcessModal(rma) {
    selectedRma = rma;
    if (rmaModalRefs) {
      rmaModalRefs.innerHTML = `<span class="admin-cell-sku">${escapeHtml(rma.rmaNumber)}</span> <span class="admin-cell-subtext">&bull;</span> <span class="admin-rma-order-link">Order: ${escapeHtml(rma.orderNumber)}</span>`;
    }
    if (rmaModalCustomer) {
      rmaModalCustomer.innerHTML = `<span class="admin-rma-customer-name">${escapeHtml(rma.customerName)}</span><span class="admin-rma-customer-meta">${escapeHtml(rma.customerEmail)}${rma.customerPhone ? " &bull; " + escapeHtml(rma.customerPhone) : ""}</span>`;
    }
    if (rmaModalItem) {
      rmaModalItem.innerHTML = `
                <div class="admin-rma-product-name">${escapeHtml(rma.productName)}</div>
                <div class="admin-rma-item-meta">
                    <span class="admin-badge admin-badge--neutral">${escapeHtml(rma.colorName || "Default")}</span>
                    <span class="admin-badge admin-badge--neutral">${escapeHtml(rma.size || "STD")}</span>
                    <span class="admin-rma-item-qty">Qty: <strong>${rma.quantity}</strong></span>
                    <span class="admin-rma-item-price">&#8369;${(rma.unitPrice || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>
            `;
    }
    if (rmaModalNotes) {
      rmaModalNotes.innerHTML = `
                <div class="admin-rma-reason-heading"><strong>Reason:</strong> ${escapeHtml(rma.reason)}</div>
                <div class="admin-rma-reason-body">${rma.customerNotes ? escapeHtml(rma.customerNotes) : '<span class="admin-cell-subtext">No additional customer notes.</span>'}</div>
            `;
    }

    if (rmaDecisionStatus)
      rmaDecisionStatus.value =
        rma.status !== "Pending" ? rma.status : "Approved";
    if (rmaDecisionResolution)
      rmaDecisionResolution.value =
        rma.resolutionType ||
        (rma.requestType === "EXCHANGE" ? "REPLACEMENT" : "REFUND");
    if (rmaDecisionRefund)
      rmaDecisionRefund.value = rma.refundAmount
        ? rma.refundAmount.toString()
        : (rma.quantity * rma.unitPrice).toFixed(2);
    if (rmaDecisionNotes) rmaDecisionNotes.value = rma.adminNotes || "";

    // Restock checkbox handling
    if (rmaDecisionRestock) {
      rmaDecisionRestock.checked = false;
      rmaDecisionRestock.disabled = rma.restocked;
    }
    if (restockGroup) {
      if (rma.restocked) {
        restockGroup.classList.add("is-disabled");
        restockGroup.title = "Item has already been restocked to inventory.";
      } else {
        restockGroup.classList.remove("is-disabled");
        restockGroup.title = "";
      }
    }

    if (rmaErrorMsg) {
      rmaErrorMsg.classList.add("is-hidden");
      rmaErrorMsg.textContent = "";
    }

    modal?.classList.remove("is-hidden");
  }

  function closeModal() {
    modal?.classList.add("is-hidden");
    selectedRma = null;
  }

  btnCloseModal?.addEventListener("click", closeModal);
  btnCancelModal?.addEventListener("click", closeModal);
  modal?.addEventListener("click", (e) => {
    if (e.target === modal) closeModal();
  });

  btnSaveDecision?.addEventListener("click", async () => {
    if (!selectedRma) return;

    const newStatus = rmaDecisionStatus?.value || "Approved";
    const resolution = rmaDecisionResolution?.value || "REFUND";
    const refundVal = parseFloat(rmaDecisionRefund?.value || "0");
    const restockVal = rmaDecisionRestock ? rmaDecisionRestock.checked : false;
    const notes = rmaDecisionNotes?.value?.trim() || "";

    if (btnSaveDecision) {
      btnSaveDecision.disabled = true;
      btnSaveDecision.textContent = "Saving...";
    }

    try {
      const res = await ApiClient.adminProcessReturn(selectedRma.id, {
        NewStatus: newStatus,
        ResolutionType: resolution,
        RefundAmount: isNaN(refundVal) ? null : refundVal,
        RestockItem: restockVal,
        AdminNotes: notes,
      });

      if (res && res.success) {
        if (window.AdminToast) {
          window.AdminToast.show(
            res.message || "RMA request updated successfully.",
            "success",
          );
        }
        closeModal();
        await loadReturns();
      } else {
        if (rmaErrorMsg) {
          rmaErrorMsg.textContent = res?.message || "Failed to update RMA.";
          rmaErrorMsg.classList.remove("is-hidden");
        }
      }
    } catch (err) {
      console.error("[AdminReturns] Error updating RMA:", err);
      if (rmaErrorMsg) {
        rmaErrorMsg.textContent =
          err.message || "Server error while processing RMA.";
        rmaErrorMsg.classList.remove("is-hidden");
      }
    } finally {
      if (btnSaveDecision) {
        btnSaveDecision.disabled = false;
        btnSaveDecision.textContent = "Save Decision";
      }
    }
  });

  function escapeHtml(str) {
    if (!str) return "";
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }
}
