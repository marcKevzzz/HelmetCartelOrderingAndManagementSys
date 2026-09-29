<%@ Page Title="Catalog" Language="C#" MasterPageFile="~/Admin/Portal.master" AutoEventWireup="true" CodeBehind="Catalog.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.CatalogPage" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Page Heading & Actions -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Product Catalog</h1>
            </div>
            <div class="admin-header-actions">
                <button type="button" class="btn-pill btn-pill--primary" id="btnOpenAddHelmetModal">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="5" x2="12" y2="19"></line>
                        <line x1="5" y1="12" x2="19" y2="12"></line>
                    </svg>
                    <span>Add Helmet Model</span>
                </button>
            </div>
        </div>

        <!-- Filter Sub-bar with Top Metadata -->
        <div class="admin-filters-bar">
            <div class="admin-filters-left">
                <div class="admin-segmented-tabs">
                    <asp:LinkButton ID="btnTabAll" runat="server" CssClass="admin-tab-btn" CommandArgument="all" OnClick="FilterTab_Click">All Products</asp:LinkButton>
                    <asp:LinkButton ID="btnTabActive" runat="server" CssClass="admin-tab-btn" CommandArgument="active" OnClick="FilterTab_Click">Active</asp:LinkButton>
                    <asp:LinkButton ID="btnTabFeatured" runat="server" CssClass="admin-tab-btn" CommandArgument="featured" OnClick="FilterTab_Click">Featured</asp:LinkButton>
                </div>
            </div>

            <!-- Table Top Metadata (Replaces Status Count Tag) -->
            <div class="admin-meta-top">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="admin-meta-top-icon">
                    <polygon points="12 2 2 7 12 12 22 7 12 2"></polygon>
                    <polyline points="2 17 12 22 22 17"></polyline>
                    <polyline points="2 12 12 17 22 12"></polyline>
                </svg>
                <span>Showing <asp:Literal ID="litShowingTop" runat="server">0</asp:Literal> of <asp:Literal ID="litTotalTop" runat="server">0</asp:Literal> models</span>
            </div>
        </div>

        <!-- Independent Scrollable Responsive Catalog Table Component -->
        <div class="admin-table-wrapper">
            <table class="admin-table admin-table-catalog">
                <colgroup>
                    <col class="col-thumb" />
                    <col class="col-model" />
                    <col class="col-brand" />
                    <col class="col-category" />
                    <col class="col-category" />
                    <col class="col-price" />
                    <col class="col-brand" />
                    <col class="col-price" />
                    <col class="col-status" />
                    <col class="col-status" />
                    <col class="col-actions catalog" />
                </colgroup>
                <thead>
                    <tr>
                        <th>Image</th>
                        <th>Helmet Model</th>
                        <th>Brand</th>
                        <th>Category</th>
                        <th>Riding Style</th>
                        <th>Base Price</th>
                        <th>Discount</th>
                        <th>Effective</th>
                        <th>Variants</th>
                        <th>Status</th>
                        <th class="admin-table-align-right">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptCatalog" runat="server">
                        <ItemTemplate>
                            <tr>
                                <td>
                                    <div class="admin-thumb-container">
                                        <img src='<%# ResolveImageUrl(Eval("MainImageUrl")) %>' 
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %>' 
                                             class="admin-thumb-img" 
                                             loading="lazy" 
                                             onerror="this.src='/Content/images/products/helmets/agv/images.jpg';" />
                                    </div>
                                </td>
                                <td>
                                    <div class="admin-product-cell">
                                        <span class="admin-cell-name" title='<%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %>'>
                                             <%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %>
                                        </span>
                                        <span class="admin-cell-sku"><%# Server.HtmlEncode(Convert.ToString(Eval("Slug"))) %></span>
                                    </div>
                                </td>
                                <td>
                                    <span class="admin-cell-brand"><%# Server.HtmlEncode(Convert.ToString(Eval("Brand"))) %></span>
                                </td>
                                <td>
                                    <span class="admin-cell-category"><%# Server.HtmlEncode(Convert.ToString(Eval("Category"))) %></span>
                                </td>
                                <td>
                                    <span class="admin-cell-mono-muted"><%# Server.HtmlEncode(Convert.ToString(Eval("RidingStyle"))) %></span>
                                </td>
                                <td>
                                    <span class="admin-cell-price">&#8369;<%# Convert.ToDecimal(Eval("BasePrice")).ToString("N2") %></span>
                                </td>
                                <td>
                                    <%# (bool)Eval("HasActiveDiscount") || Convert.ToInt32(Eval("DiscountPercentage")) > 0 ? "<span class=\"admin-badge admin-badge--low-stock\">" + Eval("DiscountBadgeText") + "</span>" : "<span class=\"admin-cell-mono-muted\">0%</span>" %>
                                </td>
                                <td>
                                    <span class="admin-cell-price admin-stock-highlight">&#8369;<%# Convert.ToDecimal(Eval("EffectivePrice")).ToString("N2") %></span>
                                </td>
                                <td>
                                    <span class="admin-size-badge" title="Variant SKUs"><%# Eval("VariantCount") %></span>
                                </td>
                                <td>
                                    <%# Convert.ToBoolean(Eval("IsActive")) ? "<span class=\"admin-badge admin-badge--active\">Active</span>" : "<span class=\"admin-badge admin-badge--inactive\">Draft</span>" %>
                                </td>
                                <td class="admin-table-align-right">
                                    <div class="admin-actions-cell admin-actions-cell--right">
                                        <a href='/Admin/Inventory.aspx?q=<%# Server.UrlEncode(Convert.ToString(Eval("Name"))) %>' class="btn-pill-sm btn-pill--outline" title="Add Stock for this model in Inventory">
                                            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" class="bi bi-plus" viewBox="0 0 16 16">
                                                <path d="M8 4a.5.5 0 0 1 .5.5v3h3a.5.5 0 0 1 0 1h-3v3a.5.5 0 0 1-1 0v-3h-3a.5.5 0 0 1 0-1h3v-3A.5.5 0 0 1 8 4"/>
                                            </svg>
                                            <span>Add Stock</span>
                                        </a>
                                        <button type="button" class="btn-pill-sm btn-pill--outline btn-edit-product" 
                                            data-id='<%# Eval("Id") %>'
                                            data-name='<%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %>'
                                            data-brandid='<%# Eval("BrandId") %>'
                                            data-catid='<%# Eval("CategoryId") %>'
                                            data-style='<%# Convert.ToString(Eval("RidingStyle")) %>'
                                            data-price='<%# Eval("BasePrice") %>'
                                            data-distype='<%# Eval("DiscountType") %>'
                                            data-disamt='<%# Eval("DiscountAmount") %>'
                                            data-img='<%# Eval("MainImageUrl") %>'
                                            data-desc='<%# Server.HtmlEncode(Convert.ToString(Eval("Description"))) %>'
                                            title="Edit Helmet Model">
                                            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                                                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
                                            </svg>
                                            <span>Edit</span>
                                        </button>
                                        <button type="button" class="btn-pill-sm btn-pill--outline btn-pill--danger btn-delete-product"
                                            data-id='<%# Eval("Id") %>'
                                            data-name='<%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %>'
                                            data-brand='<%# Server.HtmlEncode(Convert.ToString(Eval("Brand"))) %>'
                                            data-category='<%# Server.HtmlEncode(Convert.ToString(Eval("Category"))) %>'
                                            data-sku='<%# Server.HtmlEncode(Convert.ToString(Eval("Slug"))) %>'
                                            data-img='<%# ResolveImageUrl(Eval("MainImageUrl")) %>'
                                            data-variants='<%# Eval("VariantCount") %>'
                                            title="Delete Helmet Model">
                                            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                                <polyline points="3 6 5 6 21 6"></polyline>
                                                <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                                            </svg>
                                            <span>Delete</span>
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        </ItemTemplate>
                        <FooterTemplate>
                            <%# rptCatalog.Items.Count == 0 ? "<tr><td colspan='11'><div class='admin-empty-state'><div class='admin-empty-title'>No Products Found</div><p>No helmet models match the current filter.</p></div></td></tr>" : "" %>
                        </FooterTemplate>
                    </asp:Repeater>
                </tbody>
            </table>
        </div>

        <!-- Centered Pagination (Requirement 3: 1 2 ... 8 9 or 1 2 3 4) -->
        <asp:Panel ID="pnlCatalogPagination" runat="server" CssClass="admin-pagination-container" Visible="false">
            <div class="admin-pagination">
                <asp:LinkButton ID="lnkCatalogPrev" runat="server" CssClass="admin-pagination-btn" OnClick="CatalogPage_Change" CommandArgument="prev">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6"></polyline></svg>
                    <span>Previous</span>
                </asp:LinkButton>
                <div class="admin-pagination-pages">
                    <asp:Repeater ID="rptCatalogPages" runat="server">
                        <ItemTemplate>
                            <asp:PlaceHolder runat="server" Visible='<%# !(bool)Eval("IsEllipsis") %>'>
                                <asp:LinkButton runat="server" CssClass='<%# "admin-pagination-page " + Eval("CssClass") %>' 
                                    OnClick="CatalogPage_Change" CommandArgument='<%# Eval("Number") %>'>
                                    <%# Eval("Number") %>
                                </asp:LinkButton>
                            </asp:PlaceHolder>
                            <asp:PlaceHolder runat="server" Visible='<%# (bool)Eval("IsEllipsis") %>'>
                                <span class="admin-pagination-ellipsis">&hellip;</span>
                            </asp:PlaceHolder>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
                <asp:LinkButton ID="lnkCatalogNext" runat="server" CssClass="admin-pagination-btn" OnClick="CatalogPage_Change" CommandArgument="next">
                    <span>Next</span>
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
                </asp:LinkButton>
            </div>
        </asp:Panel>
    </div>

    <!-- Concise Delete Confirmation Modal Preview (Requirement 2) -->
    <div id="adminDeleteProductModal" class="admin-modal-backdrop is-hidden" hidden>
        <div class="admin-modal admin-modal--confirm">
            <div class="admin-modal-icon-circle admin-modal-icon-circle--danger">
                <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#EF4444" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="3 6 5 6 21 6"></polyline>
                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                </svg>
            </div>
            <h3 class="admin-modal-title">Delete Helmet Model</h3>
            <p class="admin-modal-desc-subtle">
                Are you sure you want to delete this product? If historical orders exist, it will be safely deactivated and archived.
            </p>

            <!-- Concise Modal Preview -->
            <div class="admin-delete-preview-card">
                <img id="delModalImage" src="/Content/images/products/helmets/agv/images.jpg" alt="Product Preview" class="admin-delete-preview-thumb" />
                <div class="admin-delete-preview-info">
                    <span id="delModalName" class="admin-delete-preview-name">Helmet Model</span>
                    <div class="admin-delete-preview-tags">
                        <span id="delModalBrand" class="admin-badge admin-badge--active">Brand</span>
                        <span id="delModalCategory" class="admin-badge admin-badge--role-staff">Category</span>
                        <span id="delModalSku" class="admin-cell-sku">sku-identifier</span>
                    </div>
                    <div class="admin-delete-preview-summary">
                        <span id="delModalVariantsSummary">0 Variant SKUs configured</span>
                    </div>
                </div>
            </div>

            <asp:HiddenField ID="hfDeleteProductId" runat="server" ClientIDMode="Static" />
            <div class="admin-modal-footer">
                <button type="button" class="btn-pill btn-pill--outline" id="btnCancelDelete">Cancel</button>
                <asp:Button ID="btnConfirmDeleteProduct" runat="server" Text="Confirm Delete" CssClass="btn-pill btn-pill--primary btn-pill--danger" OnClick="btnConfirmDeleteProduct_Click" ClientIDMode="Static" />
            </div>
        </div>
    </div>

    <!-- Add / Edit Helmet Model & Dynamic Variant Matrix Modal (5-Tab Spacious Wizard) -->
    <div id="addProductModal" class="admin-modal-backdrop is-hidden">
        <div class="admin-modal admin-modal--wizard">
            <div class="admin-modal-header">
                <div>
                    <h3 id="modalProductTitle" class="admin-modal-title">Add Helmet Model</h3>
                </div>
                <button type="button" class="admin-modal-close-btn" onclick="closeAddProductModal();" aria-label="Close modal">&times;</button>
            </div>

            <!-- Wizard Step Tab Navigation -->
            <div class="admin-wizard-tabs">
                <button type="button" class="admin-wizard-tab-btn active" data-step="1" onclick="switchWizardTab(1);">
                    <span class="tab-step-num">1</span>
                    <span>Basic Info</span>
                </button>
                <button type="button" class="admin-wizard-tab-btn" data-step="2" onclick="switchWizardTab(2);">
                    <span class="tab-step-num">2</span>
                    <span>Variants &amp; Stock</span>
                </button>
                <button type="button" class="admin-wizard-tab-btn" data-step="3" onclick="switchWizardTab(3);">
                    <span class="tab-step-num">3</span>
                    <span>Pricing &amp; Discount</span>
                </button>
                <button type="button" class="admin-wizard-tab-btn" data-step="4" onclick="switchWizardTab(4);">
                    <span class="tab-step-num">4</span>
                    <span>Images &amp; Upload</span>
                </button>
                <button type="button" class="admin-wizard-tab-btn" data-step="5" onclick="switchWizardTab(5);">
                    <span class="tab-step-num">5</span>
                    <span>Review</span>
                </button>
            </div>

            <asp:HiddenField ID="hdnVariantsJson" runat="server" />
            <input type="hidden" id="hdnEditProductId" runat="server" value="0" />

            <!-- Tab 1: Basic Information -->
            <div class="admin-wizard-pane active" data-pane="1">
                <div class="admin-form-grid-2">
                    <div class="admin-form-group">
                        <label class="admin-form-label">Manufacturer / Brand <span class="admin-required-star">*</span></label>
                        <asp:DropDownList ID="ddlNewBrand" runat="server" CssClass="admin-form-select" onchange="renderVariantMatrix();">
                        </asp:DropDownList>
                    </div>
                    <div class="admin-form-group">
                        <label class="admin-form-label">Category <span class="admin-required-star">*</span></label>
                        <asp:DropDownList ID="ddlNewCategory" runat="server" CssClass="admin-form-select">
                        </asp:DropDownList>
                    </div>
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label">Helmet Model Name <span class="admin-required-star">*</span></label>
                    <input type="text" id="txtNewName" runat="server" class="admin-form-input" placeholder="e.g. Shoei RF-1400 Dedicated" oninput="renderVariantMatrix(); validateWizardStep(1);" required="required" />
                    <span id="errNewName" class="inline-error-msg">Helmet model name is required.</span>
                </div>

                <div class="admin-form-grid-2">
                    <div class="admin-form-group">
                        <label class="admin-form-label">Riding Style</label>
                        <asp:DropDownList ID="ddlNewStyle" runat="server" CssClass="admin-form-select">
                            <asp:ListItem Value="Sport/Street">Sport / Street</asp:ListItem>
                            <asp:ListItem Value="Touring">Touring</asp:ListItem>
                            <asp:ListItem Value="Adventure/Offroad">Adventure / Dual Sport</asp:ListItem>
                            <asp:ListItem Value="Urban/Classic">Urban / Classic</asp:ListItem>
                        </asp:DropDownList>
                    </div>
                    <div class="admin-form-group">
                        <label class="admin-form-label">Certification Standards</label>
                        <input type="text" class="admin-form-input" placeholder="e.g. ECE 22.06, DOT FMVSS 218, Snell M2020D" value="ECE 22.06, DOT Certified" />
                    </div>
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label">Description &amp; Overview</label>
                    <textarea id="txtNewDescription" runat="server" class="admin-form-textarea" rows="3" placeholder="Full face composite helmet with Pinlock EVO, emergency quick release, optimal wind noise isolation..."></textarea>
                </div>

                <div class="admin-wizard-footer">
                    <button type="button" class="btn-pill btn-pill--outline" onclick="closeAddProductModal();">Cancel</button>
                    <button type="button" class="btn-pill btn-pill--primary" onclick="switchWizardTab(2);">Next: Variants &amp; Stock &rarr;</button>
                </div>
            </div>

            <!-- Tab 2: Variants & Stock (Interactive Color Picker & Gradient Support) -->
            <div class="admin-wizard-pane" data-pane="2">
                <div class="admin-form-group">
                    <label class="admin-form-label">Color Palette &amp; Finishes <span class="admin-required-star">*</span></label>
                    <div class="admin-color-manager">
                        <!-- Active Chips Container -->
                        <div id="colorChipsContainer" class="admin-palette-chips">
                            <!-- Populated dynamically by admin.js -->
                        </div>

                        <!-- Color Creator Tool -->
                        <div class="admin-color-creator-card">
                            <div class="admin-color-creator-row">
                                <div class="admin-segmented-tabs">
                                    <button type="button" id="btnColorModeSolid" class="admin-tab-btn active" onclick="setColorMode('solid');">Solid Color</button>
                                    <button type="button" id="btnColorModeGradient" class="admin-tab-btn" onclick="setColorMode('gradient');">Linear Gradient</button>
                                </div>
                                <input type="text" id="txtCustomColorName" class="admin-form-input admin-input-flex-1" placeholder="Color Name (e.g. Matte Black, Red Fade)" />
                            </div>

                            <!-- Solid Color Controls -->
                            <div id="solidColorControls" class="admin-color-creator-row">
                                <input type="color" id="pickerSolidColor" value="#18181B" class="admin-color-picker-input" oninput="syncSolidHex(this.value);" />
                                <input type="text" id="txtSolidHex" class="admin-form-input admin-input-hex" value="#18181B" maxlength="7" oninput="syncSolidPicker(this.value);" />
                                <button type="button" class="btn-pill btn-pill--outline" onclick="addColorToPalette();">+ Add Color</button>
                            </div>

                            <!-- Gradient Controls -->
                            <div id="gradientColorControls" class="admin-color-creator-row is-hidden">
                                <span class="admin-label-inline">Stop 1:</span>
                                <input type="color" id="pickerGrad1" value="#DC2626" class="admin-color-picker-input" oninput="updateGradientPreview();" />
                                <span class="admin-label-inline">Stop 2:</span>
                                <input type="color" id="pickerGrad2" value="#18181B" class="admin-color-picker-input" oninput="updateGradientPreview();" />
                                <span class="admin-label-inline">Angle (&deg;):</span>
                                <input type="number" id="numGradAngle" class="admin-form-input admin-input-angle" value="135" min="0" max="360" step="15" oninput="updateGradientPreview();" />
                                <div id="gradPreviewBox" class="admin-gradient-preview"></div>
                                <button type="button" class="btn-pill btn-pill--outline" onclick="addColorToPalette();">+ Add Gradient</button>
                            </div>
                        </div>
                    </div>
                    <input type="hidden" id="txtNewColors" value="Matte Black:#18181B, Pearl White:#FFFFFF, Racing Red:#DC2626" />
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label">Select Available Sizes</label>
                    <div class="admin-palette-chips">
                        <label class="admin-palette-chip">
                            <input type="checkbox" class="chk-new-size" value="S" onchange="renderVariantMatrix();" />
                            <span>S</span>
                        </label>
                        <label class="admin-palette-chip">
                            <input type="checkbox" class="chk-new-size" value="M" checked="checked" onchange="renderVariantMatrix();" />
                            <span>M</span>
                        </label>
                        <label class="admin-palette-chip">
                            <input type="checkbox" class="chk-new-size" value="L" checked="checked" onchange="renderVariantMatrix();" />
                            <span>L</span>
                        </label>
                        <label class="admin-palette-chip">
                            <input type="checkbox" class="chk-new-size" value="XL" checked="checked" onchange="renderVariantMatrix();" />
                            <span>XL</span>
                        </label>
                        <label class="admin-palette-chip">
                            <input type="checkbox" class="chk-new-size" value="2XL" onchange="renderVariantMatrix();" />
                            <span>2XL</span>
                        </label>
                    </div>
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label">Generated Variant Matrix &amp; Initial Stock (Auto-generated SKU)</label>
                    <div class="admin-matrix-table-wrap">
                        <table class="admin-matrix-table">
                            <thead>
                                <tr>
                                    <th>Color</th>
                                    <th>Size</th>
                                    <th>SKU</th>
                                    <th>Price Adj (&#8369;)</th>
                                    <th>Initial Stock</th>
                                    <th>Reorder Point</th>
                                </tr>
                            </thead>
                            <tbody id="matrixTableBody">
                                <!-- Populated dynamically by admin.js renderVariantMatrix() -->
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="admin-wizard-footer">
                    <button type="button" class="btn-pill btn-pill--outline" onclick="switchWizardTab(1);">&larr; Back: Basic Info</button>
                    <button type="button" class="btn-pill btn-pill--primary" onclick="switchWizardTab(3);">Next: Pricing &amp; Discount &rarr;</button>
                </div>
            </div>

            <!-- Tab 3: Pricing & Discount -->
            <div class="admin-wizard-pane" data-pane="3">
                <div class="admin-form-grid-2">
                    <div class="admin-form-group">
                        <label class="admin-form-label">Base Retail Price (&#8369;) <span class="admin-required-star">*</span></label>
                        <input type="number" id="txtNewBasePrice" runat="server" class="admin-form-input" placeholder="34000.00" step="50" min="100" value="34000.00" oninput="updatePricingPreview(); validateWizardStep(3);" required="required" />
                        <span id="errNewPrice" class="inline-error-msg">Valid positive retail price is required.</span>
                    </div>
                    <div class="admin-form-group">
                        <label class="admin-form-label">Discount Scheme</label>
                        <asp:DropDownList ID="ddlNewDiscountType" runat="server" CssClass="admin-form-select" onchange="updatePricingPreview();">
                            <asp:ListItem Value="Percentage">Percentage Discount (%)</asp:ListItem>
                            <asp:ListItem Value="FixedAmount">Fixed Amount Discount (&#8369;)</asp:ListItem>
                        </asp:DropDownList>
                    </div>
                </div>

                <div class="admin-form-grid-2">
                    <div class="admin-form-group">
                        <label class="admin-form-label">Discount Value</label>
                        <input type="number" id="txtNewDiscountValue" runat="server" class="admin-form-input" min="0" max="90000" value="0" step="1" oninput="updatePricingPreview();" />
                        <span class="admin-form-hint">
                            Enter % (e.g. 15 for 15% off) or fixed amount in Pesos (e.g. 2000 for &#8369;2,000 off).
                        </span>
                    </div>
                    <div class="admin-form-group">
                        <label class="admin-form-label">Discount Status</label>
                        <div class="admin-checkbox-card">
                            <input type="checkbox" id="chkNewDiscountActive" runat="server" checked="checked" />
                            <label for="MainContent_chkNewDiscountActive" class="admin-checkbox-label">Enable Discount Campaign</label>
                        </div>
                    </div>
                </div>

                <div class="admin-form-grid-2">
                    <div class="admin-form-group">
                        <label class="admin-form-label">Schedule Start Date (Optional)</label>
                        <input type="date" id="txtNewDiscountStartDate" runat="server" class="admin-form-input" />
                    </div>
                    <div class="admin-form-group">
                        <label class="admin-form-label">Schedule End Date (Optional)</label>
                        <input type="date" id="txtNewDiscountEndDate" runat="server" class="admin-form-input" />
                    </div>
                </div>

                <!-- Live Price Calculation Preview Box -->
                <div class="admin-effective-preview-box">
                    <div class="admin-effective-preview-label">Effective Customer Price Preview</div>
                    <div id="pricingEffectivePreview" class="admin-effective-preview-val">
                        Effective Price: <strong>&#8369;34,000.00</strong> (No discount applied)
                    </div>
                </div>

                <div class="admin-wizard-footer">
                    <button type="button" class="btn-pill btn-pill--outline" onclick="switchWizardTab(2);">&larr; Back: Variants</button>
                    <button type="button" class="btn-pill btn-pill--primary" onclick="switchWizardTab(4);">Next: Images &rarr;</button>
                </div>
            </div>

            <!-- Tab 4: Images & Media (Multi-image upload with brand folder organization) -->
            <div class="admin-wizard-pane" data-pane="4">
                <div class="admin-form-group">
                    <label class="admin-form-label">Upload Product Images (Organized by Brand)</label>
                    <div class="admin-dropzone" onclick="document.getElementById('MainContent_fileUploadImages').click();" id="imageDropzone">
                        <svg class="admin-dropzone-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
                            <circle cx="8.5" cy="8.5" r="1.5"></circle>
                            <polyline points="21 15 16 10 5 21"></polyline>
                        </svg>
                        <span class="admin-wizard-section-title">Click to upload product images or drag &amp; drop</span>
                        <span class="admin-cell-mono-muted">Supports JPG, PNG, WEBP up to 5MB each. First image becomes primary display.</span>
                    </div>
                    <asp:FileUpload ID="fileUploadImages" runat="server" AllowMultiple="true" accept=".jpg,.jpeg,.png,.webp" CssClass="admin-hidden-file-input" onchange="handleMultipleImageSelection(this);" />
                </div>

                <!-- Preview Tiles Grid (allow removing & reordering) -->
                <div class="admin-form-group">
                    <label class="admin-form-label">Selected Images Preview &amp; Order</label>
                    <div id="imageUploadGrid" class="admin-upload-grid">
                        <!-- Populated by JS when files are chosen -->
                    </div>
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label">Storefront Main Image URL (Fallback or Direct Path)</label>
                    <input type="text" id="txtNewImageUrl" runat="server" class="admin-form-input" value="/Content/images/products/helmets/agv/images.jpg" oninput="updateImagePreview();" />
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label">Additional Gallery URLs (Optional, comma-separated)</label>
                    <textarea id="txtNewGalleryUrls" runat="server" class="admin-form-textarea" rows="2" placeholder="/Content/images/products/helmets/shoei/rf1400-angle.jpg, /Content/images/products/helmets/shoei/rf1400-back.jpg"></textarea>
                </div>

                <div class="admin-wizard-footer">
                    <button type="button" class="btn-pill btn-pill--outline" onclick="switchWizardTab(3);">&larr; Back: Pricing</button>
                    <button type="button" class="btn-pill btn-pill--primary" onclick="switchWizardTab(5);">Next: Review &amp; Confirm &rarr;</button>
                </div>
            </div>

            <!-- Tab 5: Review & Confirm -->
            <div class="admin-wizard-pane" data-pane="5">
                <div class="admin-review-card">
                    <div class="admin-review-header">
                        <img id="reviewSummaryThumb" src="/Content/images/products/helmets/agv/images.jpg" alt="Helmet Preview" class="admin-review-thumb" />
                        <div class="admin-review-header-info">
                            <div class="admin-review-tags">
                                <span class="admin-badge admin-badge--active" id="reviewSummaryBrand">Shoei</span>
                                <span class="admin-badge admin-badge--role-staff" id="reviewSummaryCategory">Full Face</span>
                                <span class="admin-cell-mono-muted" id="reviewSummaryStyle">Sport/Street</span>
                            </div>
                            <h4 class="admin-review-title" id="reviewSummaryName">Shoei RF-1400 Dedicated</h4>
                            <div class="admin-review-pricing-row">
                                <span class="admin-review-base-price">Base: <span id="reviewSummaryBasePrice">&#8369;34,000.00</span></span>
                                <span class="admin-review-discount-tag" id="reviewSummaryDiscount">No Discount</span>
                                <span class="admin-review-effective-price">Effective: <strong class="admin-stock-highlight" id="reviewSummaryEffective">&#8369;34,000.00</strong></span>
                            </div>
                        </div>
                    </div>

                    <div class="admin-review-body">
                        <div class="admin-review-stat-grid">
                            <div class="admin-review-stat-item">
                                <span class="admin-review-stat-label">Configured Variants</span>
                                <span class="admin-review-stat-value" id="reviewSummaryVariantsCount">0 SKUs</span>
                            </div>
                            <div class="admin-review-stat-item">
                                <span class="admin-review-stat-label">Total Warehouse Units</span>
                                <span class="admin-review-stat-value admin-stock-highlight" id="reviewSummaryStockTotal">0 Units</span>
                            </div>
                            <div class="admin-review-stat-item">
                                <span class="admin-review-stat-label">Product Images</span>
                                <span class="admin-review-stat-value" id="reviewSummaryImagesCount">1 Image</span>
                            </div>
                        </div>

                        <div class="admin-review-variants-preview">
                            <div class="admin-review-variants-title">Variant SKU &amp; Stock Breakdown</div>
                            <div id="reviewVariantsBreakdown" class="admin-review-variants-chips">
                                <!-- Populated dynamically by renderReviewSummary() in admin.js -->
                            </div>
                        </div>
                    </div>
                </div>

                <div class="admin-wizard-footer">
                    <button type="button" class="btn-pill btn-pill--outline" onclick="switchWizardTab(4);">&larr; Back: Images</button>
                    <asp:Button ID="btnSubmitNewProduct" runat="server" CssClass="btn-pill btn-pill--primary" 
                        Text="Save Helmet Model" 
                        OnClientClick="return prepareVariantMatrixSubmission();" 
                        OnClick="btnSubmitNewProduct_Click" />
                </div>
            </div>
        </div>
    </div>
    <script src="/Scripts/admin/catalog.js?v=2"></script>
</asp:Content>
