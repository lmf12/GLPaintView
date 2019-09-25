//
//  GLPaintView.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/21.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import <OpenGLES/ES2/gl.h>

#import "MFShaderHelper.h"

#import "GLPaintView.h"

typedef struct {
    float positionCoord[3];
} Vertex;

@interface GLPaintView ()

@property (nonatomic, assign) Vertex *vertices; // 顶点数组
@property (nonatomic, assign) int currentVertexSize; // 记录顶点数组的容量，当容量不足的时候才扩容，避免频繁申请内存空间
@property (nonatomic, assign) int vertexCount;  //  顶点数

@property (nonatomic, strong) EAGLContext *context;

@property (nonatomic, assign) GLuint frameBuffer; // 帧缓存
@property (nonatomic, assign) GLuint renderBuffer; // 渲染缓存
@property (nonatomic, assign) GLuint vertexBuffer; // 顶点缓存

@property (nonatomic, assign) GLuint program; // 着色器程序
@property (nonatomic, assign) GLuint brushTextureID; // 笔触纹理

@property (nonatomic, strong) CAEAGLLayer *glLayer;

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
    if (_brushTextureID > 0) {
        glDeleteTextures(1, &_brushTextureID);
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

#pragma mark - Touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    CGPoint point = [[touches anyObject] locationInView:self];
    [self genVerticesWithPoint:point];
    [self renderPoints];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
}

#pragma mark - Private

- (void)commonInit {
    [self setupGLLayer];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
    
    // 创建着色器程序
    [self genProgram];
    
    // 创建缓存
    [self genBuffers];
    
    // 绑定纹理输出的层
    [self bindRenderLayer:self.glLayer];
    
    // 初始化笔触纹理
    [self setBrushTextureWithImageName:@"brush.png"];
    
    // 指定窗口大小
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    // 设置混合模式，才能正确渲染带有透明部分的纹理
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    // 清除画布
    [self clear];
}

// 创建输出层
- (void)setupGLLayer {
    CAEAGLLayer *layer = [[CAEAGLLayer alloc] init];
    layer.frame = self.bounds;
    layer.contentsScale = [[UIScreen mainScreen] scale];
    self.glLayer = layer;
    
    [self.layer addSublayer:self.glLayer];
}

// 创建 program
- (void)genProgram {
    self.program = [MFShaderHelper programWithShaderName:@"brush"];
    glUseProgram(self.program);
}

// 创建 buffer
- (void)genBuffers {
    glGenFramebuffers(1, &_frameBuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    glGenBuffers(1, &_vertexBuffer);
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

// 通过笔触的图片，来设置当前使用的笔触纹理
- (void)setBrushTextureWithImageName:(NSString *)imageName {
    // 加载纹理
    NSString *imagePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"brush.png"];
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    self.brushTextureID = [MFShaderHelper createTextureWithImage:image];
    
    // 将纹理设置到着色器中
    GLuint textureSlot = glGetUniformLocation(self.program, "Texture");
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.brushTextureID);
    glUniform1i(textureSlot, 0);
}

// 生成本次需要绘制的顶点
- (void)genVerticesWithPoint:(CGPoint)point {
    self.vertexCount = 1;
    
    // 容量不足，扩容
    if (self.vertexCount > self.currentVertexSize) {
        if (self.vertices) {
            free(self.vertices);
        }
        self.vertices = malloc(sizeof(Vertex) * self.vertexCount);
        self.currentVertexSize = self.vertexCount;
    }
    // 遍历赋值
    for (int i = 0; i < self.vertexCount; ++i) {
        self.vertices[i] = [self vertexWithPoint:point];
    }
}

// 通过 UIKit 的点坐标，转化成 OpenGL 的顶点
- (Vertex)vertexWithPoint:(CGPoint)point {
    float x = (point.x / self.frame.size.width) * 2 - 1;
    float y = 1 - (point.y / self.frame.size.height) * 2;
    return (Vertex){{x, y, 0}};
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

// 渲染 vertices 中保存的顶点
- (void)renderPoints {
    GLuint positionSlot = glGetAttribLocation(self.program, "Position");
    
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(Vertex) * self.vertexCount;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), NULL + offsetof(Vertex, positionCoord));
    
    glDrawArrays(GL_POINTS, 0, self.vertexCount);
    
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

// 清除画布
- (void)clear {
    glClearColor (1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
}

@end
