//
//  CollectionViewController.m
//  BottomRefreshControlExample
//
//  Created by Nikolay Vlasov on 19.01.14.
//  Copyright (c) 2014 nickvlasov. All rights reserved.
//

#import "CollectionViewController.h"

@interface CollectionViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
- (IBAction)dismissPressed;

@end

@implementation CollectionViewController

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    return self.numberOfItems;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MyCollectionCell" forIndexPath:indexPath];
    cell.contentView.backgroundColor = [UIColor lightGrayColor];
    
    return cell;
}

- (void)reloadData {
    
    [self.collectionView reloadData];
}

- (IBAction)dismissPressed {
    
    [self dismissViewControllerAnimated:YES completion:0];
}

@end
