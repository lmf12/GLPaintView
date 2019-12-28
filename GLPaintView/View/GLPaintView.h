//
//  GLPaintView.h
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/21.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 笔刷模式
 
 - MFPaintViewBrushModePaint: 画笔
 - MFPaintViewBrushModeEraser: 橡皮擦
 */
typedef NS_ENUM(NSUInteger, GLPaintViewBrushMode) {
    MFPaintViewBrushModePaint,
    MFPaintViewBrushModeEraser,
};

@class GLPaintView;

@protocol GLPaintViewDelegate <NSObject>

/// 即将开始绘画
- (void)paintViewWillBeginDraw:(GLPaintView *)paintView;
/// 结束绘画
- (void)paintViewDidFinishDraw:(GLPaintView *)paintView;

@end

@interface GLPaintView : UIView

/// 代理
@property (nonatomic, weak) id<GLPaintViewDelegate> delegate;

/// 笔刷尺寸，默认 40，建议设置小于等于 100 
@property (nonatomic, assign) CGFloat brushSize;
/// 笔刷颜色，默认黑色
@property (nonatomic, strong) UIColor *brushColor;
/// 笔刷模式，默认画笔
@property (nonatomic, assign) GLPaintViewBrushMode brushMode;
///  笔触纹理图片文件名，默认 "brush1.png"
@property (nonatomic, copy) NSString *brushImageName;

/// 纹理尺寸，即画布的实际大小，影响最终生成图片的分辨率，默认与 View 的渲染尺寸相同
@property (nonatomic, assign, readonly) CGSize textureSize;

/// 通过 frame 和 textureSize 初始化
- (instancetype)initWithFrame:(CGRect)frame textureSize:(CGSize)textureSize;

/// 撤销
- (void)undo;

/// 重做
- (void)redo;

/// 是否能撤销
- (BOOL)canUndo;

/// 是否能重做
- (BOOL)canRedo;

/// 清空画布
- (void)clear;

/// 当前的图片
- (UIImage *)currentImage;

@end

