uniform sampler2D Texture;
uniform float Effect;
varying vec2 TexCoord;

void main() {
    float force = Effect * (0.5 - min(0.5, distance(TexCoord.st, vec2(0.5, 0.5))));
    float x = sin(force * 2.0) / 5.0 * force;
    float y = cos(force * 2.0) / 5.0 * force;
    gl_FragColor = texture2D(Texture, TexCoord.st + vec2(x, y));
}
