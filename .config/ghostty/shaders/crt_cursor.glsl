// Phosphor persistence for the cursor. Run before crt.glsl so it picks up
// the same curvature and scanlines. When the cursor moves, the cell it left
// keeps glowing for a moment and fades out, like the slow phosphor of an old
// terminal. No halo of its own: crt_glow.glsl already gives the solid block
// one, and a second doubled the bleed around it. No streak between
// positions: a CRT beam jumps, it doesn't smear.

// Brightness of the afterglow just after the cursor moves (0 to 1).
const float GHOST_START = 0.45;
// Seconds for the afterglow to fall to about a third.
const float GHOST_DECAY = 0.08;

float boxDistance(vec2 p, vec2 halfSize) {
    vec2 d = abs(p) - halfSize;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

// Adds light without inverting or clipping what is already lit.
vec3 screenBlend(vec3 base, vec3 light) {
    return 1.0 - (1.0 - base) * (1.0 - clamp(light, 0.0, 1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);
    if (iFocus == 0 || iCursorVisible == 0) return;

    vec2 size = iCurrentCursor.zw;
    if (min(size.x, size.y) < 1.0) return;
    vec2 center = iCurrentCursor.xy + size * vec2(0.5, -0.5);
    float d = boxDistance(fragCoord - center, size * 0.5);

    // Leave the live cursor and the character inside it untouched.
    if (d <= 0.0) return;

    vec2 previousSize = iPreviousCursor.zw;
    if (min(previousSize.x, previousSize.y) < 1.0) return;
    vec2 previousCenter = iPreviousCursor.xy + previousSize * vec2(0.5, -0.5);
    // A colour change also resets the timer; only a move leaves a ghost.
    if (distance(previousCenter, center) < 1.0) return;

    float age = max(iTime - iTimeCursorChange, 0.0);
    float glow = GHOST_START * exp(-age / GHOST_DECAY);
    if (glow < 0.004) return;

    float g = boxDistance(fragCoord - previousCenter, previousSize * 0.5);
    float cell = 1.0 - smoothstep(-0.5, 0.5, g);
    fragColor.rgb = screenBlend(fragColor.rgb, iPreviousCursorColor.rgb * glow * cell);
}
