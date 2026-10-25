<%@ Page Language="C#" %>
<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        Response.Redirect("/access/index.aspx", false);
        Context.ApplicationInstance.CompleteRequest();
    }
</script>
