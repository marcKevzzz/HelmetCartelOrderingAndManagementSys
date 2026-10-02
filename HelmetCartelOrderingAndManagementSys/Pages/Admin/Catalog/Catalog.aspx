<%@ Page Title="Catalog" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" CodeBehind="Catalog.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.CatalogPage" Async="true" %>

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
                <a href="/Admin/CatalogItem.aspx" class="btn-pill btn-pill--primary">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="5" x2="12" y2="19"></line>
                        <line x1="5" y1="12" x2="19" y2="12"></line>
                    </svg>
                    <span>Add Helmet Model</span>
                </a>
            </div>
        </div>

        <!-- Filter Sub-bar with Top Metadata -->
        <div class="admin-filters-bar">
            <div class="admin-filters-left">
                <div class="admin-segmented-tabs">
                    <asp:LinkButton ID="btnTabAll" runat="server" CssClass="admin-tab-btn" CommandArgument="all" OnClick="FilterTab_Click">All Products</asp:LinkButton>
                    <asp:LinkButton ID="btnTabActive" runat="server" CssClass="admin-tab-btn" CommandArgument="active" OnClick="FilterTab_Click">Active</asp:LinkButton>
                    <asp:LinkButton ID="btnTabDrafts" runat="server" CssClass="admin-tab-btn" CommandArgument="drafts" OnClick="FilterTab_Click">Drafts</asp:LinkButton>
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
                    <col class="col-model catalog" />
                    <col class="col-brand" />
                    <col class="col-category-style" />
                    <col class="col-pricing" />
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
                        <th>Pricing</th>
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
                                    <span class="admin-cell-category" title='<%# Server.HtmlEncode(Convert.ToString(Eval("Category"))) %>'><%# Server.HtmlEncode(Convert.ToString(Eval("Category"))) %></span>
                                </td>
                                <td>
                                    <div class="admin-catalog-pricing-card">
                                        <span class="admin-catalog-effective-price">&#8369;<%# Convert.ToDecimal(Eval("EffectivePrice")).ToString("N2") %></span>
                                        <div class="admin-catalog-price-meta">
                                            <span class='<%# (bool)Eval("HasActiveDiscount") || Convert.ToInt32(Eval("DiscountPercentage")) > 0 ? "admin-catalog-original-price" : "admin-catalog-original-price is-regular" %>'>&#8369;<%# Convert.ToDecimal(Eval("BasePrice")).ToString("N2") %></span>
                                            <%# (bool)Eval("HasActiveDiscount") || Convert.ToInt32(Eval("DiscountPercentage")) > 0 ? "<span class=\"admin-catalog-discount\">" + Eval("DiscountBadgeText") + "</span>" : "<span class=\"admin-catalog-no-discount\">&mdash;</span>" %>
                                        </div>
                                    </div>
                                </td>
                                <td>
                                    <span class="admin-size-badge" title="Variant SKUs"><%# Eval("VariantCount") %></span>
                                </td>
                                <td>
                                    <%# Convert.ToBoolean(Eval("IsActive")) ? "<span class=\"admin-badge admin-badge--active\">Active</span>" : "<span class=\"admin-badge admin-badge--inactive\">Draft</span>" %>
                                </td>
                                <td class="admin-table-align-right">
                                    <div class="admin-actions-cell admin-actions-cell--right">
                                        <%# Convert.ToBoolean(Eval("IsActive")) ? @"<button type=""button"" class=""btn-pill-sm btn-pill--outline btn-preview-product""
                                            data-preview-url='/Pages/Storefront/ProductDetail/ProductDetail.aspx?slug=" + Eval("Slug") + @"'
                                            data-name='" + System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(Eval("Name"))) + @"'
                                            title=""Preview Product Detail"">
                                            <svg viewBox=""0 0 24 24"" width=""14"" height=""14"" fill=""none"" stroke=""currentColor"" stroke-width=""2"" stroke-linecap=""round"" stroke-linejoin=""round"" aria-hidden=""true"">
                                                <path d=""M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z""></path>
                                                <circle cx=""12"" cy=""12"" r=""3""></circle>
                                            </svg>
                                            <span>Preview</span>
                                        </button>" : "" %>
                                        <a href='/Admin/CatalogItem.aspx?id=<%# Eval("Id") %>' class="btn-pill-sm btn-pill--outline" title="Edit Helmet Model">
                                            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                                                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
                                            </svg>
                                            <span>Edit</span>
                                        </a>
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
                            <%# rptCatalog.Items.Count == 0 ? "<tr><td colspan='8'><div class='admin-empty-state'><div class='admin-empty-title'>No Products Found</div><p>No helmet models match the current filter.</p></div></td></tr>" : "" %>
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

    <div id="adminProductPreviewModal" class="admin-modal-backdrop is-hidden" hidden>
        <div class="admin-modal admin-modal--product-preview">
            <div class="admin-modal-header">
                <div>
                    <h3 id="productPreviewTitle" class="admin-modal-title">Product Detail Preview</h3>
                    <p class="admin-modal-desc-subtle">Scaled storefront preview</p>
                </div>
                <button type="button" class="admin-modal-close-btn js-close-product-preview" aria-label="Close product preview">&times;</button>
            </div>
            <div class="admin-product-preview-frame-shell">
                <iframe id="productPreviewFrame" class="admin-product-preview-frame" title="Product detail preview"></iframe>
            </div>
        </div>
    </div>

    <!-- Enhanced Delete Confirmation Modal matching Design System -->
    <div id="adminDeleteProductModal" class="admin-quick-modal-backdrop is-hidden" hidden role="dialog" aria-modal="true" aria-labelledby="delModalHeading">
        <div class="admin-quick-modal">
            <header class="admin-quick-modal-header">
                <h3 class="admin-quick-modal-title" id="delModalHeading">Delete Helmet Model</h3>
                <button type="button" class="admin-modal-close-btn" id="btnCloseDeleteModal" aria-label="Close delete modal">&times;</button>
            </header>
            <div class="admin-quick-modal-body">
                <p class="admin-modal-description" style="margin:0;font-size:var(--text-body-sm);color:var(--color-text-secondary);line-height:1.5;">
                    Are you sure you want to delete this product? If historical orders exist, it will be safely deactivated and archived.
                </p>

                <!-- Concise Modal Preview -->
                <div class="admin-delete-preview-card">
                    <img id="delModalImage" src="/Content/images/placeholder-helmet.png" alt="Product Preview" class="admin-delete-preview-thumb" />
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
            </div>

            <asp:HiddenField ID="hfDeleteProductId" runat="server" ClientIDMode="Static" />
            <footer class="admin-quick-modal-footer">
                <button type="button" class="btn-pill btn-pill--outline" id="btnCancelDelete">Cancel</button>
                <asp:Button ID="btnConfirmDeleteProduct" runat="server" Text="Confirm Delete" CssClass="btn-pill btn-pill--primary btn-pill--danger" OnClick="btnConfirmDeleteProduct_Click" ClientIDMode="Static" />
            </footer>
        </div>
    </div>


    <script src="/Scripts/admin/catalog.js?v=4"></script>
</asp:Content>
