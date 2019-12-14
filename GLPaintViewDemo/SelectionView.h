//
//  SelectionView.h
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/12/14.
//  Copyright © 2019 Lyman Li. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SelectionModel.h"

@class SelectionView;

@protocol SelectionViewDelegate <NSObject>

- (void)selectionView:(SelectionView *)selectionView didSelectModel:(SelectionModel *)model;

@end

@interface SelectionView : UIView

@property (nonatomic, weak) id <SelectionViewDelegate> delegate;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<SelectionModel *> *models;

- (void)selectIndex:(NSInteger)index;

@end
