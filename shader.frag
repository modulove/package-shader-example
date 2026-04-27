uniform sampler2D Texture;
uniform float Time;
uniform float Inset;
varying vec2 TexCoord;

const float PI2         = 6.2831853;
const float GLOW_RADIUS = 0.05;

void main() {
    vec2 uv = TexCoord;

    // The drawn quad is larger than the logo by `Inset` on each side so the
    // glow halo has somewhere to live. Map outer uv -> logo uv [0,1].
    vec2 luv = (uv - Inset) / (1.0 - 2.0 * Inset);

    // Stronger deformation near the centre, fading to zero at the edges.
    float falloff = 0.5 - min(0.5, distance(luv, vec2(0.5)));

    // Layered sines at incommensurate frequencies/phases give an organic,
    // non-repeating wobble instead of one obvious cosine.
    float wx = sin(Time * 0.37 + luv.y * 3.1)        * 0.5
             + sin(Time * 0.73 + luv.y * 5.7 + 1.3)  * 0.3
             + sin(Time * 1.13 + luv.x * 2.3 + 2.7)  * 0.2;
    float wy = cos(Time * 0.41 + luv.x * 2.9 + 2.1)  * 0.5
             + cos(Time * 0.67 + luv.x * 6.3 + 0.7)  * 0.3
             + cos(Time * 1.09 + luv.y * 1.9 + 4.2)  * 0.2;
    vec2 suv = luv + vec2(wx, wy) * falloff * 0.06;

    vec4 logo = vec4(0.0);
    if (suv.x >= 0.0 && suv.x <= 1.0 && suv.y >= 0.0 && suv.y <= 1.0) {
        logo = texture2D(Texture, suv);
    }

    // 8-tap radial alpha blur around the wobbled sample point. Pixels in
    // the inset margin (luv outside [0,1]) still pick up alpha from taps
    // that land back inside the logo, producing an aura halo.
    float glow = 0.0;
    for (int i = 0; i < 8; ++i) {
        float a = PI2 * float(i) / 8.0;
        vec2 g_uv = suv + vec2(cos(a), sin(a)) * GLOW_RADIUS;
        if (g_uv.x >= 0.0 && g_uv.x <= 1.0 && g_uv.y >= 0.0 && g_uv.y <= 1.0) {
            glow += texture2D(Texture, g_uv).a;
        }
    }
    glow /= 8.0;

    float pulse     = 0.85 + 0.15 * sin(Time * 0.7);
    vec3  glowColor = vec3(0.85, 0.95, 1.0);
    float glowAlpha = clamp(glow * pulse * 0.9, 0.0, 0.85);
    vec4  glowLayer = vec4(glowColor * glowAlpha, glowAlpha);

    gl_FragColor = mix(glowLayer, logo, logo.a);
}
