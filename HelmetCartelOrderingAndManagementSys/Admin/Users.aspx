<%@ Page Title="Users" Language="C#" MasterPageFile="~/Admin/Portal.master" AutoEventWireup="true" CodeBehind="Users.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Admin.UsersPage" Async="true" %>

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
                    <col style="width: 8%; min-width: 70px;" />
                    <col class="col-user-details" />
                    <col class="col-email" />
                    <col style="min-width: 130px;" />
                    <col style="min-width: 100px;" />
                    <col class="col-status" />
                    <col class="col-actions" />
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
                                    <div class="admin-actions-cell" style="justify-content: flex-end;">
                                        <asp:PlaceHolder ID="phCurrentUser" runat="server" Visible='<%# Convert.ToInt32(Eval("Id")) == CurrentActorUserId %>'>
                                            <span class="admin-badge--current-user" title="You are currently signed in with this account. Self-deactivation is disabled.">
                                                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
                                                Current User
                                            </span>
                                        </asp:PlaceHolder>
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
</asp:Content>
