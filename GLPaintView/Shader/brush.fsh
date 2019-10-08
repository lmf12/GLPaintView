precision highp float;

uniform float R;
uniform float G;
uniform float B;
uniform float A;

uniform sampler2D Texture;

void main (void) {
    vec4 mask = texture2D(Texture, gl_PointCoord);
    gl_FragColor = A * vec4(R, G, B, 1.0) * mask;
}
