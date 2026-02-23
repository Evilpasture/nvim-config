import subprocess
import platform
import datetime
import threading
import os
import shutil
import sys

# Try to import the manager, handle gracefully if missing
try:
    from terminal_manager import TerminalManager
    HAS_MANAGER = True
except ImportError:
    HAS_MANAGER = False

# ==============================================================================
# 1. THEME & CONSTANTS
# ==============================================================================
# ANSI 256-Color Palette (Matches your Prompt)
E = "\033["
RESET = f"{E}0m"
BOLD = f"{E}1m"

# Colors
C_GRAY    = f"{E}38;5;240m"  # Dark Gray (Borders)
C_WHITE   = f"{E}38;5;250m"  # Text
C_CYAN    = f"{E}38;5;39m"   # Accents
C_GOLD    = f"{E}38;5;214m"  # Warnings / Highlights
C_GREEN   = f"{E}38;5;78m"   # Success
C_MAGENTA = f"{E}38;5;170m"  # Git / Special

# Icons (Nerd Font)
ICON_OS   = ""
ICON_DISK = "󰋊"
ICON_GIT  = ""
ICON_PR   = ""
ICON_BUG  = ""
ICON_TIME = ""

# ==============================================================================
# 2. HELPER FUNCTIONS
# ==============================================================================
def draw_bar(percent, width=20):
    """Draws a progress bar using block characters"""
    fill_len = int(width * percent / 100)
    empty_len = width - fill_len
    
    # Color logic: Green -> Gold -> Red based on fullness
    color = C_GREEN
    if percent > 70: color = C_GOLD
    if percent > 90: color = f"{E}38;5;196m" # Red
    
    bar = f"{color}{'█' * fill_len}{C_GRAY}{'░' * empty_len}{RESET}"
    return f"{bar} {color}{percent}%{RESET}"

def get_gh_data(command):
    try:
        # Run command and decode
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT).decode("utf-8").strip()
        if not output: return []
        return output.split('\n')
    except:
        return []

def clean_gh_line(line, is_pr=True):
    """Parses raw GH output into something pretty"""
    # Raw format is usually: repo/name  #123  Title...
    parts = line.split('\t')
    
    if len(parts) < 3: return f"  {C_GRAY}•{RESET} {line}"

    # Extract useful bits
    repo = parts[0]
    number = parts[1]
    title = parts[2]
    
    icon = ICON_PR if is_pr else ICON_BUG
    return f"  {C_MAGENTA}{icon} {number}{RESET} {C_WHITE}{title[:50].ljust(50)}{RESET} {C_GRAY}({repo}){RESET}"

def get_github_username():
    """Retrieves the logged-in GitHub username from local config (instant)"""
    try:
        # Check local config first (fastest)
        username = subprocess.check_output(
            'gh config get -h github.com user', 
            shell=True, stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        
        if username:
            return username
            
        # Fallback to API if config is empty
        username = subprocess.check_output(
            'gh api user --jq .login', 
            shell=True, stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        
        return username
    except:
        # Final fallback to Windows username if GH is not configured
        return os.environ.get('USERNAME', 'User')


# ==============================================================================
# 3. LOGIC CONTROLLERS
# ==============================================================================
def auto_adjust_terminal():
    if not HAS_MANAGER: return

    manager = TerminalManager()
    hour = datetime.datetime.now().hour
    
    # NIGHT MODE (20:00 - 06:00): Darker, Retro effects ON
    if hour >= 20 or hour <= 6:
        manager.update_profile("PowerShell", opacity=85, experimental_retroTerminalEffect=True)
        return "NIGHT"
    # DAY MODE: Brighter, Sharp text
    else:
        manager.update_profile("PowerShell", opacity=95, experimental_retroTerminalEffect=False)
        return "DAY"

def show_dashboard():
    # 1. Trigger Theme Update
    mode = auto_adjust_terminal()
    
    # 2. Start Async GitHub Fetch
    results = {'prs': [], 'issues': []}
    
    # We use 'view' or list with tab separation for easier parsing
    pr_cmd = 'gh search prs --author "@me" --state open --limit 3'
    issue_cmd = 'gh search issues --author "@me" --state open --limit 3'
    
    t1 = threading.Thread(target=lambda: results.update({'prs': get_gh_data(pr_cmd)}))
    t2 = threading.Thread(target=lambda: results.update({'issues': get_gh_data(issue_cmd)}))
    t1.start()
    t2.start()

    # 3. Calculate System Stats (While waiting)
    total, used, free = shutil.disk_usage("C:/")
    disk_percent = int((used / total) * 100)
    
    now = datetime.datetime.now()
    date_str = now.strftime("%A, %d %B")
    time_str = now.strftime("%H:%M")
    
    # Greeting
    if now.hour < 12: greeting = "Good Morning"
    elif now.hour < 18: greeting = "Good Afternoon"
    else: greeting = "Good Evening"
    
    github_user = get_github_username()

    # ==========================================================================
    # 4. RENDER UI
    # ==========================================================================
    print("") 
    
    # --- HEADER ---
    print(f"  {C_GRAY}┌─{RESET} {C_CYAN}{ICON_OS} SYSTEM STATUS{RESET}")
    print(f"  {C_GRAY}│{RESET} {C_WHITE}{greeting}, {C_MAGENTA}@{github_user}{RESET}") 
    print(f"  {C_GRAY}│{RESET} {ICON_TIME} {date_str} {C_GRAY}|{RESET} {C_GOLD}{time_str}{RESET}")
    
    # --- DISK USAGE ---
    print(f"  {C_GRAY}│{RESET} {ICON_DISK} C: {draw_bar(disk_percent)}")
    
    # Wait for threads
    t1.join()
    t2.join()

    print(f"  {C_GRAY}│{RESET}")

    # --- PULL REQUESTS ---
    print(f"  {C_GRAY}├─{RESET} {C_GOLD}OPEN PULL REQUESTS{RESET}")
    if results['prs']:
        for line in results['prs']:
            print(clean_gh_line(line, is_pr=True))
    else:
        print(f"  {C_GRAY}│  {C_GREEN}✓ All caught up! No open PRs.{RESET}")

    print(f"  {C_GRAY}│{RESET}")

    # --- ISSUES ---
    print(f"  {C_GRAY}├─{RESET} {C_GOLD}PENDING ISSUES{RESET}")
    if results['issues']:
        for line in results['issues']:
             print(clean_gh_line(line, is_pr=False))
    else:
        print(f"  {C_GRAY}│  {C_GREEN}✓ Clear. No assigned issues.{RESET}")

    # --- FOOTER ---
    # Draw a footer line
    print(f"  {C_GRAY}└──────────────────────────────────────────────────────────{RESET}")
    print("")

if __name__ == "__main__":
    show_dashboard()
