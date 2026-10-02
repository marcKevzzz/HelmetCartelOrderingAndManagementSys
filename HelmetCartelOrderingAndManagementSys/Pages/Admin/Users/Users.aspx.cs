using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.UI;
using System.Web.UI.WebControls;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;

namespace HelmetCartelOrderingAndManagementSys.Admin
{
    public partial class UsersPage : Page
    {
        private readonly AdminDataRepository _adminRepo;

        public string CurrentRole
        {
            get => (ViewState["CurrentRole"] as string) ?? "all";
            set => ViewState["CurrentRole"] = value;
        }

        public UsersPage()
        {
            _adminRepo = new AdminDataRepository(new DbConnectionFactory());
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                RegisterAsyncTask(new PageAsyncTask(LoadUsersDataAsync));
            }
        }

        public int CurrentPage
        {
            get => ViewState["CurrentPage"] != null ? (int)ViewState["CurrentPage"] : 1;
            set => ViewState["CurrentPage"] = value;
        }

        public const int PageSize = 20;

        public int CurrentActorUserId
        {
            get
            {
                if (ViewState["CurrentActorUserId"] is int id && id > 0) return id;
                int actorId = ResolveCurrentActorUserId();
                ViewState["CurrentActorUserId"] = actorId;
                return actorId;
            }
        }

        private int ResolveCurrentActorUserId()
        {
            // 1. Check hc_user_id cookie
            var cookieId = Request.Cookies["hc_user_id"]?.Value;
            if (int.TryParse(cookieId, out int id) && id > 0) return id;

            // 2. Check JWT token in hc_auth_token or jwt_token cookie
            var tokenCookie = Request.Cookies["hc_auth_token"]?.Value ?? Request.Cookies["jwt_token"]?.Value;
            if (!string.IsNullOrWhiteSpace(tokenCookie))
            {
                try
                {
                    var validated = new JwtTokenProvider().ValidateToken(tokenCookie);
                    if (validated != null && validated.Id > 0) return validated.Id;
                }
                catch {}
            }

            // 3. Check Session
            if (Session["UserId"] is int sessId && sessId > 0) return sessId;

            // 4. Default admin actor in development is 1 (Staff Admin)
            return 1;
        }

        private async Task LoadUsersDataAsync()
        {
            var users = await _adminRepo.GetUsersAsync(500).ConfigureAwait(false);

            string search = Request.QueryString["q"] ?? Request.QueryString["search"];
            if (!string.IsNullOrWhiteSpace(search))
            {
                string term = search.Trim();
                users = users.Where(u =>
                    (u.FullName != null && u.FullName.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0) ||
                    (u.Email != null && u.Email.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0) ||
                    (u.PhoneNumber != null && u.PhoneNumber.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0) ||
                    u.Id.ToString().Contains(term)
                ).ToList();
            }

            if (CurrentRole != "all")
            {
                users = users.Where(u => string.Equals(u.Role, CurrentRole, StringComparison.OrdinalIgnoreCase)).ToList();
            }

            int totalCount = users.Count;
            int totalPages = Math.Max(1, (int)Math.Ceiling((double)totalCount / PageSize));

            if (CurrentPage < 1) CurrentPage = 1;
            if (CurrentPage > totalPages) CurrentPage = totalPages;

            var pagedUsers = users.Skip((CurrentPage - 1) * PageSize).Take(PageSize).ToList();

            rptUsers.DataSource = pagedUsers;
            rptUsers.DataBind();

            litTotalTop.Text = totalCount.ToString();
            litShowingTop.Text = totalCount == 0 ? "0" : $"{((CurrentPage - 1) * PageSize) + 1}–{Math.Min(CurrentPage * PageSize, totalCount)}";

            // Centered pagination
            pnlUsersPagination.Visible = totalPages > 1;
            if (totalPages > 1)
            {
                lnkUsersPrev.CssClass = "admin-pagination-btn" + (CurrentPage <= 1 ? " disabled" : "");
                lnkUsersNext.CssClass = "admin-pagination-btn" + (CurrentPage >= totalPages ? " disabled" : "");

                var pageLinks = PaginationHelper.BuildPageLinks(CurrentPage, totalPages, i => i.ToString());
                rptUsersPages.DataSource = pageLinks;
                rptUsersPages.DataBind();
            }

            UpdateTabButtonStyles();
        }

        protected void UsersPage_Change(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                string arg = btn.CommandArgument;
                if (arg == "prev")
                {
                    CurrentPage = Math.Max(1, CurrentPage - 1);
                }
                else if (arg == "next")
                {
                    CurrentPage++;
                }
                else if (int.TryParse(arg, out int p))
                {
                    CurrentPage = p;
                }
                RegisterAsyncTask(new PageAsyncTask(LoadUsersDataAsync));
            }
        }

        protected void FilterTab_Click(object sender, EventArgs e)
        {
            if (sender is LinkButton btn)
            {
                CurrentRole = btn.CommandArgument;
                CurrentPage = 1;
                RegisterAsyncTask(new PageAsyncTask(LoadUsersDataAsync));
            }
        }

        private void UpdateTabButtonStyles()
        {
            btnTabAll.CssClass = "admin-tab-btn" + (CurrentRole == "all" ? " active" : "");
            btnTabAdmin.CssClass = "admin-tab-btn" + (CurrentRole == "Admin" ? " active" : "");
            btnTabStaff.CssClass = "admin-tab-btn" + (CurrentRole == "Staff" ? " active" : "");
            btnTabCustomer.CssClass = "admin-tab-btn" + (CurrentRole == "Customer" ? " active" : "");
        }

        protected string GetStatusConfirmationTitle(object activeObj)
        {
            return Convert.ToBoolean(activeObj) ? "Deactivate user account" : "Activate user account";
        }

        protected string GetStatusConfirmationMessage(object nameObj, object activeObj)
        {
            string name = Convert.ToString(nameObj ?? "this user");
            return Convert.ToBoolean(activeObj)
                ? $"Deactivate {name}'s account? They will no longer be able to sign in."
                : $"Activate {name}'s account and restore sign-in access?";
        }

        protected void rptUsers_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName == "ToggleStatus" && e.CommandArgument != null)
            {
                string[] parts = e.CommandArgument.ToString().Split(':');
                if (parts.Length == 2 && int.TryParse(parts[0], out int userId) && bool.TryParse(parts[1], out bool currentActive))
                {
                    int actorUserId = CurrentActorUserId;

                    // 1. Strict Backend Rule: Prevent self-deactivation
                    if (userId == actorUserId && currentActive)
                    {
                        string warnMsg = "You cannot deactivate your own account. Self-deactivation is strictly prohibited to prevent administrative lockout.";
                        string toastScript = $"if(window.showAdminToast){{window.showAdminToast({Newtonsoft.Json.JsonConvert.SerializeObject(warnMsg)},'warning','Action Prohibited');}}";
                        ScriptManager.RegisterStartupScript(this, GetType(), "selfDeactBlockedToast", toastScript, true);
                        return;
                    }

                    RegisterAsyncTask(new PageAsyncTask(async () =>
                    {
                        try
                        {
                            await _adminRepo.UpdateUserStatusAsync(userId, !currentActive, actorUserId).ConfigureAwait(false);
                            string successMsg = !currentActive ? "User account has been activated." : "User account has been deactivated.";
                            string toastScript = $"if(window.showAdminToast){{window.showAdminToast({Newtonsoft.Json.JsonConvert.SerializeObject(successMsg)},'success','Status Updated');}}";
                            ScriptManager.RegisterStartupScript(this, GetType(), "userUpdateToast", toastScript, true);
                        }
                        catch (Exception ex)
                        {
                            string toastScript = $"if(window.showAdminToast){{window.showAdminToast({Newtonsoft.Json.JsonConvert.SerializeObject(ex.Message)},'error','Update Failed');}}";
                            ScriptManager.RegisterStartupScript(this, GetType(), "userUpdateErrToast", toastScript, true);
                        }
                        await LoadUsersDataAsync().ConfigureAwait(false);
                    }));
                }
            }
        }

        protected string GetInitials(object nameObj)
        {
            string name = Convert.ToString(nameObj ?? "").Trim();
            if (string.IsNullOrWhiteSpace(name)) return "U";
            var parts = name.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length >= 2)
            {
                return $"{parts[0][0]}{parts[1][0]}".ToUpperInvariant();
            }
            return name.Substring(0, Math.Min(2, name.Length)).ToUpperInvariant();
        }

        protected string RenderRoleBadge(string role)
        {
            switch (role)
            {
                case "Admin":
                    return "<span class=\"admin-badge admin-badge--role-admin\">Admin</span>";
                case "Staff":
                    return "<span class=\"admin-badge admin-badge--role-staff\">Store Staff</span>";
                default:
                    return "<span class=\"admin-badge admin-badge--role-customer\">Customer</span>";
            }
        }

        protected void btnExportUsers_Click(object sender, EventArgs e)
        {
            RegisterAsyncTask(new PageAsyncTask(async () =>
            {
                var users = await _adminRepo.GetUsersAsync(500).ConfigureAwait(false);
                var sb = new StringBuilder();
                sb.AppendLine("UserId,FirstName,LastName,Email,Phone,Role,IsActive,CreatedAt");

                foreach (var u in users)
                {
                    sb.AppendLine($"\"{u.Id}\",\"{u.FirstName.Replace("\"", "\"\"")}\",\"{u.LastName.Replace("\"", "\"\"")}\",\"{u.Email}\",\"{u.PhoneNumber}\",\"{u.Role}\",{u.IsActive},\"{u.CreatedAt:yyyy-MM-dd HH:mm}\"");
                }

                Response.Clear();
                Response.Buffer = true;
                Response.AddHeader("content-disposition", "attachment;filename=HelmetCartel_Users.csv");
                Response.Charset = "utf-8";
                Response.ContentType = "text/csv";
                Response.Output.Write(sb.ToString());
                Response.Flush();
                Response.End();
            }));
        }
    }
}
