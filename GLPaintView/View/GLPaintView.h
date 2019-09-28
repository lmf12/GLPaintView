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

@interface GLPaintView : UIView

/// 笔刷尺寸，默认 40
@property (nonatomic, assign) CGFloat brushSize;
/// 笔刷颜色，默认黑色
@property (nonatomic, strong) UIColor *brushColor;
/// 笔刷模式，默认画笔
@property (nonatomic, assign) GLPaintViewBrushMode brushMode;

///通过图片文件名来创建笔触形状
- (void)setBrushImageWithImageName:(NSString *)imageName;

/// 清空画布
- (void)clear;

@end

