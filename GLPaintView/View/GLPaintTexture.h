//
//  GLPaintTexture.h
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/28.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>

/**
 处理涂抹的绘制逻辑，最终输出一张纹理
 */
@interface GLPaintTexture : NSObject

/// 纹理尺寸
@property (nonatomic, assign, readonly) CGSize size;

/// 纹理ID
@property (nonatomic, assign, readonly) GLuint textureID;

/// 通过上下文和纹理尺寸来初始化
- (instancetype)initWithContext:(EAGLContext *)context size:(CGSize)size;

/// 绘制顶点，顶点是归一化的坐标
- (void)drawPoints:(NSArray <NSValue *>*)points;

/// 设置颜色
- (void)setColor:(UIColor *)color;

/// 设置尺寸
- (void)setBrushSize:(CGFloat)brushSize;

/// 清除画布
- (void)clear;

/// 如果有缓存，使用快速模式，否则使用普通模式
- (void)setBrushTextureUseFastModeIfCanWithImageName:(NSString *)imageName;

/// 通过笔触的图片，来设置当前使用的笔触纹理
/// isFastMode 是否快速模式，会读取缓存的纹理，读取前请确保之前缓存过 
- (void)setBrushTextureWithImageName:(NSString *)imageName
                          isFastMode:(BOOL)isFastMode;

/// 当前的图片
- (UIImage *)snapshot;

@end
