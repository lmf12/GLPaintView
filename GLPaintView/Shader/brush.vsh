attribute vec4 Position;

uniform float Size;

void main (void) {
    gl_Position = Position;
    gl_PointSize = Size;
}
