
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
// Increase to taste. At 0.0 aberration is disabled entirely.
static const float ABERRATION_SCALE   = 0.0018;
// Sub-pixel jitter during rare glitch events
static const float GLITCH_JITTER      = 0.002;
// How much the aperture grille darkens (0 = off, 0.2 = subtle)
static const float GRILLE_DEPTH       = 0.20;
// Scanline darkening ceiling
static const float SCANLINE_DEPTH     = 0.08;
// Film grain amplitude
static const float NOISE_AMP          = 0.04;
// Bloom brightness contribution
static const float BLOOM_AMT          = 0.15;

// ============================================================
// UTILITIES
// ============================================================

// Interleaved Gradient Noise — cheap, no visible pattern
float IGN(float2 uv) {
    float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    return frac(magic.z * frac(dot(uv, magic.xy)));
}

// Hash for per-scanline jitter seeds
float hash1(float n) {
    return frac(sin(n) * 43758.5453);
}

// ============================================================
// MAIN
// ============================================================
float4 main(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target {

    // ----------------------------------------------------------
    // 1. CRT GLASS CURVATURE
    //    Barrel-distorts UV. Pixels outside the curved boundary
    //    return solid black (the bezel).
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
    // 2. TIMING
    // ----------------------------------------------------------
    float degaussTime = fmod(Time, 60.0); // Fires once per minute
    float warmup      = saturate(Time / 10.0); // Effects ramp in over 10s

    // ----------------------------------------------------------
    // 3. PHYSICAL DEFORMATIONS
    // ----------------------------------------------------------

    // [A] DEGAUSS SHAKE
    //     One hard physical thunk at t=0 of each degauss cycle.
    //     Gated to Time > 5.0 so it does not fire on startup.
    if (degaussTime < 1.0 && Time > 5.0) {
        float decay  = 1.0 - degaussTime;
        float shakeX = sin(Time * 150.0) * decay * 0.010;
        float shakeY = cos(Time * 140.0) * decay * 0.010;
        sampleUV += float2(shakeX, shakeY);
    }

    // [B] OCCASIONAL TREMOR
    //     Rare, high-frequency burst that drives several downstream effects.
    float randomSpike = pow(saturate(sin(Time * 0.7)), 40.0);
    float microTremor = sin(Time * 150.0) * randomSpike;

    // [C] LAZY MAGNET WARP
    //     Soft inward pull toward screen center, stronger during tremors.
    float2 magnetPos    = float2(0.5, 0.5);
    float  distToMagnet = distance(curvedUV, magnetPos);
    float  fieldPower   = 0.02 / (distToMagnet + 0.01);
    float  inField      = saturate(fieldPower);
    inField *= inField;

    float magnetStrength = inField * (0.005 + 0.015 * microTremor) * warmup;
    sampleUV += (magnetPos - sampleUV) * magnetStrength;

    // [D] HORIZONTAL HOLD JITTER
    //     Snapped to scanline pairs so it reads as "stiff signal"
    //     rather than a jelly wobble. Extremely subtle at rest;
    //     becomes perceptible only during a tremor spike.
    float scanlineID  = floor(curvedUV.y * Resolution.y * 0.5);
    float snap        = hash1(scanlineID + floor(Time * 12.0));
    float interference = (snap - 0.5) * 0.0004;
    sampleUV.x += interference * (0.3 + microTremor * 10.0);

    // ----------------------------------------------------------
    // 4. SAMPLING & CHROMATIC ABERRATION
    //
    //    aberrationAmt is kept small enough that center-screen
    //    text (centerDist ≈ 0) is essentially unaffected. It grows
    //    toward corners and during magnetic events.
    // ----------------------------------------------------------

    // Rare full-frame glitch event (~1% of 8Hz ticks)
    float timeBlock  = floor(Time * 8.0);
    float diceRoll   = IGN(float2(timeBlock, timeBlock));
    float isGlitching = step(0.99, diceRoll);
    float jitter     = isGlitching * sin(Time * 250.0) * GLITCH_JITTER * warmup;

    float2 centerDist    = curvedUV - 0.5;
    float  aberrationAmt = dot(centerDist, centerDist) * ABERRATION_SCALE;
    aberrationAmt += magnetStrength * 1.5;

    // Degauss color flare — aberration briefly blooms on the thunk
    if (degaussTime < 1.0 && Time > 5.0) {
        aberrationAmt += (1.0 - degaussTime) * 0.03;
    }

    // 3-tap RGB split (R left, G center, B right)
    float3 color;
    color.r = shaderTexture.Sample(samplerState, sampleUV + float2( aberrationAmt + jitter, 0)).r;
    float4 centerTap = shaderTexture.Sample(samplerState, sampleUV + float2(jitter, 0));
    color.g = centerTap.g;
    color.b = shaderTexture.Sample(samplerState, sampleUV - float2( aberrationAmt - jitter, 0)).b;

    float alpha = centerTap.a;

    // Compensate for the darkening applied by scanlines + aperture grille below.
    // If you tune SCANLINE_DEPTH or GRILLE_DEPTH, adjust this accordingly.
    color *= 1.35;

    // ----------------------------------------------------------
    // 5. SCANLINES
    //    Frequency is locked to one dark band per physical pixel
    //    row, so it looks the same at every resolution.
    //    Bright pixels punch through (lerp toward 0 intensity).
    // ----------------------------------------------------------
    float pulse        = 1.0 + 0.15 * sin(Time * 1.2); // Slow phosphor breathe
    float scanline     = sin(sampleUV.y * Resolution.y * 3.14159265);
    scanline           = 0.5 + 0.5 * scanline;

    float brightness   = dot(color, float3(0.299, 0.587, 0.114));
    float scanlineIntensity = lerp(SCANLINE_DEPTH * pulse, 0.0, brightness);
    color -= scanlineIntensity * scanline;

    // ----------------------------------------------------------
    // 6. APERTURE GRILLE
    //    RGB shadow mask tied to sampleUV (post-warp) so it moves
    //    with the image and does not produce a competing Moiré grid.
    //    Frequency matches one triad per pixel column.
    // ----------------------------------------------------------
    float  xPos = sampleUV.x * Resolution.x;
    float3 mask = (1.0 - GRILLE_DEPTH) + GRILLE_DEPTH * cos((xPos + float3(0.0, 0.333, 0.666)) * 6.28318);
    color *= mask;

    // ----------------------------------------------------------
    // 7. DIAGONAL BLOOM
    //    Two diagonal taps at ±1.5px. Cheap approximation of
    //    phosphor glow spreading beyond the lit area.
    // ----------------------------------------------------------
    float2 pixelSize = 1.0 / Resolution;
    float3 glow  = shaderTexture.Sample(samplerState, sampleUV + pixelSize * 1.5).rgb;
    glow        += shaderTexture.Sample(samplerState, sampleUV - pixelSize * 1.5).rgb;
    color += glow * BLOOM_AMT * pulse;

    // ----------------------------------------------------------
    // 8. FINAL POST-PROCESS
    // ----------------------------------------------------------

    // Vignette — darkens corners, exponent tuned for a wide bright center
    float vignette = curvedUV.x * curvedUV.y * (1.0 - curvedUV.x) * (1.0 - curvedUV.y);
    vignette       = saturate(pow(16.0 * vignette, 0.15));

    // Mains hum — a slow vertical brightness wave, 2% amplitude
    float humShadow = 1.0 - (sin(curvedUV.y * 5.0 - Time * 2.0) * 0.02);

    // High-frequency flicker (120 Hz simulation) modulated by hum
    float flicker = (0.98 + 0.02 * sin(Time * 120.0)) * humShadow;

    // Degauss brightness flash — a brief white-hot surge on the thunk
    if (degaussTime < 0.2 && Time > 5.0) {
        flicker += (0.2 - degaussTime) * 2.0;
    }

    // Film grain — IGN is temporally uncorrelated so it never patterns
    float noise = (IGN(curvedUV * Resolution + Time) - 0.5) * NOISE_AMP;

    color *= flicker;
    color += noise;

    // Alpha: fully opaque at corners (masks terminal chrome) fading to
    // content alpha toward center so transparency still works there.
    float finalAlpha = lerp(1.0, alpha, vignette);

    return float4(saturate(color * vignette), finalAlpha);
}
