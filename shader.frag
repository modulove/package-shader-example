uniform sampler2D Texture;
uniform float Time;
uniform float Inset;
varying vec2 TexCoord;

const float PI2 = 6.2831853;

float in_unit(vec2 p) {
    vec2 m = step(vec2(0.0), p) * step(p, vec2(1.0));
    return m.x * m.y;
}

void main() {
    vec2 uv  = TexCoord;
    // Outer quad uv -> inner logo uv. The Inset margin around the logo
    // is reserved for the glow halo.
    vec2 luv = (uv - Inset) / (1.0 - 2.0 * Inset);

    // Stronger near the centre, fading to the edges.
    float falloff = 0.5 - min(0.5, distance(luv, vec2(0.5)));

    // Layered sines at incommensurate frequencies/phases give an organic,
    // non-repeating wobble. Amplitude tuned to be a clearly visible
    // shimmer without distorting the logo's recognisable shape.
    float wx = sin(Time * 0.37 + luv.y * 3.1)       * 0.5
             + sin(Time * 0.73 + luv.y * 5.7 + 1.3) * 0.3
             + sin(Time * 1.13 + luv.x * 2.3 + 2.7) * 0.2;
    float wy = cos(Time * 0.41 + luv.x * 2.9 + 2.1) * 0.5
             + cos(Time * 0.67 + luv.x * 6.3 + 0.7) * 0.3
             + cos(Time * 1.09 + luv.y * 1.9 + 4.2) * 0.2;
    vec2 suv = luv + vec2(wx, wy) * falloff * 0.10;

    vec4 logo = texture2D(Texture, suv) * in_unit(suv);

    // Two-ring radial alpha blur. Pixels in the inset margin pick up
    // alpha from taps that land back inside the logo, producing a
    // clearly visible aura halo around the silhouette.
    float glow_outer = 0.0;
    for (int i = 0; i < 12; ++i) {
        float a = PI2 * float(i) / 12.0;
        vec2  g = suv + vec2(cos(a), sin(a)) * 0.10;
        glow_outer += texture2D(Texture, g).a * in_unit(g);
    }
    float glow_inner = 0.0;
    for (int i = 0; i < 8; ++i) {
        float a = PI2 * (float(i) + 0.5) / 8.0;
        vec2  g = suv + vec2(cos(a), sin(a)) * 0.05;
        glow_inner += texture2D(Texture, g).a * in_unit(g);
    }
    float glow = glow_outer / 12.0 + glow_inner / 8.0 * 0.6;

    float pulse     = 0.85 + 0.15 * sin(Time * 0.7);
    vec3  glowColor = vec3(0.6, 0.85, 1.0);
    float glowAlpha = clamp(glow * pulse * 1.4, 0.0, 1.0);

    // Straight-alpha "over" composite: logo on top of glow.
    float outA = logo.a + glowAlpha * (1.0 - logo.a);
    vec3  outC = (logo.rgb * logo.a + glowColor * glowAlpha * (1.0 - logo.a))
                 / max(outA, 0.001);

    gl_FragColor = vec4(outC, outA);
}
