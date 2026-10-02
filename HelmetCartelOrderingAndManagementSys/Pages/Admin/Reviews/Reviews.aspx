<%@ Page Title="Reviews Moderation" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" %>

<asp:Content ID="Head" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="/Content/css/admin/admin.css?v=16" />
</asp:Content>

<asp:Content ID="Main" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Page Heading -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Ratings &amp; Reviews Moderation</h1>
            </div>
            <div class="admin-header-actions">
                <div class="admin-search-wrapper">
                    <input type="text" id="admin-review-search" class="admin-date-input" placeholder="Search product, customer, or review text..." />
                </div>
            </div>
        </div>

        <!-- Filter Sub-bar -->
        <div class="admin-filters-bar">
            <div class="admin-filters-left">
                <div class="admin-segmented-tabs" id="review-status-tabs">
                    <button type="button" class="admin-tab-btn active" data-filter="ALL">All</button>
                    <button type="button" class="admin-tab-btn" data-filter="REPORTED">Flagged / Reported</button>
                    <button type="button" class="admin-tab-btn" data-filter="PUBLISHED">Published</button>
                    <button type="button" class="admin-tab-btn" data-filter="HIDDEN">Hidden</button>
                </div>
            </div>
            <div class="admin-meta-top">
                <span id="review-count-indicator">Showing 0 of 0 reviews</span>
            </div>
        </div>

        <!-- Reviews Table -->
        <div class="admin-table-wrapper">
            <table class="admin-table admin-table-reviews" id="admin-reviews-table">
                <colgroup>
                    <col class="col-review-product" />
                    <col class="col-reviewer" />
                    <col class="col-rating" />
                    <col class="col-review-content" />
                    <col class="col-reports" />
                    <col class="col-review-status" />
                    <col class="col-submitted" />
                    <col class="col-actions" />
                </colgroup>
                <thead>
                    <tr>
                        <th>Product</th>
                        <th>Customer</th>
                        <th>Rating</th>
                        <th>Review</th>
                        <th class="admin-table-align-center">Reports</th>
                        <th>Visibility</th>
                        <th>Submitted</th>
                        <th class="admin-table-align-right">Actions</th>
                    </tr>
                </thead>
                <tbody id="admin-reviews-tbody">
                    <tr>
                        <td colspan="8"><div class="admin-empty-state">Loading customer reviews...</div></td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    <!-- Review Details & Moderation Modal -->
    <div id="admin-review-modal" class="modal-backdrop review-modal-backdrop is-hidden">
        <div class="modal-dialog review-modal-dialog">
            <div class="modal-header">
                <div>
                    <h3 class="modal-title" id="arm-title">Review Details</h3>
                    <p class="modal-subtitle" id="arm-subtitle">Inspect customer review details and moderation flags.</p>
                </div>
                <button type="button" class="modal-close-btn" id="btn-close-review-modal">&times;</button>
            </div>
            <div class="modal-body">
                <div class="modal-field-group">
                    <label class="modal-field-label">Product:</label>
                    <div id="arm-product-name" style="font-weight: 600; color: var(--color-text-main, #fff);"></div>
                </div>
                <div class="modal-field-group">
                    <label class="modal-field-label">Reviewer:</label>
                    <div id="arm-reviewer" style="color: var(--color-text-muted, #94a3b8);"></div>
                </div>
                <div class="modal-field-group">
                    <label class="modal-field-label">Rating:</label>
                    <div id="arm-stars" style="color: var(--color-warning, #f59e0b);"></div>
                </div>
                <div class="modal-field-group">
                    <label class="modal-field-label">Review Title:</label>
                    <div id="arm-headline" style="font-weight: 500;"></div>
                </div>
                <div class="modal-field-group">
                    <label class="modal-field-label">Full Comment:</label>
                    <blockquote id="arm-comment" style="margin: 0; padding: 0.75rem 1rem; background: rgba(255,255,255,0.04); border-left: 3px solid var(--color-brand-primary, #e11d48); border-radius: 4px; font-style: italic;"></blockquote>
                </div>
                <div class="modal-field-group" id="arm-reports-group">
                    <label class="modal-field-label">Community Flags:</label>
                    <div id="arm-flags-count" style="color: var(--color-danger, #ef4444); font-weight: 600;"></div>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn--outline" id="btn-cancel-review-modal">Close</button>
                <button type="button" class="btn btn--primary" id="btn-toggle-visibility-action">Toggle Visibility</button>
            </div>
        </div>
    </div>

    <script type="module" src="/Scripts/admin/reviews.js?v=1"></script>
</asp:Content>
