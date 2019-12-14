//
//  MFBezierCurvesTool.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/25.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import "MFBezierCurvesTool.h"

float distance(CGPoint fromPoint, CGPoint toPoint) {
    return sqrtf(powf(fromPoint.x - toPoint.x, 2.0) + pow(fromPoint.y - toPoint.y, 2.0));
}

bool isCenter(CGPoint centerPoint, CGPoint fromPoint, CGPoint toPoint) {
    bool isCenterX = fabs((fromPoint.x + toPoint.x) / 2 - centerPoint.x) < 0.0001;
    bool isCenterY = fabs((fromPoint.y + toPoint.y) / 2 - centerPoint.y) < 0.0001;
    
    return isCenterX && isCenterY;
}

@implementation MFBezierCurvesTool

#pragma mark - Public

+ (NSArray<NSValue *> *)pointsWithFrom:(CGPoint)from
                                    to:(CGPoint)to
                               control:(CGPoint)control
                             pointSize:(CGFloat)pointSize {

    CGPoint P0 = from;
    // 如果 control 是 from 和 to 的中点，则将 control 设置为和 from 重合
    CGPoint P1 = isCenter(control, from, to) ? from : control;
    CGPoint P2 = to;

    float ax = P0.x - 2 * P1.x + P2.x;
    float ay = P0.y - 2 * P1.y + P2.y;
    float bx = 2 * P1.x - 2 * P0.x;
    float by = 2 * P1.y - 2 * P0.y;
    
    float A = 4 * (ax * ax + ay * ay);
    float B = 4 * (ax * bx + ay * by);
    float C = bx * bx + by * by;
    
    float totalLength = [self lengthWithT:1 A:A B:B C:C];  // 整条曲线的长度
    float pointsPerLength = 5.0 / pointSize;  // 用点的尺寸计算出，单位长度需要多少个点
    int count = MAX(1, ceilf(pointsPerLength * totalLength));  // 曲线应该生成的点数
    
    NSMutableArray *mutArr = [[NSMutableArray alloc] init];
    for(int i = 0; i <= count; ++i) {
        float t = i * 1.0f / count;
        float length = t*totalLength;
        t = [self tWithT:t length:length A:A B:B C:C];
        // 根据 t 求出坐标
        float x = (1-t)*(1-t)*P0.x +2*(1-t)*t*P1.x + t*t*P2.x;
        float y = (1-t)*(1-t)*P0.y +2*(1-t)*t*P1.y + t*t*P2.y;
        [mutArr addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
    }
    return [mutArr copy];
}

#pragma mark - Private

/*
 【注意】
 
 以下通过固定长度 length，推导出 t 的过程，可以参考这个链接：
 https://www.zhihu.com/question/27715729/answer/293563315
 
 以下有几个变量需要注意，它们是计算过程中产生的中间变量，为了简化表达式。
 假如贝塞尔曲线的起始点是 P0，控制点是 P1，终止点是 P2。
 则：
 
 float ax = P0.x - 2 * P1.x + P2.x;
 float ay = P0.y - 2 * P1.y + P2.y;
 float bx = 2 * P1.x - 2 * P0.x;
 float by = 2 * P1.y - 2 * P0.y;
 
 float A = 4 * (ax * ax + ay * ay);
 float B = 4 * (ax * bx + ay * by);
 float C = bx * bx + by * by;
 
 */



/**
 长度函数反函数，根据 length，求出对应的 t，使用牛顿切线法求解

 @param t 给出的近似的 t，比如求长度占弧长 0.3 的 t，t 应该是接近 0.3，则传入近似值 0.3
 @param length 目标弧长，实际长度，非占比
 @param A 见【注意】
 @param B 见【注意】
 @param C 见【注意】
 @return 结果 t 值
 */
+ (float)tWithT:(float)t
         length:(float)length
              A:(float)A
              B:(float)B
              C:(float)C {
    float t1 = t;
    float t2;
    
    while (YES) {
        float speed = [self speedWithT:t1 A:A B:B C:C];
        if (speed < 0.0001f) {
            t2 = t1;
            break;
        }
        t2 = t1 - ([self lengthWithT:t1 A:A B:B C:C] - length) / speed;
        if(ABS(t1 - t2) < 0.0001f) {
            break;
        }
        t1 = t2;
    }
    return t2;
}

/**
 速度函数 s(t) = sqrt(A * t^2 + B * t + C)

 @param t t 值
 @param A 见【注意】
 @param B 见【注意】
 @param C 见【注意】
 @return 贝塞尔曲线某一点的速度
 */
+ (float)speedWithT:(float)t
                  A:(float)A
                  B:(float)B
                  C:(float)C {
    return sqrtf(MAX(A * pow(t, 2.0) + B * t + C, 0));
}

/**
 长度函数

 @param t t 值
 @param A 见【注意】
 @param B 见【注意】
 @param C 见【注意】
 @return t 值对应的曲线长度
 */
+ (float)lengthWithT:(float)t
                   A:(float)A
                   B:(float)B
                   C:(float)C {
    if (A < 0.00001f) {
        return 0.0f;
    }
    
    float temp1 = sqrtf(C + t * (B + A * t));
    float temp2 = (2 * A * t * temp1 + B * (temp1 - sqrtf(C)));
    float temp3 = log(ABS(B + 2 * sqrtf(A) * sqrtf(C) + 0.0001f));
    float temp4 = log(ABS(B + 2 * A * t + 2 * sqrtf(A) * temp1) + 0.0001f);
    float temp5 = 2 * sqrtf(A) * temp2;
    float temp6 = (B * B - 4 * A * C) * (temp3 - temp4);

    return (temp5 + temp6) / (8 * powf(A, 1.5f));
}

@end
