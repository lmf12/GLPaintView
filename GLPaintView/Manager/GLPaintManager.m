//
//  GLPaintManager.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2020/9/12.
//  Copyright © 2020 Lyman Li. All rights reserved.
//

#import "GLPaintManager.h"

static void *GLPaintQueueKey;

@implementation GLPaintManager

void runAsynOnPaintRenderQueue(void (^block)(void)) {
    dispatch_queue_t queue = [GLPaintManager sharedRenderQueue];
    if (dispatch_get_specific(GLPaintQueueKey)) {
        block();
    } else {
        dispatch_async(queue, block);
    }
}

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
        GLPaintQueueKey = &GLPaintQueueKey;
        renderQueue = dispatch_queue_create("com.lymanli.glpaint.render", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(renderQueue, GLPaintQueueKey, (__bridge void *)self, NULL);
    });
    return renderQueue;
}

@end
