import os
import subprocess

# 1. Get the path to your current custom profile
current_dir = os.path.dirname(os.path.abspath(__file__))
custom_profile = os.path.join(current_dir, "profile.ps1")

# 2. Ask PowerShell where the "Real" profile path is
pwsh_profile_path = subprocess.check_output(
    ["powershell", "-NoProfile", "-Command", "echo $PROFILE"], 
    text=True
).strip()

# 3. Create the directory if it doesn't exist (it usually doesn't on fresh PCs)
os.makedirs(os.path.dirname(pwsh_profile_path), exist_ok=True)

# 4. Write the "Pointer" line
with open(pwsh_profile_path, "w") as f:
    f.write(f'. "{custom_profile}"')

print(f"DONE: Windows is now sourcing your config from {custom_profile}")
