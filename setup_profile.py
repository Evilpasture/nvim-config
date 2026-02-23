import subprocess
import json
from pathlib import Path
import os

# ==========================================================================
# 1. DEFINE YOUR TERMINAL SETTINGS
# ==========================================================================
TERMINAL_SETTINGS = {
    "$help": "https://aka.ms/terminal-documentation",
    "$schema": "https://aka.ms/terminal-profiles-schema-preview",
    "actions": [],
    "compatibility.allowHeadless": True,
    "copyFormatting": "none",
    "copyOnSelect": False,
    "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
    "keybindings": [
        {"id": "Terminal.CopyToClipboard", "keys": "ctrl+c"},
        {"id": "Terminal.PasteFromClipboard", "keys": "ctrl+v"},
        {"id": "Terminal.DuplicatePaneAuto", "keys": "alt+shift+d"}
    ],
    "profiles": {
        "defaults": {},
        "list": [
            {
                "commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -NoLogo -ExecutionPolicy Bypass",
                "cursorShape": "vintage",
                "elevate": False,
                "experimental.retroTerminalEffect": True,
                "font": {"cellWidth": "0.65", "face": "JetBrainsMono Nerd Font Mono", "size": 14},
                "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
                "hidden": False,
                "historySize": 30000,
                "name": "Windows PowerShell",
                "opacity": 80,
                "scrollbarState": "hidden",
                "useAcrylic": True
            }
        ]
    }
}

# ==========================================================================
# 2. INSTALL WINDOWS TERMINAL SETTINGS
# ==========================================================================
def setup_terminal():
    local_app_data = Path(os.environ["LOCALAPPDATA"])
    
    # Pathlib syntax: local_app_data / "Folder" / "File"
    wt_paths = [
        local_app_data / "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
        local_app_data / "Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    ]

    installed = False
    for path in wt_paths:
        if path.parent.exists():
            # Backup
            if path.exists():
                path.with_suffix(".json.bak").write_bytes(path.read_bytes())
                print(f"✓ Backed up: {path.name}.bak")
            
            # Write new settings
            path.write_text(json.dumps(TERMINAL_SETTINGS, indent=4), encoding="utf-8")
            print(f"✓ Applied settings to: {path}")
            installed = True
    
    if not installed:
        print("! Windows Terminal settings folder not found.")

# ==========================================================================
# 3. SETUP POWERSHELL PROFILE
# ==========================================================================
def setup_powershell():
    # Use Path.cwd() for current directory
    custom_profile_path = Path(__file__).parent / "profile.ps1"

    try:
        # We still need PS to tell us where its specific profile lives
        ps_path_str = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", "echo $PROFILE"], 
            text=True
        ).strip()
        
        real_profile = Path(ps_path_str)
        real_profile.parent.mkdir(parents=True, exist_ok=True)

        # Write the pointer line (e.g., . "C:\path\to\your\profile.ps1")
        # .as_posix() ensures we use / even on Windows, which PS handles fine
        pointer_content = f'. "{custom_profile_path.absolute()}"'
        real_profile.write_text(pointer_content, encoding="utf-8-sig")
        
        print(f"✓ PowerShell profile pointer created at: {real_profile}")
    except Exception as e:
        print(f"! Failed PowerShell setup: {e}")

if __name__ == "__main__":
    setup_terminal()
    setup_powershell()
    print("\n[FINISH] Environment linked. Restart your terminal.")
