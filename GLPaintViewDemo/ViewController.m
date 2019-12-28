//
//  ViewController.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/21.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import <Photos/Photos.h>

#import "GLPaintView.h"
#import "SelectionView.h"

#import "ViewController.h"

@interface ViewController () <GLPaintViewDelegate, SelectionViewDelegate>

@property (nonatomic, strong) GLPaintView *paintView;

@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *brushButton;
@property (nonatomic, strong) UIButton *undoButton;
@property (nonatomic, strong) UIButton *redoButton;
@property (nonatomic, strong) UIButton *saveButton;

@property (nonatomic, strong) SelectionView *colorSelectionView;
@property (nonatomic, strong) SelectionView *sizeSelectionView;
@property (nonatomic, strong) SelectionView *brushSelectionView;

@property (nonatomic, strong) UIView *bottomBar;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self commonInit];
}

#pragma mark - Private

- (void)commonInit {
    [self setupPaintView];
    [self setupBottomBar];
    [self setupButtons];
    [self setupSelectionViews];
    [self setupData];
    
    [self refreshUI];
}

- (void)setupPaintView {
    CGFloat ratio = self.view.frame.size.height / self.view.frame.size.width;
    CGFloat width = 1500;
    CGSize textureSize = CGSizeMake(width, width * ratio);
    self.paintView = [[GLPaintView alloc] initWithFrame:self.view.bounds
                                            textureSize:textureSize
                                 textureBackgroundColor:[UIColor colorWithWhite:0.9 alpha:1]];
    self.paintView.delegate = self;
    [self.view addSubview:self.paintView];
}

- (void)setupBottomBar {
    CGFloat height = 320;
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0,
                                                              self.view.frame.size.height - height,
                                                              self.view.frame.size.width,
                                                              height)];
    self.bottomBar.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.bottomBar];
}

- (void)setupButtons {
    // 清除按钮
    self.clearButton = [self commonButtonWithTitle:@"清除" action:@selector(clearAction:)];
    [self setButton:self.clearButton centerX:self.view.frame.size.width * (1.0 / 6)];
    [self.bottomBar addSubview:self.clearButton];
    
    // 橡皮擦/画笔按钮
    self.brushButton = [self commonButtonWithTitle:@"橡皮擦" action:@selector(brushAction:)];
    [self setButton:self.brushButton centerX:self.view.frame.size.width * (2.0 / 6)];
    [self.bottomBar addSubview:self.brushButton];
    
    // 撤销按钮
    self.undoButton = [self commonButtonWithTitle:@"撤销" action:@selector(undoAction:)];
    [self setButton:self.undoButton centerX:self.view.frame.size.width * (3.0 / 6)];
    [self.bottomBar addSubview:self.undoButton];
    
    // 重做按钮
    self.redoButton = [self commonButtonWithTitle:@"重做" action:@selector(redoAction:)];
    [self setButton:self.redoButton centerX:self.view.frame.size.width * (4.0 / 6)];
    [self.bottomBar addSubview:self.redoButton];
    
    // 保存按钮
    self.saveButton = [self commonButtonWithTitle:@"保存" action:@selector(saveAction:)];
    [self setButton:self.saveButton centerX:self.view.frame.size.width * (5.0 / 6)];
    [self.bottomBar addSubview:self.saveButton];
}

- (void)setupSelectionViews {
    // 颜色选择
    self.colorSelectionView = [[SelectionView alloc] init];
    self.colorSelectionView.title = @"颜色";
    self.colorSelectionView.delegate = self;
    self.colorSelectionView.frame = CGRectMake(20, 70, self.view.frame.size.width - 40, 50);
    [self.bottomBar addSubview:self.colorSelectionView];
    
    // 尺寸选择
    self.sizeSelectionView = [[SelectionView alloc] init];
    self.sizeSelectionView.title = @"尺寸";
    self.sizeSelectionView.delegate = self;
    self.sizeSelectionView.frame = CGRectMake(20, 140, self.view.frame.size.width - 40, 50);
    [self.bottomBar addSubview:self.sizeSelectionView];
    
    // 笔触选择
    self.brushSelectionView = [[SelectionView alloc] init];
    self.brushSelectionView.title = @"笔触";
    self.brushSelectionView.delegate = self;
    self.brushSelectionView.frame = CGRectMake(20, 210, self.view.frame.size.width - 40, 50);
    [self.bottomBar addSubview:self.brushSelectionView];
}

- (UIButton *)commonButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 10, 50, 40)];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
    [button setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    button.titleLabel.font = [UIFont systemFontOfSize:12];
    button.backgroundColor = [UIColor blackColor];
    button.layer.masksToBounds = YES;
    button.layer.cornerRadius = 5;
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    
    return button;
}

- (void)setupData {
    [self setupColor];
    [self setupSize];
    [self setupBrush];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.colorSelectionView selectIndex:0];
        [self.sizeSelectionView selectIndex:0];
        [self.brushSelectionView selectIndex:0];
    });
}

- (void)setupColor {
    SelectionModel *color1 = [[SelectionModel alloc] init];
    color1.color = [UIColor blackColor];
    
    SelectionModel *color2 = [[SelectionModel alloc] init];
    color2.color = [UIColor redColor];
    
    SelectionModel *color3 = [[SelectionModel alloc] init];
    color3.color = [UIColor colorWithWhite:0 alpha:0.3];
    
    SelectionModel *color4 = [[SelectionModel alloc] init];
    color4.color = [UIColor purpleColor];
    
    SelectionModel *color5 = [[SelectionModel alloc] init];
    color5.color = [UIColor greenColor];
    
    SelectionModel *color6 = [[SelectionModel alloc] init];
    color6.color = [UIColor yellowColor];
    
    self.colorSelectionView.models = @[color1, color2, color3, color4, color5, color6];
}

- (void)setupSize {
    SelectionModel *size1 = [[SelectionModel alloc] init];
    size1.title = @"5";
    
    SelectionModel *size2 = [[SelectionModel alloc] init];
    size2.title = @"10";
    
    SelectionModel *size3 = [[SelectionModel alloc] init];
    size3.title = @"20";
    
    SelectionModel *size4 = [[SelectionModel alloc] init];
    size4.title = @"30";
    
    SelectionModel *size5 = [[SelectionModel alloc] init];
    size5.title = @"40";
    
    SelectionModel *size6 = [[SelectionModel alloc] init];
    size6.title = @"50";
    
    self.sizeSelectionView.models = @[size1, size2, size3, size4, size5, size6];
}

- (void)setupBrush {
    SelectionModel *brush1 = [[SelectionModel alloc] init];
    brush1.imageName = @"brush1.png";
    
    SelectionModel *brush2 = [[SelectionModel alloc] init];
    brush2.imageName = @"brush2.png";
    
    SelectionModel *brush3 = [[SelectionModel alloc] init];
    brush3.imageName = @"brush3.png";
    
    self.brushSelectionView.models = @[brush1, brush2, brush3];
}

- (void)setButton:(UIButton *)button centerX:(CGFloat)centerX {
    button.center = CGPointMake(centerX, button.center.y);
}

- (void)refreshUI {
    self.undoButton.enabled = [self.paintView canUndo];
    self.redoButton.enabled = [self.paintView canRedo];
    self.clearButton.enabled = [self.paintView canUndo];
    self.saveButton.enabled = [self.paintView canUndo];
    
    NSString *title = self.paintView.brushMode == MFPaintViewBrushModePaint ? @"橡皮擦" : @"画笔";
    [self.brushButton setTitle:title forState:UIControlStateNormal];
}

- (void)saveImage:(UIImage *)image withCompletion:(void (^)(BOOL success))completion {
    void (^saveBlock)(void) = ^ {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (completion) {
                completion(success);
            }
        }];
    };
    
    PHAuthorizationStatus authStatus = [PHPhotoLibrary authorizationStatus];
    if (authStatus == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                saveBlock();
            } else {
                if (completion) {
                    completion(NO);
                }
            }
        }];
    } else if (authStatus != PHAuthorizationStatusAuthorized) {
        if (completion) {
            completion(NO);
        }
    } else {
        saveBlock();
    }
}

#pragma mark - Action

- (void)clearAction:(id)sender {
    [self.paintView clear];
    [self refreshUI];
}

- (void)brushAction:(id)sender {
    if (self.paintView.brushMode == MFPaintViewBrushModePaint) {
        self.paintView.brushMode = MFPaintViewBrushModeEraser;
    } else {
        self.paintView.brushMode = MFPaintViewBrushModePaint;
    }
    [self refreshUI];
}

- (void)undoAction:(id)sender {
    [self.paintView undo];
    [self refreshUI];
}

- (void)redoAction:(id)sender {
    [self.paintView redo];
    [self refreshUI];
}

- (void)saveAction:(id)sender {
    UIImage *image = [self.paintView currentImage];
    [self saveImage:image withCompletion:^(BOOL success) {
        if (success) {
            NSLog(@"保存成功！");
        } else {
            NSLog(@"保存失败！");
        }
    }];
}

#pragma mark - GLPaintViewDelegate

- (void)paintViewWillBeginDraw:(GLPaintView *)paintView {
    [UIView animateWithDuration:0.25 animations:^{
        self.bottomBar.alpha = 0.0;
    }];
}

- (void)paintViewDidFinishDraw:(GLPaintView *)paintView {
    [UIView animateWithDuration:0.25 animations:^{
        self.bottomBar.alpha = 1.0;
    }];
    
    [self refreshUI];
}

#pragma mark - SelectionViewDelegate

- (void)selectionView:(SelectionView *)selectionView didSelectModel:(SelectionModel *)model {
    if (selectionView == self.colorSelectionView) {
        [self.paintView setBrushColor:model.color];
        [self refreshUI];
    } else if (selectionView == self.sizeSelectionView) {
        [self.paintView setBrushSize:model.title.integerValue];
    } else if (selectionView == self.brushSelectionView) {
        [self.paintView setBrushImageName:model.imageName];
    }
}

@end
