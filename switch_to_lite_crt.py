import os
import json
from pathlib import Path

# THE "LITE" SHADER (Final Version)
# Features: Static Scanlines, Contrast Boost, Vignette, 60Hz Analog Hum
LITE_SHADER = r"""
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
static const float SCANLINE_DEPTH   = 0.12;  // 0.0 = off, 0.15 = max before text suffers
static const float VIGNETTE_EXP     = 0.20;  // lower = harder falloff, higher = softer/cinematic
static const float FLICKER_AMP      = 0.015; // 0.01 = subtle, 0.02 = noticeable
static const float FLICKER_FREQ     = 1.2;   // 60.0 = mains hum, ~1.2 = slow organic breathe
static const float BLUR_WEIGHT      = 0.10;  // phosphor neighbor blend, 0.0 = off
static const float CONTRAST_LIFT    = 0.05;  // slight luma boost to make text pop

float4 main(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target {

    // ----------------------------------------------------------
    // 1. PHOSPHOR BLUR
    //    Averages ±1px horizontal neighbors at BLUR_WEIGHT.
    //    Softens glyph edges to read as "old monitor dot pitch"
    //    without reducing legibility — real CRTs were never sharp.
    // ----------------------------------------------------------
    float2 pixelSize = float2(1.0 / Resolution.x, 0.0);
    float4 colorL = shaderTexture.Sample(samplerState, uv - pixelSize);
    float4 colorC = shaderTexture.Sample(samplerState, uv);
    float4 colorR = shaderTexture.Sample(samplerState, uv + pixelSize);
    float4 color  = colorC * (1.0 - BLUR_WEIGHT) + (colorL + colorR) * (BLUR_WEIGHT * 0.5);

    // ----------------------------------------------------------
    // 2. LUMA-BASED SCANLINES
    //    One dark band per pixel row. Bright pixels (text) punch
    //    through toward full intensity; dark pixels (background)
    //    get the full SCANLINE_DEPTH shadow.
    // ----------------------------------------------------------
    float scanline = sin(uv.y * Resolution.y * 3.14159265);
    scanline = 0.5 + 0.5 * scanline;

    float brightness = dot(color.rgb, float3(0.299, 0.587, 0.114));
    float scanlineIntensity = lerp(SCANLINE_DEPTH, 0.0, brightness);
    color.rgb -= scanlineIntensity * scanline;

    // ----------------------------------------------------------
    // 3. CONTRAST BOOST
    //    Slight luma lift so text pops against the scanline shadow.
    //    The additive term raises midtones without blowing highlights.
    // ----------------------------------------------------------
    color.rgb = color.rgb * (1.0 + CONTRAST_LIFT) + (brightness * CONTRAST_LIFT);

    // ----------------------------------------------------------
    // 4. VIGNETTE
    //    Darkens corners to frame the screen. VIGNETTE_EXP controls
    //    how hard the falloff is — lower is more dramatic.
    // ----------------------------------------------------------
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = saturate(pow(16.0 * vignette, VIGNETTE_EXP));

    // ----------------------------------------------------------
    // 5. ORGANIC BREATHE
    //    Slow sinusoidal brightness oscillation. At FLICKER_FREQ ~1.2
    //    it reads as a warm, living phosphor rather than electrical
    //    hum. Raise FLICKER_FREQ to 50.0/60.0 for mains hum character.
    // ----------------------------------------------------------
    float flicker = 1.0 - FLICKER_AMP + FLICKER_AMP * sin(Time * FLICKER_FREQ);

    color.rgb *= flicker;

    return float4(saturate(color.rgb * vignette), 1.0);
}
"""

def install_lite_shader():
    # 1. Write the shader file
    base_dir = Path(os.environ["LOCALAPPDATA"]) / "nvim/shaders"
    base_dir.mkdir(parents=True, exist_ok=True)
    
    shader_path = base_dir / "retro_lite.hlsl"
    shader_path.write_text(LITE_SHADER, encoding="utf-8")
    print(f"✓ Lite Shader written to: {shader_path}")

    # 2. Update Windows Terminal
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
            
    if settings_path:
        with open(settings_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        updated = False
        for profile in data['profiles']['list']:
            if "PowerShell" in profile.get('name', ''):
                profile["experimental.pixelShaderPath"] = str(shader_path).replace("\\", "/")
                profile["experimental.retroTerminalEffect"] = False
                updated = True

        if updated:
            with open(settings_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4)
            print("✓ Settings updated! The terminal is now alive.")
        else:
            print("! PowerShell profile not found.")
    else:
        print("! Settings.json not found.")

if __name__ == "__main__":
    install_lite_shader()
