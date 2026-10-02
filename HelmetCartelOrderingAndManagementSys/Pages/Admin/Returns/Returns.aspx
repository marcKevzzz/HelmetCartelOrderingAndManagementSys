<%@ Page Title="Returns & Exchanges (RMA)" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" %>

<asp:Content ID="Head" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="/Content/css/admin/admin.css?v=16" />
</asp:Content>

<asp:Content ID="Main" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Page Heading -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Returns &amp; Exchanges (RMA)</h1>
            </div>
            <div class="admin-header-actions">
                <div class="admin-search-wrapper">
                    <input type="text" id="admin-rma-search" class="admin-date-input" placeholder="Search RMA, order, or customer..." />
                </div>
            </div>
        </div>

        <!-- Filter Sub-bar -->
        <div class="admin-filters-bar">
            <div class="admin-filters-left">
                <div class="admin-segmented-tabs" id="rma-status-tabs">
                    <button type="button" class="admin-tab-btn active" data-status="ALL">All</button>
                    <button type="button" class="admin-tab-btn" data-status="Pending">Pending Review</button>
                    <button type="button" class="admin-tab-btn" data-status="Approved">Approved</button>
                    <button type="button" class="admin-tab-btn" data-status="Received">Item Received</button>
                    <button type="button" class="admin-tab-btn" data-status="Completed">Completed</button>
                    <button type="button" class="admin-tab-btn" data-status="Rejected">Rejected</button>
                </div>
            </div>
            <div class="admin-meta-top">
                <span id="rma-count-indicator">Showing 0 of 0 requests</span>
            </div>
        </div>

        <!-- RMA Table -->
        <div class="admin-table-wrapper">
            <table class="admin-table admin-table-rma" id="admin-rma-table">
                <colgroup>
                    <col class="col-rma-number" />
                    <col class="col-order-number" />
                    <col class="col-customer" />
                    <col class="col-return-item" />
                    <col class="col-request-type" />
                    <col class="col-return-reason" />
                    <col class="col-return-status" />
                    <col class="col-restock" />
                    <col class="col-submitted" />
                    <col class="col-actions" />
                </colgroup>
                <thead>
                    <tr>
                        <th>RMA #</th>
                        <th>Order #</th>
                        <th>Customer</th>
                        <th>Item / Variant</th>
                        <th>Request Type</th>
                        <th>Reason</th>
                        <th>Status</th>
                        <th class="admin-table-align-center">Inventory</th>
                        <th>Submitted</th>
                        <th class="admin-table-align-right">Actions</th>
                    </tr>
                </thead>
                <tbody id="admin-rma-tbody">
                    <tr>
                        <td colspan="10"><div class="admin-empty-state">Loading return and exchange requests...</div></td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    <!-- Process RMA Modal Dialog -->
    <div id="admin-rma-modal" class="modal-backdrop review-modal-backdrop is-hidden">
        <div class="modal-dialog review-modal-dialog">
            <div class="modal-header">
                <div>
                    <h3 class="modal-title" id="rma-modal-title">Process RMA Request</h3>
                    <p class="modal-subtitle" id="rma-modal-subtitle">Update resolution, approval status, and restock inventory.</p>
                </div>
                <button type="button" class="modal-close-btn" id="btn-close-rma-modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="rma-modal-id" value="" />

                <div class="modal-field-group">
                    <label class="modal-field-label">RMA / Order Reference:</label>
                    <div id="rma-modal-refs" style="font-weight: 600; color: #fff;"></div>
                </div>

                <div class="modal-field-group">
                    <label class="modal-field-label">Customer:</label>
                    <div id="rma-modal-customer" style="color: var(--color-text-muted, #94a3b8);"></div>
                </div>

                <div class="modal-field-group">
                    <label class="modal-field-label">Item to Return / Exchange:</label>
                    <div id="rma-modal-item" style="color: #e2e8f0;"></div>
                </div>

                <div class="modal-field-group">
                    <label class="modal-field-label">Customer's Reason &amp; Notes:</label>
                    <blockquote id="rma-modal-notes" style="margin: 0; padding: 0.75rem 1rem; background: rgba(255,255,255,0.04); border-left: 3px solid var(--color-brand-primary, #e11d48); border-radius: 4px; font-style: italic;"></blockquote>
                </div>

                <hr style="border: 0; border-top: 1px solid rgba(255,255,255,0.1); margin: 1.25rem 0;" />

                <div class="modal-field-group">
                    <label for="rma-decision-status" class="modal-field-label">Update Status:</label>
                    <select id="rma-decision-status" class="modal-input">
                        <option value="Approved">Approved (Awaiting return shipment)</option>
                        <option value="Received">Item Received (Inspecting goods)</option>
                        <option value="Completed">Completed (Resolution processed)</option>
                        <option value="Rejected">Rejected</option>
                        <option value="Cancelled">Cancelled</option>
                    </select>
                </div>

                <div class="modal-field-group">
                    <label for="rma-decision-resolution" class="modal-field-label">Resolution Type:</label>
                    <select id="rma-decision-resolution" class="modal-input">
                        <option value="REFUND">Refund</option>
                        <option value="REPLACEMENT">Replacement / Exchange</option>
                        <option value="STORE_CREDIT">Store Credit</option>
                    </select>
                </div>

                <div class="modal-field-group">
                    <label for="rma-decision-refund" class="modal-field-label">Refund / Settlement Amount (&#8369;):</label>
                    <input type="number" id="rma-decision-refund" class="modal-input" step="0.01" min="0" placeholder="0.00" />
                </div>

                <div class="modal-field-group" id="rma-restock-group">
                    <label class="review-filter-checkbox-label" for="rma-decision-restock" style="cursor: pointer; display: flex; align-items: center; gap: 8px;">
                        <input type="checkbox" id="rma-decision-restock" style="width: 16px; height: 16px; accent-color: var(--color-brand-primary, #e11d48);" />
                        <span style="font-weight: 500; color: #fff;">Return item to sellable inventory (Atomic Stock Increment &amp; Audit Log)</span>
                    </label>
                </div>

                <div class="modal-field-group">
                    <label for="rma-decision-notes" class="modal-field-label">Admin Notes / Customer Feedback:</label>
                    <textarea id="rma-decision-notes" class="modal-textarea" rows="3" placeholder="Explain decision or resolution instructions..."></textarea>
                </div>

                <div id="rma-error-msg" class="report-alert-danger is-hidden"></div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn--outline" id="btn-cancel-rma-modal">Cancel</button>
                <button type="button" class="btn btn--primary" id="btn-save-rma-decision">Save Decision</button>
            </div>
        </div>
    </div>

    <script type="module" src="/Scripts/admin/returns.js?v=1"></script>
</asp:Content>
