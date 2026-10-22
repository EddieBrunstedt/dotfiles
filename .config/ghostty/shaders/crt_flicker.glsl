// A restless tube: slight brightness flicker. Run after crt.glsl so it moves
// the finished picture. Brightness is multiplied, so dark areas stay dark
// and text never shifts or blurs.

// Peak brightness swing of the flicker (0.025 = 2.5%).
const float FLICKER_AMOUNT = 0.025;
// Flicker changes per second; lower is a slow breathing, higher a buzz.
const float FLICKER_SPEED = 12.0;

float hash(float n) {
    return fract(sin(mod(n, 4096.0) * 12.9898) * 43758.5453);
}

// Smooth random value in [0, 1] that changes once per unit of x.
float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    float flicker = 1.0 + FLICKER_AMOUNT * (noise(iTime * FLICKER_SPEED) * 2.0 - 1.0);
    fragColor.rgb = clamp(fragColor.rgb * flicker, 0.0, 1.0);
}
