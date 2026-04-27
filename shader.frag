uniform sampler2D Texture;
uniform float Time;
varying vec2 TexCoord;

void main() {
    vec2 uv = TexCoord;

    // Stronger near the centre, fading to the edges.
    float falloff = 0.5 - min(0.5, distance(uv, vec2(0.5)));

    // Layered sines at incommensurate frequencies/phases give an organic,
    // non-repeating wobble.
    float wx = sin(Time * 0.37 + uv.y * 3.1)       * 0.5
             + sin(Time * 0.73 + uv.y * 5.7 + 1.3) * 0.3
             + sin(Time * 1.13 + uv.x * 2.3 + 2.7) * 0.2;
    float wy = cos(Time * 0.41 + uv.x * 2.9 + 2.1) * 0.5
             + cos(Time * 0.67 + uv.x * 6.3 + 0.7) * 0.3
             + cos(Time * 1.09 + uv.y * 1.9 + 4.2) * 0.2;

    gl_FragColor = texture2D(Texture, uv + vec2(wx, wy) * falloff * 0.10);
}
