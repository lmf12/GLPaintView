//
//  GLPaintTexture.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/28.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import "GLPaintManager.h"
#import "MFShaderHelper.h"
#import "UIColor+Extension.h"

#import "GLPaintTexture.h"

typedef struct {
    float positionCoord[3];
} Vertex;

@interface GLPaintTexture ()

@property (nonatomic, assign, readwrite) CGSize size;
@property (nonatomic, assign, readwrite) GLuint textureID;  // 最终输出的结果
@property (nonatomic, strong, readwrite) UIColor *backgroundColor;
@property (nonatomic, strong) UIImage *backgroundImage;

// 绘画在 paintTextureID 上进行，
// 绘制完成后，paintTextureID 和 backgroundTextureID 进行叠加，绘制到 textureID 上
@property (nonatomic, assign) GLuint backgroundTextureID;  // 背景图纹理 ID
@property (nonatomic, assign) GLuint paintTextureID;  // 绘画的纹理 ID

@property (nonatomic, assign) GLuint normalVertexBuffer;  // 用于纹理叠加的顶点缓存

@property (nonatomic, assign) Vertex *vertices; // 顶点数组
@property (nonatomic, assign) int currentVertexSize; // 记录顶点数组的容量，当容量不足的时候才扩容，避免频繁申请内存空间
@property (nonatomic, assign) int vertexCount;  //  顶点数

@property (nonatomic, assign) GLuint frameBuffer; // 帧缓存
@property (nonatomic, assign) GLuint renderBuffer; // 渲染缓存
@property (nonatomic, assign) GLuint vertexBuffer; // 顶点缓存

@property (nonatomic, assign) GLuint brushProgram; // 绘画着色器程序
@property (nonatomic, assign) GLuint normalProgram; // 纹理叠加着色器程序
@property (nonatomic, assign) GLuint brushTextureID; // 笔触纹理

@property (nonatomic, strong) NSMutableDictionary *brushTextureCache;  // 笔触纹理缓存

@end

@implementation GLPaintTexture

- (void)dealloc {
    if (_vertices) {
        free(_vertices);
        _vertices = nil;
    }
    if (_brushProgram) {
        glUseProgram(0);
        glDeleteProgram(_brushProgram);
    }
    if (_normalProgram) {
        glUseProgram(0);
        glDeleteProgram(_normalProgram);
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
    if (_paintTextureID > 0) {
        glDeleteTextures(1, &_paintTextureID);
    }
    if (_backgroundTextureID > 0) {
        glDeleteTextures(1, &_backgroundTextureID);
    }
    [self deleteBuffers];
}

- (instancetype)initWithSize:(CGSize)size
             backgroundColor:(UIColor *)backgroundColor
             backgroundImage:(UIImage *)backgroundImage{
    self = [super init];
    if (self) {
        self.size = size;
        self.backgroundColor = backgroundColor;
        self.backgroundImage = backgroundImage;
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
    [self renderBackground];
    [self renderPaint];
}

- (void)setColor:(UIColor *)color {
    MFColor mfColor = [color mf_color];
    
    glUseProgram(self.brushProgram);
    GLuint rSlot = glGetUniformLocation(self.brushProgram, "R");
    GLuint gSlot = glGetUniformLocation(self.brushProgram, "G");
    GLuint bSlot = glGetUniformLocation(self.brushProgram, "B");
    GLuint aSlot = glGetUniformLocation(self.brushProgram, "A");
    
    glUniform1f(rSlot, mfColor.r);
    glUniform1f(gSlot, mfColor.g);
    glUniform1f(bSlot, mfColor.b);
    glUniform1f(aSlot, mfColor.a);
}

- (void)setBrushSize:(CGFloat)brushSize {
    glUseProgram(self.brushProgram);
    GLuint sizeSlot = glGetUniformLocation(self.brushProgram, "Size");
    
    GLfloat size = brushSize / 100.0 * [self drawableWidth] / 4.0; // 按照 100 占宽度四分之一来等比缩放
    glUniform1f(sizeSlot, size);
}

- (void)clear {
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.paintTextureID, 0);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    [self renderBackground];
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
    }
}

- (UIImage *)snapshot {
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.textureID, 0);
    UIImage *image = [self imageFromTextureWithWidth:[self drawableWidth]
                                              height:[self drawableHeight]];
    return image;
}

#pragma mark - Private

- (void)commonInit {
    [EAGLContext setCurrentContext:[GLPaintManager sharedPaintContext]];
    
    self.brushTextureCache = [[NSMutableDictionary alloc] init];
    self.brushMode = GLPaintTextureBrushModePaint;
    
    // 创建着色器程序
    [self genBrushProgram];
    [self genNormalProgram];
    
    // 创建缓存
    [self genBuffers];
    [self setupNormalVertexBuffer];
    
    // 创建纹理
    [self genTargetTexture];
    [self genPaintTexture];
    [self genBackgroundTexture];
    
    // 初始化笔触纹理
    [self setBrushTextureWithImageName:@"brush1.png" isFastMode:NO];
}

// 创建 brushProgram
- (void)genBrushProgram {
    self.brushProgram = [MFShaderHelper programWithShaderName:@"brush"];
}

// 创建 normalProgram
- (void)genNormalProgram {
    self.normalProgram = [MFShaderHelper programWithShaderName:@"normal"];
}

// 创建 buffer
- (void)genBuffers {
    glGenFramebuffers(1, &_frameBuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    glGenBuffers(1, &_vertexBuffer);
}

// 初始化绘制纹理的顶点缓存
- (void)setupNormalVertexBuffer {
    float vertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,
        -1.0f, 1.0f, 0.0f, 0.0f, 1.0f,
        1.0f, -1.0f, 0.0f, 1.0f, 0.0f,
        1.0f, 1.0f, 0.0f, 1.0f, 1.0f,
    };
    
    glGenBuffers(1, &_normalVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _normalVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
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

// 创建绘画纹理
- (void)genPaintTexture {
    glGenTextures(1, &_paintTextureID);
    glBindTexture(GL_TEXTURE_2D, _paintTextureID);
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, [self drawableWidth], [self drawableHeight], 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _paintTextureID, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

// 创建背景纹理
- (void)genBackgroundTexture {
    if (self.backgroundImage) {
        self.backgroundTextureID = [MFShaderHelper createTextureWithImage:self.backgroundImage];
    }
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
    if (_normalVertexBuffer != 0) {
        glDeleteBuffers(1, &_normalVertexBuffer);
    }
}

// 绘制 vertices 中保存的顶点
- (void)renderPoints {
    glEnable(GL_BLEND);
    if (self.brushMode == GLPaintTextureBrushModePaint) {
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    } else {
        glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_ALPHA);
    }
    
    glViewport(0, 0, [self drawableWidth], [self drawableHeight]); // 绘制前先切换 Viewport
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    // 绑定到绘画纹理
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.paintTextureID, 0);
    
    glUseProgram(self.brushProgram);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.brushTextureID);
    glUniform1i(glGetUniformLocation(self.brushProgram, "Texture"), 0);
    
    GLuint positionSlot = glGetAttribLocation(self.brushProgram, "Position");
    
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(Vertex) * self.vertexCount;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), NULL + offsetof(Vertex, positionCoord));
    
    glDrawArrays(GL_POINTS, 0, self.vertexCount);
}

// 绘制背景颜色和背景图片
- (void)renderBackground {
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glViewport(0, 0, [self drawableWidth], [self drawableHeight]);
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.textureID, 0);
    MFColor mfColor = [self.backgroundColor mf_color];
    glClearColor(mfColor.r, mfColor.g, mfColor.b, mfColor.a);
    glClear(GL_COLOR_BUFFER_BIT);
    
    if (self.backgroundTextureID) {
        glBindBuffer(GL_ARRAY_BUFFER, self.normalVertexBuffer);
        
        glUseProgram(self.normalProgram);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, self.backgroundTextureID);
        glUniform1i(glGetUniformLocation(self.normalProgram, "Texture"), 0);
        
        GLuint positionSlot = glGetAttribLocation(self.normalProgram, "Position");
        GLuint textureSlot = glGetAttribLocation(self.normalProgram, "TextureCoords");
        
        glEnableVertexAttribArray(positionSlot);
        glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(textureSlot);
        glVertexAttribPointer(textureSlot, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3* sizeof(float)));
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
}

// 绘制绘画的结果
- (void)renderPaint {
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glViewport(0, 0, [self drawableWidth], [self drawableHeight]);
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.textureID, 0);
    glBindBuffer(GL_ARRAY_BUFFER, self.normalVertexBuffer);
    
    glUseProgram(self.normalProgram);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.paintTextureID);
    glUniform1i(glGetUniformLocation(self.normalProgram, "Texture"), 0);
    
    GLuint positionSlot = glGetAttribLocation(self.normalProgram, "Position");
    GLuint textureSlot = glGetAttribLocation(self.normalProgram, "TextureCoords");
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(textureSlot);
    glVertexAttribPointer(textureSlot, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3* sizeof(float)));
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

// 获取图片
- (UIImage *)imageFromTextureWithWidth:(int)width height:(int)height {
    int size = width * height * 4;
    GLubyte *buffer = malloc(size);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, size, NULL);
    int bitsPerComponent = 8;
    int bitsPerPixel = 32;
    int bytesPerRow = 4 * width;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef imageRef = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    free(buffer);
    return image;
}

@end
