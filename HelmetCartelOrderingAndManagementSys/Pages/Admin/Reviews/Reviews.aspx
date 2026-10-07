<%@ Page Title="Reviews Moderation" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" %>



<asp:Content ID="Head" ContentPlaceHolderID="HeadContent" runat="server">

    <link rel="stylesheet" href="/Content/css/admin/admin.css?v=16" />

</asp:Content>



<asp:Content ID="Main" ContentPlaceHolderID="MainContent" runat="server">

    <%

        var authCookie = Request.Cookies[HelmetCartelOrderingAndManagementSys.Constants.AppConstants.JwtConfiguration.AuthCookieName]?.Value;

        var tokenUser = new HelmetCartelOrderingAndManagementSys.Infrastructure.JwtTokenProvider().ValidateToken(authCookie);

        bool isUserAdmin = tokenUser != null && tokenUser.Role == HelmetCartelOrderingAndManagementSys.Constants.AppConstants.Roles.Admin;

    %>

    <script>

        window.HC_IS_ADMIN = <%= isUserAdmin ? "true" : "false" %>;

    </script>

    <div class="admin-card-container">

        <!-- Top Row: Page Heading -->

        <div class="admin-page-header">

            <div class="admin-page-title-row">

                <h1 class="admin-page-title">Ratings &amp; Reviews Moderation</h1>

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

                    <col class="col-actions reviews" />

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

                    <div class="reviews-arm-product-name-presentation" id="arm-product-name"></div>

                </div>

                <div class="modal-field-group">

                    <label class="modal-field-label">Reviewer:</label>

                    <div class="reviews-arm-reviewer-presentation" id="arm-reviewer"></div>

                </div>

                <div class="modal-field-group">

                    <label class="modal-field-label">Rating:</label>

                    <div class="reviews-arm-stars-presentation" id="arm-stars"></div>

                </div>

                <div class="modal-field-group">

                    <label class="modal-field-label">Review Title:</label>

                    <div class="reviews-arm-headline-presentation" id="arm-headline"></div>

                </div>

                <div class="modal-field-group">

                    <label class="modal-field-label">Full Comment:</label>

                    <blockquote class="reviews-arm-comment-presentation" id="arm-comment"></blockquote>

                </div>

                <div class="modal-field-group" id="arm-reports-group">

                    <label class="modal-field-label">Community Flags:</label>

                    <div class="reviews-arm-flags-count-presentation" id="arm-flags-count"></div>

                </div>

            </div>

            <div class="modal-footer">

                <button type="button" class="btn btn--danger is-hidden" id="btn-delete-review-modal">Delete Review</button>

                <button type="button" class="btn btn--outline" id="btn-cancel-review-modal">Close</button>

                <button type="button" class="btn btn--primary" id="btn-toggle-visibility-action">Toggle Visibility</button>

            </div>

        </div>

    </div>



    <!-- Dedicated Delete Review Confirmation Modal (Admin Only) -->

    <div id="adminDeleteReviewModal" class="admin-quick-modal-backdrop is-hidden" hidden role="dialog" aria-modal="true" aria-labelledby="delReviewModalHeading">

        <div class="admin-quick-modal">

            <header class="admin-quick-modal-header">

                <div>

                    <h3 class="admin-quick-modal-title" id="delReviewModalHeading">Delete Customer Review</h3>

                    <p class="admin-modal-subtitle">Permanent review removal</p>

                </div>

                <button type="button" class="admin-modal-close-btn" id="btnCloseDeleteReviewModal" aria-label="Close delete modal">&times;</button>

            </header>

            <div class="admin-quick-modal-body">

                <p class="admin-modal-description">

                    Are you sure you want to permanently delete this customer review? This action cannot be undone and will remove the review and any associated community report logs.

                </p>

                <div class="admin-delete-preview-card">

                    <div class="admin-delete-preview-info">

                        <div class="admin-delete-preview-tags">

                            <span id="delReviewProduct" class="admin-badge admin-badge--active">Product</span>

                            <span id="delReviewRating" class="admin-badge admin-badge--verified">&#9733;&#9733;&#9733;&#9733;&#9733;</span>

                        </div>

                        <span id="delReviewAuthor" class="admin-delete-preview-name">Reviewer Name</span>

                        <blockquote id="delReviewSnippet" class="reviews-arm-comment-presentation" style="margin-top: 8px; font-size: 0.85rem; max-height: 80px; overflow: hidden; text-overflow: ellipsis;"></blockquote>

                    </div>

                </div>

            </div>

            <footer class="admin-quick-modal-footer">

                <button type="button" class="btn-pill btn-pill--outline" id="btnCancelDeleteReview">Cancel</button>

                <button type="button" class="btn-pill btn-pill--danger btn-pill--danger-fill" id="btnConfirmDeleteReview">Delete Review</button>

            </footer>

        </div>

    </div>



    <script type="module" src="/Scripts/admin/reviews.js?v=3"></script>

</asp:Content>

