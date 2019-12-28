//
//  MFPaintStack.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/12/28.
//  Copyright © 2019 Lyman Li. All rights reserved.
//

#import "MFPaintStack.h"

@interface MFPaintStack ()

@property (nonatomic, strong) NSMutableArray<MFPaintModel *> *models;

@end

@implementation MFPaintStack

- (instancetype)init {
    self = [super init];
    if (self) {
        self.models = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - Public

- (void)pushModel:(MFPaintModel *)model {
    if (![model isKindOfClass:[MFPaintModel class]]) {
        return;
    }
    [self.models addObject:model];
}

- (void)popModel {
    [self.models removeLastObject];
}

- (MFPaintModel *)topModel {
    return [self.models lastObject];
}

- (BOOL)isEmpty {
    return self.models.count == 0;
}

- (NSArray<MFPaintModel *> *)modelList {
    return [self.models copy];
}

- (void)clear {
    [self.models removeAllObjects];
}

@end
