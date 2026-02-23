
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
    // 1. EARLY EXIT CURVATURE
    // --------------------------------------------------------
    float2 centeredUV = uv * 2.0 - 1.0;
    float2 offset = abs(centeredUV.yx) / float2(5.0, 4.0); 
    centeredUV = centeredUV + centeredUV * offset * offset;
    float2 curvedUV = centeredUV * 0.5 + 0.5;

    if (any(curvedUV < 0.0) || any(curvedUV > 1.0)) {
        return float4(0, 0, 0, 1);
    }

    // --------------------------------------------------------
    // 2. TIMING & WARMUP
    // --------------------------------------------------------
    float degaussTime = frac(Time / 60.0) * 60.0;
    float warmup = saturate(Time / 10.0);

    // --------------------------------------------------------
    // 3. PHYSICAL DEFORMATIONS
    // --------------------------------------------------------
    // Degauss Shake
    if (degaussTime < 1.0 && Time > 10.0) {
        float decay = (1.0 - degaussTime);
        float shakeX = sin(degaussTime * 150.0) * decay * 0.015;
        float shakeY = cos(degaussTime * 140.0) * decay * 0.015;
        curvedUV += float2(shakeX, shakeY);
    }

    // *** INVERSE SQUARE MAGNET LOGIC ***
    float2 magnetPos = float2(
        0.5 + 0.35 * cos(Time * 0.4), 
        0.5 + 0.25 * sin(Time * 0.9)
    );
    
    // 1. Raw Distance
    float distToMagnet = distance(curvedUV, magnetPos);
    
    // 2. Physical Falloff (1 / r)
    // We use a small epsilon (0.01) to prevent division by zero.
    // The field strength drops off rapidly but never truly hits zero.
    float fieldPower = 0.02 / (distToMagnet + 0.01); 
    float inField = pow(saturate(fieldPower), 2.0); // Shape the curve
    
    // 3. Apply Warmup
    float magnetStrength = inField * 0.05 * warmup;

    // Apply Geometric Warp (Pulling pixels towards the magnet)
    curvedUV += (magnetPos - curvedUV) * magnetStrength;

    // --------------------------------------------------------
    // 4. SAMPLING & ELECTRON BEAM DIVERGENCE
    // --------------------------------------------------------
    // Jitter (Using IGN)
    float timeBlock = floor(Time * 8.0);
    float diceRoll = InterleavedGradientNoise(float2(timeBlock, timeBlock)); 
    float isGlitching = step(0.98, diceRoll);
    float jitter = isGlitching * sin(Time * 250.0) * 0.003 * warmup;

    // Base Aberration (Lens curvature)
    float2 centerDist = curvedUV - 0.5;
    float aberrationAmt = dot(centerDist, centerDist) * 0.0025;
    
    // *** MAGNETIC RAINBOW EFFECT ***
    // Magnets bend electron beams based on mass/charge. 
    // This causes R, G, and B to split heavily under magnetic load.
    float magnetColorShift = magnetStrength * 1.5; 
    aberrationAmt += magnetColorShift;

    // Degauss Swirl
    if (degaussTime < 1.0 && Time > 10.0) aberrationAmt += (1.0 - degaussTime) * 0.05;

    // 3-Tap Sampling
    float3 color;
    color.r = shaderTexture.Sample(samplerState, curvedUV + float2(aberrationAmt + jitter, 0)).r;
    color.g = shaderTexture.Sample(samplerState, curvedUV + float2(jitter, 0)).g;
    color.b = shaderTexture.Sample(samplerState, curvedUV - float2(aberrationAmt - jitter, 0)).b;
    
    color *= 1.35; // Brightness compensation

    // --------------------------------------------------------
    // 5. SCANLINES & PHOSPHOR PERSISTENCE
    // --------------------------------------------------------
    float pulse = 1.0 + (0.15 * sin(Time * 1.2)); 
    float scanline = sin(curvedUV.y * Resolution.y * 3.14159);
    scanline = 0.5 + 0.5 * scanline;
    
    float brightness = dot(color, float3(0.299, 0.587, 0.114));

    // Phosphor Bleed
    float persistence = smoothstep(0.6, 1.0, brightness);
    float dynamicDarkness = lerp(0.08 * pulse, 0.01, persistence); 
    
    float scanlineIntensity = lerp(dynamicDarkness, 0.0, brightness); 
    color -= scanlineIntensity * scanline;

    // Aperture Grille
    float xPos = curvedUV.x * Resolution.x;
    float3 mask = 0.8 + 0.2 * cos((xPos + float3(0, 0.33, 0.66)) * 6.28);
    color *= mask;

    // --------------------------------------------------------
    // 6. DIAGONAL BLOOM
    // --------------------------------------------------------
    float2 pixelSize = 1.0 / Resolution;
    float3 glow = shaderTexture.Sample(samplerState, curvedUV + (pixelSize * 1.5)).rgb;
    glow += shaderTexture.Sample(samplerState, curvedUV - (pixelSize * 1.5)).rgb;
    
    color += (glow * 0.2 * pulse); 

    // --------------------------------------------------------
    // 7. FINAL POST-PROCESS
    // --------------------------------------------------------
    // Vignette
    float vignette = curvedUV.x * curvedUV.y * (1.0 - curvedUV.x) * (1.0 - curvedUV.y);
    vignette = saturate(pow(16.0 * vignette, 0.15)); 
    
    // Flicker
    float flicker = 0.98 + 0.02 * sin(Time * 120.0);
    
    // IGN Grain
    float noise = (InterleavedGradientNoise(curvedUV * Resolution + Time) - 0.5) * 0.05;
    
    color *= flicker;
    color += noise;

    return float4(saturate(color * vignette), 1.0);
}
