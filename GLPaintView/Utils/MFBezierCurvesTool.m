//
//  MFBezierCurvesTool.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/25.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import "MFBezierCurvesTool.h"

@implementation MFBezierCurvesTool

#pragma mark - Public

+ (NSArray<NSValue *> *)pointsWithFrom:(CGPoint)from
                                    to:(CGPoint)to
                               control:(CGPoint)control {
    float len = 0.05;
    float t = 0;
    NSMutableArray *mutArr = [[NSMutableArray alloc] init];
    while (t <= 1.0) {
        float x = pow(1 - t, 2) * from.x + 2 * t * (1 - t) * control.x + pow(t, 2) * to.x;
        float y = pow(1 - t, 2) * from.y + 2 * t * (1 - t) * control.y + pow(t, 2) * to.y;
        [mutArr addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
        t += len;
    }
    return [mutArr copy];
}

@end
