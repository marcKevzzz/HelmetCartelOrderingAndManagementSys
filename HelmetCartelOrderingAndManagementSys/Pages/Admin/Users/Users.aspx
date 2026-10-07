<%@ Page Title="Users" Language="C#" MasterPageFile="~/Pages/Admin/Portal.master" AutoEventWireup="true" CodeBehind="Users.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.UsersPage" Async="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <div class="admin-card-container">
        <!-- Top Row: Page Heading (Removed unnecessary export actions) -->
        <div class="admin-page-header">
            <div class="admin-page-title-row">
                <h1 class="admin-page-title">Users & Access Control</h1>
            </div>
        </div>

        <!-- Filter Sub-bar with Top Metadata -->
        <div class="admin-filters-bar">
            <div class="admin-filters-left">
                <div class="admin-segmented-tabs">
                    <asp:LinkButton ID="btnTabAll" runat="server" CssClass="admin-tab-btn" CommandArgument="all" OnClick="FilterTab_Click">All Users</asp:LinkButton>
                    <asp:LinkButton ID="btnTabAdmin" runat="server" CssClass="admin-tab-btn" CommandArgument="Admin" OnClick="FilterTab_Click">Admins</asp:LinkButton>
                    <asp:LinkButton ID="btnTabStaff" runat="server" CssClass="admin-tab-btn" CommandArgument="Staff" OnClick="FilterTab_Click">Staff</asp:LinkButton>
                    <asp:LinkButton ID="btnTabCustomer" runat="server" CssClass="admin-tab-btn" CommandArgument="Customer" OnClick="FilterTab_Click">Customers</asp:LinkButton>
                </div>
            </div>

            <!-- Table Top Metadata (Replaces Status Count Tag) -->
            <div class="admin-meta-top">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="admin-meta-top-icon">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                    <circle cx="9" cy="7" r="4"></circle>
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                    <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
                </svg>
                <span>Showing <asp:Literal ID="litShowingTop" runat="server">0</asp:Literal> of <asp:Literal ID="litTotalTop" runat="server">0</asp:Literal> accounts</span>
            </div>
        </div>

        <!-- Independent Scrollable Responsive Users Table Component -->
        <div class="admin-table-wrapper">
            <table class="admin-table admin-table-users">
                <colgroup>
                    <col class="users-table-column-1" />
                    <col class="col-user-details" />
                    <col class="col-email" />
                    <col class="users-table-column-2" />
                    <col class="users-table-column-3" />
                    <col class="col-status" />
                    <col class="col-actions users" />
                </colgroup>
                <thead>
                    <tr>
                        <th>UID</th>
                        <th>User Details</th>
                        <th>Email Address</th>
                        <th>Phone Number</th>
                        <th>System Role</th>
                        <th>Account Status</th>
                        <th class="admin-table-align-right">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptUsers" runat="server" OnItemCommand="rptUsers_ItemCommand">
                        <ItemTemplate>
                            <tr>
                                <td>
                                    <span class="admin-cell-sku">#<%# Convert.ToInt32(Eval("Id")).ToString("D3") %></span>
                                </td>
                                <td>
                                    <div class="admin-variant-cell" title='<%# Server.HtmlEncode(Convert.ToString(Eval("FullName"))) %>'>
                                        <span class="admin-cell-name"><%# Server.HtmlEncode(Convert.ToString(Eval("FullName"))) %></span>
                                    </div>
                                </td>
                                <td>
                                    <span class="admin-cell-mono-muted" title='<%# Server.HtmlEncode(Convert.ToString(Eval("Email"))) %>'><%# Server.HtmlEncode(Convert.ToString(Eval("Email"))) %></span>
                                </td>
                                <td>
                                    <span class="admin-activity-time"><%# Server.HtmlEncode(Convert.ToString(Eval("PhoneNumber"))) %></span>
                                </td>
                                <td>
                                    <%# RenderRoleBadge(Convert.ToString(Eval("Role"))) %>
                                </td>
                                <td>
                                    <%# Convert.ToBoolean(Eval("IsActive")) ? "<span class=\"admin-badge admin-badge--active\">Active</span>" : "<span class=\"admin-badge admin-badge--inactive\">Disabled</span>" %>
                                </td>
                                <td class="admin-table-align-right">
                                    <div class="users-admin-actions-cell-presentation admin-actions-cell">
                                        <asp:PlaceHolder ID="phCurrentUser" runat="server" Visible='<%# Convert.ToInt32(Eval("Id")) == CurrentActorUserId %>'>
                                            <span class="admin-badge--current-user" title="You are currently signed in with this account. Self-deactivation is disabled.">
                                                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
                                                Current User
                                            </span>
                                        </asp:PlaceHolder>
                                        <button type="button" class="btn-pill-sm btn-pill--outline" 
                                            onclick='openEditRoleModal(<%# Eval("Id") %>, <%# Newtonsoft.Json.JsonConvert.SerializeObject(Eval("FullName")) %>, <%# Newtonsoft.Json.JsonConvert.SerializeObject(Eval("Email")) %>, <%# Newtonsoft.Json.JsonConvert.SerializeObject(Eval("Role")) %>, <%# Convert.ToInt32(Eval("Id")) == CurrentActorUserId ? "true" : "false" %>)' 
                                            title="Change System Role">
                                            <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                                <path d="M12 20h9"></path>
                                                <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"></path>
                                            </svg>
                                            <span>Edit Role</span>
                                        </button>
                                        <asp:LinkButton ID="btnToggleActive" runat="server" 
                                            CommandName="ToggleStatus" 
                                            CommandArgument='<%# Eval("Id") + ":" + Eval("IsActive") %>'
                                            data-admin-confirm="true"
                                            data-confirm-title='<%# GetStatusConfirmationTitle(Eval("IsActive")) %>'
                                            data-confirm-message='<%# GetStatusConfirmationMessage(Eval("FullName"), Eval("IsActive")) %>'
                                            CssClass='<%# Convert.ToBoolean(Eval("IsActive")) ? "btn-pill-sm btn-pill--outline btn-pill--danger" : "btn-pill-sm btn-pill--outline" %>'
                                            Visible='<%# Convert.ToInt32(Eval("Id")) != CurrentActorUserId %>'>
                                            <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                                <%# Convert.ToBoolean(Eval("IsActive")) 
                                                    ? "<circle cx=\"12\" cy=\"12\" r=\"10\"></circle><line x1=\"4.93\" y1=\"4.93\" x2=\"19.07\" y2=\"19.07\"></line>" 
                                                    : "<polyline points=\"20 6 9 17 4 12\"></polyline>" %>
                                            </svg>
                                            <span><%# Convert.ToBoolean(Eval("IsActive")) ? "Deactivate" : "Activate" %></span>
                                        </asp:LinkButton>
                                    </div>
                                </td>
                            </tr>
                        </ItemTemplate>
                        <FooterTemplate>
                            <%# rptUsers.Items.Count == 0 ? "<tr><td colspan='7'><div class='admin-empty-state'><div class='admin-empty-title'>No Users Found</div><p>No user accounts match the current filter or search criteria.</p></div></td></tr>" : "" %>
                        </FooterTemplate>
                    </asp:Repeater>
                </tbody>
            </table>
        </div>

        <!-- Centered Pagination (Requirement 3: 1 2 ... 8 9 or 1 2 3 4) -->
        <asp:Panel ID="pnlUsersPagination" runat="server" CssClass="admin-pagination-container" Visible="false">
            <div class="admin-pagination">
                <asp:LinkButton ID="lnkUsersPrev" runat="server" CssClass="admin-pagination-btn" OnClick="UsersPage_Change" CommandArgument="prev">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6"></polyline></svg>
                    <span>Previous</span>
                </asp:LinkButton>
                <div class="admin-pagination-pages">
                    <asp:Repeater ID="rptUsersPages" runat="server">
                        <ItemTemplate>
                            <asp:PlaceHolder runat="server" Visible='<%# !(bool)Eval("IsEllipsis") %>'>
                                <asp:LinkButton runat="server" CssClass='<%# "admin-pagination-page " + Eval("CssClass") %>' 
                                    OnClick="UsersPage_Change" CommandArgument='<%# Eval("Number") %>'>
                                    <%# Eval("Number") %>
                                </asp:LinkButton>
                            </asp:PlaceHolder>
                            <asp:PlaceHolder runat="server" Visible='<%# (bool)Eval("IsEllipsis") %>'>
                                <span class="admin-pagination-ellipsis">&hellip;</span>
                            </asp:PlaceHolder>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
                <asp:LinkButton ID="lnkUsersNext" runat="server" CssClass="admin-pagination-btn" OnClick="UsersPage_Change" CommandArgument="next">
                    <span>Next</span>
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
                </asp:LinkButton>
            </div>
        </asp:Panel>
    </div>

    <!-- Edit User Role Modal -->
    <div id="modalEditRole" class="admin-modal-backdrop is-hidden" role="dialog" aria-modal="true" aria-labelledby="modalEditRoleTitle">
        <div class="admin-modal">
            <div class="admin-modal-header">
                <div>
                    <h2 id="modalEditRoleTitle" class="admin-modal-title">Edit System Role</h2>
                    <div class="admin-modal-desc-subtle">Update permissions and access level for this account.</div>
                </div>
                <button type="button" class="admin-modal-close-btn" onclick="closeEditRoleModal()" aria-label="Close dialog">&times;</button>
            </div>
            <div class="admin-modal-body">
                <div class="edit-role-user-summary">
                    <div class="edit-role-avatar" id="modalRoleInitials">U</div>
                    <div class="edit-role-user-info">
                        <div class="edit-role-user-name" id="modalRoleUserName">User Name</div>
                        <div class="edit-role-user-email" id="modalRoleUserEmail">user@example.com</div>
                    </div>
                </div>

                <div class="edit-role-form-group">
                    <label for="ddlSelectRole" class="form-label">Assign System Role</label>
                    <select id="ddlSelectRole" class="form-control admin-select">
                        <option value="Customer">Customer &mdash; Storefront shopper &amp; personal order history</option>
                        <option value="Staff">Staff &mdash; Store operations, Orders, Inventory, POS, Returns, Catalog</option>
                        <option value="Admin">Admin &mdash; Full administrative access &amp; Access Control</option>
                    </select>
                    <span class="inline-hint-msg" id="modalRoleNote">Changes take effect immediately on next request or token refresh.</span>
                </div>

                <div id="modalRoleSelfWarn" class="modal-alert modal-alert--warning is-hidden" style="margin-top: 12px;">
                    <strong>Self-demotion protection:</strong> You are currently signed in with this account. You cannot remove your own Admin access.
                </div>
            </div>
            <div class="admin-modal-footer">
                <button type="button" class="btn-pill btn-pill--outline" onclick="closeEditRoleModal()">Cancel</button>
                <asp:Button ID="btnConfirmRoleChange" runat="server" CssClass="btn-pill btn-pill--primary" Text="Save Role Changes" OnClick="btnConfirmRoleChange_Click" />
            </div>
        </div>
    </div>
    <asp:HiddenField ID="hfSelectedUserId" runat="server" />
    <asp:HiddenField ID="hfSelectedNewRole" runat="server" />

    <script>
        function openEditRoleModal(userId, fullName, email, currentRole, isCurrentUser) {
            document.getElementById('<%= hfSelectedUserId.ClientID %>').value = userId;
            document.getElementById('modalRoleUserName').textContent = fullName;
            document.getElementById('modalRoleUserEmail').textContent = email;

            var initials = 'U';
            if (fullName) {
                var parts = fullName.trim().split(' ');
                initials = parts.length >= 2 ? (parts[0][0] + parts[1][0]).toUpperCase() : fullName.substring(0, Math.min(2, fullName.length)).toUpperCase();
            }
            document.getElementById('modalRoleInitials').textContent = initials;

            var ddl = document.getElementById('ddlSelectRole');
            ddl.value = currentRole;
            document.getElementById('<%= hfSelectedNewRole.ClientID %>').value = currentRole;

            var selfWarn = document.getElementById('modalRoleSelfWarn');
            var saveBtn = document.getElementById('<%= btnConfirmRoleChange.ClientID %>');

            if (isCurrentUser) {
                if (currentRole === 'Admin') {
                    // Current admin can stay admin, but if dropdown changes, disable
                    selfWarn.classList.remove('is-hidden');
                } else {
                    selfWarn.classList.add('is-hidden');
                }
            } else {
                selfWarn.classList.add('is-hidden');
            }

            ddl.onchange = function () {
                document.getElementById('<%= hfSelectedNewRole.ClientID %>').value = this.value;
                if (isCurrentUser && this.value !== 'Admin') {
                    saveBtn.disabled = true;
                    selfWarn.classList.remove('is-hidden');
                } else {
                    saveBtn.disabled = false;
                    if (!isCurrentUser) selfWarn.classList.add('is-hidden');
                }
            };

            var modal = document.getElementById('modalEditRole');
            if (modal) modal.classList.remove('is-hidden');
            document.body.classList.add('modal-open');
        }

        function closeEditRoleModal() {
            var modal = document.getElementById('modalEditRole');
            if (modal) modal.classList.add('is-hidden');
            document.body.classList.remove('modal-open');
        }

        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') {
                closeEditRoleModal();
            }
        });
    </script>
</asp:Content>
