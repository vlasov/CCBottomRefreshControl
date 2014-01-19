//
//  ScrollViewController.h
//  BottomRefreshControlExample
//
//  Created by Nikolay Vlasov on 18.01.14.
//  Copyright (c) 2014 nickvlasov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ScrollViewController : UIViewController

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) UIRefreshControl *topRefreshControl;

@property (nonatomic) NSInteger numberOfItems;

- (void)reloadData;

@end
