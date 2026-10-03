<%@ Page Title="My Account & Order Tracking" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Profile.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.ProfilePage" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href='<%= ResolveUrl("~/Content/css/storefront/profile.css?v=8") %>' />
    <link rel="stylesheet" href="/Content/css/receipts.css?v=1" />
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="profile-container">
        <!-- 1. Top Breadcrumb & Contact Info Strip (Matching 1st Screenshot) -->
        <div class="profile-top-header-strip">
            <nav class="profile-breadcrumb" aria-label="Breadcrumb">
                <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="profile-breadcrumb__link">Home</asp:HyperLink>
                <svg class="profile-breadcrumb__separator" viewBox="0 0 24 24" fill="none" stroke-width="2">
                    <polyline points="9 18 15 12 9 6"></polyline>
                </svg>
                <span class="profile-breadcrumb__current" id="profile-breadcrumb-label">Account</span>
            </nav>
        </div>

        <!-- 2. Main Two-Column Layout (Sidebar + Content Area) -->
        <div class="profile-layout-grid">
            <!-- Sidebar (Design modeled after Admin Sidebar with pure monochrome tokens) -->
            <aside class="profile-sidebar" id="profile-sidebar" aria-label="Customer Navigation">
                <div class="profile-sidebar-top">
                    <!-- User summary & Avatar header -->
                    <div class="profile-sidebar-header">
                        <div class="profile-sidebar-user">
                            <div class="profile-sidebar-avatar" id="profile-avatar">HC</div>
                            <div class="profile-sidebar-user-meta">
                                <h2 class="profile-sidebar-name" id="profile-user-name">Loading Rider...</h2>
                                <span class="profile-sidebar-time-subtle" id="profile-role-text">Created: Loading...</span>
                            </div>
                        </div>
                    </div>

                    <!-- Navigation Group -->
                    <div class="profile-nav-group">
                        <div class="profile-nav-group-header">
                            <span class="profile-nav-group-title">Navigation</span>
                        </div>
                        <ul class="profile-nav-list" role="tablist">
                            <li>
                                <button type="button" class="profile-nav-link" data-tab="details" role="tab" aria-selected="false">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                                        <circle cx="12" cy="7" r="4"></circle>
                                    </svg>
                                    <span>Account details</span>
                                </button>
                            </li>
                            <li>
                                <button type="button" class="profile-nav-link active" data-tab="orders" role="tab" aria-selected="true">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                        <circle cx="12" cy="12" r="10"></circle>
                                        <polyline points="12 6 12 12 16 14"></polyline>
                                    </svg>
                                    <span>Order history</span>
                                    <span class="profile-nav-count" id="nav-count-orders" style="display: none;"></span>
                                </button>
                            </li>
                            <li>
                                <button type="button" class="profile-nav-link" data-tab="wishlist" role="tab" aria-selected="false">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                        <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>
                                    </svg>
                                    <span>Wishlist</span>
                                    <span class="profile-nav-count" id="nav-count-wishlist" style="display: none;"></span>
                                </button>
                            </li>
                            <li>
                                <button type="button" class="profile-nav-link" data-tab="addresses" role="tab" aria-selected="false">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                        <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                                        <circle cx="12" cy="10" r="3"></circle>
                                    </svg>
                                    <span>Addresses</span>
                                    <span class="profile-nav-count" id="nav-count-addresses" style="display: none;"></span>
                                </button>
                            </li>
                            <li>
                                <button type="button" class="profile-nav-link" data-tab="payments" role="tab" aria-selected="false">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                        <rect x="2" y="5" width="20" height="14" rx="2"></rect>
                                        <line x1="2" y1="10" x2="22" y2="10"></line>
                                    </svg>
                                    <span>Payment history</span>
                                    <span class="profile-nav-count" id="nav-count-payments" style="display: none;"></span>
                                </button>
                            </li>
                            <li>
                                <button type="button" class="profile-nav-link" data-tab="security" role="tab" aria-selected="false">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
                                        <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
                                    </svg>
                                    <span>Security &amp; Password</span>
                                </button>
                            </li>
                        </ul>
                    </div>
                </div>

                <!-- Sidebar Footer: Log Out / Sign Out at Bottom -->
                <div class="profile-sidebar-footer">
                    <button type="button" class="profile-nav-link profile-nav-link--logout" id="btn-profile-logout" title="Sign Out of Cartel Account">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
                            <polyline points="16 17 21 12 16 7"></polyline>
                            <line x1="21" y1="12" x2="9" y2="12"></line>
                        </svg>
                        <span>Sign Out</span>
                    </button>
                </div>
            </aside>

            <!-- Main Content Area -->
            <main class="profile-content-area">
                <!-- TAB 1: ORDER HISTORY (Active by default, consistent with other sections) -->
                <section class="profile-tab-pane active" id="tab-pane-orders" aria-label="Order History">
                    <div class="profile-section-card">
                        <div class="profile-section-header">
                            <div>
                                <h2 class="profile-section-card__title">Order History</h2>
                                <p class="profile-section-card__desc">Review your past purchases, shipment statuses, and track active deliveries.</p>
                            </div>

                            <div class="shop-header__sort" id="order-sort-dropdown-wrap">
                                <button type="button" class="shop-sort-btn" id="order-sort-btn" aria-label="Sort orders" aria-haspopup="true" aria-expanded="false">
                                    <span>Sort by: <strong id="current-order-sort-label">Newest First</strong></span>
                                    <svg class="shop-header__sort-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <polyline points="6 9 12 15 18 9"></polyline>
                                    </svg>
                                </button>
                                <div class="shop-sort-menu" id="order-sort-menu">
                                    <button type="button" class="shop-sort-option active" data-sort="newest">Newest First</button>
                                    <button type="button" class="shop-sort-option" data-sort="oldest">Oldest First</button>
                                    <button type="button" class="shop-sort-option" data-sort="amount-high">Highest Amount</button>
                                    <button type="button" class="shop-sort-option" data-sort="amount-low">Lowest Amount</button>
                                    <button type="button" class="shop-sort-option" data-sort="status-active">In Progress / Delivery</button>
                                    <button type="button" class="shop-sort-option" data-sort="status-completed">Delivered &amp; Completed</button>
                                    <button type="button" class="shop-sort-option" data-sort="status-cancelled">Cancelled</button>
                                </div>
                            </div>
                        </div>

                        <!-- Loading State -->
                        <div class="order-loading-box" id="orders-loading-state">
                            <div class="loading-spinner"></div>
                            <span>Retrieving real-time order history from MSSQL ledger...</span>
                        </div>

                        <!-- Empty State -->
                        <div class="empty-orders-card" id="orders-empty-state" style="display: none;">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="empty-orders-icon">
                                <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path>
                                <line x1="3" y1="6" x2="21" y2="6"></line>
                                <path d="M16 10a4 4 0 0 1-8 0"></path>
                            </svg>
                            <h3>No Orders Found</h3>
                            <p>You haven't placed any orders matching this search or filter criteria.</p>
                            <asp:HyperLink runat="server" NavigateUrl="~/Pages/Storefront/Shop/Shop.aspx" CssClass="btn btn--primary btn--sm">Explore Shop</asp:HyperLink>
                        </div>

                        <!-- Orders Cards List Container (Dynamically populated with stacking deck images) -->
                        <div class="order-cards-list" id="order-cards-container">
                            <!-- Populated dynamically via Scripts/profile.js -->
                        </div>
                    </div>
                </section>

                <!-- TAB 2: ACCOUNT DETAILS -->
                <section class="profile-tab-pane" id="tab-pane-details" aria-label="Personal Information">
                    <div class="profile-section-card">
                        <div class="profile-section-card__header">
                            <h2 class="profile-section-card__title">Personal Information</h2>
                            <p class="profile-section-card__desc">Update your name and contact details for deliveries and order receipts.</p>
                        </div>

                        <form id="form-edit-profile" class="settings-form" novalidate>
                            <div class="form-row-2col">
                                <div class="form-group">
                                    <label for="edit-first-name" class="form-label">First Name *</label>
                                    <input type="text" id="edit-first-name" class="form-input" placeholder="e.g. Marc Kevin" autocomplete="given-name" required />
                                    <span class="inline-error-msg" id="err-first-name"></span>
                                </div>
                                <div class="form-group">
                                    <label for="edit-last-name" class="form-label">Last Name *</label>
                                    <input type="text" id="edit-last-name" class="form-input" placeholder="e.g. Del Mundo" autocomplete="family-name" required />
                                    <span class="inline-error-msg" id="err-last-name"></span>
                                </div>
                            </div>

                            <div class="form-group">
                                <label for="edit-email" class="form-label">Email Address</label>
                                <input type="email" id="edit-email" class="form-input" autocomplete="username" readonly disabled />
                                <span class="form-helper-text">Your primary account email cannot be changed for security purposes.</span>
                            </div>

                            <div class="form-group">
                                <label for="edit-phone" class="form-label">Mobile Phone Number</label>
                                <input type="tel" id="edit-phone" class="form-input" placeholder="e.g. +63 917 123 4567" autocomplete="tel" />
                                <span class="inline-error-msg" id="err-phone"></span>
                            </div>

                            <div>
                                <button type="submit" class="btn btn--primary" id="btn-save-profile">
                                    Save Profile Changes
                                </button>
                            </div>
                        </form>
                    </div>
                </section>

                <!-- TAB 3: WISHLIST (Moved from navbar to Profile Sidebar) -->
                <section class="profile-tab-pane" id="tab-pane-wishlist" aria-label="Customer Wishlist">
                    <div class="profile-section-card">
                        <div class="profile-section-header">
                            <div>
                                <h2 class="profile-section-card__title">Saved Wishlist</h2>
                                <p class="profile-section-card__desc" id="profile-wishlist-count-desc">Loading your saved gear...</p>
                            </div>
                            <button type="button" class="btn btn--outline btn--sm" id="btn-clear-profile-wishlist" style="display: none;">
                                Clear Wishlist
                            </button>
                        </div>

                        <!-- Wishlist Content Container -->
                        <div class="profile-wishlist-container" id="profile-wishlist-content">
                            <!-- Populated dynamically via Scripts/profile.js -->
                        </div>
                    </div>
                </section>

                <!-- TAB 4: DELIVERY ADDRESSES -->
                <section class="profile-tab-pane" id="tab-pane-addresses" aria-label="Saved Addresses">
                    <div class="profile-section-card">
                        <div class="profile-section-header">
                            <div>
                                <h2 class="profile-section-card__title">Saved Delivery Addresses</h2>
                                <p class="profile-section-card__desc">Manage your shipping destinations for quick auto-fill during checkout.</p>
                            </div>
                            <button type="button" class="btn btn--primary btn--sm" id="btn-add-new-address">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                                    <line x1="12" y1="5" x2="12" y2="19"></line>
                                    <line x1="5" y1="12" x2="19" y2="12"></line>
                                </svg>
                                <span>Add New Address</span>
                            </button>
                        </div>

                        <!-- Loading State -->
                        <div class="order-loading-box" id="addresses-loading-state">
                            <div class="loading-spinner"></div>
                            <span>Retrieving saved shipping destinations...</span>
                        </div>

                        <!-- Empty State -->
                        <div class="empty-orders-card" id="addresses-empty-state" style="display: none;">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="empty-orders-icon">
                                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                                <circle cx="12" cy="10" r="3"></circle>
                            </svg>
                            <h3>No Saved Addresses Found</h3>
                            <p>Save your home, garage, or office address for seamless one-click checkout.</p>
                            <button type="button" class="btn btn--primary btn--sm" id="btn-empty-add-address">Add First Address</button>
                        </div>

                        <!-- Address Cards Grid -->
                        <div class="address-cards-grid" id="addresses-cards-container">
                            <!-- Dynamically populated via profile.js -->
                        </div>
                    </div>
                </section>

                <!-- TAB 5: PAYMENT METHODS & RECEIPTS -->
                <section class="profile-tab-pane" id="tab-pane-payments" aria-label="Payment Transactions">
                    <div class="profile-section-card">
                        <div class="profile-section-header">
                            <div>
                                <h2 class="profile-section-card__title">Payment Transaction History</h2>
                                <p class="profile-section-card__desc">Review gateway references, payment transaction logs, and download transaction receipts.</p>
                            </div>
                        </div>

                        <!-- Loading State -->
                        <div class="order-loading-box" id="payments-loading-state">
                            <div class="loading-spinner"></div>
                            <span>Retrieving verified transaction history...</span>
                        </div>

                        <!-- Empty State -->
                        <div class="empty-orders-card" id="payments-empty-state" style="display: none;">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="empty-orders-icon">
                                <rect x="2" y="5" width="20" height="14" rx="2"></rect>
                                <line x1="2" y1="10" x2="22" y2="10"></line>
                            </svg>
                            <h3>No Payment Records Found</h3>
                            <p>Once you complete a transaction via HitPay, COD, or in-store, your records will appear here.</p>
                        </div>

                        <!-- Payments Table Container -->
                        <div class="payments-table-container" id="payments-table-container">
                            <table class="payments-table">
                                <thead>
                                    <tr>
                                        <th>Gateway Ref / Transaction ID</th>
                                        <th>Order Number</th>
                                        <th>Payment Gateway</th>
                                        <th>Status</th>
                                        <th>Amount</th>
                                        <th>Transaction Date</th>
                                        <th>Digital Receipt</th>
                                    </tr>
                                </thead>
                                <tbody id="payments-table-body">
                                    <!-- Populated dynamically via Scripts/profile.js -->
                                </tbody>
                            </table>
                        </div>
                    </div>
                </section>

                <!-- TAB 6: SECURITY & PASSWORD -->
                <section class="profile-tab-pane" id="tab-pane-security" aria-label="Security & Password">
                    <div class="profile-section-card">
                        <div class="profile-section-card__header">
                            <h2 class="profile-section-card__title">Password &amp; Security</h2>
                            <p class="profile-section-card__desc">Ensure your account uses a secure password with at least 6 characters.</p>
                        </div>

                        <form id="form-change-password" class="settings-form" novalidate>
                            <div class="form-group">
                                <label for="pwd-current" class="form-label">Current Password *</label>
                                <input type="password" id="pwd-current" class="form-input" placeholder="Enter current password" autocomplete="current-password" required />
                                <span class="inline-error-msg" id="err-pwd-current"></span>
                            </div>

                            <div class="form-group">
                                <label for="pwd-new" class="form-label">New Password *</label>
                                <input type="password" id="pwd-new" class="form-input" placeholder="Minimum 6 characters" autocomplete="new-password" required />
                                <span class="inline-error-msg" id="err-pwd-new"></span>
                            </div>

                            <div class="form-group">
                                <label for="pwd-confirm" class="form-label">Confirm New Password *</label>
                                <input type="password" id="pwd-confirm" class="form-input" placeholder="Re-type new password" autocomplete="new-password" required />
                                <span class="inline-error-msg" id="err-pwd-confirm"></span>
                            </div>

                            <div>
                                <button type="submit" class="btn btn--primary" id="btn-save-password">
                                    Update Password
                                </button>
                            </div>
                        </form>
                    </div>
                </section>
            </main>
        </div>
    </div>

    <!-- 3. Official Digital Receipt Modal -->
    <div class="receipt-modal-overlay" id="receipt-modal-overlay" role="dialog" aria-modal="true" aria-labelledby="receipt-dialog-title">
        <div class="receipt-modal-container">
            <div class="receipt-modal-header">
                <h3 class="receipt-modal-title" id="receipt-dialog-title">Digital Sales Receipt</h3>
                <button type="button" class="receipt-modal-close" id="btn-receipt-modal-close" aria-label="Close receipt modal">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                        <line x1="18" y1="6" x2="6" y2="18"></line>
                        <line x1="6" y1="6" x2="18" y2="18"></line>
                    </svg>
                </button>
            </div>

            <div class="receipt-modal-body">
                <div class="digital-receipt-doc" id="digital-receipt-doc">
                    <div class="loading-spinner"></div>
                    <span>Formatting receipt...</span>
                </div>
            </div>

            <div class="receipt-modal-footer">
                <button type="button" class="btn btn--outline btn--sm" id="btn-print-receipt">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                        <polyline points="6 9 6 2 18 2 18 9"></polyline>
                        <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path>
                        <rect x="6" y="14" width="12" height="8"></rect>
                    </svg>
                    <span>Print / Save Receipt</span>
                </button>
            </div>
        </div>
    </div>

    <!-- 4. Address Management Modal -->
    <div class="receipt-modal-overlay" id="address-modal-overlay" role="dialog" aria-modal="true" aria-labelledby="address-modal-title">
        <div class="receipt-modal-container address-modal-container">
            <div class="receipt-modal-header">
                <h3 class="receipt-modal-title" id="address-modal-title">Add Delivery Address</h3>
                <button type="button" class="receipt-modal-close" id="btn-address-modal-close" aria-label="Close address modal">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                        <line x1="18" y1="6" x2="6" y2="18"></line>
                        <line x1="6" y1="6" x2="18" y2="18"></line>
                    </svg>
                </button>
            </div>

            <form id="form-address-modal" class="address-modal-form" novalidate>
                <div class="receipt-modal-body address-modal-body">
                    <input type="hidden" id="addr-id" value="0" />
                    <div class="form-row-2col">
                        <div class="form-group">
                            <label for="addr-recipient-name" class="form-label">Recipient Full Name *</label>
                            <input type="text" id="addr-recipient-name" class="form-input" placeholder="e.g. Marc Kevin" autocomplete="name" required />
                            <span class="inline-error-msg" id="err-addr-recipient-name"></span>
                        </div>
                        <div class="form-group">
                            <label for="addr-phone" class="form-label">Recipient Phone Number *</label>
                            <input type="tel" id="addr-phone" class="form-input" placeholder="e.g. (+63) 995 123 4567" autocomplete="tel" required />
                            <span class="inline-error-msg" id="err-addr-phone"></span>
                        </div>
                    </div>
                    <div class="form-row-2col">
                        <div class="form-group">
                            <label for="addr-label" class="form-label">Address Label *</label>
                            <input type="text" id="addr-label" class="form-input" placeholder="e.g. Home, Office, Garage" autocomplete="off" required />
                            <span class="inline-error-msg" id="err-addr-label"></span>
                        </div>
                        <div class="form-group">
                            <label for="addr-street" class="form-label">Street Address / Unit / Bldg *</label>
                            <input type="text" id="addr-street" class="form-input" placeholder="House/Unit #, Street name" autocomplete="street-address" required />
                            <span class="inline-error-msg" id="err-addr-street"></span>
                        </div>
                    </div>

                    <div class="form-row-2col">
                        <div class="form-group">
                            <label for="addr-brgy" class="form-label">Barangay</label>
                            <input type="text" id="addr-brgy" class="form-input" placeholder="e.g. Brgy. Commonwealth" autocomplete="address-level3" />
                        </div>
                        <div class="form-group">
                            <label for="addr-city" class="form-label">City / Municipality *</label>
                            <input type="text" id="addr-city" class="form-input" placeholder="e.g. Quezon City" autocomplete="address-level2" required />
                            <span class="inline-error-msg" id="err-addr-city"></span>
                        </div>
                    </div>

                    <div class="form-row-2col">
                        <div class="form-group">
                            <label for="addr-province" class="form-label">Province *</label>
                            <input type="text" id="addr-province" class="form-input" placeholder="e.g. Metro Manila" autocomplete="address-level1" required />
                            <span class="inline-error-msg" id="err-addr-province"></span>
                        </div>
                        <div class="form-group">
                            <label for="addr-postal" class="form-label">Postal / ZIP Code</label>
                            <input type="text" id="addr-postal" class="form-input" placeholder="e.g. 1108" autocomplete="postal-code" />
                        </div>
                    </div>

                    <div class="form-group">
                        <label for="addr-landmark" class="form-label">Delivery Notes / Landmark</label>
                        <input type="text" id="addr-landmark" class="form-input" placeholder="e.g. Near Petron station, black gate" />
                    </div>

                    <div class="form-group address-checkbox-wrap">
                        <label class="address-checkbox-label">
                            <input type="checkbox" id="addr-is-default" />
                            <span>Set as default delivery address</span>
                        </label>
                    </div>
                </div>

                <div class="receipt-modal-footer">
                    <button type="button" class="btn btn--outline btn--sm" id="btn-cancel-address-modal">Cancel</button>
                    <button type="submit" class="btn btn--primary btn--sm" id="btn-save-address-modal">Save Address</button>
                </div>
            </form>
        </div>
    </div>

    <!-- 5. Sign Out Confirmation Modal (Matching Admin Portal) -->
    <div id="profileSignOutModal" class="admin-modal-backdrop is-hidden" hidden role="dialog" aria-modal="true" aria-labelledby="profileSignOutTitle">
        <div class="admin-modal admin-modal--confirm">
            <div class="admin-modal-icon-circle">
                <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
                    <polyline points="16 17 21 12 16 7"></polyline>
                    <line x1="21" y1="12" x2="9" y2="12"></line>
                </svg>
            </div>
            <h3 class="admin-modal-title" id="profileSignOutTitle">Sign Out Confirmation</h3>
            <p class="admin-modal-desc-subtle">
                Are you sure you want to sign out of your Helmet Cartel account?
            </p>
            <div class="admin-modal-footer">
                <button type="button" class="btn btn--outline btn--sm" id="btnCancelProfileSignOut">Cancel</button>
                <button type="button" class="btn btn--primary btn--sm" id="btnConfirmProfileSignOut">Confirm Sign Out</button>
            </div>
        </div>
    </div>

    <!-- 6. Order Cancellation Confirmation Modal -->
    <div id="profileCancelOrderModal" class="admin-modal-backdrop is-hidden" hidden role="dialog" aria-modal="true" aria-labelledby="profileCancelOrderTitle">
        <div class="admin-modal admin-modal--confirm">
            <div class="admin-modal-icon-circle admin-modal-icon-circle--danger">
                <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"></circle>
                    <line x1="15" y1="9" x2="9" y2="15"></line>
                    <line x1="9" y1="9" x2="15" y2="15"></line>
                </svg>
            </div>
            <h3 class="admin-modal-title" id="profileCancelOrderTitle">Cancel Order</h3>
            <p class="admin-modal-desc-subtle" id="profileCancelOrderDesc">
                Are you sure you want to cancel order <strong id="cancel-order-num-text"></strong>? Any reserved stock will be immediately released back into inventory.
            </p>
            <div class="form-group cancel-reason-wrap">
                <label for="cancel-order-reason-select" class="form-label">Reason for cancellation *</label>
                <select id="cancel-order-reason-select" class="form-input">
                    <option value="Changed mind / found alternative">Changed mind / found alternative</option>
                    <option value="Ordered wrong helmet size / color">Ordered wrong helmet size / color</option>
                    <option value="Delivery address error">Delivery address error</option>
                    <option value="Payment method issue">Payment method issue</option>
                    <option value="Duplicate order placed">Duplicate order placed</option>
                    <option value="Other">Other reason</option>
                </select>
            </div>
            <div class="form-group">
                <label for="cancel-order-notes" class="form-label">Additional Comments (Optional)</label>
                <textarea id="cancel-order-notes" class="form-input" rows="2" placeholder="Details about why you are cancelling..."></textarea>
            </div>
            <div id="profileCancelOrderError" class="auth-error-msg is-hidden"></div>
            <div class="admin-modal-footer">
                <button type="button" class="btn btn--outline btn--sm" id="btnDismissCancelOrder">Keep Order</button>
                <button type="button" class="btn btn--danger btn--sm" id="btnConfirmCancelOrder">Confirm Cancellation</button>
            </div>
        </div>
    </div>

    <!-- 7. Order Return & Exchange Modal -->
    <div id="profileRmaModal" class="receipt-modal-overlay" role="dialog" aria-modal="true" aria-labelledby="profileRmaTitle">
        <div class="receipt-modal-container address-modal-container">
            <div class="receipt-modal-header">
                <div>
                    <h3 class="receipt-modal-title" id="profileRmaTitle">Request Return / Exchange</h3>
                    <p class="receipt-modal-subtitle">Submit a return or exchange request for your delivered order.</p>
                </div>
                <button type="button" class="receipt-modal-close" id="btn-close-profile-rma" aria-label="Close RMA modal">&times;</button>
            </div>
            <div class="receipt-modal-body address-modal-body">
                <input type="hidden" id="profile-rma-order-id" value="" />
                
                <div class="form-group">
                    <label for="profile-rma-item-select" class="form-label">Select Item to Return / Exchange *</label>
                    <select id="profile-rma-item-select" class="form-input" required></select>
                </div>

                <div class="form-group">
                    <label class="form-label">Request Type *</label>
                    <div class="rma-radio-group">
                        <label class="rma-radio-label">
                            <input type="radio" name="profile-rma-type" value="RETURN" checked />
                            <span>Return for Refund</span>
                        </label>
                        <label class="rma-radio-label">
                            <input type="radio" name="profile-rma-type" value="EXCHANGE" />
                            <span>Exchange for Size / Color</span>
                        </label>
                    </div>
                </div>

                <div class="form-group">
                    <label for="profile-rma-reason" class="form-label">Reason *</label>
                    <select id="profile-rma-reason" class="form-input">
                        <option value="WRONG_SIZE">Wrong Size / Fit Issue</option>
                        <option value="DEFECTIVE">Defective or Damaged Gear</option>
                        <option value="NOT_AS_DESCRIBED">Item Not as Described</option>
                        <option value="CHANGED_MIND">Changed Mind / Unused</option>
                        <option value="OTHER">Other Reason</option>
                    </select>
                </div>

                <div class="form-group">
                    <label for="profile-rma-notes" class="form-label">Details &amp; Explanations</label>
                    <textarea id="profile-rma-notes" class="form-input" rows="3" placeholder="Provide any details about the fit issue, defect, or preferred replacement..."></textarea>
                </div>

                <div class="profile-rma-policy-notice">
                    &#9432; Returned gear must be unridden with factory tags, visor protective film, and original packaging intact.
                </div>

                <div id="profile-rma-error" class="auth-error-msg is-hidden"></div>
            </div>
            <div class="receipt-modal-footer">
                <button type="button" class="btn btn--outline btn--sm" id="btn-cancel-profile-rma">Cancel</button>
                <button type="button" class="btn btn--primary btn--sm" id="btn-submit-profile-rma">Submit Request</button>
            </div>
        </div>
    </div>

    <!-- Page Specific Script -->
    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/profile.js?v=vouchers-12") %>'></script>
</asp:Content>
