precision highp float;

uniform sampler2D Texture;

void main (void) {
    vec4 mask = texture2D(Texture, gl_PointCoord);
    gl_FragColor = vec4(mask.r, 0.0, 0.0, mask.a);
    
}
