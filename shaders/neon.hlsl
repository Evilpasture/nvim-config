
Texture2D shaderTexture : register(t0);
SamplerState samplerState : register(s0);

cbuffer PixelShaderSettings : register(b0) {
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

// Interleaved Gradient Noise (High Performance)
float InterleavedGradientNoise(float2 uv) {
    float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    return frac(magic.z * frac(dot(uv, magic.xy)));
}

float4 main(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    
    // --------------------------------------------------------
    // 1. EARLY EXIT CURVATURE (The Physical Glass)
    // --------------------------------------------------------
    float2 centeredUV = uv * 2.0 - 1.0;
    float2 offset = abs(centeredUV.yx) / float2(5.0, 4.0); 
    centeredUV = centeredUV + centeredUV * offset * offset;
    float2 curvedUV = centeredUV * 0.5 + 0.5;

    // Early exit: Solid Black for the monitor bezel
    if (any(curvedUV < 0.0) || any(curvedUV > 1.0)) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    float2 sampleUV = curvedUV; 

    // --------------------------------------------------------
    // 2. TIMING & WARMUP
    // --------------------------------------------------------
    float degaussTime = fmod(Time, 60.0);
    float warmup = saturate(Time / 10.0);

    // --------------------------------------------------------
    // 3. PHYSICAL DEFORMATIONS (The "Realism Patch")
    // --------------------------------------------------------
    // 1. Occasional Tremor Logic
    float randomSpike = pow(saturate(sin(Time * 0.7)), 40.0); 
    float microTremor = sin(Time * 150.0) * randomSpike;

    // 2. Lazy Magnet (Subtle static warp)
    float2 magnetPos = float2(0.5, 0.5); 
    float distToMagnet = distance(curvedUV, magnetPos);
    float fieldPower = 0.02 / (distToMagnet + 0.01); 
    float inField = saturate(fieldPower);
    inField *= inField; 

    float magnetStrength = inField * (0.005 + (0.015 * microTremor)) * warmup;
    sampleUV += (magnetPos - sampleUV) * magnetStrength;

    // 3. THE "STIFF" SIGNAL PATCH (Horizontal Hold Jitter)
    // Snaps the jitter to scanline pairs to prevent "Jelly" feel.
    float scanlineID = floor(curvedUV.y * Resolution.y * 0.5);
    float snap = frac(sin(scanlineID + floor(Time * 12.0)) * 43758.5453); 
    float interference = (snap - 0.5) * 0.0004; // Extremely subtle

    // Only apply noticeable jitter during a tremor or very faintly otherwise
    sampleUV.x += interference * (0.3 + microTremor * 10.0);

    // --------------------------------------------------------
    // 4. SAMPLING & ELECTRON BEAM DIVERGENCE
    // --------------------------------------------------------
    float timeBlock = floor(Time * 8.0);
    float diceRoll = InterleavedGradientNoise(float2(timeBlock, timeBlock)); 
    float isGlitching = step(0.99, diceRoll);
    float jitter = isGlitching * sin(Time * 250.0) * 0.002 * warmup;

    float2 centerDist = curvedUV - 0.5;
    float aberrationAmt = dot(centerDist, centerDist) * 0.002;
    aberrationAmt += (magnetStrength * 1.5); 

    // 3-Tap Sampling
    float3 color;
    color.r = shaderTexture.Sample(samplerState, sampleUV + float2(aberrationAmt + jitter, 0)).r;
    float4 centerTap = shaderTexture.Sample(samplerState, sampleUV + float2(jitter, 0));
    color.g = centerTap.g;
    color.b = shaderTexture.Sample(samplerState, sampleUV - float2(aberrationAmt - jitter, 0)).b;
    
    float alpha = centerTap.a; 
    color *= 1.35; 

    // --------------------------------------------------------
    // 5. SCANLINES & PHOSPHOR PERSISTENCE
    // --------------------------------------------------------
    float pulse = 1.0 + (0.15 * sin(Time * 1.2)); 
    float scanline = sin(sampleUV.y * Resolution.y * 3.14159);
    scanline = 0.5 + 0.5 * scanline;
    
    float brightness = dot(color, float3(0.299, 0.587, 0.114));
    float persistence = smoothstep(0.6, 1.0, brightness);
    float scanlineIntensity = lerp(0.08 * pulse, 0.0, brightness); 
    
    color -= scanlineIntensity * scanline;

    // Aperture Grille (Tied to sampleUV to prevent Moiré)
    float xPos = sampleUV.x * Resolution.x;
    float3 mask = 0.8 + 0.2 * cos((xPos + float3(0, 0.33, 0.66)) * 6.28);
    color *= mask;

    // --------------------------------------------------------
    // 6. DIAGONAL BLOOM
    // --------------------------------------------------------
    float2 pixelSize = 1.0 / Resolution;
    float3 glow = shaderTexture.Sample(samplerState, sampleUV + (pixelSize * 1.5)).rgb;
    glow += shaderTexture.Sample(samplerState, sampleUV - (pixelSize * 1.5)).rgb;
    color += (glow * 0.15 * pulse); 

    // --------------------------------------------------------
    // 7. FINAL POST-PROCESS
    // --------------------------------------------------------
    // Physical Vignette
    float vignette = curvedUV.x * curvedUV.y * (1.0 - curvedUV.x) * (1.0 - curvedUV.y);
    vignette = saturate(pow(16.0 * vignette, 0.15)); 
    
    // Slow hum shadow (brightness variation, not geometric)
    float humShadow = 1.0 - (sin(curvedUV.y * 5.0 - Time * 2.0) * 0.02);
    float flicker = (0.98 + 0.02 * sin(Time * 120.0)) * humShadow;
    
    float noise = (InterleavedGradientNoise(curvedUV * Resolution + Time) - 0.5) * 0.04;
    
    color *= flicker;
    color += noise;

    // Fade alpha to opaque at corners to mask the gray terminal background
    float finalAlpha = lerp(1.0, alpha, vignette);

    return float4(saturate(color * vignette), finalAlpha);
}
