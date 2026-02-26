import subprocess
import platform
import datetime
import threading
import shutil
import psutil
import os
import requests
import socket
from pathlib import Path

# Try to import the manager, handle gracefully if missing
try:
    from terminal_manager import TerminalManager

    HAS_MANAGER = True
except ImportError:
    HAS_MANAGER = False

# ==============================================================================
# 1. CONFIG & THEME
# ==============================================================================
PROJECT_ROOT = Path("E:/")

E = "\033["
RESET = f"{E}0m"
BOLD = f"{E}1m"
C_GRAY = f"{E}38;5;240m"
C_WHITE = f"{E}38;5;250m"
C_CYAN = f"{E}38;5;39m"
C_GOLD = f"{E}38;5;214m"
C_GREEN = f"{E}38;5;78m"
C_MAGENTA = f"{E}38;5;170m"
C_RED = f"{E}38;5;196m"

ICON_OS = ""
ICON_DISK = "󰋊"
ICON_PR = ""
ICON_BUG = ""
ICON_TIME = ""
ICON_DIR = ""
ICON_WIFI = ""
ICON_PLUG = ""
ICON_RAM = "󰍛"
ICON_CPU = ""
ICON_TEMP = ""


# ==============================================================================
# 2. HELPER FUNCTIONS
# ==============================================================================
def is_admin():
    try:
        import ctypes

        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except:
        return False


def is_lhm_alive():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.1)
        return s.connect_ex(("localhost", 8085)) == 0


def get_relative_time(timestamp):
    delta = datetime.datetime.now().timestamp() - timestamp
    if delta < 3600:
        return f"{int(delta // 60)}m ago"
    if delta < 84600:
        return f"{int(delta // 3600)}h ago"
    return f"{int(delta // 86400)}d ago"


def check_connection():
    try:
        subprocess.check_call(
            ["ping", "-n", "1", "-w", "1000", "github.com"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except:
        return False


def get_gh_username():
    try:
        return (
            subprocess.check_output(
                "gh api user --jq .login", shell=True, stderr=subprocess.DEVNULL
            )
            .decode("utf-8")
            .strip()
        )
    except:
        return os.environ.get("USERNAME", "Dev")


def get_recent_projects(limit=3):
    if not PROJECT_ROOT.exists():
        return []
    projects = []
    try:
        for item in PROJECT_ROOT.iterdir():
            if item.is_dir() and (item / ".git").exists():
                projects.append({"name": item.name, "time": item.stat().st_mtime})
    except:
        pass
    projects.sort(key=lambda x: x["time"], reverse=True)
    return projects[:limit]


def get_gh_data(cmd):
    try:
        out = (
            subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
            .decode("utf-8")
            .strip()
        )
        return out.split("\n") if out else []
    except:
        return []


def format_gh_line(line, icon):
    parts = line.split("\t")
    if len(parts) < 3:
        return f"  {C_GRAY}│{RESET}  {C_GRAY}• {line[:50]}{RESET}"

    repo = parts[0].split("/")[-1]
    num = parts[1]
    title = parts[2]
    clean_title = (title[:40] + "..") if len(title) > 40 else title.ljust(40)

    return f"  {C_GRAY}│{RESET}  {C_MAGENTA}{icon} {num.ljust(6)}{RESET} {C_WHITE}{clean_title}{RESET} {C_GRAY}({repo}){RESET}"


def get_cpu_temp():
    """Fetches CPU Package Temp from LibreHardwareMonitor Web Server"""
    url = "http://localhost:8085/data.json"
    try:
        response = requests.get(url, timeout=0.5)  # Fast timeout
        data = response.json()

        def find_temp(node):
            # Look for the CPU Package sensor
            if node.get("Text") == "CPU Package" and "°C" in node.get("Value", ""):
                return node.get("Value")
            # Recursive check children
            for child in node.get("Children", []):
                res = find_temp(child)
                if res:
                    return res
            return None

        temp_str = find_temp(data)
        if temp_str:
            # "54.2 °C" -> 54
            return int(float(temp_str.split(" ")[0]))
    except:
        pass
    return None


def draw_bar(percent, width=15):
    fill_len = int(width * percent / 100)
    empty_len = width - fill_len
    color = C_GREEN if percent < 75 else (C_GOLD if percent < 90 else C_RED)
    return f"{color}{'█' * fill_len}{C_GRAY}{'░' * empty_len}{RESET} {color}{str(int(percent)).rjust(3)}%{RESET}"


# ==============================================================================
# 3. MAIN RENDERER
# ==============================================================================
def show_dashboard():
    # Setup Async Tasks
    data = {"prs": [], "issues": [], "projects": [], "online": False, "handle": "..."}
    pr_cmd = 'gh search prs --author "@me" --state open --limit 3'
    iss_cmd = 'gh search issues --assignee "@me" --state open --limit 3'

    threads = [
        threading.Thread(target=lambda: data.update({"online": check_connection()})),
        threading.Thread(target=lambda: data.update({"handle": get_gh_username()})),
        threading.Thread(
            target=lambda: data.update({"projects": get_recent_projects()})
        ),
        threading.Thread(target=lambda: data.update({"prs": get_gh_data(pr_cmd)})),
        threading.Thread(target=lambda: data.update({"issues": get_gh_data(iss_cmd)})),
    ]
    for t in threads:
        t.start()

    # --- SYNC STATS (CPU/RAM/DISK) ---
    cpu_load = psutil.cpu_percent(interval=0.5)
    mem = psutil.virtual_memory()
    cpu_temp = get_cpu_temp() if is_lhm_alive() else "OFF"
    disk_c = int(shutil.disk_usage("C:/").used / shutil.disk_usage("C:/").total * 100)
    disk_e = 0
    if Path("E:/").exists():
        disk_e = int(
            shutil.disk_usage("E:/").used / shutil.disk_usage("E:/").total * 100
        )
    if Path("D:/").exists():
        disk_d = int(
            shutil.disk_usage("D:/").used / shutil.disk_usage("D:/").total * 100
        )

    now = datetime.datetime.now()
    date_str = now.strftime("%a, %d %b")
    time_str = now.strftime("%H:%M")

    for t in threads:
        t.join()

    admin_tag = f" {C_GOLD}(ADMIN){RESET}" if is_admin() else ""

    # --- UI RENDER ---
    print("")
    status_msg = (
        f"{C_GREEN}{ICON_WIFI} ONLINE"
        if data["online"]
        else f"{C_RED}{ICON_PLUG} OFFLINE"
    )

    # Header
    print(
        f"  {C_GRAY}┌─{RESET} {C_CYAN}{ICON_OS} {platform.system().upper()}{RESET}{admin_tag}"
    )
    print(f"  {C_GRAY}│{RESET} Welcome, {C_MAGENTA}@{data['handle']}{RESET}")
    print(
        f"  {C_GRAY}│{RESET} {ICON_TIME} {date_str} {C_GRAY}|{RESET} {C_GOLD}{time_str}{RESET} {C_GRAY}|{RESET} {status_msg}{RESET}"
    )
    print(f"  {C_GRAY}│{RESET}")

    # Performance
    temp_str = f"{C_GOLD}{cpu_temp}°C{RESET}" if cpu_temp else f"{C_GRAY}N/A{RESET}"
    print(
        f"  {C_GRAY}│{RESET} {ICON_CPU} CPU: {draw_bar(cpu_load)} {C_GRAY}|{RESET} {ICON_TEMP} {temp_str}"
    )
    print(
        f"  {C_GRAY}│{RESET} {ICON_RAM} RAM: {draw_bar(mem.percent)} {C_GRAY}|{RESET} {C_GRAY}{int(mem.used / 1024**3)}G/{int(mem.total / 1024**3)}G{RESET}"
    )
    print(f"  {C_GRAY}│{RESET}")

    # Storage
    warn_c = f" {C_RED}{BOLD}[CRITICAL]{RESET}" if disk_c > 95 else ""
    print(
        f"  {C_GRAY}│{RESET} {ICON_DISK} C: {draw_bar(disk_c)} {C_GRAY}(Sys){RESET}{warn_c}"
    )
    if Path("E:/").exists():
        print(
            f"  {C_GRAY}│{RESET} {ICON_DISK} E: {draw_bar(disk_e)} {C_GRAY}(Data){RESET}"
        )
    print(f"  {C_GRAY}│{RESET}")
    if Path("D:/").exists():
        print(
            f"  {C_GRAY}│{RESET} {ICON_DISK} D: {draw_bar(disk_d)} {C_GRAY}(Data){RESET}"
        )
    print(f"  {C_GRAY}│{RESET}")

    # Projects
    print(f"  {C_GRAY}├─{RESET} {C_GOLD}RECENT PROJECTS (E:){RESET}")
    if data["projects"]:
        for p in data["projects"]:
            print(
                f"  {C_GRAY}│{RESET}  {C_CYAN}{ICON_DIR} {p['name'].ljust(25)}{RESET} {C_GRAY}{get_relative_time(p['time'])}{RESET}"
            )
    else:
        print(f"  {C_GRAY}│  {C_GRAY}No git repos found.{RESET}")
    print(f"  {C_GRAY}│{RESET}")

    # GitHub
    if data["online"]:
        print(f"  {C_GRAY}├─{RESET} {C_GOLD}PULL REQUESTS{RESET}")
        if data["prs"]:
            for line in data["prs"]:
                print(format_gh_line(line, ICON_PR))
        else:
            print(f"  {C_GRAY}│  {C_GREEN}✓ No open PRs{RESET}")

        print(f"  {C_GRAY}│{RESET}")
        print(f"  {C_GRAY}├─{RESET} {C_GOLD}ISSUES{RESET}")
        if data["issues"]:
            for line in data["issues"]:
                print(format_gh_line(line, ICON_BUG))
        else:
            print(f"  {C_GRAY}│  {C_GREEN}✓ No pending issues{RESET}")
    else:
        print(f"  {C_GRAY}├─{RESET} {C_RED}GITHUB DISCONNECTED{RESET}")

    print(
        f"  {C_GRAY}└──────────────────────────────────────────────────────────{RESET}\n"
    )


if __name__ == "__main__":
    show_dashboard()
