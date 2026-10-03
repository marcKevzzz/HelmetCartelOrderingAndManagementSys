<%@ Page Title="Returns & Exchanges (RMA)" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" %>

<asp:Content ID="Head" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="/Content/css/admin/admin.css?v=17" />
</asp:Content>

<asp:Content ID="Main" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Page Heading -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Returns &amp; Exchanges</h1>
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
    <div id="admin-rma-modal" class="modal-backdrop is-hidden">
        <div class="modal-dialog admin-rma-dialog">
            <div class="modal-header admin-rma-header">
                <div class="modal-header-titles">
                    <h3 class="modal-title" id="rma-modal-title">Process RMA Request</h3>
                    <p class="modal-subtitle" id="rma-modal-subtitle">Review customer claim details, execute resolution, and manage stock return.</p>
                </div>
                <button type="button" class="modal-close-btn" id="btn-close-rma-modal" aria-label="Close dialog">&times;</button>
            </div>
            <div class="modal-body admin-rma-body">
                <input type="hidden" id="rma-modal-id" value="" />

                <!-- 1. Customer & Claim Overview Bento Card -->
                <div class="admin-rma-overview-card">
                    <div class="admin-rma-overview-grid">
                        <div class="admin-rma-meta-block">
                            <span class="admin-rma-field-label">RMA &amp; Order Reference</span>
                            <div id="rma-modal-refs" class="admin-rma-ref-value"></div>
                        </div>

                        <div class="admin-rma-meta-block">
                            <span class="admin-rma-field-label">Customer Details</span>
                            <div id="rma-modal-customer" class="admin-rma-customer-value"></div>
                        </div>

                        <div class="admin-rma-meta-block admin-rma-meta-block--full">
                            <span class="admin-rma-field-label">Item to Return / Exchange</span>
                            <div id="rma-modal-item" class="admin-rma-item-value"></div>
                        </div>

                        <div class="admin-rma-meta-block admin-rma-meta-block--full">
                            <span class="admin-rma-field-label">Customer's Stated Reason &amp; Notes</span>
                            <blockquote id="rma-modal-notes" class="admin-rma-reason-quote"></blockquote>
                        </div>
                    </div>
                </div>

                <!-- 2. Section Heading -->
                <div class="admin-rma-divider">
                    <span class="admin-rma-divider-text">Disposition Decision &amp; Settlement</span>
                </div>

                <!-- 3. Decision Form Grid -->
                <div class="admin-rma-form-grid">
                    <div class="modal-field-group">
                        <label for="rma-decision-status" class="modal-field-label">Update Status</label>
                        <select id="rma-decision-status" class="modal-select admin-rma-select">
                            <option value="Approved">Approved (Awaiting return shipment)</option>
                            <option value="Received">Item Received (Inspecting goods)</option>
                            <option value="Completed">Completed (Resolution processed)</option>
                            <option value="Rejected">Rejected</option>
                            <option value="Cancelled">Cancelled</option>
                        </select>
                    </div>

                    <div class="modal-field-group">
                        <label for="rma-decision-resolution" class="modal-field-label">Resolution Type</label>
                        <select id="rma-decision-resolution" class="modal-select admin-rma-select">
                            <option value="REFUND">Refund</option>
                            <option value="REPLACEMENT">Replacement / Exchange</option>
                            <option value="STORE_CREDIT">Store Credit</option>
                        </select>
                    </div>

                    <div class="modal-field-group admin-rma-field--full">
                        <label for="rma-decision-refund" class="modal-field-label">Refund / Settlement Amount (&#8369;)</label>
                        <div class="admin-rma-currency-field">
                            <span class="admin-rma-currency-addon">&#8369;</span>
                            <input type="number" id="rma-decision-refund" class="modal-input admin-rma-input admin-rma-currency-input" step="0.01" min="0" placeholder="0.00" />
                        </div>
                    </div>

                    <div class="admin-rma-restock-card" id="rma-restock-group">
                        <label class="admin-rma-checkbox-label" for="rma-decision-restock">
                            <input type="checkbox" id="rma-decision-restock" class="admin-rma-checkbox" />
                            <div class="admin-rma-checkbox-text">
                                <span class="admin-rma-checkbox-title">Return item to sellable inventory</span>
                                <span class="admin-rma-checkbox-desc">Atomic stock increment (`UPDLOCK`) and verified RESTOCK audit log entry.</span>
                            </div>
                        </label>
                    </div>

                    <div class="modal-field-group admin-rma-field--full">
                        <label for="rma-decision-notes" class="modal-field-label">Admin Notes &amp; Customer Feedback</label>
                        <textarea id="rma-decision-notes" class="modal-textarea admin-rma-textarea" rows="3" placeholder="Explain disposition decision or provide instructions for customer..."></textarea>
                    </div>
                </div>

                <div id="rma-error-msg" class="modal-alert modal-alert--danger is-hidden"></div>
            </div>
            <div class="modal-footer admin-rma-footer">
                <button type="button" class="btn-pill btn-pill--outline" id="btn-cancel-rma-modal">Cancel</button>
                <button type="button" class="btn-pill btn-pill--primary" id="btn-save-rma-decision">Save Decision</button>
            </div>
        </div>
    </div>

    <script type="module" src="/Scripts/admin/returns.js?v=2"></script>
</asp:Content>
