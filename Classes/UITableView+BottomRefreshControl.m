//
//  UITableView+BottomRefreshControl.m
//  Showroom
//
//  Created by Nikolay Vlasov on 14.01.14.
//  Copyright (c) 2014 Cloud Castle Group. All rights reserved.
//

#import "UITableView+BottomRefreshControl.h"
#import <objc/runtime.h>

@interface CategoryContext : NSObject

@property (nonatomic) BOOL refreshed;
@property (nonatomic) BOOL bottomInsetChanged;
@property (nonatomic) BOOL wasTracking;
@property (nonatomic) BOOL ignoreInsetChanges;
@property (nonatomic) BOOL ignoreScrollerInsetChanges;

@property (nonatomic) UITableView *fakeTableView;
@property (nonatomic) RACDisposable *endRefreshSubscription;

@end

@implementation CategoryContext

@end

static char kBottomRefreshControlKey;
static char kCategoryContextKey;

const CGFloat kStartRefreshContentOffset = 120.;


@implementation UITableView (BottomRefreshControl)


- (void)setBottomRefreshControl:(UIRefreshControl *)refreshControl {
    
    if (!self.context) {
        
        self.context = [CategoryContext new];
        
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:self.style];
        tableView.userInteractionEnabled = NO;
        tableView.backgroundColor = [UIColor clearColor];
        tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        tableView.transform = CGAffineTransformMakeRotation(M_PI);
        [tableView addSubview:refreshControl];
        self.context.fakeTableView = tableView;
        

        @weakify(self, refreshControl);
        
        [[self rac_signalForSelector:@selector(didMoveToSuperview)] subscribeNext:^(id x) {
            
            @strongify(self);
            [[self superview] insertSubview:self.context.fakeTableView aboveSubview:self];
            [self layoutFakeTableView];
        }];
        
        [RACObserve(self, frame) subscribeNext:^(id x) {
            
            @strongify(self);
            [self layoutFakeTableView];
        }];
        
        [RACObserve(self, contentInset) subscribeNext:^(id x) {
            
            @strongify(self);
            if (!self.context.ignoreInsetChanges) {

                [self layoutFakeTableView];
                if (self.context.bottomInsetChanged)
                    [self changeBottomInset];
            }
        }];

        [RACObserve(self, scrollIndicatorInsets) subscribeNext:^(id x) {
            
            @strongify(self, refreshControl);
            if (!self.context.ignoreScrollerInsetChanges) {
                
                if (self.context.bottomInsetChanged)
                    [self changeScrollerBottomInset:-refreshControl.height];
            }
        }];

        [RACObserve(self, contentOffset) subscribeNext:^(id x) {
            
            @strongify(self);

            if (self.context.wasTracking && !self.tracking) {
            
                self.context.wasTracking = self.tracking;
                [self didEndDragging];
            }
            
            self.context.wasTracking = self.tracking;

            CGFloat offset = (self.contentOffsetY + self.contentInsetTop + self.height) - MAX((self.contentHeight + self.contentInsetBottom + self.contentInsetTop), self.height);
            
            if (offset > 0)
                [self handleBottomBounceOffset:offset];
            else
                self.context.refreshed = NO;
        }];
    }
    
    UIRefreshControl *oldRefreshControl = self.bottomRefreshControl;
    if (oldRefreshControl) {
        
        [self.context.endRefreshSubscription dispose];
        [oldRefreshControl removeFromSuperview];
    }
    
    if (refreshControl) {
        
        UITableView *fakeTableView = self.context.fakeTableView;
        
        [fakeTableView addSubview:refreshControl];
        
        if (![fakeTableView superview] && [self superview]) {
            
            [[self superview] insertSubview:self.context.fakeTableView aboveSubview:self];
            [self layoutFakeTableView];
        }
        
        @weakify(self);
        self.context.endRefreshSubscription = [[refreshControl rac_signalForSelector:@selector(endRefreshing)] subscribeNext:^(id x) {
            
            @strongify(self);
            [self stopRefresh];
        }];
    }

    [self willChangeValueForKey:@"bottomRefreshControl"];
    objc_setAssociatedObject(self, &kBottomRefreshControlKey, refreshControl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"bottomRefreshControl"];
}

- (UIRefreshControl *)bottomRefreshControl {
    
    return objc_getAssociatedObject(self, &kBottomRefreshControlKey);
}

- (void)setContext:(CategoryContext *)context {
    
    objc_setAssociatedObject(self, &kCategoryContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CategoryContext *)context {
    
    return objc_getAssociatedObject(self, &kCategoryContextKey);
}

- (void)layoutFakeTableView {
    
    self.context.fakeTableView.frame = self.frame;
    self.context.fakeTableView.height = kStartRefreshContentOffset;
    self.context.fakeTableView.maxY = self.maxY - self.contentInsetBottom;
}

- (void)handleBottomBounceOffset:(CGFloat)offset {
    
    if (!self.context.refreshed && (!self.decelerating || (self.decelerating && (self.context.fakeTableView.contentOffsetY < -1)))) {
        
        if (offset < kStartRefreshContentOffset) {
            
            if (!isIOS6)
                offset *= 1.5;
            self.context.fakeTableView.contentOffsetY = -offset;
            
        } else
            [self startRefresh];
    }
}

- (void)startRefresh {
    
    UIRefreshControl *refreshControl = self.bottomRefreshControl;
    
    if (refreshControl.refreshing)
        return;
    
    [refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
    [refreshControl beginRefreshing];
    if (isIOS6)
        self.context.fakeTableView.contentInsetTop = 0;
    
    if (!self.dragging)
        [self changeBottomInset];
}

- (void)stopRefresh {
    
    if (isIOS6)
        self.context.fakeTableView.contentInsetTop = 0;

    self.context.wasTracking = self.tracking;
    
    if (!self.tracking && self.context.bottomInsetChanged)
        [self revertBottomInset];
    
    self.context.refreshed = self.tracking;
}

- (void)changeBottomContentInset:(CGFloat)delta {
    
    self.context.ignoreInsetChanges = YES;
    self.contentInsetBottom += delta;
    self.context.ignoreInsetChanges = NO;
}

- (void)changeScrollerBottomInset:(CGFloat)delta {
    
    UIEdgeInsets scrollerInsets = self.scrollIndicatorInsets;
    scrollerInsets.bottom += delta;

    self.context.ignoreScrollerInsetChanges = YES;
    self.scrollIndicatorInsets = scrollerInsets;
    self.context.ignoreScrollerInsetChanges = NO;
}

- (void)changeBottomInset {

    CGFloat contentOffsetY = self.contentOffsetY;
    [self changeBottomContentInset:self.bottomRefreshControl.height];
    self.contentOffsetY = contentOffsetY;
    
    self.context.bottomInsetChanged = YES;
}

- (void)revertBottomInset {
    
    [UIView beginAnimations:0 context:0];
    [self changeBottomContentInset:-self.bottomRefreshControl.height];
    [UIView commitAnimations];
    
    self.context.bottomInsetChanged = NO;
}

- (void)didEndDragging {
    
    if (self.bottomRefreshControl.refreshing && !self.context.bottomInsetChanged)
        [self changeBottomInset];
    
    if (self.context.bottomInsetChanged && !self.bottomRefreshControl.refreshing)
        [self revertBottomInset];
}

@end
