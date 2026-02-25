import subprocess
import platform
import datetime
import threading
import shutil
import os
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


# ==============================================================================
# 2. HELPER FUNCTIONS
# ==============================================================================
def draw_bar(percent, width=15):
    fill_len = int(width * percent / 100)
    empty_len = width - fill_len
    color = C_GREEN if percent < 75 else (C_GOLD if percent < 90 else C_RED)
    return f"{color}{'█' * fill_len}{C_GRAY}{'░' * empty_len}{RESET} {color}{str(percent).rjust(3)}%{RESET}"


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
    """Runs a GH search command and returns lines"""
    try:
        # Use --limit to keep it fast, results are tab-separated by default in gh search
        out = (
            subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
            .decode("utf-8")
            .strip()
        )
        return out.split("\n") if out else []
    except:
        return []


def format_gh_line(line, icon):
    """Parses 'repo/name  #number  title' format from gh search"""
    # GH Search outputs: REPO    ID    TITLE    LABELS    UPDATED_AT
    parts = line.split("\t")
    if len(parts) < 3:
        return f"  {C_GRAY}│{RESET}  {C_GRAY}• {line[:50]}{RESET}"

    repo = parts[0].split("/")[-1]  # just the repo name
    num = parts[1]
    title = parts[2]

    # Truncate title to keep UI clean
    clean_title = (title[:40] + "..") if len(title) > 40 else title.ljust(40)

    return f"  {C_GRAY}│{RESET}  {C_MAGENTA}{icon} {num.ljust(6)}{RESET} {C_WHITE}{clean_title}{RESET} {C_GRAY}({repo}){RESET}"


# ==============================================================================
# 3. MAIN RENDERER
# ==============================================================================
def show_dashboard():
    # 1. Background Tasks
    data = {"prs": [], "issues": [], "projects": [], "online": False, "handle": "..."}

    # GLOBAL SEARCH: finds items authored by you or assigned to you across all repos
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

    # 2. System Stats (Sync)
    total_c, used_c, _ = shutil.disk_usage("C:/")
    disk_c = int((used_c / total_c) * 100)
    disk_e = 0
    if Path("E:/").exists():
        total_e, used_e, _ = shutil.disk_usage("E:/")
        disk_e = int((used_e / total_e) * 100)

    now = datetime.datetime.now()
    date_str = now.strftime("%a, %d %b")
    time_str = now.strftime("%H:%M")

    for t in threads:
        t.join()

    # 3. Render UI
    print("")
    status_msg = (
        f"{C_GREEN}{ICON_WIFI} ONLINE"
        if data["online"]
        else f"{C_RED}{ICON_PLUG} OFFLINE"
    )

    # HEADER
    print(f"  {C_GRAY}┌─{RESET} {C_CYAN}{ICON_OS} {platform.system().upper()}{RESET}")
    print(f"  {C_GRAY}│{RESET} Welcome, {C_MAGENTA}@{data['handle']}{RESET}")
    print(
        f"  {C_GRAY}│{RESET} {ICON_TIME} {date_str} {C_GRAY}|{RESET} {C_GOLD}{time_str}{RESET} {C_GRAY}|{RESET} {status_msg}{RESET}"
    )
    print(f"  {C_GRAY}│{RESET}")

    # DISKS
    print(f"  {C_GRAY}│{RESET} {ICON_DISK} C: {draw_bar(disk_c)} {C_GRAY}(Sys){RESET}")
    if Path("E:/").exists():
        print(
            f"  {C_GRAY}│{RESET} {ICON_DISK} E: {draw_bar(disk_e)} {C_GRAY}(Data){RESET}"
        )
    print(f"  {C_GRAY}│{RESET}")

    # PROJECTS
    print(f"  {C_GRAY}├─{RESET} {C_GOLD}RECENT PROJECTS (E:){RESET}")
    if data["projects"]:
        for p in data["projects"]:
            print(
                f"  {C_GRAY}│{RESET}  {C_CYAN}{ICON_DIR} {p['name'].ljust(25)}{RESET} {C_GRAY}{get_relative_time(p['time'])}{RESET}"
            )
    else:
        print(f"  {C_GRAY}│  {C_GRAY}No git repos found in {PROJECT_ROOT}{RESET}")
    print(f"  {C_GRAY}│{RESET}")

    # GITHUB
    if data["online"]:
        # Pull Requests
        print(f"  {C_GRAY}├─{RESET} {C_GOLD}PULL REQUESTS{RESET}")
        if data["prs"]:
            for line in data["prs"]:
                print(format_gh_line(line, ICON_PR))
        else:
            print(f"  {C_GRAY}│  {C_GREEN}✓ No open PRs{RESET}")

        print(f"  {C_GRAY}│{RESET}")

        # Issues
        print(f"  {C_GRAY}├─{RESET} {C_GOLD}ISSUES{RESET}")
        if data["issues"]:
            for line in data["issues"]:
                print(format_gh_line(line, ICON_BUG))
        else:
            # Fallback check: if no assigned issues, check if user is author
            # (Sometimes people have issues they created but aren't assigned to)
            author_issues = get_gh_data(
                'gh search issues --author "@me" --state open --limit 3'
            )
            if author_issues:
                for line in author_issues:
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
