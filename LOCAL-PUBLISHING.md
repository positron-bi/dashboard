# انتشار هم‌زمان لوکال و GitHub

پس از ساخت خروجی HTML، این دستور را از PowerShell اجرا کنید:

```powershell
& ".\tools\publish-dashboard.ps1" -CommitMessage "Update dashboard"
```

این کار نسخهٔ وب را در `C:\Dashboards\dashboard` با جایگزینی امن منتشر می‌کند و تغییرات را نیز commit و push می‌کند.

برای دیدن نسخهٔ لوکال روی همان سیستم:

```powershell
& ".\tools\start-local-server.ps1"
```

سپس آدرس زیر را باز کنید:

```text
http://localhost:8080/dashboard/
```

برای نمایش در شبکهٔ داخلی، سرور را با IP همین سیستم اجرا کنید؛ این سرور به Administrator نیاز ندارد. نمونه:

```powershell
& ".\tools\start-local-server.ps1" -BindAddress "192.168.10.46"
```

کلاینت‌های شبکه از آدرس `http://192.168.10.46:8080/dashboard/` استفاده می‌کنند. اگر فایروال سازمانی اتصال را مسدود کند، باید تیم شبکه برای پورت 8080 مجوز ورودی اعمال کند.

برای اتصال به Generator هر داشبورد، همان دستور `publish-dashboard.ps1` را در انتهای فایل `.bat` یا PowerShell آن Generator قرار دهید. برای هر مخزن، نام سایت را تغییر دهید؛ نمونه:

```powershell
& "C:\Path\To\dashboard\tools\publish-dashboard.ps1" -Source "C:\Path\To\treasury-dashboard" -SiteName "treasury"
```

در سرور شبکه، این مسیر را به یک Site در IIS متصل کنید و به‌جای `serve-local.ps1` از IIS استفاده کنید.

برای دریافت تغییرهایی که Generatorهای دیگر روی GitHub منتشر می‌کنند، اجرا کنید:

```powershell
& ".\tools\sync-local-sites.ps1"
```
