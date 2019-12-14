//
//  SelectionCell.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/12/14.
//  Copyright © 2019 Lyman Li. All rights reserved.
//

#import "SelectionCell.h"

@interface SelectionCell ()

@property (nonatomic, strong) UIButton *content;
@property (nonatomic, strong) UIView *selectView;

@end

@implementation SelectionCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self.backgroundColor = [UIColor blackColor];
    [self.content setImage:nil forState:UIControlStateNormal];
    [self.content setTitle:nil forState:UIControlStateNormal];
    self.selectView.hidden = YES;
}

#pragma mark - Custom Accessor

- (void)setModel:(SelectionModel *)model {
    _model = model;
    
    if (model.imageName) {
        [self.content setImage:[UIImage imageNamed:model.imageName]
                      forState:UIControlStateNormal];
    } else if (model.title) {
        [self.content setTitle:model.title
                      forState:UIControlStateNormal];
    } else {
        self.backgroundColor = model.color;
    }
}

- (void)setIsSelect:(BOOL)isSelect {
    _isSelect = isSelect;
    
    self.selectView.hidden = !isSelect;
}

#pragma mark - Private

- (void)commonInit {
    self.backgroundColor = [UIColor blackColor];
    self.layer.masksToBounds = YES;
    self.layer.cornerRadius = 5;
    self.content = [[UIButton alloc] initWithFrame:self.bounds];
    self.content.titleLabel.font = [UIFont systemFontOfSize:14];
    self.content.userInteractionEnabled = NO;
    [self.content setTitleColor:[UIColor whiteColor]
                       forState:UIControlStateNormal];
    [self addSubview:self.content];
    
    self.selectView = [[UIView alloc] initWithFrame:self.bounds];
    self.selectView.backgroundColor = [UIColor clearColor];
    self.selectView.layer.borderColor = [UIColor redColor].CGColor;
    self.selectView.layer.borderWidth = 4;
    self.selectView.hidden = YES;
    [self addSubview:self.selectView];
}

@end
