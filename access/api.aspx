<%@ Page Language="C#" ContentType="application/json" %>
<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        Response.Cache.SetCacheability(HttpCacheability.NoCache);
        Response.Cache.SetNoStore();
        var identity = User == null || User.Identity == null ? "" : User.Identity.Name;
        var payload = new {
            identity = identity,
            isAdmin = DashboardAccess.IsAdministrator(identity),
            dashboards = DashboardAccess.AllowedDashboards(identity)
        };
        Response.Write(new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(payload));
    }
</script>
