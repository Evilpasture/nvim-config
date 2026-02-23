
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
