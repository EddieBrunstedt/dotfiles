// Phosphor glow. Run after crt.glsl: on a real tube the light spreads in the
// glass in front of the phosphor, so the halo lies over the scanlines and
// the shadow mask instead of being cut by them. Bright text gets a soft
// halo that rounds off its pixel edges; the strokes themselves stay sharp.

// How much light the halo adds (0 = off).
const float GLOW_STRENGTH = 0.18;
// Reach of the halo in screen pixels. Keep it well past the stroke width:
// a halo about as wide as the strokes reads as out of focus, not as glow.
const float GLOW_RADIUS = 9.0;
// Only light brighter than this glows, so the background stays black.
const float GLOW_THRESHOLD = 0.1;
// Brightness above the knee adds only GLOW_ROLLOFF as much halo, so bold and
// white text glow a little more than normal text instead of bleeding over
// their neighbours. The shader sees linear light, where the theme's green
// text is about 0.54 and white about 0.8.
const float GLOW_KNEE = 0.55;
const float GLOW_ROLLOFF = 0.15;

// Enough samples that the wide disc stays smooth instead of showing copies.
const int GLOW_SAMPLES = 64;
const float GOLDEN_ANGLE = 2.39996323;

// Match crt.glsl's warped glass boundary. Apply after the halo so light
// cannot spread into the bezel. Keep these warp values in sync with CRT.
float glassMask(vec2 uv) {
    float aspect = iResolution.x / iResolution.y;
    vec2 pos = uv * 2.0 - 1.0;
    pos *= vec2(1.0) + pos.yx * pos.yx
        * vec2(1.0 / (50.0 * aspect), 1.0 / 50.0);
    vec2 edge = vec2(1.0) - clamp(pos * pos, 0.0, 1.0);
    return clamp(edge.x * edge.y * iResolution.y, 0.0, 1.0);
}

// Adds light without inverting or clipping what is already lit.
vec3 screenBlend(vec3 base, vec3 light) {
    return 1.0 - (1.0 - base) * (1.0 - clamp(light, 0.0, 1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    // A golden-angle spiral covers the disc evenly with few samples; the
    // gaussian weight makes the halo fade out instead of ending at an edge.
    vec3 glow = vec3(0.0);
    float total = 0.0;
    for (int i = 0; i < GLOW_SAMPLES; i++) {
        float r = sqrt((float(i) + 0.5) / float(GLOW_SAMPLES));
        float a = float(i) * GOLDEN_ANGLE;
        vec2 offset = vec2(cos(a), sin(a)) * r * GLOW_RADIUS;
        vec3 c = texture(iChannel0, uv + offset / iResolution.xy).rgb;
        float l = dot(c, vec3(0.299, 0.587, 0.114));
        float lit = smoothstep(GLOW_THRESHOLD, GLOW_THRESHOLD + 0.2, l);
        float rolled = l > GLOW_KNEE ? GLOW_KNEE + (l - GLOW_KNEE) * GLOW_ROLLOFF : l;
        float w = exp(-2.0 * r * r);
        glow += c * (rolled / max(l, 1e-4)) * lit * w;
        total += w;
    }

    fragColor.rgb = screenBlend(fragColor.rgb, glow / total * GLOW_STRENGTH);
    fragColor.rgb *= glassMask(uv);
}
