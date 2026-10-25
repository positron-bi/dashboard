<%@ Page Language="C#" %>
<%@ Import Namespace="System.DirectoryServices" %>
<%@ Import Namespace="System.Linq" %>
<script runat="server">
    private string Token { get { return (string)(Session["dashboard-access-csrf"] ?? ""); } }
    private string Message { get; set; }
    private string ErrorMessage { get; set; }

    protected void Page_Init(object sender, EventArgs e)
    {
        if (Session["dashboard-access-csrf"] == null) Session["dashboard-access-csrf"] = Guid.NewGuid().ToString("N");
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        var identity = User == null || User.Identity == null ? "" : User.Identity.Name;
        if (!DashboardAccess.IsAdministrator(identity)) { Response.StatusCode = 403; Context.ApplicationInstance.CompleteRequest(); return; }
        if (!IsPostBack) return;
        if (!String.Equals(Request.Form["csrf"], Token, StringComparison.Ordinal)) { ErrorMessage = "درخواست نامعتبر است؛ صفحه را تازه کنید."; return; }
        try {
            if (Request.Form["action"] == "delete") {
                DashboardAccess.DeleteGrant(Request.Form["user"]);
                Message = "دسترسی کاربر حذف شد.";
                return;
            }
            var entered = (Request.Form["user"] ?? "").Trim();
            var account = ResolveAccount(entered);
            var selected = Request.Form.GetValues("dashboard") ?? new string[0];
            DashboardAccess.SaveGrant(account.user, account.display, selected, Request.Form["administrator"] == "on");
            Message = "دسترسی کاربر ذخیره شد.";
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
    }

    private dynamic ResolveAccount(string entered)
    {
        if (String.IsNullOrWhiteSpace(entered)) throw new Exception("نام کاربری را وارد کنید.");
        var name = entered.Contains("\\") ? entered.Substring(entered.IndexOf('\\') + 1) : entered;
        using (var root = new DirectoryEntry("LDAP://RootDSE")) {
            var namingContext = root.Properties["defaultNamingContext"][0].ToString();
            using (var directory = new DirectoryEntry("LDAP://" + namingContext))
            using (var search = new DirectorySearcher(directory)) {
                search.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=" + EscapeLdap(name) + "))";
                search.PropertiesToLoad.Add("sAMAccountName");
                search.PropertiesToLoad.Add("displayName");
                var result = search.FindOne();
                if (result == null || result.Properties["sAMAccountName"].Count == 0) throw new Exception("این کاربر در Active Directory پیدا نشد.");
                var sam = result.Properties["sAMAccountName"][0].ToString();
                var display = result.Properties["displayName"].Count == 0 ? sam : result.Properties["displayName"][0].ToString();
                var domain = (User.Identity.Name ?? "").Contains("\\") ? User.Identity.Name.Split('\\')[0] : Environment.UserDomainName;
                return new { user = domain + "\\" + sam, display = display + " (" + sam + ")" };
            }
        }
    }

    private string EscapeLdap(string value) { return value.Replace("\\", "\\5c").Replace("*", "\\2a").Replace("(", "\\28").Replace(")", "\\29").Replace("\0", "\\00"); }

    protected string H(string value) { return Server.HtmlEncode(value ?? ""); }
</script>
<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>مدیریت دسترسی داشبوردها</title><style>body{margin:0;background:#f6f8fb;color:#172033;font:15px Tahoma,Arial,sans-serif}main{max-width:1060px;margin:30px auto;padding:28px;background:#fff;border:1px solid #d9e0ea;border-radius:12px}h1{margin-top:0}p{line-height:1.9}.hint{color:#657086}.notice{padding:10px;border-radius:7px;background:#dcfce7;color:#166534}.error{padding:10px;border-radius:7px;background:#fee2e2;color:#b91c1c}form{margin:20px 0;padding:20px;border:1px solid #d9e0ea;border-radius:9px}.field{display:grid;gap:7px;max-width:480px}input{padding:10px;border:1px solid #bdc7d5;border-radius:6px;font:inherit}.apps{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin:18px 0}.apps label{padding:9px;border:1px solid #d9e0ea;border-radius:6px}button,a.button{padding:10px 15px;border:0;border-radius:6px;background:#155e75;color:white;text-decoration:none;font:inherit;cursor:pointer}.delete{background:#b91c1c}table{width:100%;border-collapse:collapse}th,td{text-align:right;padding:11px;border-bottom:1px solid #d9e0ea}@media(max-width:720px){.apps{grid-template-columns:1fr}main{margin:0;border:0;border-radius:0}}</style></head><body><main><h1>مدیریت دسترسی داشبوردها</h1><p class="hint">کاربر سازمانی را مانند <b>a.farshchian</b> وارد کنید. سامانه همان لحظه آن را در Active Directory بررسی می‌کند؛ نیازی به ساخت فهرست دستی کاربران نیست.</p><p>کاربر واردشده: <b><%= H(User.Identity.Name) %></b></p><% if (!String.IsNullOrEmpty(Message)) { %><p class="notice"><%= H(Message) %></p><% } %><% if (!String.IsNullOrEmpty(ErrorMessage)) { %><p class="error"><%= H(ErrorMessage) %></p><% } %><form method="post"><input type="hidden" name="csrf" value="<%= H(Token) %>"><input type="hidden" name="action" value="save"><div class="field"><label>کاربر Active Directory</label><input name="user" placeholder="a.farshchian یا PARS\a.farshchian" required></div><div class="apps"><% foreach (var id in DashboardCatalog.All) { %><label><input type="checkbox" name="dashboard" value="<%= id %>"> <%= H(DashboardCatalog.Names[id]) %></label><% } %></div><label><input type="checkbox" name="administrator"> مدیر دسترسی‌ها نیز باشد</label><p><button type="submit">ذخیره دسترسی</button> <a class="button" href="../dashboard/">بازگشت به درگاه</a></p></form><h2>دسترسی‌های ثبت‌شده</h2><table><tr><th>کاربر</th><th>داشبوردها</th><th></th></tr><% foreach (var grant in DashboardAccess.Grants()) { %><tr><td><b><%= H(grant.DisplayName) %></b><br><span class="hint"><%= H(grant.User) %></span></td><td><%= H(String.Join("، ", (grant.Dashboards ?? new System.Collections.Generic.List<string>()).Select(id => DashboardCatalog.Names.ContainsKey(id) ? DashboardCatalog.Names[id] : id))) %></td><td><form method="post" style="padding:0;margin:0;border:0"><input type="hidden" name="csrf" value="<%= H(Token) %>"><input type="hidden" name="action" value="delete"><input type="hidden" name="user" value="<%= H(grant.User) %>"><button class="delete" type="submit">حذف</button></form></td></tr><% } %></table></main></body></html>
