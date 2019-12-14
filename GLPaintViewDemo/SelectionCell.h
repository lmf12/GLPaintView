//
//  SelectionCell.h
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/12/14.
//  Copyright © 2019 Lyman Li. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SelectionModel.h"

@interface SelectionCell : UICollectionViewCell

@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, strong) SelectionModel *model;

@end
