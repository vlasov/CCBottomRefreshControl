//
//  ScrollViewController.m
//  BottomRefreshControlExample
//
//  Created by Nikolay Vlasov on 18.01.14.
//  Copyright (c) 2014 nickvlasov. All rights reserved.
//

#import "ScrollViewController.h"
#import "UIScrollView+BottomRefreshControl.h"

@interface ScrollViewController ()

@property (nonatomic, strong) UITextField *textField;

- (IBAction)toggleKeyboardPressed;

@end


@implementation ScrollViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.numberOfItems = 20;

    self.topRefreshControl = [UIRefreshControl new];
    [self.topRefreshControl addTarget:self action:@selector(refreshTop) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:self.topRefreshControl];
    
    UIRefreshControl *bottomRefreshControl = [UIRefreshControl new];
    [bottomRefreshControl addTarget:self action:@selector(refreshBottom) forControlEvents:UIControlEventValueChanged];
    
	self.scrollView.bottomRefreshControl = bottomRefreshControl;
    
    self.textField = [[UITextField alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.textField];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:0];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:0];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refreshTop {
    
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        self.numberOfItems += 5;
        [self reloadData];
        [self.topRefreshControl endRefreshing];
    });
}

- (void)refreshBottom {
    
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        self.numberOfItems = MAX(0, self.numberOfItems-5);
        [self reloadData];
        [self.scrollView.bottomRefreshControl endRefreshing];
    });
}

- (void)reloadData {
    
}

- (IBAction)toggleKeyboardPressed {
    
    if ([self.textField isFirstResponder])
        [self.textField resignFirstResponder];
    else
        [self.textField becomeFirstResponder];
}


- (void)keyboardWillShow:(NSNotification *)notification {
    
    NSDictionary *userInfo = [notification userInfo];
    
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGRect frameEnd = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    [UIView animateWithDuration:duration animations:^{
        
        self.scrollView.contentInsetBottom = MAX(0., self.scrollView.maxY-frameEnd.origin.y);
        self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset;
    }];
}


- (void)keyboardWillHide:(NSNotification *)notification {
    
    NSDictionary *userInfo = [notification userInfo];
    
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        
        self.scrollView.contentInsetBottom = 0;
        self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset;
    }];
}



@end
