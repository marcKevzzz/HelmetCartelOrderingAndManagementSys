<%@ Page Title="Your Shopping Cart" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Cart.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.Cart" ResponseEncoding="utf-8" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="container cart-page-container">
        <!-- Breadcrumb -->
        <nav class="shop-breadcrumb" aria-label="Breadcrumb">
            <a href="<%= ResolveUrl("~/Default.aspx") %>" class="shop-breadcrumb__link">Home</a>
            <svg class="shop-breadcrumb__icon" viewBox="0 0 24 24" fill="none" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
            <span class="shop-breadcrumb__current">Cart</span>
        </nav>

        <h1 class="cart-page-title">YOUR CART</h1>

        <div class="cart-layout">
            <!-- Left: Cart Items -->
            <div class="cart-items-box" id="cart-items-container">
                <p id="empty-cart-msg" class="cart-empty-message">
                    Your cart is currently empty. <a href="<%= ResolveUrl("~/Pages/Shop.aspx") %>" class="cart-empty-link">Browse helmets</a>
                </p>
            </div>

            <!-- Right: Order Summary Card -->
            <div class="order-summary-card">
                <h2 class="order-summary-title">Order Summary</h2>

                <div class="order-summary__row">
                    <span class="order-summary__label">Subtotal</span>
                    <strong id="summary-subtotal">&#8369;0</strong>
                </div>

                <div class="order-summary__row">
                    <span class="order-summary__label">Fulfillment</span>
                    <strong>FREE (In-Store Pickup)</strong>
                </div>

                <div class="order-summary__row order-summary__total">
                    <span>Total</span>
                    <span id="summary-total">&#8369;0</span>
                </div>

                <button type="button" id="btn-checkout" class="btn btn--primary btn--block">
                    <span>Go to Checkout</span>
                    <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="7" y1="17" x2="17" y2="7"></line>
                        <polyline points="7 7 17 7 17 17"></polyline>
                    </svg>
                </button>
            </div>
        </div>
    </div>

    <!-- Client-Side Cart Script -->
    <script type="module">
        import { CartManager } from '<%= ResolveUrl("~/Scripts/cart.js") %>';
        import { RealtimeManager } from '<%= ResolveUrl("~/Scripts/realtime.js") %>';

        const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
        })[char]);
        const emptyCartMarkup = document.getElementById('empty-cart-msg')?.outerHTML || '';

        function renderCartView() {
            CartManager.updateCartBadge();
            const container = document.getElementById('cart-items-container');
            const emptyMsg = document.getElementById('empty-cart-msg');
            const items = CartManager.getItems();

            if (items.length === 0) {
                container.innerHTML = emptyCartMarkup;
            } else {
                if (emptyMsg) emptyMsg.classList.add('tab-pane--hidden');
                const selectedItems = CartManager.getSelectedItems();
                const allSelected = selectedItems.length === items.length && items.length > 0;
                
                let html = `
                <div class="cart-select-all-bar">
                    <div class="cart-select-all-left btn-select-all" title="Toggle select all items">
                        <button type="button" class="cart-drawer-item__check ${allSelected ? 'is-checked' : ''}" aria-label="Select all items">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                                <polyline points="20 6 9 17 4 12"></polyline>
                            </svg>
                        </button>
                        <span class="cart-select-all-text">Select All (${items.length} items)</span>
                    </div>
                    <button type="button" class="btn-clear-selected ${selectedItems.length > 0 ? '' : 'is-disabled'}" title="Remove selected items">
                        Remove Selected
                    </button>
                </div>
                `;

                html += items.map(item => {
                    const isChecked = item.isSelected !== false;
                    return `
                    <div class="cart-item ${isChecked ? '' : 'cart-item--unselected'}" data-variant-id="${escapeHtml(item.variantId)}">
                        <button type="button" class="cart-drawer-item__check ${isChecked ? 'is-checked' : ''} btn-toggle-check" data-variant-id="${escapeHtml(item.variantId)}" title="${isChecked ? 'Deselect item' : 'Select for checkout'}" aria-label="Toggle selection">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                                <polyline points="20 6 9 17 4 12"></polyline>
                            </svg>
                        </button>
                        <a href="ProductDetail.aspx?id=${Number(item.productId)}" class="cart-item__thumb" title="View details for ${escapeHtml(item.name)}">
                            <img src="${escapeHtml(item.imageUrl)}" alt="${escapeHtml(item.name)}" class="cart-item__img" />
                        </a>
                        <div class="cart-item__details">
                            <h3 class="cart-item__title"><a href="ProductDetail.aspx?id=${Number(item.productId)}">${escapeHtml(item.name)}</a></h3>
                            <p class="cart-item__variant-text">Size: <strong>${escapeHtml(item.size)}</strong></p>
                            <p class="cart-item__variant-text">Color: <strong>${escapeHtml(item.color)}</strong></p>
                            <div class="cart-item__price">&#8369;${Number(item.price).toLocaleString()}</div>
                            ${Number(item.availableStock) < Number(item.quantity) ? '<p class="cart-item__stock-note">Insufficient stock. Update or remove this item before checkout.</p>' : ''}
                        </div>
                        <div class="cart-item__actions">
                            <button type="button" class="btn-remove-item" data-variant-id="${escapeHtml(item.variantId)}" title="Remove Item" aria-label="Remove ${escapeHtml(item.name)}">
                                <svg viewBox="0 0 24 24">
                                    <polyline points="3 6 5 6 21 6"></polyline>
                                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                                </svg>
                            </button>
                            <div class="quantity-stepper">
                                <button type="button" class="stepper-btn btn-qty-minus" data-variant-id="${escapeHtml(item.variantId)}" aria-label="Decrease quantity of ${escapeHtml(item.name)}">-</button>
                                <span class="stepper-value">${item.quantity}</span>
                                <button type="button" class="stepper-btn btn-qty-plus" data-variant-id="${escapeHtml(item.variantId)}" aria-label="Increase quantity of ${escapeHtml(item.name)}">+</button>
                            </div>
                        </div>
                    </div>
                    `;
                }).join('');

                container.innerHTML = html;
            }

            const selectedItems = CartManager.getSelectedItems();
            const subtotal = CartManager.getSelectedSubtotal();
            const total = CartManager.getTotal();

            document.getElementById('summary-subtotal').innerHTML = `&#8369;${subtotal.toLocaleString()}`;
            document.getElementById('summary-total').innerHTML = `&#8369;${total.toLocaleString()}`;

            const checkoutBtn = document.getElementById('btn-checkout');
            if (checkoutBtn) {
                const btnSpan = checkoutBtn.querySelector('span');
                if (btnSpan) {
                    btnSpan.textContent = selectedItems.length > 0 
                        ? `Go to Checkout (${selectedItems.length})` 
                        : 'Select items to checkout';
                }
                checkoutBtn.classList.toggle('btn--disabled', selectedItems.length === 0);
            }
        }

        document.addEventListener('click', (e) => {
            if (e.target.closest('.btn-select-all')) {
                const allSelected = CartManager.getSelectedItems().length === CartManager.getItems().length;
                CartManager.selectAll(!allSelected);
                renderCartView();
                return;
            }
            if (e.target.closest('.btn-clear-selected')) {
                const selected = CartManager.getSelectedItems();
                if (selected.length > 0) {
                    selected.forEach(item => CartManager.removeItem(item.variantId));
                    renderCartView();
                    RealtimeManager.showToast(`Removed ${selected.length} items from cart.`, 'delete');
                }
                return;
            }
            const toggleCheckBtn = e.target.closest('.btn-toggle-check');
            if (toggleCheckBtn) {
                const id = toggleCheckBtn.dataset.variantId;
                CartManager.toggleItemSelection(id);
                renderCartView();
                return;
            }
            if (e.target.closest('.btn-remove-item')) {
                const id = e.target.closest('.btn-remove-item').dataset.variantId;
                const item = CartManager.getItems().find(i => String(i.variantId) === String(id));
                const name = item ? item.name : 'Item';
                CartManager.removeItem(id);
                renderCartView();
                RealtimeManager.showToast(`${name} removed from your cart.`, 'delete');
                return;
            }
            if (e.target.closest('.btn-qty-minus')) {
                const id = e.target.closest('.btn-qty-minus').dataset.variantId;
                const item = CartManager.getItems().find(i => String(i.variantId) === String(id));
                if (item) {
                    CartManager.updateQuantity(id, item.quantity - 1);
                    renderCartView();
                }
                return;
            }
            if (e.target.closest('.btn-qty-plus')) {
                const id = e.target.closest('.btn-qty-plus').dataset.variantId;
                const item = CartManager.getItems().find(i => String(i.variantId) === String(id));
                if (item) {
                    CartManager.updateQuantity(id, item.quantity + 1);
                    renderCartView();
                }
                return;
            }
            // Allow clicking item container like a label
            const cartItem = e.target.closest('.cart-item');
            if (cartItem && !e.target.closest('.cart-item__actions, a, .btn-remove-item, .quantity-stepper')) {
                const id = cartItem.dataset.variantId;
                if (id) {
                    CartManager.toggleItemSelection(id);
                    renderCartView();
                    return;
                }
            }
            if (e.target.closest('#btn-checkout')) {
                const selected = CartManager.getSelectedItems();
                if (selected.length === 0) {
                    RealtimeManager.showToast('Please select at least 1 item to checkout.', 'alert');
                    return;
                }
                if (selected.some(item => !Number.isSafeInteger(Number(item.variantId)))) {
                    RealtimeManager.showToast('An older cart item needs to be added again from its product page.', 'alert');
                    return;
                }
                if (selected.some(item => Number(item.availableStock) < Number(item.quantity))) {
                    RealtimeManager.showToast('One or more selected items have insufficient stock.', 'alert');
                    return;
                }
                window.location.href = '<%= ResolveUrl("~/Pages/Checkout.aspx") %>';
                return;
            }
        });

        document.addEventListener('DOMContentLoaded', () => {
            renderCartView();
            CartManager.refreshItems().then(renderCartView).catch(() => {});
        });
    </script>
</asp:Content>
