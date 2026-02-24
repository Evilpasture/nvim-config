import subprocess
import os
import time
import sys

def manage_clicker():
    exe_name = "clicker.exe"
    build_dir = "build"
    
    print(f"--- Automated Build Cycle for {exe_name} ---")

    # 1. Kill the existing process
    print(f"[*] Terminating existing {exe_name} instances...")
    subprocess.run(
        ["taskkill", "/F", "/IM", exe_name, "/T"], 
        stdout=subprocess.DEVNULL, 
        stderr=subprocess.DEVNULL
    )
    
    # Wait for file handle release
    time.sleep(0.5)

    # 2. Run the CMake Build
    print("[*] Running CMake build...")
    # Using shell=True for cmake on Windows can sometimes be more stable with paths
    build_result = subprocess.run(
        ["cmake", "--build", build_dir, "--config", "Release"],
        capture_output=False
    )

    if build_result.returncode != 0:
        print("\n[!] Build FAILED.")
        sys.exit(1)

    # 3. Find and Start the new binary
    potential_paths = [
        os.path.join(os.getcwd(), exe_name),
        os.path.join(os.getcwd(), build_dir, exe_name),
        os.path.join(os.getcwd(), build_dir, "Release", exe_name)
    ]

    target_exe = None
    for path in potential_paths:
        if os.path.exists(path):
            target_exe = path
            break

    if target_exe:
        print(f"[*] Starting {target_exe} in background...")
        
        # FIX: Removed CREATE_NEW_CONSOLE conflict.
        # Added DEVNULL redirection so the daemon doesn't try to use this terminal's IO.
        subprocess.Popen(
            [target_exe],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            creationflags=subprocess.DETACHED_PROCESS,
            close_fds=True
        )
        print("[+] Success! Daemon is detached and running.")
    else:
        print("[!] Could not find compiled clicker.exe.")

if __name__ == "__main__":
    manage_clicker()
