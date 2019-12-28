//
//  MFPaintModel.h
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/12/28.
//  Copyright © 2019 Lyman Li. All rights reserved.
//

#import "GLPaintView.h"

@interface MFPaintModel : NSObject

/// 笔刷尺寸
@property (nonatomic, assign) CGFloat brushSize;
/// 笔刷颜色
@property (nonatomic, strong) UIColor *brushColor;
/// 笔刷模式
@property (nonatomic, assign) GLPaintViewBrushMode brushMode;
/// 笔触纹理图片文件名
@property (nonatomic, copy) NSString *brushImageName;
/// 点序列
@property (nonatomic, copy) NSArray<NSValue *> *points;

@end
