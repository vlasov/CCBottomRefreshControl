//
//  UITableView+BottomRefreshControl.m
//  Showroom
//
//  Created by Nikolay Vlasov on 14.01.14.
//  Copyright (c) 2014 Nikolay Vlasov. All rights reserved.
//

#import "UIScrollView+BottomRefreshControl.h"

#import <objc/runtime.h>
#import <objc/message.h>

#import <Masonry/Masonry.h>



@interface NSObject (Swizzling)

+ (void)swizzleMethod:(SEL)origSelector withMethod:(SEL)newSelector;

@end

@implementation NSObject (Swizzling)

+ (void)swizzleMethod:(SEL)origSelector withMethod:(SEL)newSelector {
    
    Method origMethod = class_getInstanceMethod(self, origSelector);
    Method newMethod = class_getInstanceMethod(self, newSelector);
    
    if(class_addMethod(self, origSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(self, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

@end


NSString *const kRefrehControllerEndRefreshingNotification = @"RefrehControllerEndRefreshing";


@interface UIRefreshControl (BottomRefreshControl)

@property (nonatomic) BOOL manualEndRefreshing;

@end


static char kManualEndRefreshingKey;

@implementation UIRefreshControl (BottomRefreshControl)

+ (void)load {
    
    [self swizzleMethod:@selector(endRefreshing) withMethod:@selector(brc_endRefreshing)];
}


- (void)brc_endRefreshing {
    
    if (self.manualEndRefreshing)
        [[NSNotificationCenter defaultCenter] postNotificationName:kRefrehControllerEndRefreshingNotification object:self];
    else
        [self brc_endRefreshing];
}

- (void)setManualEndRefreshing:(BOOL)manual {

    objc_setAssociatedObject(self, &kManualEndRefreshingKey, @(manual), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)manualEndRefreshing {
    
    NSNumber *manual = objc_getAssociatedObject(self, &kManualEndRefreshingKey);
    return (manual) ? [manual boolValue] : NO;
}

@end



@interface brc_context : NSObject

@property (nonatomic) BOOL refreshed;
@property (nonatomic) BOOL adjustBottomInset;
@property (nonatomic) BOOL wasTracking;
@property (nonatomic) NSDate *beginRefreshingDate;

@property (nonatomic, weak) UITableView *fakeTableView;

@end

@implementation brc_context

@end





static char kBottomRefreshControlKey;
static char kCategoryContextKey;

const CGFloat kStartRefreshContentOffset = 120.;
const CGFloat kMinRefershTime = 0.5;


@implementation UIScrollView (BottomRefreshControl)

+ (void)load {
    
    [self swizzleMethod:@selector(didMoveToSuperview) withMethod:@selector(brc_didMoveToSuperview)];
    [self swizzleMethod:@selector(setContentInset:) withMethod:@selector(brc_setContentInset:)];
    [self swizzleMethod:@selector(contentInset) withMethod:@selector(brc_contentInset)];
    [self swizzleMethod:@selector(setContentOffset:) withMethod:@selector(brc_setContentOffset:)];
}

- (void)brc_didMoveToSuperview {
    
    [self brc_didMoveToSuperview];
    
    if (!self.context)
        return;
    
    if (self.superview)
        [self insertFakeTableView];
    else
        [self.context.fakeTableView removeFromSuperview];
}

- (void)brc_setContentInset:(UIEdgeInsets)insets {
    
    if (self.adjustBottomInset)
        insets.bottom += self.bottomRefreshControl.frame.size.height;
        
    [self brc_setContentInset:insets];
    
    [self setNeedsUpdateConstraints];
}

- (UIEdgeInsets)brc_contentInset {
    
    UIEdgeInsets insets = [self brc_contentInset];
    
    if (self.adjustBottomInset)
        insets.bottom -= self.bottomRefreshControl.frame.size.height;
    
    return insets;
}

- (void)brc_setContentOffset:(CGPoint)contentOffset {
    
    [self brc_setContentOffset:contentOffset];

    if (!self.context)
        return;
    
    if (self.context.wasTracking && !self.tracking)
        [self didEndTracking];
    
    self.context.wasTracking = self.tracking;
    
    UIEdgeInsets contentInset = self.contentInset;
    CGFloat height = self.frame.size.height;

    CGFloat offset = (contentOffset.y + contentInset.top + height) - MAX((self.contentSize.height + contentInset.bottom + contentInset.top), height);
    
    if (offset > 0)
        [self handleBottomBounceOffset:offset];
    else
        self.context.refreshed = NO;
}

- (void)checkRefreshingTimeAndPerformBlock:(void (^)())block {

    NSDate *date = self.context.beginRefreshingDate;
    
    if (!date)
        block();
    else {
        
        NSTimeInterval timeSinceLastRefresh = [[NSDate date] timeIntervalSinceDate:date];
        if  (timeSinceLastRefresh > kMinRefershTime)
            block();
        else
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((kMinRefershTime-timeSinceLastRefresh) * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
    }
}

- (void)insertFakeTableView {

    UITableView *tableView = self.context.fakeTableView;
    
    [self.superview insertSubview:tableView aboveSubview:self];
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.and.right.equalTo(self);
        make.height.equalTo(@(kStartRefreshContentOffset));
        make.bottom.equalTo(self).offset(-self.contentInset.bottom);
    }];
}

- (void)updateConstraints {

    [self.context.fakeTableView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self).offset(-self.contentInset.bottom);
    }];

    [super updateConstraints];
}

- (void)setAdjustBottomInset:(BOOL)adjust animated:(BOOL)animated {
    
    UIEdgeInsets contentInset = self.contentInset;
    self.context.adjustBottomInset = adjust;
    
    if (animated)
        [UIView beginAnimations:0 context:0];

    self.contentInset = contentInset;
    
    if (animated)
        [UIView commitAnimations];
}

- (BOOL)adjustBottomInset {
    
    return self.context.adjustBottomInset;
}

- (void)setBottomRefreshControl:(UIRefreshControl *)refreshControl {
    
    if (self.bottomRefreshControl) {

        [[NSNotificationCenter defaultCenter] removeObserver:self name:kRefrehControllerEndRefreshingNotification object:self.bottomRefreshControl];
        self.bottomRefreshControl.manualEndRefreshing = NO;
        
        [self.context.fakeTableView removeFromSuperview];
        
        self.context = 0;
    }
    
    if (refreshControl) {
        
        brc_context *context = [brc_context new];
        self.context = context;
        
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        tableView.userInteractionEnabled = NO;
        tableView.backgroundColor = [UIColor clearColor];
        tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        tableView.transform = CGAffineTransformMakeRotation(M_PI);

        refreshControl.manualEndRefreshing = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEndRefreshing) name:kRefrehControllerEndRefreshingNotification object:refreshControl];
         
        [tableView addSubview:refreshControl];

        context.fakeTableView = tableView;

        if (self.superview)
            [self insertFakeTableView];
    }
    
    [self willChangeValueForKey:@"bottomRefreshControl"];
    objc_setAssociatedObject(self, &kBottomRefreshControlKey, refreshControl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"bottomRefreshControl"];
}

- (UIRefreshControl *)bottomRefreshControl {
    
    return objc_getAssociatedObject(self, &kBottomRefreshControlKey);
}

- (void)setContext:(brc_context *)context {
    
    objc_setAssociatedObject(self, &kCategoryContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (brc_context *)context {
    
    return objc_getAssociatedObject(self, &kCategoryContextKey);
}

- (void)handleBottomBounceOffset:(CGFloat)offset {
    
    CGPoint contentOffset = self.context.fakeTableView.contentOffset;

    if (!self.context.refreshed && (!self.decelerating || (contentOffset.y < 0))) {
        
        if (offset < kStartRefreshContentOffset) {
            
            contentOffset.y = -offset/1.5;
            self.context.fakeTableView.contentOffset = contentOffset;
            
        } else if (!self.bottomRefreshControl.refreshing)
            [self startRefresh];
    }
}

- (void)didEndRefreshing {
    
    [self checkRefreshingTimeAndPerformBlock:^{
        [self.bottomRefreshControl brc_endRefreshing];
        [self stopRefresh];
    }];
}

- (void)startRefresh {

    self.context.beginRefreshingDate = [NSDate date];

    [self.bottomRefreshControl sendActionsForControlEvents:UIControlEventValueChanged];
    [self.bottomRefreshControl beginRefreshing];    

    if (!self.tracking && !self.adjustBottomInset)
        [self setAdjustBottomInset:YES animated:YES];
}

- (void)stopRefresh {
    
    self.context.wasTracking = self.tracking;
    
    if (!self.tracking && self.adjustBottomInset) {
     
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setAdjustBottomInset:NO animated:NO];
        });
    }
    
    self.context.refreshed = self.tracking;
}

- (void)didEndTracking {
    
    if (self.bottomRefreshControl.refreshing && !self.adjustBottomInset)
        [self setAdjustBottomInset:YES animated:YES];
    
    if (self.adjustBottomInset && !self.bottomRefreshControl.refreshing)
        [self setAdjustBottomInset:NO animated:NO];
}

@end





@implementation UITableView (BottomRefreshControl)

+ (void)load {
    
    [self swizzleMethod:@selector(reloadData) withMethod:@selector(brc_reloadData)];
}

- (void)brc_reloadData {
    
    if (!self.context)
        [self brc_reloadData];
    else
        [self checkRefreshingTimeAndPerformBlock:^{
            [self brc_reloadData];
        }];
}

@end





@implementation UICollectionView (BottomRefreshControl)

+ (void)load {
    
    [self swizzleMethod:@selector(reloadData) withMethod:@selector(brc_reloadData)];
}

- (void)brc_reloadData {
    
    if (!self.context)
        [self brc_reloadData];
    else
        [self checkRefreshingTimeAndPerformBlock:^{
            [self brc_reloadData];
        }];
}

@end
