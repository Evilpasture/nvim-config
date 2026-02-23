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

float4 main(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    
    // 1. Single Texture Sample (No Distortion)
    float4 color = shaderTexture.Sample(samplerState, uv);

    // 2. Luma-Based Scanlines (Static)
    float scanline = sin(uv.y * Resolution.y * 3.14159);
    scanline = 0.5 + 0.5 * scanline;
    
    // Calculate brightness
    float brightness = dot(color.rgb, float3(0.299, 0.587, 0.114));
    
    // If pixel is bright (text), scanlines disappear (0.0).
    // If pixel is dark (bg), scanlines are subtle (0.1).
    float scanlineIntensity = lerp(0.1, 0.0, brightness); 
    
    color.rgb -= scanlineIntensity * scanline;

    // 3. Contrast Boost
    // Make text pop against the scanlines
    color.rgb = color.rgb * 1.05 + (brightness * 0.05);

    // 4. Subtle Vignette
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = saturate(pow(16.0 * vignette, 0.1)); 
    
    // 5. ANALOG HEARTBEAT (The "Hum")
    // A tiny 2% brightness oscillation.
    // It feels like the power supply capacitor is doing its best.
    float flicker = 0.99 + 0.01 * sin(Time * 60.0);
    
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
