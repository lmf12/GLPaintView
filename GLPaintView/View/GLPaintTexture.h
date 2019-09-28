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

/// 清除画布
- (void)clear;

@end
