//
//  MFPaintStack.h
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/12/28.
//  Copyright © 2019 Lyman Li. All rights reserved.
//

#import "MFPaintModel.h"

@interface MFPaintStack : NSObject

/// 入栈
- (void)pushModel:(MFPaintModel *)model;
/// 出栈
- (void)popModel;
/// 获取栈顶元素
- (MFPaintModel *)topModel;
/// 栈是否为空
- (BOOL)isEmpty;
/// 栈中的数据
- (NSArray<MFPaintModel *> *)modelList;
/// 移除所有元素
- (void)clear;

@end
