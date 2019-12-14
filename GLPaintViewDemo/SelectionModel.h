//
//  SelectionModel.h
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/12/14.
//  Copyright © 2019 Lyman Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SelectionModel : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *imageName;
@property (nonatomic, strong) UIColor *color;

@end

