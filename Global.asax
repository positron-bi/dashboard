<%@ Application Language="C#" %>
<script runat="server">
    private static readonly System.Collections.Generic.Dictionary<string, string> ProtectedPaths =
        new System.Collections.Generic.Dictionary<string, string>(System.StringComparer.OrdinalIgnoreCase) {
            { "/treasury-dashboard/", "treasury" }, { "/treasuryflow-dashboard/", "forecast" },
            { "/inventory-dashboard/", "inventory" }, { "/aging-dashboard/", "aging" },
            { "/ledger-dashboard/", "ledger" }, { "/reconciliation_dashboard/", "reconciliation" },
            { "/organization-dashboard/", "organization" }, { "/financial-statements/", "financial-statements" },
            { "/financial-group/", "financial-group" }, { "/vesta-dashboard/", "vesta" },
            { "/meta-dashboard/", "meta" }, { "/atlas-dashboard/", "atlas" },
            { "/ad-hoc-reports/", "ad-hoc-reports" }
        };

    void Application_AuthorizeRequest(object sender, EventArgs args)
    {
        var path = (Request.Path ?? "/").ToLowerInvariant();
        if (path.StartsWith("/access/") || path.StartsWith("/dashboard/")) return;
        string dashboardId = null;
        foreach (var item in ProtectedPaths) {
            if (path.StartsWith(item.Key)) { dashboardId = item.Value; break; }
        }
        if (dashboardId == null) return;
        var identity = Context.User == null || Context.User.Identity == null ? "" : Context.User.Identity.Name;
        if (Context.User == null || !Context.User.Identity.IsAuthenticated || !DashboardAccess.IsAllowed(identity, dashboardId)) {
            Response.StatusCode = 403;
            Response.TrySkipIisCustomErrors = true;
            Response.ContentType = "text/html; charset=utf-8";
            Response.Write("<html dir='rtl'><body style='font-family:tahoma;padding:40px'><h2>دسترسی به این سامانه برای شما فعال نیست.</h2><p>برای دریافت دسترسی با مدیر سامانه تماس بگیرید.</p></body></html>");
            Context.ApplicationInstance.CompleteRequest();
        }
    }
</script>
