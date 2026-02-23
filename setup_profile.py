import os
import json
import shutil
import subprocess
from pathlib import Path

# ==========================================================================
# CONFIGURATION
# ==========================================================================
# The "Bloom + Scanline" Shader Code
NEON_SHADER_CONTENT = r"""
Texture2D shaderTexture : register(t0);
SamplerState samplerState : register(s0);

cbuffer PixelShaderSettings : register(b0) {
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

float hash(float n) {
    return frac(sin(n) * 43758.5453123);
}

float4 main(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    
    // --------------------------------------------------------
    // 0. WARM-UP CYCLE
    // --------------------------------------------------------
    // Prevents effects from exploding immediately at launch.
    // Effects fade in over the first 10 seconds.
    float warmup = saturate(Time / 10.0);

    // --------------------------------------------------------
    // 1. BASE CURVATURE
    // --------------------------------------------------------
    float2 centeredUV = uv * 2.0 - 1.0;
    float2 offset = abs(centeredUV.yx) / float2(5.0, 4.0); 
    centeredUV = centeredUV + centeredUV * offset * offset;
    float2 curvedUV = centeredUV * 0.5 + 0.5;

    if (curvedUV.x < 0.0 || curvedUV.x > 1.0 || curvedUV.y < 0.0 || curvedUV.y > 1.0) {
        return float4(0, 0, 0, 1);
    }

    // --------------------------------------------------------
    // 2. DEGAUSS EFFECT (Fixed)
    // --------------------------------------------------------
    float degaussTime = fmod(Time, 60.0);
    
    // FIX: Only allow degauss if the terminal has been open for > 10 seconds
    if (degaussTime < 1.0 && Time > 10.0) {
        float decay = (1.0 - degaussTime);
        float shakeX = sin(degaussTime * 150.0) * decay * 0.015;
        float shakeY = cos(degaussTime * 140.0) * decay * 0.015;
        curvedUV += float2(shakeX, shakeY);
    }

    // --------------------------------------------------------
    // 3. MAGNETIC INTERFERENCE (With Warmup)
    // --------------------------------------------------------
    float2 magnetPos = float2(
        0.5 + 0.35 * cos(Time * 0.4), 
        0.5 + 0.25 * sin(Time * 0.9)
    );

    float distToMagnet = distance(curvedUV, magnetPos);
    float inField = 1.0 - smoothstep(0.0, 0.25, distToMagnet); 
    float magnetStrength = 0.0;
    
    if (inField > 0.0) {
        // Multiply by warmup so magnet doesn't warp text instantly on launch
        magnetStrength = inField * 0.03 * warmup; 
        curvedUV += (magnetPos - curvedUV) * magnetStrength;
    }

    // --------------------------------------------------------
    // 4. JITTER & COLOR SAMPLING
    // --------------------------------------------------------
    float timeBlock = floor(Time * 8.0);
    float diceRoll = hash(timeBlock);
    float isGlitching = step(0.98, diceRoll);
    
    // Apply warmup to glitch too
    float jitter = isGlitching * sin(Time * 250.0) * 0.003 * warmup;

    // Base Aberration
    float2 centerDist = curvedUV - 0.5;
    float aberrationAmt = dot(centerDist, centerDist) * 0.0025;
    
    // Add Magnetic Shift
    aberrationAmt += magnetStrength * 0.05;

    // Degauss Color Swirl (Only after 10s)
    if (degaussTime < 1.0 && Time > 10.0) {
        aberrationAmt += (1.0 - degaussTime) * 0.05; 
    }

    // Sample Texture
    float3 color;
    color.r = shaderTexture.Sample(samplerState, curvedUV + float2(aberrationAmt + jitter, 0)).r * 1.35;
    color.g = shaderTexture.Sample(samplerState, curvedUV + float2(jitter, 0)).g * 1.35;
    color.b = shaderTexture.Sample(samplerState, curvedUV - float2(aberrationAmt - jitter, 0)).b * 1.35;

    // --------------------------------------------------------
    // 5. SCANLINES & PHOSPHORS
    // --------------------------------------------------------
    float pulse = 1.0 + (0.15 * sin(Time * 1.2)); 
    float scanline = sin(curvedUV.y * Resolution.y * 3.14159);
    scanline = 0.5 + 0.5 * scanline;
    
    float brightness = dot(color, float3(0.299, 0.587, 0.114));
    float scanlineIntensity = lerp(0.08 * pulse, 0.0, brightness); 
    color -= scanlineIntensity * scanline;

    // Aperture Grille
    float xPos = curvedUV.x * Resolution.x;
    float3 mask = float3(1.0, 1.0, 1.0);
    mask.r = 0.8 + 0.2 * cos(xPos * 6.28); 
    mask.g = 0.8 + 0.2 * cos((xPos + 0.33) * 6.28);
    mask.b = 0.8 + 0.2 * cos((xPos + 0.66) * 6.28);
    color *= mask;

    // --------------------------------------------------------
    // 6. BLOOM & VIGNETTE
    // --------------------------------------------------------
    float2 pixelSize = 1.0 / Resolution;
    float3 glow = 0;
    glow += shaderTexture.Sample(samplerState, curvedUV + float2(-pixelSize.x, 0)).rgb;
    glow += shaderTexture.Sample(samplerState, curvedUV + float2(pixelSize.x, 0)).rgb;
    glow += shaderTexture.Sample(samplerState, curvedUV + float2(0, -pixelSize.y)).rgb;
    glow += shaderTexture.Sample(samplerState, curvedUV + float2(0, pixelSize.y)).rgb;
    
    color += (glow * 0.25 * pulse); 

    // Vignette
    float vignette = curvedUV.x * curvedUV.y * (1.0 - curvedUV.x) * (1.0 - curvedUV.y);
    vignette = saturate(pow(16.0 * vignette, 0.15)); 
    
    // --------------------------------------------------------
    // 7. POST-PROCESS
    // --------------------------------------------------------
    float flicker = 0.98 + 0.02 * sin(Time * 120.0);
    float noise = (hash(curvedUV.x + (curvedUV.y * 100.0) + (Time * 10.0)) - 0.5) * 0.04;
    
    color *= flicker;
    color += noise;

    return float4(saturate(color * vignette), 1.0);
}
"""

class TerminalManager:
    def __init__(self):
        self.path = self._find_settings_path()
        self.data = self._load_settings()

    def _find_settings_path(self):
        local = Path(os.environ["LOCALAPPDATA"])
        # Check Stable then Preview
        paths = [
            local / "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
            local / "Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
        ]
        for p in paths:
            if p.exists():
                return p
        raise FileNotFoundError("Could not find Windows Terminal settings.json")

    def _load_settings(self):
        # Create backup
        if not self.path.with_suffix(".json.bak").exists():
            shutil.copy2(self.path, self.path.with_suffix(".json.bak"))
            print(f"📦 Backup created at {self.path.name}.bak")
            
        with open(self.path, 'r', encoding='utf-8') as f:
            return json.load(f)

    def save(self):
        with open(self.path, 'w', encoding='utf-8') as f:
            json.dump(self.data, f, indent=4)
        print(f"💾 Settings saved to {self.path}")

    def update_profile(self, name_query, **kwargs):
        """Intelligently updates a profile without overwriting other keys"""
        profiles = self.data.get('profiles', {})
        # Handle both list and dict structures in newer WT versions
        p_list = profiles.get('list', []) if isinstance(profiles, dict) else profiles

        updated_count = 0
        for profile in p_list:
            # Match "PowerShell", "Windows PowerShell", "pwsh", etc.
            if name_query.lower() in profile.get('name', '').lower():
                for key, value in kwargs.items():
                    profile[key] = value
                updated_count += 1
        
        if updated_count > 0:
            print(f"✨ Updated {updated_count} profile(s) matching '{name_query}'")
            self.save()
        else:
            print(f"⚠️ No profile found matching '{name_query}'")

def install_shader():
    # Create a 'shaders' folder relative to this script
    base_dir = Path(__file__).parent
    shader_dir = base_dir / "shaders"
    shader_dir.mkdir(exist_ok=True)
    
    shader_file = shader_dir / "neon.hlsl"
    shader_file.write_text(NEON_SHADER_CONTENT, encoding="utf-8")
    
    print(f"🎨 Shader file created at: {shader_file}")
    return shader_file.absolute()

def link_powershell_profile():
    # Current script directory
    base_dir = Path(__file__).parent
    custom_profile = base_dir / "profile.ps1"
    
    if not custom_profile.exists():
        print("❌ Error: profile.ps1 not found in this folder!")
        return

    try:
        # Ask PowerShell where the 'Real' profile is
        ps_path_str = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", "echo $PROFILE"], 
            text=True
            ).strip()
        
        real_profile = Path(ps_path_str)
        real_profile.parent.mkdir(parents=True, exist_ok=True)

        # CRITICAL: Write with UTF-8 BOM ('utf-8-sig') for Windows PowerShell 5.1 compatibility
        pointer_content = f'. "{custom_profile}"'
        real_profile.write_text(pointer_content, encoding="utf-8-sig")
        
        print(f"🔗 PowerShell profile linked successfully to: {real_profile}")
    except Exception as e:
        print(f"❌ Failed to link PowerShell: {e}")


def make_borderless():
    # 1. Locate Settings
    local_app_data = Path(os.environ["LOCALAPPDATA"])
    wt_paths = [
        local_app_data / "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
        local_app_data / "Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    ]
    
    settings_path = None
    for p in wt_paths:
        if p.exists():
            settings_path = p
            break
            
    if not settings_path:
        print("X Settings.json not found.")
        return

    # 2. Load
    with open(settings_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 3. Apply Borderless Settings
    # A. Global settings
    data["launchMode"] = "maximized" # Always start big
    
    # B. Profile settings (Padding)
    updated = False
    for profile in data['profiles']['list']:
        if "PowerShell" in profile.get('name', ''):
            # "0" removes the gap between the window edge and the text
            profile["padding"] = "0" 
            updated = True

    # 4. Save
    if updated:
        with open(settings_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4)
        print("✓ Padding removed (Border is gone).")
        print("✓ Launch mode set to Maximized.")
    else:
        print("! PowerShell profile not found.")


def main():
    print("--- 🚀 STARTING TERMINAL SETUP ---")
    
    # 1. Install Shader
    shader_path = install_shader()
    make_borderless()
    # 2. Update Terminal JSON
    try:
        manager = TerminalManager()
        
        # We update PowerShell profiles to use the Shader, Font, and Acrylic
        manager.update_profile("PowerShell", **{
            "font": {"face": "JetBrainsMono Nerd Font Mono", "size": 13},
            "opacity": 90, 
            "useAcrylic": True,
            "experimental.pixelShaderPath": str(shader_path).replace("\\", "/"), # JSON prefers forward slashes
            "experimental.retroTerminalEffect": False # Turn off built-in retro to use our shader
        })
        
    except FileNotFoundError as e:
        print(f"❌ {e}")
    except Exception as e:
        print(f"❌ Unexpected error updating JSON: {e}")

    # 3. Link Profile
    link_powershell_profile()
    
    print("\n✅ SETUP COMPLETE!")
    print("👉 Please restart Windows Terminal.")

if __name__ == "__main__":
    main()
