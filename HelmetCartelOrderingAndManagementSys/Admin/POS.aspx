<%@ Page Title="POS Counter" Language="C#" MasterPageFile="~/Admin/Portal.master" %>

<asp:Content ID="PosHead" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="/Content/css/admin/pos.css?v=2" />
</asp:Content>

<asp:Content ID="PosMain" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container pos-page" id="posCounter">
        <div class="admin-page-header">
            <div class="admin-page-title-row"><h1 class="admin-page-title">POS Counter</h1></div>
            <div class="admin-header-actions"><a href="/Admin/Orders.aspx" class="btn-pill btn-pill--outline">View Orders</a></div>
        </div>

        <div class="pos-layout">
            <section class="pos-catalog" aria-labelledby="posCatalogTitle">
                <div class="pos-section-head"><h2 id="posCatalogTitle">Products</h2><span id="posResultCount" aria-live="polite"></span></div>
                <div class="pos-catalog-controls">
                    <label class="pos-search-field" for="posSearch">
                        <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="8"></circle><path d="m21 21-4.35-4.35"></path></svg>
                        <input id="posSearch" type="search" placeholder="Search model or SKU" autocomplete="off" />
                    </label>
                    <select id="posBrand" aria-label="Filter products by brand"><option value="">All brands</option></select>
                    <select id="posCategory" aria-label="Filter products by category"><option value="">All categories</option></select>
                </div>
                <div id="posCatalogMessage" class="pos-message" role="status" aria-live="polite" hidden></div>
                <div id="posProductGrid" class="pos-product-grid" aria-live="polite"></div>
            </section>

            <section id="posSalePanel" class="pos-sale-panel" aria-labelledby="posSaleTitle">
                <div class="pos-sale-head">
                    <div><h2 id="posSaleTitle">Current Sale</h2><span id="posItemCount">0 items</span></div>
                    <button type="button" id="posCloseSale" class="pos-icon-button pos-close-sale" aria-label="Close current sale">&times;</button>
                </div>
                <div id="posSaleError" class="pos-inline-alert" role="alert" hidden></div>
                <div id="posCartItems" class="pos-cart-items" aria-live="polite"></div>
                <div class="pos-sale-bottom">
                    <div class="pos-subtotal-row"><span>Subtotal</span><strong id="posSubtotal">&#8369;0.00</strong></div>
                    <div class="pos-total-row"><span>Total</span><strong id="posTotal">&#8369;0.00</strong></div>
                    <details class="pos-customer-details" id="posCustomerDetails">
                        <summary>Customer details <span>Optional</span></summary>
                        <div class="pos-customer-fields">
                            <label>Name<input id="posCustomerName" type="text" maxlength="100" autocomplete="name" placeholder="Walk-in Customer" /></label>
                            <label>Phone<input id="posCustomerPhone" type="tel" maxlength="30" autocomplete="tel" placeholder="Phone number" /></label>
                            <label>Email<input id="posCustomerEmail" type="email" maxlength="256" autocomplete="email" placeholder="Email address" aria-describedby="posCustomerEmailError" /></label>
                            <span id="posCustomerEmailError" class="inline-error-msg" role="alert" hidden></span>
                        </div>
                    </details>
                    <div class="pos-payment-section">
                        <span class="pos-field-label">Payment</span>
                        <div class="pos-payment-options" role="radiogroup" aria-label="Payment method">
                            <label class="pos-payment-option"><input type="radio" name="posPayment" value="Cash" checked /><span>Cash</span></label>
                            <label class="pos-payment-option"><input type="radio" name="posPayment" value="Card_POS" /><span>Card terminal</span></label>
                        </div>
                        <div id="posCashFields" class="pos-cash-fields">
                            <label for="posCashTendered">Cash received</label>
                            <input id="posCashTendered" type="number" min="0" step="0.01" inputmode="decimal" placeholder="0.00" aria-describedby="posCashError" />
                            <span id="posCashError" class="inline-error-msg" role="alert" hidden></span>
                            <div class="pos-change-row"><span>Change</span><strong id="posChange">&#8369;0.00</strong></div>
                        </div>
                        <div id="posCardFields" class="pos-card-fields" hidden>
                            <label class="pos-card-confirm"><input id="posCardApproved" type="checkbox" /><span>Card terminal payment approved</span></label>
                            <span id="posCardError" class="inline-error-msg" role="alert" hidden></span>
                        </div>
                    </div>
                    <button type="button" id="posCompleteSale" class="btn-pill btn-pill--primary pos-complete-button" disabled>Complete Sale</button>
                </div>
            </section>
        </div>
    </div>

    <div id="posMobileBackdrop" class="pos-mobile-backdrop" hidden></div>
    <button type="button" id="posMobileCart" class="pos-mobile-cart" aria-controls="posSalePanel" aria-expanded="false" hidden>
        <span>Current Sale <strong id="posMobileCount">0 items</strong></span><strong id="posMobileTotal">&#8369;0.00</strong>
    </button>

    <div id="posReceiptModal" class="pos-receipt-backdrop" role="dialog" aria-modal="true" aria-labelledby="posReceiptTitle" hidden>
        <div class="pos-receipt">
            <div class="pos-receipt-head"><h2 id="posReceiptTitle">Sale Complete</h2><span id="posReceiptNumber"></span></div>
            <div id="posReceiptItems" class="pos-receipt-items"></div>
            <div class="pos-receipt-total"><span>Total</span><strong id="posReceiptTotal"></strong></div>
            <div id="posReceiptPayment" class="pos-receipt-payment"></div>
            <div class="pos-receipt-actions">
                <button type="button" id="posPrintReceipt" class="btn-pill btn-pill--outline">Print Receipt</button>
                <button type="button" id="posNewSale" class="btn-pill btn-pill--primary">New Sale</button>
            </div>
        </div>
    </div>
    <script src="/Scripts/vendor/jquery-3.7.1.min.js"></script>
    <script src="/Scripts/vendor/jquery.signalR-2.4.3.min.js"></script>
    <script type="module" src="/Scripts/admin/pos.js?v=3"></script>
</asp:Content>
