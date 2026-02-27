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

// ============================================================
// TUNING CONSTANTS
// ============================================================

// [ STATIC MAGNET SETTINGS ]
// 0.5, 0.5 is dead center. 
// Try 0.9, 0.9 to push the defect to the bottom-right corner.
static const float2 MAGNET_POS        = float2(0.5, 0.5); 

// How much the colors separate radially (The "Suck" difference)
static const float MAGNET_PULL_STR    = 1.0; 

// How much the colors twist (The "Swirl")
// Kept low for readability based on your feedback.
static const float MAGNET_SWIRL_AMT   = 0.005; 

// [ CHROMATIC ABERRATION (LENS) ]
static const float ABERRATION_SCALE   = 0.0018;
static const float SUBPIXEL_X         = 0.45; 
static const float SUBPIXEL_Y         = 0.15; 

// [ GLITCH & DISTORTION ]
static const float GLITCH_JITTER      = 0.002;

// [ MASKING & SCANLINES ]
static const float GRILLE_DEPTH       = 0.20;
static const float SCANLINE_DEPTH     = 0.08;

// [ POST-PROCESSING ]
static const float NOISE_AMP          = 0.04;
static const float BLOOM_AMT          = 0.15;


// ============================================================
// UTILITIES
// ============================================================
float IGN(float2 uv) {
    float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    return frac(magic.z * frac(dot(uv, magic.xy)));
}

float hash1(float n) {
    return frac(sin(n) * 43758.5453);
}


// ============================================================
// MAIN SHADER
// ============================================================
float4 main(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target {

    // ----------------------------------------------------------
    // 1. CRT GLASS CURVATURE
    // ----------------------------------------------------------
    float2 centeredUV = uv * 2.0 - 1.0;
    float2 offset = abs(centeredUV.yx) / float2(5.0, 4.0);
    centeredUV = centeredUV + centeredUV * offset * offset;
    float2 curvedUV = centeredUV * 0.5 + 0.5;

    if (any(curvedUV < 0.0) || any(curvedUV > 1.0)) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    float2 sampleUV = curvedUV;

    // ----------------------------------------------------------
    // 2. TIMING & GATING
    // ----------------------------------------------------------
    float degaussTime = fmod(Time, 60.0);    
    float warmup      = saturate(Time / 10.0); 

    // ----------------------------------------------------------
    // 3. PHYSICAL DEFORMATIONS
    // ----------------------------------------------------------

    // [A] DEGAUSS SHAKE
    if (degaussTime < 1.0 && Time > 5.0) {
        float decay  = 1.0 - degaussTime;
        float shakeX = sin(Time * 150.0) * decay * 0.010;
        float shakeY = cos(Time * 140.0) * decay * 0.010;
        sampleUV += float2(shakeX, shakeY);
    }

    // [B] OCCASIONAL TREMOR
    float randomSpike = pow(saturate(sin(Time * 0.7)), 40.0);
    float microTremor = sin(Time * 150.0) * randomSpike;

    // [C] STATIC MAGNET PHYSICS
    float2 magnetDelta = curvedUV - MAGNET_POS;
    float  distToMagnet = length(magnetDelta);

    // Calculate the raw "Pull Strength" based on distance
    float pullPower = 0.02 / (distToMagnet + 0.01);
    float inField   = saturate(pullPower);
    inField *= inField; // Exponential falloff

    float baseMagnetStrength = inField * (0.005 + 0.015 * microTremor) * warmup;
    
    // Create the Radial Vector (The Suck)
    float2 pullVector = magnetDelta * baseMagnetStrength * MAGNET_PULL_STR;

    // Create the Tangent Vector (The Swirl)
    float swirlPower = smoothstep(0.4, 0.0, distToMagnet) * warmup;
    float2 magnetTangent = float2(-magnetDelta.y, magnetDelta.x) / (distToMagnet + 0.001);
    float2 swirlVector = magnetTangent * swirlPower * MAGNET_SWIRL_AMT;

    // [D] HORIZONTAL HOLD JITTER
    float scanlineID   = floor(curvedUV.y * Resolution.y * 0.5);
    float snap         = hash1(scanlineID + floor(Time * 12.0));
    float interference = (snap - 0.5) * 0.0004;
    sampleUV.x += interference * (0.3 + microTremor * 10.0);


    // ----------------------------------------------------------
    // 4. CHROMATIC SPLIT (THE "SUCK" DIFFERENTIAL)
    // ----------------------------------------------------------
    float timeBlock   = floor(Time * 8.0);
    float diceRoll    = IGN(float2(timeBlock, timeBlock));
    float isGlitching = step(0.99, diceRoll);
    float jitter      = isGlitching * sin(Time * 250.0) * GLITCH_JITTER * warmup;

    float2 centerDist = curvedUV - 0.5;
    float  lensAb     = dot(centerDist, centerDist) * ABERRATION_SCALE;
    
    if (degaussTime < 1.0 && Time > 5.0) {
        lensAb += (1.0 - degaussTime) * 0.03;
    }

    float2 pixelUnit = 1.0 / Resolution;
    float2 subpixel  = pixelUnit * float2(SUBPIXEL_X, SUBPIXEL_Y);

    // HERE IS THE MAGIC:
    // We apply 'pullVector' (The Suck) with different multipliers per color.
    // RED   = 0.6x (Resists the magnet, stays closer to original pos)
    // GREEN = 1.0x (Normal pull)
    // BLUE  = 1.6x (Gets sucked deep into the center)
    
    float2 redCoord   = sampleUV - (pullVector * 0.6) + float2( lensAb + jitter, 0.0) + subpixel + swirlVector * 1.0;
    float2 greenCoord = sampleUV - (pullVector * 1.0) + float2( jitter,          0.0)            - swirlVector * 0.5;
    float2 blueCoord  = sampleUV - (pullVector * 1.6) + float2(-lensAb + jitter, 0.0) - subpixel - swirlVector * 1.2;

    float3 color;
    color.r = shaderTexture.Sample(samplerState, redCoord).r;
    
    float4 centerTap = shaderTexture.Sample(samplerState, greenCoord);
    color.g = centerTap.g;
    
    color.b = shaderTexture.Sample(samplerState, blueCoord).b;
    float alpha = centerTap.a;

    color *= 1.35; 

    // ----------------------------------------------------------
    // 5. SCANLINES
    // ----------------------------------------------------------
    float pulse      = 1.0 + 0.15 * sin(Time * 1.2); 
    float scanline   = sin(sampleUV.y * Resolution.y * 3.14159265);
    scanline         = 0.5 + 0.5 * scanline;

    float brightness = dot(color, float3(0.299, 0.587, 0.114));
    float scanlineIntensity = lerp(SCANLINE_DEPTH * pulse, 0.0, brightness);
    color -= scanlineIntensity * scanline;

    // ----------------------------------------------------------
    // 6. APERTURE GRILLE
    // ----------------------------------------------------------
    float  xPos = sampleUV.x * Resolution.x;
    float3 mask = (1.0 - GRILLE_DEPTH) + GRILLE_DEPTH * cos((xPos + float3(0.0, 0.333, 0.666)) * 6.28318);
    color *= mask;

    // ----------------------------------------------------------
    // 7. DIAGONAL BLOOM
    // ----------------------------------------------------------
    float3 glow  = shaderTexture.Sample(samplerState, sampleUV + pixelUnit * 1.5).rgb;
    glow        += shaderTexture.Sample(samplerState, sampleUV - pixelUnit * 1.5).rgb;
    color += glow * BLOOM_AMT * pulse;

    // ----------------------------------------------------------
    // 8. FINAL POST-PROCESS
    // ----------------------------------------------------------
    float vignette = curvedUV.x * curvedUV.y * (1.0 - curvedUV.x) * (1.0 - curvedUV.y);
    vignette       = saturate(pow(16.0 * vignette, 0.15));

    float humShadow = 1.0 - (sin(curvedUV.y * 5.0 - Time * 2.0) * 0.02);
    float flicker = (0.98 + 0.02 * sin(Time * 120.0)) * humShadow;

    if (degaussTime < 0.2 && Time > 5.0) {
        flicker += (0.2 - degaussTime) * 2.0;
    }

    float noise = (IGN(curvedUV * Resolution + Time) - 0.5) * NOISE_AMP;

    color *= flicker;
    color += noise;

    float finalAlpha = lerp(1.0, alpha, vignette);

    return float4(saturate(color * vignette), finalAlpha);
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
            local
            / "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
            local
            / "Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json",
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

        with open(self.path, "r", encoding="utf-8") as f:
            return json.load(f)

    def save(self):
        with open(self.path, "w", encoding="utf-8") as f:
            json.dump(self.data, f, indent=4)
        print(f"💾 Settings saved to {self.path}")

    def update_profile(self, name_query, **kwargs):
        """Intelligently updates a profile without overwriting other keys"""
        profiles = self.data.get("profiles", {})
        # Handle both list and dict structures in newer WT versions
        p_list = profiles.get("list", []) if isinstance(profiles, dict) else profiles

        updated_count = 0
        for profile in p_list:
            # Match "PowerShell", "Windows PowerShell", "pwsh", etc.
            if name_query.lower() in profile.get("name", "").lower():
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
            ["powershell", "-NoProfile", "-Command", "echo $PROFILE"], text=True
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
        local_app_data
        / "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
        local_app_data
        / "Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json",
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
    with open(settings_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # 3. Apply Borderless Settings
    # A. Global settings
    data["launchMode"] = "maximized"  # Always start big

    # B. Profile settings (Padding)
    updated = False
    for profile in data["profiles"]["list"]:
        if "PowerShell" in profile.get("name", ""):
            # "0" removes the gap between the window edge and the text
            profile["padding"] = "0"
            updated = True

    # 4. Save
    if updated:
        with open(settings_path, "w", encoding="utf-8") as f:
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
        manager.update_profile(
            "PowerShell",
            **{
                "font": {"face": "JetBrainsMono Nerd Font Mono", "size": 13},
                "opacity": 90,
                "useAcrylic": True,
                "experimental.pixelShaderPath": str(shader_path).replace(
                    "\\", "/"
                ),  # JSON prefers forward slashes
                "experimental.retroTerminalEffect": False,  # Turn off built-in retro to use our shader
            },
        )

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
