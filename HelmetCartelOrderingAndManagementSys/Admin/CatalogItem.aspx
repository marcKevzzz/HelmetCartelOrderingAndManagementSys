<%@ Page Title="Manage Helmet Model" Language="C#" MasterPageFile="~/Admin/Portal.master" AutoEventWireup="true" CodeBehind="CatalogItem.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.CatalogItemPage" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container admin-wizard-page">
        <!-- Sticky / Top Action Header -->
        <header class="admin-item-sticky-header">
            <div class="admin-item-header-left">
                <div class="admin-item-title-wrap">
                    <button type="button" class="admin-back-btn" id="btnBackToCatalog" title="Back to Catalog" aria-label="Back to Catalog">
                        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <line x1="19" y1="12" x2="5" y2="12"></line>
                            <polyline points="12 19 5 12 12 5"></polyline>
                        </svg>
                    </button>
                    <div class="admin-page-title-col">
                        <h1 class="admin-page-title" id="txtHeaderTitle" runat="server">New Helmet Model</h1>
                        <span class="admin-item-status-pill <%= IsDraft ? "is-draft" : "is-published" %>" id="badgePublishStatus">
                            <%= !IsDraft ? "PUBLISHED" : (ProductId > 0 ? "DRAFT (Saved)" : "DRAFT (Not Saved)") %>
                        </span>
                    </div>
                </div>
            </div>

            <div class="admin-item-header-actions">
                <button type="button" class="btn-pill btn-pill--outline" id="btnDiscard">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="3 6 5 6 21 6"></polyline>
                        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                    </svg>
                    <span>Discard Changes</span>
                </button>
                <asp:LinkButton ID="btnSaveDraft" runat="server" CssClass="btn-pill btn-pill--secondary" OnClick="btnSaveDraft_Click" ClientIDMode="Static">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"></path>
                        <polyline points="17 21 17 13 7 13 7 21"></polyline>
                        <polyline points="7 3 7 8 15 8"></polyline>
                    </svg>
                    <span>Save as Draft</span>
                </asp:LinkButton>
                <asp:LinkButton ID="btnPublish" runat="server" CssClass="btn-pill btn-pill--primary" OnClick="btnPublish_Click" ClientIDMode="Static">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="20 6 9 17 4 12"></polyline>
                    </svg>
                    <span>Publish Helmet</span>
                </asp:LinkButton>
            </div>
        </header>

        <!-- Hidden State Fields (Static IDs for JS Access) -->
        <asp:HiddenField ID="hdnProductId" runat="server" Value="0" ClientIDMode="Static" />
        <asp:HiddenField ID="hdnIsActive" runat="server" Value="1" ClientIDMode="Static" />
        <asp:HiddenField ID="hdnDiscountType" runat="server" Value="Percentage" ClientIDMode="Static" />
        <asp:HiddenField ID="hdnDiscountIsActive" runat="server" Value="True" ClientIDMode="Static" />
        <asp:HiddenField ID="hdnColorType" runat="server" Value="Solid" ClientIDMode="Static" />
        <asp:HiddenField ID="hdnColorsJson" runat="server" Value="[]" ClientIDMode="Static" />
        <asp:HiddenField ID="hdnVariantsJson" runat="server" Value="[]" ClientIDMode="Static" />
        <asp:HiddenField ID="hdnSpecificationsJson" runat="server" Value="[]" ClientIDMode="Static" />
        <asp:HiddenField ID="hdnGalleryJson" runat="server" Value="[]" ClientIDMode="Static" />
        <asp:HiddenField ID="hdnRedirectAfterSave" runat="server" Value="" ClientIDMode="Static" />

        <!-- Wizard Step Tab Navigation (6 Sequential Steps) -->
        <div class="admin-wizard-tabs" id="catalogWizardTabs" role="tablist">
            <button type="button" class="admin-wizard-tab-btn active" data-step="1" role="tab" onclick="switchWizardTab(1);">
                <span class="tab-step-num">1</span>
                <span>Basic Info</span>
            </button>
            <button type="button" class="admin-wizard-tab-btn" data-step="2" role="tab" onclick="switchWizardTab(2);">
                <span class="tab-step-num">2</span>
                <span>Specifications</span>
            </button>
            <button type="button" class="admin-wizard-tab-btn" data-step="3" role="tab" onclick="switchWizardTab(3);">
                <span class="tab-step-num">3</span>
                <span>Variants &amp; Stock</span>
            </button>
            <button type="button" class="admin-wizard-tab-btn" data-step="4" role="tab" onclick="switchWizardTab(4);">
                <span class="tab-step-num">4</span>
                <span>Pricing &amp; Discount</span>
            </button>
            <button type="button" class="admin-wizard-tab-btn" data-step="5" role="tab" onclick="switchWizardTab(5);">
                <span class="tab-step-num">5</span>
                <span>Images &amp; Upload</span>
            </button>
            <button type="button" class="admin-wizard-tab-btn" data-step="6" role="tab" onclick="switchWizardTab(6);">
                <span class="tab-step-num">6</span>
                <span>Review</span>
            </button>
        </div>

        <!-- ====================================================================
             TAB 1: Basic Information
             ==================================================================== -->
        <div class="admin-wizard-pane active" data-pane="1">
            <div class="admin-form-grid-2">
                <div class="admin-form-group">
                    <label class="admin-form-label" for="ddlBrand">Manufacturer / Brand <span class="admin-required-star">*</span></label>
                    <div class="admin-select-with-add">
                        <asp:DropDownList ID="ddlBrand" runat="server" CssClass="admin-form-select" ClientIDMode="Static">
                        </asp:DropDownList>
                        <button type="button" class="btn-quick-add" id="btnOpenAddBrandModal" title="Add new brand">
                            + New Brand
                        </button>
                    </div>
                    <span class="inline-error-msg" id="errBrand">Please select a brand.</span>
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="ddlCategory">Category <span class="admin-required-star">*</span></label>
                    <div class="admin-select-with-add">
                        <asp:DropDownList ID="ddlCategory" runat="server" CssClass="admin-form-select" ClientIDMode="Static">
                        </asp:DropDownList>
                        <button type="button" class="btn-quick-add" id="btnOpenAddCategoryModal" title="Add new category">
                            + New Category
                        </button>
                    </div>
                    <span class="inline-error-msg" id="errCategory">Please select a category.</span>
                </div>
            </div>

            <div class="admin-form-grid-2">
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtProductName">Helmet Model Name <span class="admin-required-star">*</span></label>
                    <asp:TextBox ID="txtProductName" runat="server" CssClass="admin-form-input" placeholder="e.g. Shoei RF-1400 Dedicated" ClientIDMode="Static"></asp:TextBox>
                    <span class="inline-error-msg" id="errProductName">Product name is required.</span>
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtSlug">URL Slug Preview</label>
                    <div class="admin-slug-preview-wrap">
                        <span class="admin-slug-prefix">/shop/helmets/</span>
                        <asp:TextBox ID="txtSlug" runat="server" CssClass="admin-form-input admin-slug-input" placeholder="shoei-rf-1400-dedicated" ClientIDMode="Static"></asp:TextBox>
                    </div>
                </div>
            </div>

            <div class="admin-form-group">
                <label class="admin-form-label" for="txtDescription">Full Product Description <span class="admin-required-star">*</span></label>
                <asp:TextBox ID="txtDescription" runat="server" TextMode="MultiLine" Rows="3" CssClass="admin-form-textarea" placeholder="Full face composite helmet with Pinlock EVO, emergency quick release, optimal wind noise isolation..." ClientIDMode="Static"></asp:TextBox>
                <span class="inline-error-msg" id="errDescription">Product description is required.</span>
            </div>

            <div class="admin-form-row-checkbox">
                <label class="admin-checkbox-label">
                    <asp:CheckBox ID="chkIsFeatured" runat="server" ClientIDMode="Static" />
                    <span>Feature this helmet on storefront home banners and highlights</span>
                </label>
            </div>

            <div class="admin-wizard-footer">
                <div></div>
                <button type="button" class="btn-pill btn-pill--primary" onclick="switchWizardTab(2);">Next: Specifications &rarr;</button>
            </div>
        </div>

        <!-- ====================================================================
             TAB 2: Technical Specifications
             ==================================================================== -->
        <div class="admin-wizard-pane" data-pane="2">
            <div class="admin-form-grid-2">
                <div class="admin-form-group">
                    <label class="admin-form-label" for="spec_shell_material">Shell Material <span class="admin-required-star">*</span></label>
                    <input type="text" id="spec_shell_material" class="admin-form-input spec-field" data-spec-key="shell_material" data-display-name="Shell Material" placeholder="e.g. Advanced Polycarbonate Composite" />
                    <span class="inline-error-msg" id="errSpecShellMaterial">Shell material is required (e.g. Polycarbonate, Carbon Fiber).</span>
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="spec_safety_certifications">Safety Certifications <span class="admin-required-star">*</span></label>
                    <input type="text" id="spec_safety_certifications" class="admin-form-input spec-field" data-spec-key="safety_certifications" data-display-name="Safety Certifications" placeholder="e.g. ECE 22.06, DOT FMVSS 218" />
                    <span class="inline-error-msg" id="errSpecSafetyCertifications">Safety certification is required (e.g. ECE 22.06, DOT).</span>
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="spec_weight">Helmet Weight <span class="admin-required-star">*</span></label>
                    <input type="text" id="spec_weight" class="admin-form-input spec-field" data-spec-key="weight" data-display-name="Weight" placeholder="e.g. 1,450g ± 50g" />
                    <span class="inline-error-msg" id="errSpecWeight">Helmet weight is required (e.g. 1,450g ± 50g).</span>
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="spec_retention_system">Retention / Chinstrap System</label>
                    <input type="text" id="spec_retention_system" class="admin-form-input spec-field" data-spec-key="retention_system" data-display-name="Retention System" placeholder="e.g. Double D-Ring or Micrometric Steel Buckle" />
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="spec_visor">Visor / Face Shield</label>
                    <input type="text" id="spec_visor" class="admin-form-input spec-field" data-spec-key="visor" data-display-name="Visor System" placeholder="e.g. Class 1 Optics Anti-Scratch Quick-Release" />
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="spec_pinlock">Pinlock &amp; Anti-Fog</label>
                    <input type="text" id="spec_pinlock" class="admin-form-input spec-field" data-spec-key="pinlock" data-display-name="Pinlock / Anti-Fog" placeholder="e.g. Pinlock 120 MaxVision Included" />
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="spec_ventilation">Ventilation System</label>
                    <input type="text" id="spec_ventilation" class="admin-form-input spec-field" data-spec-key="ventilation" data-display-name="Ventilation" placeholder="e.g. 3 Crown Intakes, Chin Vent, 2 Exhaust Extractors" />
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="spec_interior_liner">Interior Liner</label>
                    <input type="text" id="spec_interior_liner" class="admin-form-input spec-field" data-spec-key="interior_liner" data-display-name="Interior Liner" placeholder="e.g. Moisture-Wicking, Removable & Washable" />
                </div>

                <div class="admin-form-group">
                    <label class="admin-form-label" for="spec_intercom_compatibility">Intercom Compatibility</label>
                    <input type="text" id="spec_intercom_compatibility" class="admin-form-input spec-field" data-spec-key="intercom_compatibility" data-display-name="Intercom Ready" placeholder="e.g. Cardo / Sena Speaker Cutouts" />
                </div>
            </div>

            <!-- Custom Specifications Section -->
            <div class="admin-form-section">
                <div class="admin-form-subheading-row">
                    <span class="admin-form-label">Additional Custom Specifications</span>
                    <button type="button" class="btn-pill btn-pill--outline btn-pill--xs" id="btnAddCustomSpec">
                        + Add Custom Specification
                    </button>
                </div>

                <div class="admin-custom-specs-list" id="customSpecsContainer">
                    <!-- Dynamically populated rows -->
                </div>
                <span class="inline-error-msg" id="errCustomSpecs">Please provide both a label and a value for all added custom specifications.</span>
            </div>

            <div class="admin-wizard-footer">
                <button type="button" class="btn-pill btn-pill--outline" onclick="switchWizardTab(1);">&larr; Back: Basic Info</button>
                <button type="button" class="btn-pill btn-pill--primary" onclick="switchWizardTab(3);">Next: Variants &amp; Stock &rarr;</button>
            </div>
        </div>

        <!-- ====================================================================
             TAB 3: Variants & Stock
             ==================================================================== -->
        <div class="admin-wizard-pane" data-pane="3">
            <div class="admin-form-group">
                <label class="admin-form-label">Color Palette &amp; Finishes <span class="admin-required-star">*</span></label>
                <div class="admin-color-manager">
                    <!-- Active Chips Container -->
                    <div id="paletteChipsContainer" class="admin-palette-chips">
                        <span class="admin-empty-chips-msg" id="msgEmptyPalette">No colors added yet. Create at least one color below.</span>
                    </div>

                    <!-- Color Creator Column (Aligns errColors directly beneath card) -->
                    <div class="admin-color-creator-column">
                        <div class="admin-color-creator-card">
                            <div class="admin-color-creator-row">
                                <span class="admin-label-inline">Finish Type:</span>
                                <!-- Segmented Pill Toggle matching Screenshot 2 -->
                                <div class="admin-segmented-pill" id="pillColorTypeToggle" role="radiogroup" aria-label="Color Finish Type">
                                    <button type="button" class="admin-pill-segment is-active" data-val="Solid" role="radio" aria-checked="true">SOLID</button>
                                    <button type="button" class="admin-pill-segment" data-val="LinearGradient" role="radio" aria-checked="false">GRADIENT</button>
                                </div>
                            </div>

                            <!-- Solid Finish Controls -->
                            <div class="admin-color-creator-row" id="rowSolidControls">
                                <input type="color" id="pickerSolidColor" class="admin-color-picker-input" value="#111827" />
                                <input type="text" id="txtSolidHex" class="admin-form-input admin-input-hex" value="#111827" maxlength="7" placeholder="#HEX" />
                                <input type="text" id="txtColorName" class="admin-form-input admin-input-flex-1" placeholder="Color Name (e.g. Matte Black)" />
                                <button type="button" class="btn-pill btn-pill--outline" id="btnAddColorToPalette">
                                    + Add Color
                                </button>
                            </div>

                            <!-- Gradient Finish Controls -->
                            <div class="admin-color-creator-row is-hidden" id="rowGradientControls">
                                <div class="admin-label-inline-row">
                                    <input type="color" id="pickerGradStop1" class="admin-color-picker-input" value="#DC2626" title="Stop 1" />
                                    <span class="admin-label-inline">to</span>
                                    <input type="color" id="pickerGradStop2" class="admin-color-picker-input" value="#111827" title="Stop 2" />
                                    <div class="admin-gradient-preview" id="gradPreviewSwatch"></div>
                                </div>
                                <div class="admin-label-inline-row">
                                    <span class="admin-label-inline">Angle (&deg;):</span>
                                    <input type="number" id="txtGradAngle" class="admin-form-input admin-input-angle" value="135" min="0" max="360" step="15" />
                                </div>
                                <input type="text" id="txtGradColorName" class="admin-form-input admin-input-flex-1" placeholder="Color Name (e.g. Crimson Fade)" />
                                <button type="button" class="btn-pill btn-pill--outline" id="btnAddGradientToPalette">
                                    + Add Gradient
                                </button>
                            </div>
                        </div>

                        <span class="inline-error-msg" id="errColors">At least one colorway must be added to the palette.</span>
                    </div>
                </div>
            </div>

            <!-- Available Sizes Selector (Black Pill When Active, Muted When Inactive) -->
            <div class="admin-form-group">
                <label class="admin-form-label">Select Available Sizes <span class="admin-required-star">*</span></label>
                <div class="admin-size-pills-row" id="sizesSelector">
                    <button type="button" class="admin-size-pill" data-size="XS" aria-pressed="false">XS</button>
                    <button type="button" class="admin-size-pill" data-size="S" aria-pressed="false">S</button>
                    <button type="button" class="admin-size-pill" data-size="M" aria-pressed="false">M</button>
                    <button type="button" class="admin-size-pill" data-size="L" aria-pressed="false">L</button>
                    <button type="button" class="admin-size-pill" data-size="XL" aria-pressed="false">XL</button>
                    <button type="button" class="admin-size-pill" data-size="2XL" aria-pressed="false">2XL</button>
                    <button type="button" class="admin-size-pill" data-size="3XL" aria-pressed="false">3XL</button>
                </div>
                <span class="inline-error-msg" id="errSizes">At least one helmet size must be selected.</span>
            </div>

            <!-- Generated Variant Matrix Table -->
            <div class="admin-form-group">
                <label class="admin-form-label">Generated Variant Matrix &amp; Initial Stock (Auto-generated SKU)</label>
                <div class="admin-matrix-table-wrap">
                    <table class="admin-matrix-table" id="tableVariantMatrix">
                        <thead>
                            <tr>
                                <th>Colorway</th>
                                <th>Size</th>
                                <th>SKU <span class="admin-required-star">*</span></th>
                                <th>Price Adj. (&#8369;)</th>
                                <th>Initial Stock</th>
                                <th>Reorder Point</th>
                                <th class="admin-table-align-right">Action</th>
                            </tr>
                        </thead>
                        <tbody id="tbodyVariantMatrix">
                            <tr id="rowEmptyMatrix">
                                <td colspan="7" class="admin-empty-cell-msg">
                                    Add at least one color above to automatically generate size variant combinations.
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                <span class="inline-error-msg" id="errVariants">At least one size variant combination with a valid SKU is required.</span>
            </div>

            <div class="admin-wizard-footer">
                <button type="button" class="btn-pill btn-pill--outline" onclick="switchWizardTab(2);">&larr; Back: Specifications</button>
                <button type="button" class="btn-pill btn-pill--primary" onclick="switchWizardTab(4);">Next: Pricing &amp; Discount &rarr;</button>
            </div>
        </div>

        <!-- ====================================================================
             TAB 4: Pricing & Discount
             ==================================================================== -->
        <div class="admin-wizard-pane" data-pane="4">
            <div class="admin-form-grid-2">
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtBasePrice">Base Retail Price (&#8369;) <span class="admin-required-star">*</span></label>
                    <asp:TextBox ID="txtBasePrice" runat="server" CssClass="admin-form-input" placeholder="34000.00" ClientIDMode="Static"></asp:TextBox>
                    <span class="inline-error-msg" id="errBasePrice">Valid positive retail price is required.</span>
                </div>

                <!-- Joined Discount Input Group matching Screenshot 1 -->
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtDiscountValue">Promotional Discount</label>
                    <div class="admin-input-joined">
                        <asp:TextBox ID="txtDiscountValue" runat="server" CssClass="admin-form-input" placeholder="0" ClientIDMode="Static"></asp:TextBox>
                        <asp:DropDownList ID="ddlDiscountUnit" runat="server" CssClass="admin-form-select" ClientIDMode="Static">
                            <asp:ListItem Text="%" Value="Percentage" Selected="True"></asp:ListItem>
                            <asp:ListItem Text="&#8369;" Value="FixedAmount"></asp:ListItem>
                        </asp:DropDownList>
                    </div>
                </div>
            </div>

            <div class="admin-form-grid-2">
                <!-- Segmented Pill Toggle matching Screenshot 2 -->
                <div class="admin-form-group">
                    <label class="admin-form-label">Discount Campaign Status</label>
                    <div class="admin-segmented-pill" id="pillDiscountStatusToggle" role="radiogroup" aria-label="Discount Status">
                        <button type="button" class="admin-pill-segment true is-active" data-val="Active" role="radio" aria-checked="true">ACTIVE</button>
                        <button type="button" class="admin-pill-segment" data-val="Inactive" role="radio" aria-checked="false">INACTIVE</button>
                    </div>
                </div>

            </div>

            <div class="admin-form-grid-2">
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtDiscountStartDate">Schedule Start Date (Optional)</label>
                    <asp:TextBox ID="txtDiscountStartDate" runat="server" TextMode="Date" CssClass="admin-form-input" ClientIDMode="Static"></asp:TextBox>
                </div>
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtDiscountEndDate">Schedule End Date (Optional)</label>
                    <asp:TextBox ID="txtDiscountEndDate" runat="server" TextMode="Date" CssClass="admin-form-input" ClientIDMode="Static"></asp:TextBox>
                </div>
            </div>

            <!-- Live Price Calculation Preview Box (Matching Previous Design) -->
            <div class="admin-effective-preview-box">
                <div class="admin-effective-preview-label">Effective Customer Price Preview</div>
                <div id="pricingEffectivePreview" class="admin-effective-preview-val">
                    Effective Price: <strong id="lblPreviewEffectivePrice">&#8369;0.00</strong>
                    <span id="lblPreviewDiscount" class="admin-effective-discount-tag">(No discount applied)</span>
                </div>
            </div>

            <div class="admin-wizard-footer">
                <button type="button" class="btn-pill btn-pill--outline" onclick="switchWizardTab(3);">&larr; Back: Variants &amp; Stock</button>
                <button type="button" class="btn-pill btn-pill--primary" onclick="switchWizardTab(5);">Next: Images &amp; Upload &rarr;</button>
            </div>
        </div>

        <!-- ====================================================================
             TAB 5: Images & Upload
             ==================================================================== -->
        <div class="admin-wizard-pane" data-pane="5">
            <div class="admin-form-group">
                <div class="admin-section-header-compact">
                    <div>
                        <label class="admin-form-label">Product Visual Media &amp; Gallery <span class="admin-required-star">*</span></label>
                        <span class="admin-form-hint">Drag images to reorder. The first image automatically serves as the primary storefront display.</span>
                    </div>
                    <button type="button" class="btn-pill btn-pill--outline btn-pill--xs" id="btnToggleUrlInput">
                        + Add Image from URL
                    </button>
                </div>

                <!-- Hidden file input triggered by dropzone or browse -->
                <input type="file" id="fileImagePicker" class="is-hidden" multiple accept="image/jpeg,image/png,image/webp" />

                <!-- Clean Dropzone -->
                <div class="admin-dropzone" id="imageDropzone" role="button" tabindex="0" aria-label="Upload product images">
                    <svg class="admin-dropzone-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
                        <circle cx="8.5" cy="8.5" r="1.5"></circle>
                        <polyline points="21 15 16 10 5 21"></polyline>
                    </svg>
                    <span class="admin-wizard-section-title">Drop product images here, or browse files</span>
                </div>

                <!-- Optional URL Input Row (toggled by + Add Image from URL button) -->
                <div class="admin-url-input-row is-hidden" id="rowAddByUrl">
                    <input type="url" id="txtAddImageUrl" class="admin-form-input admin-input-flex-1" placeholder="Paste image web URL (e.g. /Content/images/products/shoei.jpg or https://...)" />
                    <button type="button" class="btn-pill btn-pill--primary btn-pill--sm" id="btnConfirmAddUrl">Add URL</button>
                    <button type="button" class="btn-pill btn-pill--outline btn-pill--sm" id="btnCancelAddUrl">Cancel</button>
                </div>

                <span class="inline-error-msg" id="errGalleryImages">At least one product image is required.</span>
            </div>

            <!-- Hidden ASP.NET TextBox to preserve backend binding of Primary Main Image URL -->
            <asp:TextBox ID="txtMainImageUrl" runat="server" CssClass="is-hidden" ClientIDMode="Static"></asp:TextBox>

            <!-- Gallery Tiles Grid with Between-Tile Drop Indicator -->
            <div class="admin-form-group">
                <div class="admin-upload-grid" id="galleryTilesGrid" aria-label="Product Gallery Images">
                    <div class="admin-upload-drop-indicator" id="galleryDropIndicator"></div>
                    <span class="admin-palette-empty" id="galleryEmptyNotice">No product images added yet. Drop or select images above.</span>
                </div>
            </div>

            <div class="admin-wizard-footer">
                <button type="button" class="btn-pill btn-pill--outline" onclick="switchWizardTab(4);">&larr; Back: Pricing &amp; Discount</button>
                <button type="button" class="btn-pill btn-pill--primary" onclick="switchWizardTab(6);">Next: Review &amp; Confirm &rarr;</button>
            </div>
        </div>

        <!-- ====================================================================
             TAB 6: Review & Confirm
             ==================================================================== -->
        <div class="admin-wizard-pane" data-pane="6">
            <!-- Mini Storefront Card Component -->
            <div class="admin-product-detail-mini">
                <div class="admin-product-detail-mini__media">
                    <img id="reviewSummaryThumb" src="" alt="Helmet Preview" class="admin-product-detail-mini__image is-hidden" />
                    <div id="reviewSummaryThumbEmpty" class="admin-product-detail-mini__empty-image">
                        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
                            <circle cx="8.5" cy="8.5" r="1.5"></circle>
                            <polyline points="21 15 16 10 5 21"></polyline>
                        </svg>
                        <span>No image uploaded</span>
                    </div>
                    <span class="admin-product-detail-mini__image-label">Storefront Preview</span>
                </div>
                <div class="admin-product-detail-mini__content">
                    <div class="admin-review-tags">
                        <span class="admin-badge admin-badge--active" id="reviewSummaryBrand">Brand</span>
                        <span class="admin-badge admin-badge--role-staff" id="reviewSummaryCategory">Category</span>
                    </div>
                    <h3 class="admin-product-detail-mini__title" id="reviewSummaryName">Product Name</h3>
                    <div class="admin-product-detail-mini__rating">
                        <span>&#9733;&#9733;&#9733;&#9733;&#9733;</span>
                        <span>Brand New Model Preview</span>
                    </div>
                    <div class="admin-review-pricing-row">
                        <span class="admin-product-detail-mini__price" id="reviewSummaryEffective">&#8369;0.00</span>
                        <span class="admin-review-base-price" id="reviewSummaryBasePrice">&#8369;0.00</span>
                        <span class="admin-review-discount-tag" id="reviewSummaryDiscount">No Discount</span>
                    </div>
                    <p id="reviewSummaryDescription" class="admin-product-detail-mini__description">Product description will appear here.</p>
                    <div class="admin-product-detail-mini__options">
                        <div>
                            <span class="admin-product-detail-mini__option-label">Available Colors</span>
                            <div id="reviewColorSwatches" class="admin-product-detail-mini__swatches"></div>
                        </div>
                        <div>
                            <span class="admin-product-detail-mini__option-label">Available Sizes</span>
                            <div id="reviewSizeOptions" class="admin-product-detail-mini__sizes"></div>
                        </div>
                    </div>
                    <button type="button" class="btn-pill btn-pill--primary admin-product-detail-mini__cart" disabled>Storefront Add to Cart (Preview)</button>
                </div>
            </div>

            <!-- Summary Breakdown Box (Matching Previous Design) -->
            <div class="admin-summary-box">
                <div class="admin-summary-row">
                    <span class="admin-summary-label">Configured Variant SKUs</span>
                    <span class="admin-summary-val" id="reviewSummaryVariantsCount">0 SKUs</span>
                </div>
                <div class="admin-summary-row">
                    <span class="admin-summary-label">Total Warehouse Units</span>
                    <span class="admin-summary-val admin-stock-highlight" id="reviewSummaryStockTotal">0 Units</span>
                </div>
                <div class="admin-summary-row">
                    <span class="admin-summary-label">Technical Specifications Configured</span>
                    <span class="admin-summary-val" id="reviewSummarySpecsCount">0 Specs</span>
                </div>
                <div class="admin-summary-row">
                    <span class="admin-summary-label">Product Gallery Images</span>
                    <span class="admin-summary-val" id="reviewSummaryImagesCount">0 Images</span>
                </div>
            </div>

            <div class="admin-wizard-footer">
                <button type="button" class="btn-pill btn-pill--outline" onclick="switchWizardTab(5);">&larr; Back: Images &amp; Upload</button>
                <div class="admin-actions-group">
                    <button type="button" class="btn-pill btn-pill--secondary" onclick="document.getElementById('btnSaveDraft').click();">Save as Draft</button>
                    <button type="button" class="btn-pill btn-pill--primary" onclick="document.getElementById('btnPublish').click();">Publish Helmet</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Quick Add Brand Modal -->
    <div class="admin-quick-modal-backdrop is-hidden" id="modalQuickBrand" role="dialog" aria-modal="true" aria-labelledby="modalQuickBrandTitle">
        <div class="admin-quick-modal">
            <header class="admin-quick-modal-header">
                <h3 class="admin-quick-modal-title" id="modalQuickBrandTitle">Add New Brand</h3>
                <button type="button" class="admin-modal-close-btn" id="btnCloseQuickBrand">&times;</button>
            </header>
            <div class="admin-quick-modal-body">
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtQuickBrandName">Brand Name <span class="admin-required-star">*</span></label>
                    <input type="text" id="txtQuickBrandName" class="admin-form-input" placeholder="e.g. AGV, Shoei, HJC" />
                    <span class="inline-error-msg" id="errQuickBrandName">Brand name is required.</span>
                </div>
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtQuickBrandWebsite">Website (Optional)</label>
                    <input type="url" id="txtQuickBrandWebsite" class="admin-form-input" placeholder="https://..." />
                </div>
            </div>
            <footer class="admin-quick-modal-footer">
                <button type="button" class="btn-pill btn-pill--outline" id="btnCancelQuickBrand">Cancel</button>
                <button type="button" class="btn-pill btn-pill--primary" id="btnSaveQuickBrand">Save Brand</button>
            </footer>
        </div>
    </div>

    <!-- Quick Add Category Modal -->
    <div class="admin-quick-modal-backdrop is-hidden" id="modalQuickCategory" role="dialog" aria-modal="true" aria-labelledby="modalQuickCategoryTitle">
        <div class="admin-quick-modal">
            <header class="admin-quick-modal-header">
                <h3 class="admin-quick-modal-title" id="modalQuickCategoryTitle">Add New Category</h3>
                <button type="button" class="admin-modal-close-btn" id="btnCloseQuickCategory">&times;</button>
            </header>
            <div class="admin-quick-modal-body">
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtQuickCategoryName">Category Name <span class="admin-required-star">*</span></label>
                    <input type="text" id="txtQuickCategoryName" class="admin-form-input" placeholder="e.g. Modular Helmets, Dual-Sport" />
                    <span class="inline-error-msg" id="errQuickCategoryName">Category name is required.</span>
                </div>
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtQuickCategorySlug">Slug Preview</label>
                    <input type="text" id="txtQuickCategorySlug" class="admin-form-input" placeholder="modular-helmets" />
                </div>
                <div class="admin-form-group">
                    <label class="admin-form-label" for="txtQuickCategoryDesc">Description (Optional)</label>
                    <textarea id="txtQuickCategoryDesc" class="admin-form-textarea" rows="2" placeholder="Brief category description..."></textarea>
                </div>
            </div>
            <footer class="admin-quick-modal-footer">
                <button type="button" class="btn-pill btn-pill--outline" id="btnCancelQuickCategory">Cancel</button>
                <button type="button" class="btn-pill btn-pill--primary" id="btnSaveQuickCategory">Save Category</button>
            </footer>
        </div>
    </div>

    <!-- Save Draft / Unsaved Changes Confirmation Modal -->
    <div class="admin-quick-modal-backdrop is-hidden" id="modalUnsavedChanges" role="dialog" aria-modal="true" aria-labelledby="modalUnsavedTitle">
        <div class="admin-quick-modal">
            <header class="admin-quick-modal-header">
                <h3 class="admin-quick-modal-title" id="modalUnsavedTitle">Unsaved Changes</h3>
                <button type="button" class="admin-modal-close-btn" id="btnCloseUnsavedModal">&times;</button>
            </header>
            <div class="admin-quick-modal-body">
                <p class="admin-modal-description">
                    You have unsaved changes on this helmet model. Would you like to save your work as a draft before leaving?
                </p>
            </div>
            <footer class="admin-quick-modal-footer">
                <button type="button" class="btn-pill btn-pill--danger" id="btnDiscardAndLeave">Discard &amp; Leave</button>
                <button type="button" class="btn-pill btn-pill--secondary" id="btnModalSaveDraft">Save as Draft</button>
                <button type="button" class="btn-pill btn-pill--outline" id="btnCancelLeave">Keep Editing</button>
            </footer>
        </div>
    </div>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="/Scripts/admin/catalog-item.js?v=18"></script>
</asp:Content>
