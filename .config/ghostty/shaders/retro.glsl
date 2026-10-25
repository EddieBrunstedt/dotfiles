// CRT for retro.conf: phosphor glow, scanlines, a curved and vignetted
// tube face, flicker and grain over the theme's own colours. Flicker and
// grain move only while Ghostty's animation loop runs: in the focused window.
//
// Ghostty hands the shader linear light; its colour uniforms are sRGB.

// Unlit glass, added everywhere so black reads as a dark green tube.
const vec3 GLASS = vec3(0.0004, 0.0016, 0.0006);

// Screen pixels per font pixel; retro.conf sizes the font to exactly this.
const float PIXEL = 2.0;
// Brightness of the last screen row of each font pixel row.
const float SCANLINE_GAP = 0.45;

const float GLOW = 0.3;
const float GLOW_RADIUS = 5.0;

// Tube face: corner radius and edge falloff in screen px, corner darkening.
const float CORNER = 40.0;
const float EDGE = 14.0;
const float VIGNETTE = 0.35;
// Bulge of the glass: how far the corners pull in, as a fraction of the
// half-width and half-height. The centre stays pixel-exact.
const float CURVE = 0.025;

// How narrow the band is where the curve blends neighbouring font pixels
// or scanlines, as a fraction of a font pixel: 1/SHARP. At least 2 keeps
// flat areas exact; much higher and some strokes come out 1 or 3 px wide.
const float SHARP = 8.0;

// Brightness swing of the flicker (0.025 = 2.5%), and how many times a
// second it changes; lower is a slow breathing, higher a buzz.
const float FLICKER = 0.025;
const float FLICKER_SPEED = 12.0;
// Grain strength, in display brightness, and new grain frames per second.
const float GRAIN = 0.03;
const float GRAIN_FPS = 24.0;

// Random value in [0, 1] for a cell of a lattice, uniform at any scale.
float hash(vec3 p) {
    uvec3 q = uvec3(ivec3(floor(p))) * uvec3(1597334673u, 3812015801u, 2798796415u);
    return float((q.x ^ q.y ^ q.z) * 1597334673u) / 4294967295.0;
}

// Random value in [0, 1] that drifts smoothly to a new one each unit of x.
float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    return mix(hash(vec3(i)), hash(vec3(i + 1.0)), f * f * (3.0 - 2.0 * f));
}

// What a colour emits above the background; only that glows. The margin
// stops rounding noise in the background from picking up scanlines.
vec3 light(vec3 c) {
    vec3 bg = pow(iBackgroundColor, vec3(2.2));
    return max(c - bg - 0.002, 0.0);
}

// Where font pixels start, from the top left, modulo PIXEL. The cursor
// sits on the text grid, so its corner tells. retro.conf's padding keeps
// this 0, but padding only reaches new windows: ones open when retro is
// toggled on keep the main config's, which can put the grid off by one.
vec2 gridOffset() {
    return mod(vec2(iCurrentCursor.x, iResolution.y - iCurrentCursor.y), PIXEL);
}

// The terminal image at a tube position, read one font pixel at a time.
// Plain filtering would smear each 2x2 block once the curve shifts it off
// the screen grid; this blends whole blocks, over a sliver of their edges.
vec3 pixelated(vec2 pos) {
    vec2 res = iResolution.xy;
    vec2 offset = gridOffset();
    // Font pixels counted from the top left.
    vec2 g = (vec2(pos.x, res.y - pos.y) - offset) / PIXEL - 0.5;
    vec2 i = floor(g);
    vec2 f = clamp((fract(g) - 0.5) * SHARP + 0.5, 0.0, 1.0);
    vec3 c[4];
    for (int k = 0; k < 4; k++) {
        vec2 block = (i + vec2(k % 2, k / 2) + 0.5) * PIXEL + offset;
        c[k] = texture(iChannel0, vec2(block.x, res.y - block.y) / res).rgb;
    }
    return mix(mix(c[0], c[1], f.x), mix(c[2], c[3], f.x), f.y);
}

// Screen position to the point on the terminal image shown there.
vec2 warp(vec2 uv) {
    vec2 c = uv * 2.0 - 1.0;
    c *= 1.0 + CURVE * c.yx * c.yx;
    return c * 0.5 + 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    // Everything below works on the curved tube, not the flat window.
    vec2 uv = warp(fragCoord / res);
    vec2 pos = uv * res;

    vec3 src = pixelated(pos);
    vec3 lit = light(src);

    // Glow: a disc of samples, nearer ones weighted more.
    vec3 glow = vec3(0.0);
    float total = 0.0;
    for (int ring = 1; ring <= 3; ring++) {
        float r = GLOW_RADIUS * float(ring) / 3.0;
        int taps = ring * 8;
        for (int i = 0; i < taps; i++) {
            float a = 6.2831853 * (float(i) + 0.5 * float(ring)) / float(taps);
            float w = 1.0 / float(ring);
            glow += light(texture(iChannel0, uv + r * vec2(cos(a), sin(a)) / res).rgb) * w;
            total += w;
        }
    }
    glow /= total;

    // Where in its font pixel row this is, from the top; edges blend like
    // pixelated()'s, where the curve makes rows drift off the screen grid.
    float t = fract((res.y - pos.y - gridOffset().y) / PIXEL);
    float gap = clamp((t - 0.5) * SHARP + 0.5, 0.0, 1.0);
    // Bright pixels bleed into their gap row, as a fat beam would.
    float peak = max(lit.r, max(lit.g, lit.b));
    float beam = mix(1.0, mix(SCANLINE_GAP, 1.0, 0.5 * peak), gap);

    vec3 col = (src - lit) + lit * beam + glow * GLOW + GLASS;

    // Rounded tube edge and darker corners.
    vec2 p = abs(pos - 0.5 * res) - (0.5 * res - CORNER);
    float dist = length(max(p, 0.0)) + min(max(p.x, p.y), 0.0) - CORNER;
    float face = smoothstep(0.0, -EDGE, dist);
    vec2 q = uv * (1.0 - uv);
    float vig = mix(1.0, pow(16.0 * q.x * q.y, 0.25), VIGNETTE);
    col *= face * vig;

    // Flicker multiplies, so dark stays dark and text never moves.
    col *= 1.0 + FLICKER * (noise(iTime * FLICKER_SPEED) * 2.0 - 1.0);

    // Grain is added in display brightness, where it is even from black
    // to white, and only on the glass, not the bezel.
    float n = hash(vec3(fragCoord, floor(iTime * GRAIN_FPS))) - 0.5;
    col = pow(max(pow(col, vec3(1.0 / 2.2)) + GRAIN * n * face, 0.0), vec3(2.2));

    fragColor = vec4(col, 1.0);
}
