import json
import os
from pathlib import Path

class TerminalManager:
    def __init__(self):
        self.path = self._find_settings_path()
        self.data = self._load_settings()

    def _find_settings_path(self):
        """Locates the active Windows Terminal settings file."""
        local = Path(os.environ["LOCALAPPDATA"])
        paths = [
            local / "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
            local / "Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
        ]
        for p in paths:
            if p.exists():
                return p
        raise FileNotFoundError("Could not locate Windows Terminal settings.json")

    def _load_settings(self):
        with open(self.path, 'r', encoding='utf-8') as f:
            return json.load(f)

    def save(self):
        """Commits changes to disk."""
        with open(self.path, 'w', encoding='utf-8') as f:
            json.dump(self.data, f, indent=4)
        print(f"✓ Terminal settings updated at {self.path.name}")

    def update_profile(self, name_query="PowerShell", **kwargs):
        """
        Updates specific keys for profiles matching name_query.
        Usage: manager.update_profile("PowerShell", opacity=50, cursorShape="bar")
        """
        updated = False
        # profiles can be a list or a dict with a 'list' key
        profiles = self.data.get('profiles', {})
        profile_list = profiles.get('list', []) if isinstance(profiles, dict) else []

        for profile in profile_list:
            if name_query.lower() in profile.get('name', '').lower():
                for key, value in kwargs.items():
                    profile[key] = value
                updated = True
        
        if updated:
            self.save()
        else:
            print(f"! No profile found matching '{name_query}'")

    def set_global(self, **kwargs):
        """Updates top-level settings (theme, focus mode, etc.)"""
        for key, value in kwargs.items():
            self.data[key] = value
        self.save()

# ==========================================================================
# Example Usage (CLI)
# ==========================================================================
if __name__ == "__main__":
    import sys
    
    manager = TerminalManager()
    
    # Example: python term_manager.py 50 True
    if len(sys.argv) > 2:
        opacity = int(sys.argv[1])
        retro = sys.argv[2].lower() == 'true'
        manager.update_profile("PowerShell", **{"experimental.retroTerminalEffect": False})
    else:
        print("Usage: python term_manager.py [opacity] [retro_bool]")
