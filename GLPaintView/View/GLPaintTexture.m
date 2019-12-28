//
//  GLPaintTexture.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/28.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import "MFShaderHelper.h"

#import "UIColor+Extension.h"

#import "GLPaintTexture.h"

typedef struct {
    float positionCoord[3];
} Vertex;

@interface GLPaintTexture ()

@property (nonatomic, assign, readwrite) CGSize size;
@property (nonatomic, assign, readwrite) GLuint textureID;


@property (nonatomic, assign) Vertex *vertices; // 顶点数组
@property (nonatomic, assign) int currentVertexSize; // 记录顶点数组的容量，当容量不足的时候才扩容，避免频繁申请内存空间
@property (nonatomic, assign) int vertexCount;  //  顶点数

@property (nonatomic, strong) EAGLContext *context;

@property (nonatomic, assign) GLuint frameBuffer; // 帧缓存
@property (nonatomic, assign) GLuint renderBuffer; // 渲染缓存
@property (nonatomic, assign) GLuint vertexBuffer; // 顶点缓存

@property (nonatomic, assign) GLuint program; // 着色器程序
@property (nonatomic, assign) GLuint brushTextureID; // 笔触纹理

@property (nonatomic, strong) NSMutableDictionary *brushTextureCache;  // 笔触纹理缓存

@end

@implementation GLPaintTexture

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
    // 删除笔触纹理
    [self.brushTextureCache enumerateKeysAndObjectsUsingBlock:^(NSString *key,
                                                                NSMutableArray<NSNumber *> *IDs,
                                                                BOOL *stop) {
        for (NSNumber *number in IDs) {
            GLuint textureID = [number intValue];
            if (textureID > 0) {
                glDeleteTextures(1, &textureID);
            }
        }
    }];
    
    if (_textureID > 0) {
        glDeleteTextures(1, &_textureID);
    }
    [self deleteBuffers];
}

- (instancetype)initWithContext:(EAGLContext *)context size:(CGSize)size {
    self = [super init];
    if (self) {
        self.context = context;
        self.size = size;
        [self commonInit];
    }
    return self;
}

#pragma mark - Public

- (void)drawPoints:(NSArray<NSValue *> *)points {
    self.vertexCount = (int)[points count];
    
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
        self.vertices[i] = (Vertex){points[i].CGPointValue.x, points[i].CGPointValue.y, 0};
    }
    // 渲染
    [self renderPoints];
}

- (void)setColor:(UIColor *)color {
    MFColor mfColor = [color mf_color];
    
    glUseProgram(self.program);
    GLuint rSlot = glGetUniformLocation(self.program, "R");
    GLuint gSlot = glGetUniformLocation(self.program, "G");
    GLuint bSlot = glGetUniformLocation(self.program, "B");
    GLuint aSlot = glGetUniformLocation(self.program, "A");
    
    glUniform1f(rSlot, mfColor.r);
    glUniform1f(gSlot, mfColor.g);
    glUniform1f(bSlot, mfColor.b);
    glUniform1f(aSlot, mfColor.a);
}

- (void)setBrushSize:(CGFloat)brushSize {
    glUseProgram(self.program);
    GLuint sizeSlot = glGetUniformLocation(self.program, "Size");
    
    GLfloat size = brushSize / 100.0 * [self drawableWidth] / 4.0; // 按照 100 占宽度四分之一来等比缩放
    glUniform1f(sizeSlot, size);
}

- (void)clear {
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    
    glClearColor (1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
}

- (void)setBrushTextureUseFastModeIfCanWithImageName:(NSString *)imageName {
    NSMutableArray *textureIDs = [self.brushTextureCache valueForKey:imageName];
    [self setBrushTextureWithImageName:imageName isFastMode:textureIDs != nil];
}

- (void)setBrushTextureWithImageName:(NSString *)imageName
                          isFastMode:(BOOL)isFastMode {
    if (imageName.length == 0) {
        return;
    }
    if (isFastMode) {
        NSMutableArray *textureIDs = [self.brushTextureCache valueForKey:imageName];
        if (!textureIDs) {
            return;
        }
        self.brushTextureID = (GLuint)[[textureIDs firstObject] intValue];
        [self applyBrushTexture];
    } else {
        // 加载纹理
        UIImage *image = [UIImage imageNamed:imageName];
        self.brushTextureID = [MFShaderHelper createTextureWithImage:image];
        
        // 添加缓存
        NSMutableArray *textureIDs = [self.brushTextureCache valueForKey:imageName];
        if (!textureIDs) {
            textureIDs = [[NSMutableArray alloc] init];
        }
        [textureIDs addObject:@(self.brushTextureID)];
        [self.brushTextureCache setValue:textureIDs forKey:imageName];
        
        // 异步应用
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applyBrushTexture];
        });
    }
}

#pragma mark - Private

- (void)commonInit {
    self.brushTextureCache = [[NSMutableDictionary alloc] init];
    
    // 创建着色器程序
    [self genProgram];
    
    // 创建缓存
    [self genBuffers];
    
    // 创建目标纹理
    [self genTargetTexture];
    
    // 初始化笔触纹理
    [self setBrushTextureWithImageName:@"brush1.png" isFastMode:NO];
     
    // 设置混合模式，才能正确渲染带有透明部分的纹理
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    // 清除画布
    [self clear];
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

// 创建目标纹理
- (void)genTargetTexture {
    glGenTextures(1, &_textureID);
    glBindTexture(GL_TEXTURE_2D, _textureID);
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, [self drawableWidth], [self drawableHeight], 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _textureID, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

// 获取渲染缓存宽度
- (GLint)drawableWidth {
    return self.size.width;
}

// 获取渲染缓存高度
- (GLint)drawableHeight {
    return self.size.height;
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
    glViewport(0, 0, [self drawableWidth], [self drawableHeight]); // 绘制前先切换 Viewport
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    
    glUseProgram(self.program);
    GLuint positionSlot = glGetAttribLocation(self.program, "Position");
    
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(Vertex) * self.vertexCount;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), NULL + offsetof(Vertex, positionCoord));
    
    glDrawArrays(GL_POINTS, 0, self.vertexCount);
}

// 应用笔触纹理
- (void)applyBrushTexture {
    glUseProgram(self.program);
    GLuint textureSlot = glGetUniformLocation(self.program, "Texture");
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.brushTextureID);
    glUniform1i(textureSlot, 0);
}

@end
