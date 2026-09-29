<%@ Page Language="C#" AutoEventWireup="true" %>
<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        Response.Redirect("~/Pages/Auth.aspx" + Request.Url.Query, true);
    }
</script>
