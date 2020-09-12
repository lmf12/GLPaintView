//
//  GLPaintManager.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2020/9/12.
//  Copyright © 2020 Lyman Li. All rights reserved.
//

#import "GLPaintManager.h"

@implementation GLPaintManager

+ (EAGLContext *)sharedPaintContext {
    static dispatch_once_t onceToken;
    static EAGLContext *context;
    dispatch_once(&onceToken, ^{
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    });
    return context;
}

+ (dispatch_queue_t)sharedRenderQueue {
    static dispatch_once_t onceToken;
    static dispatch_queue_t renderQueue;
    dispatch_once(&onceToken, ^{
        renderQueue = dispatch_queue_create("com.lymanli.glpaint.render", DISPATCH_QUEUE_SERIAL);
    });
    return renderQueue;
}

@end
