// Monochrome phosphor CRT for retro.conf. Static: no time uniforms, so
// Ghostty still redraws only when the terminal changes.
//
// Ghostty hands the shader linear light; its colour uniforms are sRGB.

// Phosphor at full drive, and the unlit glass. Green: vec3(0.20, 1.0, 0.25)
const vec3 PHOSPHOR = vec3(1.0, 0.40, 0.045);
const vec3 GLASS = vec3(0.0016, 0.0010, 0.0006);

// Screen pixels per font pixel; retro.conf sizes the font to exactly this.
const float PIXEL = 2.0;
// Brightness of the last screen row of each font pixel row.
const float SCANLINE_GAP = 0.45;

const float GLOW = 0.55;
const float GLOW_RADIUS = 7.0;

// Tube face: corner radius and edge falloff in screen px, corner darkening.
const float CORNER = 40.0;
const float EDGE = 14.0;
const float VIGNETTE = 0.35;

vec3 linear(vec3 c) { return pow(c, vec3(2.2)); }

// Saturated colours have little luminance (blue least), but on a
// monochrome tube they should still read clearly.
float drive(vec3 c) {
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    float peak = max(c.r, max(c.g, c.b));
    return mix(lum, peak, 0.6);
}

// Background maps to 0, the default foreground to 0.8, white above it.
float level(vec2 uv) {
    float bg = drive(linear(iBackgroundColor));
    float fg = drive(linear(iForegroundColor));
    float d = drive(texture(iChannel0, uv).rgb);
    return max(d - bg, 0.0) / max(fg - bg, 1e-3) * 0.8;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;

    float v = level(uv);

    // Glow: a disc of samples, nearer ones weighted more.
    float glow = 0.0;
    float total = 0.0;
    for (int ring = 1; ring <= 3; ring++) {
        float r = GLOW_RADIUS * float(ring) / 3.0;
        int taps = ring * 8;
        for (int i = 0; i < taps; i++) {
            float a = 6.2831853 * (float(i) + 0.5 * float(ring)) / float(taps);
            float w = 1.0 / float(ring);
            glow += level(uv + r * vec2(cos(a), sin(a)) / res) * w;
            total += w;
        }
    }
    glow /= total;

    // Rows counted from the top, where the text grid starts.
    float row = floor(res.y - fragCoord.y);
    bool gap = mod(row, PIXEL) == PIXEL - 1.0;
    // Bright pixels bleed into their gap row, as a fat beam would.
    float beam = gap ? mix(SCANLINE_GAP, 1.0, 0.5 * v) : 1.0;

    float e = v * beam + glow * GLOW;
    // Hot phosphor desaturates toward white.
    vec3 col = PHOSPHOR * e + vec3(1.0, 0.85, 0.6) * 0.25 * pow(clamp(v * beam, 0.0, 1.0), 3.0);
    col += GLASS;

    // Rounded tube edge and darker corners.
    vec2 p = abs(fragCoord - 0.5 * res) - (0.5 * res - CORNER);
    float dist = length(max(p, 0.0)) + min(max(p.x, p.y), 0.0) - CORNER;
    float face = smoothstep(0.0, -EDGE, dist);
    vec2 q = uv * (1.0 - uv);
    float vig = mix(1.0, pow(16.0 * q.x * q.y, 0.25), VIGNETTE);

    fragColor = vec4(col * face * vig, 1.0);
}
