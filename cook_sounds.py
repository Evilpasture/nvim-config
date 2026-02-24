import wave
import struct
import math
import os

def generate_beep(filename, start_freq, end_freq, duration_ms, volume=0.3):
    sample_rate = 44100
    num_samples = int(sample_rate * (duration_ms / 1000.0))
    
    # Ensure directory exists
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    with wave.open(filename, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = i / sample_rate
            progress = i / num_samples
            
            # Linear frequency sweep (The Chirp)
            current_freq = start_freq + (end_freq - start_freq) * progress
            
            # Square wave logic
            phase = 2 * math.pi * current_freq * t
            value = 32767 * volume * (1 if math.sin(phase) > 0 else -1)
            
            # ADVANCED ENVELOPE:
            # 1. 2ms Fade-in (Prevents "sharp" digital pop)
            # 2. Smooth exponential Fade-out (Simulates energy loss)
            attack_samples = int(sample_rate * 0.002)
            if i < attack_samples:
                envelope = i / attack_samples
            else:
                envelope = math.exp(-progress * 10) # Exponential decay
            
            f.writeframes(struct.pack('<h', int(value * envelope)))

# ----------------------------------------------------------
# THE SOUND PALETTE (Adjusted for "Analog" feel)
# ----------------------------------------------------------

# CLICK: High-pitched chirp. Start at 1200Hz, drop to 800Hz. Very fast.
generate_beep('sounds/click.wav', 1200, 800, 25, 0.2)

# SPACE: Mid-range "thack". Start at 600Hz, drop to 400Hz.
generate_beep('sounds/space.wav', 600, 400, 45, 0.25)

# ENTER: Heavy low-end "clunk". Start at 300Hz, drop to 150Hz.
generate_beep('sounds/enter.wav', 300, 150, 100, 0.3)

print("Sound palette generated in /sounds")
