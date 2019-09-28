//
//  UIColor+Extension.h
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/28.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef struct {
    float r;
    float g;
    float b;
    float a;
} MFColor;

@interface UIColor (Extension)

- (MFColor)mf_color;

@end
