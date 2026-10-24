# -*- coding: utf-8 -*-
"""Rebuild the cash treasury dashboard with the approved HTTP login mode."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


home = Path.home()
access_dir = home / "Desktop" / "DashboardAccess"
sys.path.insert(0, str(access_dir))
from dashboard_auth import protect_html  # noqa: E402


launcher_path = home / "Desktop" / "all" / "گزارش خزانه" / "treasury_launcher.py"
spec = importlib.util.spec_from_file_location("cash_treasury_launcher", launcher_path)
if not spec or not spec.loader:
    raise RuntimeError("Cash treasury generator was not found.")
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

data = launcher.extract_data(launcher.DAILY_INPUT_PATH, launcher.NP_INPUT_PATH, log_fn=lambda _: None)
template = launcher_path.with_name("template_dashboard.html")
html = launcher.build_html(data, template, log_fn=lambda _: None)
wrapped = protect_html(html, launcher.USERS_FILE, "treasury", "داشبورد خزانه")
target = Path(launcher.OUTPUT_DIR) / "index.html"
target.write_text(wrapped, encoding="utf-8")
print(f"Updated {target}")
