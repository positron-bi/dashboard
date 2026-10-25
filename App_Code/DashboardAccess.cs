using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Script.Serialization;

public sealed class DashboardGrant
{
    public string User { get; set; }
    public string DisplayName { get; set; }
    public List<string> Dashboards { get; set; }
}

public sealed class DashboardAccessState
{
    public List<string> Administrators { get; set; } = new List<string>();
    public List<DashboardGrant> Grants { get; set; } = new List<DashboardGrant>();
}

public static class DashboardCatalog
{
    public static readonly string[] All = {
        "treasury", "forecast", "inventory", "aging", "ledger", "reconciliation",
        "organization", "financial-statements", "financial-group", "vesta", "meta",
        "atlas", "ad-hoc-reports"
    };

    public static readonly IDictionary<string, string> Names = new Dictionary<string, string> {
        { "treasury", "خزانه‌داری" }, { "forecast", "پیش‌بینی خزانه" },
        { "inventory", "انبار" }, { "aging", "سررسید مطالبات" },
        { "ledger", "گزارش گردش حساب‌ها" }, { "reconciliation", "تطبیق حساب‌ها" },
        { "organization", "ساختار هیئت‌مدیره و سهامداری" },
        { "financial-statements", "صورت‌های مالی" }, { "financial-group", "گروه مالی" },
        { "vesta", "وستا" }, { "meta", "متا" }, { "atlas", "اطلس" },
        { "ad-hoc-reports", "گزارش‌های موردی" }
    };
}

public static class DashboardAccess
{
    private static readonly object Gate = new object();
    private static readonly JavaScriptSerializer Json = new JavaScriptSerializer();

    private static string Normalize(string value)
    {
        return (value ?? "").Trim().ToLowerInvariant();
    }

    private static string DataFile
    {
        get { return HttpContext.Current.Server.MapPath("~/App_Data/dashboard-access.json"); }
    }

    private static DashboardAccessState Read()
    {
        lock (Gate)
        {
            if (!File.Exists(DataFile)) return new DashboardAccessState();
            var state = Json.Deserialize<DashboardAccessState>(File.ReadAllText(DataFile)) ?? new DashboardAccessState();
            state.Administrators = state.Administrators ?? new List<string>();
            state.Grants = state.Grants ?? new List<DashboardGrant>();
            return state;
        }
    }

    private static void Write(DashboardAccessState state)
    {
        lock (Gate)
        {
            var folder = Path.GetDirectoryName(DataFile);
            Directory.CreateDirectory(folder);
            var temporary = DataFile + ".new";
            File.WriteAllText(temporary, Json.Serialize(state));
            if (File.Exists(DataFile)) File.Replace(temporary, DataFile, null);
            else File.Move(temporary, DataFile);
        }
    }

    public static bool IsAdministrator(string identity)
    {
        var configured = (System.Configuration.ConfigurationManager.AppSettings["PositronBI.Access.Administrators"] ?? "")
            .Split(new[] { ';', ',' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(Normalize);
        return configured.Contains(Normalize(identity)) || Read().Administrators.Select(Normalize).Contains(Normalize(identity));
    }

    public static IList<string> AllowedDashboards(string identity)
    {
        if (IsAdministrator(identity)) return DashboardCatalog.All;
        var grant = Read().Grants.FirstOrDefault(item => Normalize(item.User) == Normalize(identity));
        return grant == null ? new List<string>() : (grant.Dashboards ?? new List<string>())
            .Where(id => DashboardCatalog.All.Contains(id, StringComparer.OrdinalIgnoreCase)).ToList();
    }

    public static bool IsAllowed(string identity, string dashboardId)
    {
        return AllowedDashboards(identity).Contains(dashboardId, StringComparer.OrdinalIgnoreCase);
    }

    public static IList<DashboardGrant> Grants()
    {
        return Read().Grants.OrderBy(item => item.DisplayName ?? item.User).ToList();
    }

    public static void SaveGrant(string user, string displayName, IEnumerable<string> dashboardIds, bool administrator)
    {
        var normalizedUser = Normalize(user);
        if (String.IsNullOrWhiteSpace(normalizedUser)) throw new ArgumentException("نام کاربری معتبر نیست.");
        var state = Read();
        state.Grants.RemoveAll(item => Normalize(item.User) == normalizedUser);
        state.Grants.Add(new DashboardGrant {
            User = user.Trim(),
            DisplayName = String.IsNullOrWhiteSpace(displayName) ? user.Trim() : displayName.Trim(),
            Dashboards = dashboardIds.Where(id => DashboardCatalog.All.Contains(id, StringComparer.OrdinalIgnoreCase)).Distinct(StringComparer.OrdinalIgnoreCase).ToList()
        });
        state.Administrators.RemoveAll(item => Normalize(item) == normalizedUser);
        if (administrator) state.Administrators.Add(user.Trim());
        Write(state);
    }

    public static void DeleteGrant(string user)
    {
        var normalizedUser = Normalize(user);
        var state = Read();
        state.Grants.RemoveAll(item => Normalize(item.User) == normalizedUser);
        state.Administrators.RemoveAll(item => Normalize(item) == normalizedUser);
        Write(state);
    }
}
