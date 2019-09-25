attribute vec4 Position;

void main (void) {
    gl_Position = Position;
    gl_PointSize = 100.0;
}
