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

@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (weak, nonatomic) IBOutlet UIButton *colorButton1;
@property (weak, nonatomic) IBOutlet UIButton *colorButton2;
@property (weak, nonatomic) IBOutlet UIButton *colorButton3;
@property (weak, nonatomic) IBOutlet UIButton *colorButton4;
@property (weak, nonatomic) IBOutlet UIButton *colorButton5;

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
    
    [self setCornerRadius:self.clearButton];
    [self setCornerRadius:self.colorButton1];
    [self setCornerRadius:self.colorButton2];
    [self setCornerRadius:self.colorButton3];
    [self setCornerRadius:self.colorButton4];
    [self setCornerRadius:self.colorButton5];
}

- (void)setCornerRadius:(UIButton *)button {
    button.layer.cornerRadius = 5;
    button.layer.masksToBounds = YES;
}

- (IBAction)clearAction:(id)sender {
    [self.paintView clear];
}

- (IBAction)colorAction:(UIButton *)sender {
    [self.paintView setBrushColor:sender.backgroundColor];
}

@end
