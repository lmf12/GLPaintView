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

#pragma mark - Private

- (void)commonInit {
    [self setupGLLayer];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
    
    // 创建顶点数组
    self.vertices = malloc(sizeof(Vertex) * 4); // 4 个顶点
    
    self.vertices[0] = (Vertex){{-0.5, 0.5, 0}};
    self.vertices[1] = (Vertex){{-0.5, -0.5, 0}};
    self.vertices[2] = (Vertex){{0.5, 0.5, 0}};
    self.vertices[3] = (Vertex){{0.5, -0.5, 0}};
    
    // 加载笔触纹理
    NSString *imagePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"brush.png"];
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    self.brushTextureID = [MFShaderHelper createTextureWithImage:image];
    
    // 创建着色器程序
    [self genProgram];
    
    // 创建缓存
    [self genBuffers];
    
    // 绑定纹理输出的层
    [self bindRenderLayer:self.glLayer];
    
    // 指定窗口大小
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    // 设置混合模式，才能正确渲染带有透明部分的纹理
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    // 开始渲染
    [self display];
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
}

// 创建 buffer
- (void)genBuffers {
    glGenFramebuffers(1, &_frameBuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    glGenBuffers(1, &_vertexBuffer);
}

// 绑定图像要输出的 layer
- (void)bindRenderLayer:(CALayer <EAGLDrawable> *)layer {
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER,
                              _renderBuffer);
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

// 刷新视图
- (void)display {
    glUseProgram(self.program);
    
    GLuint positionSlot = glGetAttribLocation(self.program, "Position");
    GLuint textureSlot = glGetUniformLocation(self.program, "Texture");
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.brushTextureID);
    glUniform1i(textureSlot, 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(Vertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), NULL + offsetof(Vertex, positionCoord));
    
    // 将背景清除成白色
    glClearColor (1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glDrawArrays(GL_POINTS, 0, 4);
    
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

@end
