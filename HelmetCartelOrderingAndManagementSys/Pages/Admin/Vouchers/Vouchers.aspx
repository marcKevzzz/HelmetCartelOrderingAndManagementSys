<%@ Page Title="Voucher Management" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" ResponseEncoding="utf-8" %>

<asp:Content ID="VoucherHead" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="/Content/css/admin/vouchers.css?v=3" />
</asp:Content>

<asp:Content ID="VoucherMain" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container voucher-page">
        <!-- 1. Top Row: Page Heading & Actions -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Promotional Vouchers</h1>
            </div>
            <div class="admin-header-actions">
                <button type="button" id="btn-open-create" class="btn-pill btn-pill--primary">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="5" x2="12" y2="19"></line>
                        <line x1="5" y1="12" x2="19" y2="12"></line>
                    </svg>
                    <span>Create Voucher</span>
                </button>
            </div>
        </div>

        <!-- 2. Metric KPI Cards (Semantic CSS, Matching Dashboard Layout) -->
        <div class="admin-kpi-grid voucher-kpi-grid">
            <div class="admin-kpi-card voucher-kpi-card">
                <div class="admin-kpi-label">Total Vouchers</div>
                <div class="admin-kpi-value" id="stat-total-vouchers">0</div>
                <div id="stat-total-trend">
                    <span class="admin-trend-badge admin-trend--neutral" title="Total promotional vouchers created">
                        <svg class="admin-trend-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                        <span>0.0%</span>
                    </span>
                </div>
            </div>

            <div class="admin-kpi-card voucher-kpi-card">
                <div class="admin-kpi-label">Active &amp; Ready</div>
                <div class="admin-kpi-value" id="stat-active-vouchers">0</div>
                <div id="stat-active-trend">
                    <span class="admin-trend-badge admin-trend--up" title="Active operational vouchers">
                        <svg class="admin-trend-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"></polyline><polyline points="16 7 22 7 22 13"></polyline></svg>
                        <span>+100.0%</span>
                    </span>
                </div>
            </div>

            <div class="admin-kpi-card voucher-kpi-card">
                <div class="admin-kpi-label">Total Redemptions</div>
                <div class="admin-kpi-value" id="stat-total-redemptions">0</div>
                <div id="stat-redemptions-trend">
                    <span class="admin-trend-badge admin-trend--up" title="Successful redemptions across orders">
                        <svg class="admin-trend-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"></polyline><polyline points="16 7 22 7 22 13"></polyline></svg>
                        <span>+1</span>
                    </span>
                </div>
            </div>

            <div class="admin-kpi-card voucher-kpi-card">
                <div class="admin-kpi-label">Expired / Inactive</div>
                <div class="admin-kpi-value" id="stat-expired-vouchers">0</div>
                <div id="stat-expired-trend">
                    <span class="admin-trend-badge admin-trend--neutral" title="Inactive, expired, or depleted vouchers">
                        <svg class="admin-trend-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                        <span>0.0%</span>
                    </span>
                </div>
            </div>
        </div>

        <!-- 3. Filter Sub-bar with Segmented Status Tabs -->
        <div class="admin-filters-bar">
            <div class="admin-filters-left">
                <div class="admin-segmented-tabs" id="voucher-status-tabs" role="tablist">
                    <button type="button" class="admin-tab-btn active" data-status="ALL">All Vouchers</button>
                    <button type="button" class="admin-tab-btn" data-status="ACTIVE">Active</button>
                    <button type="button" class="admin-tab-btn" data-status="INACTIVE">Inactive</button>
                    <button type="button" class="admin-tab-btn" data-status="EXPIRED">Expired / Depleted</button>
                </div>
            </div>

            <div class="admin-meta-top">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="admin-meta-top-icon">
                    <polygon points="12 2 2 7 12 12 22 7 12 2"></polygon>
                    <polyline points="2 17 12 22 22 17"></polyline>
                    <polyline points="2 12 12 17 22 12"></polyline>
                </svg>
                <span id="voucher-count-indicator">Showing 0 of 0 vouchers</span>
            </div>
        </div>

        <!-- 4. Main Voucher Table -->
        <div class="admin-table-wrapper">
            <table class="admin-table admin-table-vouchers">
                <thead>
                    <tr>
                        <th style="min-width: 170px;">Voucher Code</th>
                        <th style="min-width: 160px;">Discount Value</th>
                        <th style="min-width: 140px;">Min. Spend</th>
                        <th style="min-width: 160px;">Usage Progress</th>
                        <th style="min-width: 180px;">Validity &amp; Expiry</th>
                        <th style="min-width: 140px; text-align: right;">Actions</th>
                    </tr>
                </thead>
                <tbody id="voucher-rows">
                    <tr>
                        <td colspan="7">
                            <div class="admin-empty-state">
                                <div class="admin-empty-title">Loading vouchers...</div>
                                <p>Fetching current promotional codes from the server.</p>
                            </div>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    <!-- 5. Create / Edit Voucher Modal -->
    <div id="modal-voucher" class="modal-backdrop is-hidden" role="dialog" aria-modal="true" aria-labelledby="voucher-modal-title">
        <div class="admin-modal-voucher">
            <!-- Modal Header -->
            <div class="modal-header">
                <div>
                    <h2 id="voucher-modal-title">Create Promotional Voucher</h2>
                    <p>Configure discount rules, spend thresholds, and usage limits.</p>
                </div>
                <button type="button" id="btn-close-modal" class="modal-close-btn" aria-label="Close dialog">&times;</button>
            </div>

            <!-- Modal Body -->
            <div class="modal-body">
                <!-- Live Ticket Preview Card -->
                <div class="voucher-ticket-preview" aria-hidden="true">
                    <div class="voucher-preview-top">
                        <span class="voucher-preview-brand">
                            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"></path>
                                <line x1="7" y1="7" x2="7.01" y2="7"></line>
                            </svg>
                            Helmet Cartel Voucher
                        </span>
                        <span class="voucher-preview-status" id="preview-status-pill">Active</span>
                    </div>
                    <div class="voucher-preview-main">
                        <div class="voucher-preview-discount" id="preview-discount-val">10% OFF</div>
                        <div class="voucher-preview-code" id="preview-code-val">CODE</div>
                    </div>
                    <div class="voucher-preview-footer">
                        <span id="preview-min-spend">No minimum spend</span>
                        <span id="preview-expiry">No expiration date</span>
                    </div>
                </div>

                <!-- Form Fields Grid -->
                <div class="voucher-modal-grid">
                    <!-- 1. Code -->
                    <div class="admin-form-group">
                        <label class="admin-form-label" for="voucher-code">Voucher Code <span class="admin-required-star">*</span></label>
                        <input type="text" id="voucher-code" class="admin-form-input voucher-code-input" maxlength="30" placeholder="e.g. CARTEL10" autocomplete="off" />
                        <span class="voucher-field-hint">3–30 letters, numbers, or hyphens (auto-uppercased).</span>
                        <span id="voucher-code-error" class="inline-error-msg" role="alert"></span>
                    </div>

                    <!-- 2. Discount Type -->
                    <div class="admin-form-group">
                        <label class="admin-form-label" for="voucher-type">Discount Type <span class="admin-required-star">*</span></label>
                        <select id="voucher-type" class="admin-form-select">
                            <option value="PERCENTAGE">Percentage Discount (%)</option>
                            <option value="FIXED_AMOUNT">Fixed Peso Amount (&#8369;)</option>
                        </select>
                        <span id="voucher-type-error" class="inline-error-msg" role="alert"></span>
                    </div>

                    <!-- 3. Discount Value -->
                    <div class="admin-form-group">
                        <label class="admin-form-label" for="voucher-value">Discount Value <span class="admin-required-star">*</span></label>
                        <div class="admin-input-addon-wrap">
                            <input type="number" id="voucher-value" class="admin-form-input" min="0.01" step="0.01" placeholder="e.g. 10" />
                            <span class="admin-input-addon" id="voucher-value-unit">%</span>
                        </div>
                        <span id="voucher-value-error" class="inline-error-msg" role="alert"></span>
                    </div>

                    <!-- 4. Minimum Spend -->
                    <div class="admin-form-group">
                        <label class="admin-form-label" for="voucher-minimum">Minimum Merchandise Spend (&#8369;)</label>
                        <div class="admin-input-addon-wrap admin-input-addon-wrap--left">
                            <span class="admin-input-addon">&#8369;</span>
                            <input type="number" id="voucher-minimum" class="admin-form-input" min="0" step="0.01" value="0.00" placeholder="0.00" />
                        </div>
                        <span class="voucher-field-hint">Leave 0 for no minimum spend restriction.</span>
                        <span id="voucher-minimum-error" class="inline-error-msg" role="alert"></span>
                    </div>

                    <!-- 5. Expiration Date -->
                    <div class="admin-form-group">
                        <label class="admin-form-label" for="voucher-expiry">Expiration Date &amp; Time (Optional)</label>
                        <input type="datetime-local" id="voucher-expiry" class="admin-form-input" />
                        <span class="voucher-field-hint">Leave blank for no expiration date.</span>
                        <span id="voucher-expiry-error" class="inline-error-msg" role="alert"></span>
                    </div>

                    <!-- 6. Total Usage Limit -->
                    <div class="admin-form-group">
                        <label class="admin-form-label" for="voucher-limit">Total Usage Limit (Optional)</label>
                        <input type="number" id="voucher-limit" class="admin-form-input" min="1" step="1" placeholder="e.g. 100 (Leave blank for unlimited)" />
                        <span class="voucher-field-hint">Total redemptions allowed across all customers.</span>
                        <span id="voucher-limit-error" class="inline-error-msg" role="alert"></span>
                    </div>

                </div>

                <div id="voucher-modal-alert" class="modal-alert modal-alert--danger is-hidden" role="alert"></div>
            </div>

            <!-- Modal Footer -->
            <div class="modal-footer">
                <button type="button" id="btn-cancel-modal" class="btn-pill btn-pill--outline">Cancel</button>
                <button type="button" id="btn-save-voucher" class="btn-pill btn-pill--primary">Save Voucher</button>
            </div>
        </div>
    </div>

    <script type="module" src="/Scripts/admin/vouchers.js?v=3"></script>
</asp:Content>
