//
//  GLPaintView.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/21.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import "GLPaintTexture.h"
#import "MFBezierCurvesTool.h"
#import "MFShaderHelper.h"

#import "GLPaintView.h"

typedef struct {
    float positionCoord[3];
    float textureCoord[2];
} Vertex;

CGPoint middlePoint(CGPoint point1, CGPoint point2) {
    return CGPointMake((point1.x + point2.x) / 2, (point1.y + point2.y) / 2);
}

static NSInteger const kDefaultBrushSize = 40;

@interface GLPaintView ()

@property (nonatomic, strong) GLPaintTexture *paintTexture;

@property (nonatomic, strong) EAGLContext *context;

@property (nonatomic, assign) GLuint frameBuffer; // 帧缓存
@property (nonatomic, assign) GLuint renderBuffer; // 渲染缓存
@property (nonatomic, assign) GLuint vertexBuffer; // 顶点缓存

@property (nonatomic, assign) GLuint program; // 着色器程序

@property (nonatomic, assign) Vertex *vertices;

@property (nonatomic, strong) CAEAGLLayer *glLayer;

@property (nonatomic, assign) CGPoint fromPoint; // 贝塞尔曲线的起始点

@end

@implementation GLPaintView

- (void)dealloc {
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    if (_vertices) {
        free(_vertices);
        _vertices = nil;
    }
    if (_program) {
        glUseProgram(0);
        glDeleteProgram(_program);
    }
    [self deleteBuffers];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

#pragma mark - Public

- (void)clear {
    [self.paintTexture clear];
    [self display];
}

- (void)setBrushImageWithImageName:(NSString *)imageName {
    [self.paintTexture setBrushTextureWithImageName:imageName];
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    CGPoint point = [[touches anyObject] locationInView:self];
    NSArray *points = [self verticesWithPoints:@[@(point)]];
    [self drawPointsToScreen:points];
    self.fromPoint = point;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    [self addPointWithTouches:touches];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    [self addPointWithTouches:touches];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    
    [self addPointWithTouches:touches];
}

- (void)addPointWithTouches:(NSSet<UITouch *> *)touches {
    UITouch *currentTouch = [touches anyObject];
    CGPoint previousPoint = [currentTouch previousLocationInView:self];
    CGPoint currentPoint = [currentTouch locationInView:self];
    
    // 起始点和当前的点重合，不需要绘制
    if (CGPointEqualToPoint(self.fromPoint, currentPoint)) {
        return;
    }
    
    CGPoint from = self.fromPoint;
    CGPoint to = middlePoint(previousPoint, currentPoint);
    CGPoint control = previousPoint;
    
    NSArray <NSValue *>*points = [MFBezierCurvesTool pointsWithFrom:from
                                                                 to:to
                                                            control:control
                                                          pointSize:self.brushSize];
    if (points.count == 0) {
        return;
    }
    
    // 去除第一个点，避免与上次绘制的最后一个点重复
    NSMutableArray *mutPoints = [points mutableCopy];
    [mutPoints removeObjectAtIndex:0];
    
    [self drawPointsToScreen:[self verticesWithPoints:[mutPoints copy]]];
    
    self.fromPoint = to;
}

#pragma mark - Custom Accessor

- (void)setBrushSize:(CGFloat)brushSize {
    _brushSize = brushSize;
    
    [self.paintTexture setBrushSize:brushSize];
}

- (void)setBrushColor:(UIColor *)brushColor {
    _brushColor = brushColor;
    
    [self.paintTexture setColor:brushColor];
}

- (void)setBrushMode:(GLPaintViewBrushMode)brushMode {
    _brushMode = brushMode;
}

#pragma mark - Private

- (void)commonInit {
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
    
    self.vertices = malloc(sizeof(Vertex) * 4);
    self.vertices[0] = (Vertex){{-1, 1, 0}, {0, 1}};
    self.vertices[1] = (Vertex){{-1, -1, 0}, {0, 0}};
    self.vertices[2] = (Vertex){{1, 1, 0}, {1, 1}};
    self.vertices[3] = (Vertex){{1, -1, 0}, {1, 0}};
    
    [self setupGLLayer];
    [self genProgram];
    [self genBuffers];
    [self bindRenderLayer:self.glLayer];
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    self.paintTexture = [[GLPaintTexture alloc] initWithContext:self.context
                                                           size:CGSizeMake(self.drawableWidth, self.drawableHeight)];
    [self bindTexture];
    
    self.brushSize = kDefaultBrushSize;
    self.brushColor = [UIColor blackColor];
    self.brushMode = MFPaintViewBrushModePaint;
}

// 创建 program
- (void)genProgram {
    self.program = [MFShaderHelper programWithShaderName:@"normal"];
}

// 创建 buffer
- (void)genBuffers {
    glGenFramebuffers(1, &_frameBuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    glGenBuffers(1, &_vertexBuffer);
}

// 创建输出层
- (void)setupGLLayer {
    CAEAGLLayer *layer = [[CAEAGLLayer alloc] init];
    layer.frame = self.bounds;
    layer.contentsScale = [[UIScreen mainScreen] scale];
    self.glLayer = layer;
    
    [self.layer addSublayer:self.glLayer];
}

// 绑定图像要输出的 layer
- (void)bindRenderLayer:(CALayer <EAGLDrawable> *)layer {
    glBindRenderbuffer(GL_RENDERBUFFER, self.renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER,
                              self.renderBuffer);
}

// 绑定要绘制的纹理
- (void)bindTexture {
    glUseProgram(self.program);
    GLuint textureSlot = glGetUniformLocation(self.program, "Texture");
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, self.paintTexture.textureID);
    glUniform1i(textureSlot, 1);
}

// 绘制数据到屏幕
- (void)drawPointsToScreen:(NSArray<NSValue *> *)points {
    [self.paintTexture drawPoints:points];
    [self display];
}

// 绘制
- (void)display {
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    
    glUseProgram(self.program);
    
    GLuint positionSlot = glGetAttribLocation(self.program, "Position");
    GLuint textureCoordsSlot = glGetAttribLocation(self.program, "TextureCoords");
    
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(Vertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), NULL + offsetof(Vertex, positionCoord));
    
    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), NULL + offsetof(Vertex, textureCoord));
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

// 获取渲染缓存宽度
- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    
    return backingWidth;
}

// 获取渲染缓存高度
- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    return backingHeight;
}

// UIKit 坐标点，转化为顶点坐标
- (NSArray <NSValue *>*)verticesWithPoints:(NSArray <NSValue *>*)points {
    NSMutableArray *mutArr = [[NSMutableArray alloc] init];
    for (int i = 0; i < points.count; ++i) {
        [mutArr addObject:@([self vertexWithPoint:points[i].CGPointValue])];
    }
    return [mutArr copy];
}

// 归一化顶点坐标
- (CGPoint)vertexWithPoint:(CGPoint)point {
    float x = (point.x / self.frame.size.width) * 2 - 1;
    float y = 1 - (point.y / self.frame.size.height) * 2;
    return CGPointMake(x, y);
}

// 清除 buffer
- (void)deleteBuffers {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    if (_frameBuffer != 0) {
        glDeleteFramebuffers(1, &_frameBuffer);
    }
    if (_renderBuffer != 0) {
        glDeleteRenderbuffers(1, &_renderBuffer);
    }
    if (_vertexBuffer != 0) {
        glDeleteBuffers(1, &_vertexBuffer);
    }
}

@end
