//
//  ViewController.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/21.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import "GLPaintView.h"

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic, strong) GLPaintView *paintView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self commonInit];
}

- (void)commonInit {
    self.paintView = [[GLPaintView alloc] initWithFrame:CGRectMake(0, 100, self.view.bounds.size.width, self.view.bounds.size.width)];
    self.paintView.layer.borderColor = [[UIColor grayColor] CGColor];
    self.paintView.layer.borderWidth = 1;
    [self.view addSubview:self.paintView];
}

@end
