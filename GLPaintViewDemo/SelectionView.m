//
//  SelectionView.m
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/12/14.
//  Copyright © 2019 Lyman Li. All rights reserved.
//

#import "SelectionCell.h"

#import "SelectionView.h"

static NSString * const kSelectionCell = @"SelectionCell";

@interface SelectionView () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UICollectionView *collectionView;

@property (nonatomic, assign) NSInteger currentIndex;

@end

@implementation SelectionView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.titleLabel.frame = CGRectMake(0, 0, 80, self.frame.size.height);
    self.collectionView.frame = CGRectMake(80, 0, self.bounds.size.width - 100, self.bounds.size.height);
}

#pragma mark - Custom Accessor

- (void)setTitle:(NSString *)title {
    _title = title;
    self.titleLabel.text = title;
}

- (void)setModels:(NSArray *)models {
    _models = [models copy];
    [self.collectionView reloadData];
}

#pragma mark - Public

- (void)selectIndex:(NSInteger)index{
    self.currentIndex = index;
    [self.collectionView reloadData];
    
    [_collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
    
    if ([self.delegate respondsToSelector:@selector(selectionView:didSelectModel:)]) {
        [self.delegate selectionView:self didSelectModel:self.models[index]];
    }
}

#pragma mark - Private

- (void)commonInit {
    [self setupTitleLabel];
    [self setupCollectionView];
}

- (void)setupTitleLabel {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.font = [UIFont systemFontOfSize:14];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.titleLabel];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.minimumLineSpacing = 10;
    flowLayout.minimumInteritemSpacing = 0;
    flowLayout.itemSize = CGSizeMake(40, 40);
    flowLayout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);
    flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                             collectionViewLayout:flowLayout];
    self.collectionView.backgroundColor = [UIColor whiteColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    [self.collectionView registerClass:[SelectionCell class]
            forCellWithReuseIdentifier:kSelectionCell];
    
    [self addSubview:self.collectionView];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.models count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SelectionCell *cell = (SelectionCell *)[collectionView dequeueReusableCellWithReuseIdentifier:kSelectionCell forIndexPath:indexPath];
    cell.model = self.models[indexPath.row];
    cell.isSelect = indexPath.row == self.currentIndex;
    
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self selectIndex:indexPath.row];
}

@end
