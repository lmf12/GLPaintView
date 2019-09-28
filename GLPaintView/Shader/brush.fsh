precision highp float;

uniform float R;
uniform float G;
uniform float B;

uniform sampler2D Texture;

void main (void) {
    vec4 mask = texture2D(Texture, gl_PointCoord);
    gl_FragColor = vec4(R, G, B, mask.a);
    
}
