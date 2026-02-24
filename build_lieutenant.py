import wave
import struct
import math
import os
import subprocess
import time
import sys

# ============================================================
# 1. THE COOK: AUDIO GENERATION
# ============================================================

def generate_beep(filename, start_freq, end_freq, duration_ms, volume=0.2):
    """Generates a vintage square-wave beep with pitch decay."""
    sample_rate = 44100
    num_samples = int(sample_rate * (duration_ms / 1000.0))
    
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    with wave.open(filename, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = i / sample_rate
            progress = i / num_samples
            
            # Pitch Decay (Chirp)
            current_freq = start_freq + (end_freq - start_freq) * progress
            phase = 2 * math.pi * current_freq * t
            
            # Square wave logic
            value = 32767 * volume * (1 if math.sin(phase) > 0 else -1)
            
            # Attack and Decay Envelope
            attack_samples = int(sample_rate * 0.002)
            if i < attack_samples:
                envelope = i / attack_samples
            else:
                envelope = math.exp(-progress * 10) # Natural exponential decay
            
            f.writeframes(struct.pack('<h', int(value * envelope)))

def cook_sounds():
    """Defines and generates the sound palette."""
    print("[*] Cooking sound palette...")
    palette = {
        'sounds/click.wav':  (1200, 800, 25, 0.15),
        'sounds/space.wav':  (600, 400, 45, 0.20),
        'sounds/enter.wav':  (300, 150, 100, 0.25),
    }
    for path, params in palette.items():
        generate_beep(path, *params)
    print("[+] Audio assets cooked.")

# ============================================================
# 2. THE BUILD: COMPILATION & DAEMON MANAGEMENT
# ============================================================

def build_and_start():
    exe_name = "clicker.exe"
    build_dir = "build"
    
    print(f"[*] Terminating existing {exe_name} instances...")
    subprocess.run(["taskkill", "/F", "/IM", exe_name, "/T"], 
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    time.sleep(0.5) # Wait for Windows to release file handles
    if not os.path.exists(os.path.join(build_dir, "CMakeCache.txt")):
        print("[*] Initializing CMake configuration (Clang + Ninja)...")
        os.makedirs(build_dir, exist_ok=True)
        
        # Explicitly pointing to clang-cl and Ninja
        config_cmd = [
            "cmake", "-S", ".", "-B", build_dir,
            "-G", "Ninja",
            "-DCMAKE_C_COMPILER=clang", # or "clang" depending on your PATH
            "-DCMAKE_BUILD_TYPE=Release"
        ]
        
        config_result = subprocess.run(config_cmd)
        if config_result.returncode != 0:
            print("[!] Configuration FAILED. Ensure Ninja and Clang are in your PATH.")
            sys.exit(1)
    # -------------------------------
    print("[*] Running CMake build...")
    build_result = subprocess.run(["cmake", "--build", build_dir, "--config", "Release"])

    if build_result.returncode != 0:
        print("\n[!] Build FAILED.")
        sys.exit(1)

    # Path detection for the compiled binary
    potential_paths = [
        os.path.join(os.getcwd(), exe_name),
        os.path.join(os.getcwd(), build_dir, exe_name),
        os.path.join(os.getcwd(), build_dir, "Release", exe_name)
    ]

    target_exe = next((p for p in potential_paths if os.path.exists(p)), None)

    if target_exe:
        print(f"[*] Launching {target_exe}...")
        subprocess.Popen(
            [target_exe],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL,
            creationflags=subprocess.DETACHED_PROCESS,
            close_fds=True
        )
        print("[+] Success! Sound daemon is active.")
    else:
        print("[!] clicker.exe not found.")

# ============================================================
# 3. ENTRY POINT
# ============================================================

if __name__ == "__main__":
    # If run normally, do the full cycle
    cook_sounds()
    build_and_start()
