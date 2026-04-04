import winreg
import ctypes


def reset_python_aliases():
    # The path where Windows stores the toggle state for App Aliases
    path = r"Software\Microsoft\Windows\CurrentVersion\App Paths"
    alias_key_path = r"Software\Microsoft\Windows\CurrentVersion\AppExecutionAlias"

    targets = ["python.exe", "python3.exe", "py.exe"]

    print("--- Resetting Python Execution Aliases ---")

    for target in targets:
        try:
            # 1. Kill the Registry entries for the aliases to force a reset
            full_path = f"{alias_key_path}\\{target}"
            with winreg.OpenKey(
                winreg.HKEY_CURRENT_USER, alias_key_path, 0, winreg.KEY_ALL_ACCESS
            ) as key:
                try:
                    winreg.DeleteKey(key, target)
                    print(f"[+] Reset metadata for {target}")
                except FileNotFoundError:
                    print(f"[-] {target} alias not found in registry, skipping...")
        except Exception as e:
            print(f"[!] Error processing {target}: {e}")

    # 2. Force a refresh of the environment strings
    # This tells Windows to broadcast a 'Settings Change' message
    print("[*] Broadcasting system change notification...")
    HWND_BROADCAST = 0xFFFF
    WM_SETTINGCHANGE = 0x001A
    SMTO_ABORTIFHUNG = 0x0002
    result = ctypes.c_long()

    ctypes.windll.user32.SendMessageTimeoutW(
        HWND_BROADCAST,
        WM_SETTINGCHANGE,
        0,
        "Environment",
        SMTO_ABORTIFHUNG,
        5000,
        ctypes.byref(result),
    )

    print("\nDone. Please close this terminal and open a new one.")
    print(
        "If 'py' still fails, the Store stubs are likely corrupted beyond a soft reset."
    )


if __name__ == "__main__":
    reset_python_aliases()
