<%@ Page Title="Inventory" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" CodeBehind="Inventory.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.InventoryPage" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Page Heading & Actions -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Inventory Operations</h1>
            </div>
            <div class="admin-header-actions">
                <!-- View Mode Switcher: Active Inventory vs Stock In History -->
                <div class="admin-segmented-tabs">
                    <asp:LinkButton ID="btnViewActiveStock" runat="server" CssClass="admin-tab-btn active" CommandArgument="stock" OnClick="btnViewMode_Click">Active Stock</asp:LinkButton>
                    <asp:LinkButton ID="btnViewAuditHistory" runat="server" CssClass="admin-tab-btn" CommandArgument="audit" OnClick="btnViewMode_Click">Stock In History</asp:LinkButton>
                </div>
            </div>
        </div>

        <!-- 1. ACTIVE INVENTORY PANEL -->
        <asp:Panel cssclass="inventory-panel" ID="pnlActiveStock" runat="server">

            <!-- Filter Sub-bar: Status Tabs + Category Filter + Available Counter (Active Stock Only) -->
            <div class="admin-filters-bar inventory">
                <div class="admin-filters-left">
                    <div class="admin-segmented-tabs">
                        <asp:LinkButton ID="btnTabAll" runat="server" CssClass="admin-tab-btn" CommandArgument="all" OnClick="FilterTab_Click">All</asp:LinkButton>
                        <asp:LinkButton ID="btnTabActive" runat="server" CssClass="admin-tab-btn active" CommandArgument="active" OnClick="FilterTab_Click">Active</asp:LinkButton>
                        <asp:LinkButton ID="btnTabInactive" runat="server" CssClass="admin-tab-btn" CommandArgument="inactive" OnClick="FilterTab_Click">Inactive</asp:LinkButton>
                        <asp:LinkButton ID="btnTabInStock" runat="server" CssClass="admin-tab-btn" CommandArgument="in_stock" OnClick="FilterTab_Click">In Stock</asp:LinkButton>
                        <asp:LinkButton ID="btnTabLowStock" runat="server" CssClass="admin-tab-btn" CommandArgument="low_stock" OnClick="FilterTab_Click">Low Stock</asp:LinkButton>
                        <asp:LinkButton ID="btnTabOutOfStock" runat="server" CssClass="admin-tab-btn" CommandArgument="out_of_stock" OnClick="FilterTab_Click">Out of Stock</asp:LinkButton>
                    </div>

                    <asp:DropDownList ID="ddlBrandFilter" runat="server" AutoPostBack="true" OnSelectedIndexChanged="FilterDropdown_Changed" CssClass="admin-filter-select" aria-label="Filter by brand">
                    </asp:DropDownList>
                    <!-- Helmet Type / Category Dropdown -->
                    <asp:DropDownList ID="ddlCategoryFilter" runat="server" AutoPostBack="true" OnSelectedIndexChanged="FilterDropdown_Changed" CssClass="admin-filter-select" aria-label="Filter by helmet category">
                    </asp:DropDownList>
                    <asp:HyperLink ID="lnkClearFilter" runat="server" NavigateUrl="/Pages/Admin/Inventory/Inventory.aspx" CssClass="btn-pill-sm btn-pill--outline" Visible="false">
                        <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                        <span>Clear Filter</span>
                    </asp:HyperLink>
                </div>

                <!-- Meta Range Info (Moved to Top) -->
                <div class="admin-meta-top">
                     <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="admin-meta-top-icon">
                        <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
                        <polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>
                        <line x1="12" y1="22.08" x2="12" y2="12"></line>
                    </svg>
                    Showing <asp:Literal ID="litShowingRange" runat="server">1-50</asp:Literal> of <asp:Literal ID="litTotalCount" runat="server">0</asp:Literal> variants (<asp:Literal ID="litAvailableCount" runat="server">0</asp:Literal> total units)
                </div>
            </div>

            <!-- Modern Data Table (Brand & Model combined, Desktop fit with zero horizontal scroll) -->
            <div class="admin-table-wrapper">
                <table class="admin-table">
                    <colgroup>
                        <col class="col-thumb" />
                        <col class="col-model" />
                        <col class="col-category" />
                        <col class="col-color" />
                        <col class="col-size" />
                        <col class="col-stock" />
                        <col class="col-price" />
                        <col class="col-sku" />
                        <col class="col-status" />
                        <col class="col-actions" />
                    </colgroup>
                    <thead>
                        <tr>
                            <th>Image</th>
                            <th>Brand &amp; Helmet Model</th>
                            <th>Category</th>
                            <th>Color</th>
                            <th>Size</th>
                            <th>Stock</th>
                            <th>Price</th>
                            <th>SKU</th>
                            <th>Stock Status</th>
                            <th class="admin-table-align-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <asp:Repeater ID="rptInventory" runat="server">
                            <ItemTemplate>
                                <tr class='<%# Convert.ToBoolean(Eval("IsActive")) ? "" : "is-row-inactive" %>'>
                                    <td>
                                        <div class="admin-thumb-container">
                                            <img src='<%# HelmetCartelOrderingAndManagementSys.Infrastructure.CatalogImageHelper.GetUrl(ResolveImageUrl(Eval("MainImageUrl"))) %>' 
                                                 alt='<%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %>' 
                                                 class="admin-thumb-img" 
                                                 loading="lazy" 
                                                 onerror="this.onerror=null;this.src='/Content/images/placeholder-helmet.png';" />
                                        </div>
                                    </td>
                                    <td class="admin-cell-main">
                                        <div class="admin-product-cell">
                                            <span class="admin-cell-brand"><%# Server.HtmlEncode(Convert.ToString(Eval("BrandName"))) %></span>
                                            <span class="admin-cell-name" title='<%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %>'>
                                                <%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %>
                                            </span>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="admin-cell-category" title='<%# Server.HtmlEncode(Convert.ToString(Eval("CategoryName"))) %>'><%# Server.HtmlEncode(Convert.ToString(Eval("CategoryName"))) %></span>
                                    </td>
                                    <td>
                                        <div class="admin-variant-cell color" title='<%# Server.HtmlEncode(Convert.ToString(Eval("Color"))) %>'>
                                            <%# RenderColorSwatch(Eval("ColorHex")) %>
                                            <span><%# Server.HtmlEncode(Convert.ToString(Eval("Color"))) %></span>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="admin-size-badge"><%# Server.HtmlEncode(Convert.ToString(Eval("Size"))) %></span>
                                    </td>
                                    <td>
                                        <span class='admin-cell-stock <%# Convert.ToInt32(Eval("AvailableStock")) <= 0 ? "admin-cell-stock--critical" : (Convert.ToInt32(Eval("AvailableStock")) <= Convert.ToInt32(Eval("ReorderPoint")) ? "admin-cell-stock--low-stock" : "") %>'><%# FormatStockNumber(Eval("AvailableStock")) %></span>
                                    </td>
                                    <td>
                                        <span class="admin-cell-price">&#8369;<%# Convert.ToDecimal(Eval("EffectivePrice")).ToString("N2") %></span>
                                    </td>
                                    <td>
                                        <span class="admin-cell-sku" title='<%# Server.HtmlEncode(Convert.ToString(Eval("SKU"))) %>'><%# Server.HtmlEncode(Convert.ToString(Eval("SKU"))) %></span>
                                    </td>
                                    <td>
                                        <%# RenderStatusBadge(Convert.ToString(Eval("StockStatus")), Convert.ToInt32(Eval("AvailableStock"))) %>
                                    </td>
                                    <td class="admin-table-align-right">
                                        <div class="admin-actions-cell admin-actions-cell--right">
                                             <button type="button" 
                                                class='<%# "admin-variant-status-btn js-toggle-inventory-active " + (Convert.ToBoolean(Eval("IsActive")) ? "is-active" : "is-inactive") %>'
                                                data-variant-id='<%# Eval("VariantId") %>'
                                                data-active='<%# Convert.ToBoolean(Eval("IsActive")) ? "true" : "false" %>'
                                                title='<%# Convert.ToBoolean(Eval("IsActive")) ? "Click to deactivate variant" : "Click to activate variant" %>'>
                                            <span class="status-text"><%# Convert.ToBoolean(Eval("IsActive")) ? "Active" : "Inactive" %></span>
                                        </button>
                                            <button type="button" class="btn-pill-sm btn-pill--outline js-open-stock-modal"
                                                data-variant-id='<%# Eval("VariantId") %>'
                                                data-title='<%# System.Web.HttpUtility.HtmlAttributeEncode(string.Format("{0} - {1} ({2})", Eval("ProductName"), Eval("Color"), Eval("Size"))) %>'
                                                data-current-stock='<%# Eval("AvailableStock") %>'
                                                title="Add stock units">
                                                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" class="bi bi-plus" viewBox="0 0 16 16">
                                                    <path d="M8 4a.5.5 0 0 1 .5.5v3h3a.5.5 0 0 1 0 1h-3v3a.5.5 0 0 1-1 0v-3h-3a.5.5 0 0 1 0-1h3v-3A.5.5 0 0 1 8 4"/>
                                                </svg>
                                                <span>Add Stock</span>
                                            </button>
                                            
                                        </div>
                                    </td>
                                </tr>
                            </ItemTemplate>
                            <FooterTemplate>
                                <%# rptInventory.Items.Count == 0 ? "<tr><td colspan='10'><div class='admin-empty-state'><div class='admin-empty-title'>No Variants Found</div><p>No inventory variants match the current search or filters.</p></div></td></tr>" : "" %>
                            </FooterTemplate>
                        </asp:Repeater>
                    </tbody>
                </table>
            </div>

            <!-- Footer Pagination (Rendered ONLY in Active Stock View) -->
            <asp:Panel ID="pnlInventoryPagination" runat="server" CssClass="admin-table-footer admin-table-footer--center" Visible="false">
                <div class="admin-pagination">
                    <asp:LinkButton ID="btnPrevPage" runat="server" CssClass="admin-pagination-btn" OnClick="btnPrevPage_Click">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="19" y1="12" x2="5" y2="12"></line><polyline points="12 19 5 12 12 5"></polyline></svg>
                        <span>Previous</span>
                    </asp:LinkButton>
                    <div class="admin-pagination-pages">
                        <asp:Repeater ID="rptPaginationPages" runat="server" OnItemCommand="rptPaginationPages_ItemCommand">
                            <ItemTemplate>
                                <asp:PlaceHolder runat="server" Visible='<%# !(bool)Eval("IsEllipsis") %>'>
                                    <asp:LinkButton ID="btnPage" runat="server" 
                                        CommandName="GoToPage" 
                                        CommandArgument='<%# Eval("PageNumber") %>' 
                                        CssClass='<%# "admin-pagination-page" + ((bool)Eval("IsActive") ? " active" : "") %>'>
                                        <%# Eval("PageNumber") %>
                                    </asp:LinkButton>
                                </asp:PlaceHolder>
                                <asp:PlaceHolder runat="server" Visible='<%# (bool)Eval("IsEllipsis") %>'>
                                    <span class="admin-pagination-ellipsis">&hellip;</span>
                                </asp:PlaceHolder>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                    <asp:LinkButton ID="btnNextPage" runat="server" CssClass="admin-pagination-btn" OnClick="btnNextPage_Click">
                        <span>Next</span>
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
                    </asp:LinkButton>
                </div>
            </asp:Panel>
            
        </asp:Panel>

        <!-- 2. STOCK AUDIT & ADDITIONS HISTORY PANEL -->
        <asp:Panel ID="pnlAuditHistory" cssclass="inventory-panel" runat="server" Visible="false">
            <div class="admin-filters-bar">
                <div class="admin-filters-left">
                    <div class="admin-segmented-tabs">
                        <asp:LinkButton ID="btnAuditTypeAll" runat="server" CssClass="admin-tab-btn" CommandArgument="all" OnClick="AuditTypeTab_Click">All Activities</asp:LinkButton>
                        <asp:LinkButton ID="btnAuditTypeRestock" runat="server" CssClass="admin-tab-btn" CommandArgument="restock" OnClick="AuditTypeTab_Click">Restocks</asp:LinkButton>
                        <asp:LinkButton ID="btnAuditTypeAdjustment" runat="server" CssClass="admin-tab-btn" CommandArgument="adjustment" OnClick="AuditTypeTab_Click">Adjustments</asp:LinkButton>
                    </div>

                    <asp:DropDownList ID="ddlAuditBrandFilter" runat="server" AutoPostBack="true" OnSelectedIndexChanged="AuditFilterDropdown_Changed" CssClass="admin-filter-select" aria-label="Filter stock history by brand">
                    </asp:DropDownList>
                </div>
                <div class="admin-meta-top">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="admin-meta-top-icon">
                        <circle cx="12" cy="12" r="10"></circle>
                        <polyline points="12 6 12 12 16 14"></polyline>
                    </svg>
                    Showing <asp:Literal ID="litAuditCount" runat="server">0</asp:Literal> history records (<asp:Literal ID="litAuditUnitsAdded" runat="server">0</asp:Literal> units added)
                </div>
            </div>

            <div class="admin-table-wrapper">
                <table class="admin-table">
                    <colgroup>
                        <col class="inventory-table-column-1" />
                        <col class="inventory-table-column-2" />
                        <col class="inventory-table-column-3" />
                        <col class="inventory-table-column-4" />
                        <col class="inventory-table-column-5" />
                        <col class="inventory-table-column-6" />
                        <col class="inventory-table-column-7" />
                    </colgroup>
                    <thead>
                        <tr>
                            <th>Date &amp; Time</th>
                            <th>Brand &amp; Helmet Model</th>
                            <th>Variant (Color / Size)</th>
                            <th>Quantity Added</th>
                            <th>Stock Transition</th>
                            <th>Staff Member</th>
                            <th>Reference / Notes</th>
                        </tr>
                    </thead>
                    <tbody>
                        <asp:Repeater ID="rptAuditHistory" runat="server">
                            <ItemTemplate>
                                <tr>
                                    <td>
                                        <span class="admin-cell-sku admin-cell-bold">
                                            <%# Convert.ToDateTime(Eval("CreatedAt")).ToString("MMM dd, yyyy HH:mm") %>
                                        </span>
                                    </td>
                                    <td class="admin-cell-main">
                                        <div class="admin-product-cell">
                                            <span class="admin-cell-brand"><%# Server.HtmlEncode(Convert.ToString(Eval("BrandName"))) %></span>
                                            <span class="admin-cell-name" title='<%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %>'>
                                                <%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %>
                                            </span>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="admin-cell-category"><%# Server.HtmlEncode(Convert.ToString(Eval("Color"))) %> (<%# Server.HtmlEncode(Convert.ToString(Eval("Size"))) %>)</span>
                                    </td>
                                    <td>
                                        <span class="admin-badge admin-badge--in-stock"><%# FormatQuantityAdded(Eval("QuantityChanged")) %></span>
                                    </td>
                                    <td>
                                        <span class="admin-cell-mono-muted">
                                            <%# FormatStockNumber(Eval("PreviousStock")) %> &rarr; <strong class="admin-stock-highlight"><%# FormatStockNumber(Eval("NewStock")) %></strong>
                                        </span>
                                    </td>
                                    <td>
                                        <span class="admin-size-badge"><%# Server.HtmlEncode(Convert.ToString(Eval("PerformedBy"))) %></span>
                                    </td>
                                    <td>
                                        <span class="admin-cell-sku" title='<%# Server.HtmlEncode(Convert.ToString(Eval("ReferenceNumber") ?? Eval("Notes") ?? "—")) %>'>
                                            <%# Server.HtmlEncode(Convert.ToString(Eval("ReferenceNumber") ?? Eval("Notes") ?? "—")) %>
                                        </span>
                                    </td>
                                </tr>
                            </ItemTemplate>
                            <FooterTemplate>
                                <%# rptAuditHistory.Items.Count == 0 ? "<tr><td colspan='7'><div class='admin-empty-state'><div class='admin-empty-title'>No Stock In Logs</div><p>No inventory addition logs recorded yet.</p></div></td></tr>" : "" %>
                            </FooterTemplate>
                        </asp:Repeater>
                    </tbody>
                </table>
            </div>

            <asp:Panel ID="pnlAuditPagination" runat="server" CssClass="admin-pagination-container" Visible="false">
                <div class="admin-pagination">
                    <asp:LinkButton ID="btnAuditPrevPage" runat="server" CssClass="admin-pagination-btn" CommandArgument="prev" OnClick="AuditPage_Change">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="19" y1="12" x2="5" y2="12"></line><polyline points="12 5 5 12 12 19"></polyline></svg>
                        <span>Previous</span>
                    </asp:LinkButton>
                    <div class="admin-pagination-pages">
                        <asp:Repeater ID="rptAuditPaginationPages" runat="server">
                            <ItemTemplate>
                                <asp:LinkButton ID="btnAuditPage" runat="server" CommandName="GoToPage" CommandArgument='<%# Eval("PageNumber") %>'
                                    CssClass='<%# "admin-pagination-page" + ((bool)Eval("IsActive") ? " active" : "") %>'
                                    Visible='<%# !(bool)Eval("IsEllipsis") %>' OnClick="AuditPage_Change"><%# Eval("PageNumber") %></asp:LinkButton>
                                <asp:Literal ID="litAuditPageEllipsis" runat="server" Text="&hellip;" Visible='<%# (bool)Eval("IsEllipsis") %>' />
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                    <asp:LinkButton ID="btnAuditNextPage" runat="server" CssClass="admin-pagination-btn" CommandArgument="next" OnClick="AuditPage_Change">
                        <span>Next</span>
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
                    </asp:LinkButton>
                </div>
            </asp:Panel>
        </asp:Panel>
    </div>

    <!-- Quick Stock In Modal (Addition ONLY, with live preview before confirmation) -->
    <div id="stockAdjustModal" class="admin-modal-backdrop is-hidden" hidden>
        <div class="admin-modal admin-modal--form">
            <div class="admin-modal-header">
                <div>
                    <h3 class="admin-modal-title">Add Stock</h3>
                    <div id="adjustModalHelmetTitle" class="admin-modal-desc-subtle">Helmet Variant</div>
                </div>
                <button type="button" class="admin-modal-close-btn js-close-stock-modal" aria-label="Close modal">&times;</button>
            </div>

            <asp:HiddenField ID="hdnAdjustVariantId" runat="server" />

            <div class="admin-form-grid-2">
                <div class="admin-kpi-card">
                    <div class="admin-kpi-label">Current Stock</div>
                    <div id="adjustModalCurrentStock" class="admin-kpi-value">0</div>
                </div>
                <div class="admin-kpi-card">
                    <div class="admin-kpi-label">Updated Stock Preview</div>
                    <div id="adjustModalUpdatedStock" class="admin-kpi-value admin-stock-highlight">0</div>
                </div>
            </div>

            <div class="admin-form-grid-2">
                <div class="admin-form-group">
                    <label class="admin-form-label">Units to Add (+)</label>
                    <input type="number" id="txtAdjustQuantity" runat="server" min="1" max="10000" class="admin-form-input" value="5" />
                </div>
                <div class="admin-form-group">
                    <label class="admin-form-label">Stock In Reason</label>
                    <asp:DropDownList ID="ddlAdjustReason" runat="server" CssClass="admin-form-select">
                        <asp:ListItem Value="Supplier Shipment">Supplier Restock</asp:ListItem>
                        <asp:ListItem Value="Inventory Recount">Physical Recount (+)</asp:ListItem>
                        <asp:ListItem Value="Customer Return">Customer Return (+)</asp:ListItem>
                        <asp:ListItem Value="Warehouse Transfer">Warehouse Transfer In</asp:ListItem>
                    </asp:DropDownList>
                </div>
            </div>

            <div class="admin-form-group">
                <label class="admin-form-label">Reference / PO #</label>
                <input type="text" id="txtAdjustReference" runat="server" placeholder="e.g. PO-2026-089 or Restock Batch" class="admin-form-input" />
            </div>

            <div class="admin-modal-footer">
                <button type="button" class="btn-pill btn-pill--outline js-close-stock-modal">Cancel</button>
                <asp:Button ID="btnSubmitStockAdjust" runat="server" CssClass="btn-pill btn-pill--primary" Text="Add Stock" OnClick="btnSubmitStockAdjust_Click" OnClientClick="return handleStockAdjustSubmit(this);" />
            </div>
        </div>
    </div>

    <script src='<%= ResolveUrl("~/Scripts/admin/inventory.js?v=1") %>'></script>
</asp:Content>
