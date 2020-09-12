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
#import "MFPaintStack.h"
#import "GLPaintManager.h"

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

@property (nonatomic, strong) UIColor *backgroundColor; /// 纹理背景色
@property (nonatomic, strong) UIImage *backgroundImage; /// 纹理图片

@property (nonatomic, assign) GLuint frameBuffer; // 帧缓存
@property (nonatomic, assign) GLuint renderBuffer; // 渲染缓存
@property (nonatomic, assign) GLuint vertexBuffer; // 顶点缓存

@property (nonatomic, assign) GLuint program; // 着色器程序

@property (nonatomic, assign) Vertex *vertices;

@property (nonatomic, strong) CAEAGLLayer *glLayer;

@property (nonatomic, assign) CGPoint fromPoint; // 贝塞尔曲线的起始点

@property (nonatomic, assign, readwrite) CGSize textureSize;

@property (nonatomic, strong) NSMutableArray *pointsPreDraw;  // 手指按住屏幕，到离开，产生的所有的点

@property (nonatomic, strong) MFPaintStack *operationStack;  // 操作的栈
@property (nonatomic, strong) MFPaintStack *undoOperationStack;  // 撤销的操作的栈

@end

@implementation GLPaintView

- (void)dealloc {
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

- (instancetype)initWithFrame:(CGRect)frame
                  textureSize:(CGSize)textureSize
              backgroundColor:(UIColor *)backgroundColor
              backgroundImage:(UIImage *)backgroundImage {
    self = [super initWithFrame:frame];
    if (self) {
        self.textureSize = textureSize;
        self.backgroundColor = backgroundColor;
        self.backgroundImage = backgroundImage;
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
                  textureSize:(CGSize)textureSize
              backgroundColor:(UIColor *)backgroundColor {
    return [self initWithFrame:frame
                   textureSize:textureSize
               backgroundColor:backgroundColor
               backgroundImage:nil];
}

- (instancetype)initWithFrame:(CGRect)frame
                  textureSize:(CGSize)textureSize
              backgroundImage:(UIImage *)backgroundImage {
    return [self initWithFrame:frame
                   textureSize:textureSize
               backgroundColor:[UIColor whiteColor]
               backgroundImage:backgroundImage];
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
    
    [self.operationStack clear];
    [self.undoOperationStack clear];
}

- (void)undo {
    if ([self.operationStack isEmpty]) {
        return;
    }
    MFPaintModel *model = self.operationStack.topModel;
    [self.operationStack popModel];
    [self.undoOperationStack pushModel:model];
    
    [self reDraw];
}

- (void)redo {
    if ([self.undoOperationStack isEmpty]) {
        return;
    }
    MFPaintModel *model = self.undoOperationStack.topModel;
    [self.undoOperationStack popModel];
    [self.operationStack pushModel:model];
    
    [self drawModel:model];
}

- (BOOL)canUndo {
    return ![self.operationStack isEmpty];
}

- (BOOL)canRedo {
    return ![self.undoOperationStack isEmpty];
}

- (UIImage *)currentImage {
    UIImage *image = [self.paintTexture snapshot];
    return image;
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    if ([self.delegate respondsToSelector:@selector(paintViewWillBeginDraw:)]) {
        [self.delegate paintViewWillBeginDraw:self];
    }
    
    CGPoint point = [[touches anyObject] locationInView:self];
    NSArray *points = [self verticesWithPoints:@[@(point)]];
    
    [self.pointsPreDraw removeAllObjects];
    [self.pointsPreDraw addObjectsFromArray:points];
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
    
    [self addOperation];
    
    if ([self.delegate respondsToSelector:@selector(paintViewDidFinishDraw:)]) {
        [self.delegate paintViewDidFinishDraw:self];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    
    [self addPointWithTouches:touches];
    
    [self addOperation];
    
    if ([self.delegate respondsToSelector:@selector(paintViewDidFinishDraw:)]) {
        [self.delegate paintViewDidFinishDraw:self];
    }
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
    points = [self verticesWithPoints:[mutPoints copy]];

    [self.pointsPreDraw addObjectsFromArray:points];
    [self drawPointsToScreen:points];
    
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
    [self setBrushMode:GLPaintViewBrushModePaint];
}

- (void)setBrushMode:(GLPaintViewBrushMode)brushMode {
    _brushMode = brushMode;
    self.paintTexture.brushMode = (GLPaintTextureBrushMode)brushMode;
}

- (void)setBrushImageName:(NSString *)brushImageName {
    _brushImageName = [brushImageName copy];
    
    [self.paintTexture setBrushTextureUseFastModeIfCanWithImageName:brushImageName];
}

#pragma mark - Private

- (void)commonInit {
    [EAGLContext setCurrentContext:[GLPaintManager sharedPaintContext]];
    
    self.operationStack = [[MFPaintStack alloc] init];
    self.undoOperationStack = [[MFPaintStack alloc] init];
    self.pointsPreDraw = [[NSMutableArray alloc] init];
    
    self.vertices = malloc(sizeof(Vertex) * 4);
    self.vertices[0] = (Vertex){{-1, 1, 0}, {0, 1}};
    self.vertices[1] = (Vertex){{-1, -1, 0}, {0, 0}};
    self.vertices[2] = (Vertex){{1, 1, 0}, {1, 1}};
    self.vertices[3] = (Vertex){{1, -1, 0}, {1, 0}};
    
    [self setupGLLayer];
    [self genProgram];
    [self genBuffers];
    [self bindRenderLayer:self.glLayer];
    
    // 没有指定纹理尺寸，设置默认值
    if (CGSizeEqualToSize(self.textureSize, CGSizeZero)) {
        self.textureSize = CGSizeMake(self.drawableWidth, self.drawableHeight);
    }
    
    self.paintTexture = [[GLPaintTexture alloc] initWithSize:self.textureSize
                                             backgroundColor:self.backgroundColor
                                             backgroundImage:self.backgroundImage];
    [self bindTexture];
    
    self.brushSize = kDefaultBrushSize;
    self.brushColor = [UIColor blackColor];
    self.brushMode = GLPaintViewBrushModePaint;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self clear];
    });
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
    [[GLPaintManager sharedPaintContext] renderbufferStorage:GL_RENDERBUFFER
                                                fromDrawable:layer];
    
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
    glDisable(GL_BLEND);
    
    glViewport(0, 0, [self drawableWidth], [self drawableHeight]); // 绘制前先切换 Viewport
    
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    
    glUseProgram(self.program);
    
    GLuint positionSlot = glGetAttribLocation(self.program, "Position");
    GLuint textureCoordsSlot = glGetAttribLocation(self.program, "TextureCoords");
    
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(Vertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), NULL + offsetof(Vertex, positionCoord));
    
    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), NULL + offsetof(Vertex, textureCoord));
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    [[GLPaintManager sharedPaintContext] presentRenderbuffer:GL_RENDERBUFFER];
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

// 记录操作数据
- (void)addOperation {
    MFPaintModel *model = [[MFPaintModel alloc] init];
    model.brushSize = self.brushSize;
    model.brushColor = self.brushColor;
    model.brushImageName = self.brushImageName;
    model.brushMode = self.brushMode;
    model.points = self.pointsPreDraw;
    [self.operationStack pushModel:model];
    // 产生新的操作时，移除撤销的操作栈
    [self.undoOperationStack clear];
}

// 重新绘制全部 operationStack 中的数据
- (void)reDraw {
    CGFloat originBrushSize = self.brushSize;
    UIColor *originBrushColor = self.brushColor;
    NSString *originBrushImageName = self.brushImageName;
    GLPaintViewBrushMode originBrushMode = self.brushMode;
    
    [self.paintTexture clear];
    for (MFPaintModel *model in self.operationStack.modelList) {
        self.brushSize = model.brushSize;
        self.brushColor = model.brushColor;
        self.brushImageName = model.brushImageName;
        self.brushMode = model.brushMode;
        [self.paintTexture drawPoints:model.points];
    }
    [self display];
    
    // 绘制完，还原设置
    self.brushSize = originBrushSize;
    self.brushColor = originBrushColor;
    self.brushImageName = originBrushImageName;
    self.brushMode = originBrushMode;
}

// 绘制 model 中的数据
- (void)drawModel:(MFPaintModel *)model {
    CGFloat originBrushSize = self.brushSize;
    UIColor *originBrushColor = self.brushColor;
    NSString *originBrushImageName = self.brushImageName;
    GLPaintViewBrushMode originBrushMode = self.brushMode;
    
    self.brushSize = model.brushSize;
    self.brushColor = model.brushColor;
    self.brushImageName = model.brushImageName;
    self.brushMode = model.brushMode;
    [self.paintTexture drawPoints:model.points];
    [self display];
    
    // 绘制完，还原设置
    self.brushSize = originBrushSize;
    self.brushColor = originBrushColor;
    self.brushImageName = originBrushImageName;
    self.brushMode = originBrushMode;
}

@end
