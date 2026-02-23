import subprocess
import platform
import datetime
import threading
import os
from terminal_manager import TerminalManager

# ANSI Colors
CYAN = "\033[96m"
YELLOW = "\033[93m"
GRAY = "\033[90m"
RESET = "\033[0m"

def get_gh_data(command):
    try:
        # Run command and decode
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT).decode("utf-8").strip()
        
        # Previously, .split('\n') on an empty string returned [''], which is "True" in Python.
        if not output:
            return []
            
        return output.split('\n')
    except Exception:
        return []


def auto_adjust_terminal():
    manager = TerminalManager()
    hour = datetime.datetime.now().hour
    
    # If it's late, make the terminal darker and turn on the retro vibe
    if hour >= 20 or hour <= 6:
        manager.update_profile("PowerShell", opacity=60, experimental_retroTerminalEffect=True)
    else:
        manager.update_profile("PowerShell", opacity=90, experimental_retroTerminalEffect=False)


def show_dashboard():
    auto_adjust_terminal()
    # Store results in a dictionary for thread safety
    results = {'prs': [], 'issues': []}
    
    pr_cmd = 'gh search prs --author "@me" --state open --limit 3'
    issue_cmd = 'gh search issues --author "@me" --state open --limit 3'
    
    # Define threading logic
    def fetch_prs(): results['prs'] = get_gh_data(pr_cmd)
    def fetch_issues(): results['issues'] = get_gh_data(issue_cmd)
    
    t1 = threading.Thread(target=fetch_prs)
    t2 = threading.Thread(target=fetch_issues)
    
    t1.start()
    t2.start()

    # System Info (Runs while GitHub commands are working)
    date_str = datetime.datetime.now().strftime("%A, %B %d | %H:%M")
    os_name = f"{platform.system()} {platform.release()}"
    computer_name = os.environ.get('COMPUTERNAME', 'Unknown')

    print(f"\n  {CYAN}{'-'*56}")
    print(f"  SYSTEM: {computer_name} | {date_str}")
    print(f"  {'-'*56}{RESET}")
    print(f"  {GRAY}💻 OS: {os_name}{RESET}")

    # Wait for threads
    t1.join()
    t2.join()

    # Pull Requests Section
    print(f"\n  {YELLOW}OPEN PULL REQUESTS (Global):{RESET}")
    if results['prs']: # This now correctly evaluates to False if list is empty
        for line in results['prs']: 
            print(f"     {line}")
    else:
        print(f"      {GRAY}All caught up!{RESET}")

    # Issues Section
    print(f"\n  {YELLOW}OPEN ISSUES (Global):{RESET}")
    if results['issues']:
        for line in results['issues']: 
            print(f"     {line}")
    else:
        print(f"      {GRAY}No pending issues.{RESET}")

    print(f"\n  {CYAN}{'-'*56}{RESET}\n")

if __name__ == "__main__":
    show_dashboard()
