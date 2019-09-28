//
//  UIColor+Extension.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/28.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import "UIColor+Extension.h"

@implementation UIColor (Extension)

- (MFColor)mf_color {
    double r = 0;
    double g = 0;
    double b = 0;
    double a = 0;
    
    [self getRed:&r green:&g blue:&b alpha:&a];
    
    MFColor color;
    color.r = r;
    color.g = g;
    color.b = b;
    color.a = a;
    
    return color;
}

@end
