import json
import os
from pathlib import Path

def switch_to_native_retro():
    # 1. Find the settings file
    local = Path(os.environ["LOCALAPPDATA"])
    paths = [
        local / "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
        local / "Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    ]
    
    settings_path = None
    for p in paths:
        if p.exists():
            settings_path = p
            break
            
    if not settings_path:
        print("Could not find Windows Terminal settings.")
        return

    # 2. Load Data
    with open(settings_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 3. Modify Profiles
    profiles = data.get('profiles', {})
    p_list = profiles.get('list', []) if isinstance(profiles, dict) else profiles

    updated = False
    for profile in p_list:
        # Target your PowerShell profile(s)
        if "PowerShell" in profile.get('name', ''):
            # CLEAR the custom shader path (removes the stripes)
            profile["experimental.pixelShaderPath"] = "" 
            
            # ENABLE the built-in CRT effect
            profile["experimental.retroTerminalEffect"] = True
            
            # Ensure transparency stays on
            profile["opacity"] = 85 
            profile["useAcrylic"] = True
            
            updated = True

    # 4. Save
    if updated:
        with open(settings_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4)
        print(f"✓ Reverted to Native Retro CRT effect in: {settings_path.name}")
        print("  (Stripes removed, readability restored)")
    else:
        print("No PowerShell profile found to update.")

if __name__ == "__main__":
    switch_to_native_retro()
