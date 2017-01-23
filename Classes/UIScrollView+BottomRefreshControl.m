//
//  UITableView+BottomRefreshControl.m
//  BottomRefreshControl
//
//  Created by Nikolay Vlasov on 14.01.14.
//  Copyright (c) 2014 Nikolay Vlasov. All rights reserved.
//

#import "UIScrollView+BottomRefreshControl.h"

#import <objc/runtime.h>
#import <objc/message.h>


@implementation NSObject (Swizzling)

+ (void)brc_swizzleMethod:(SEL)origSelector withMethod:(SEL)newSelector {
    
    Method origMethod = class_getInstanceMethod(self, origSelector);
    Method newMethod = class_getInstanceMethod(self, newSelector);
    
    if(class_addMethod(self, origSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(self, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

@end


@implementation UIView (FindSubview)

- (UIView *)brc_findFirstSubviewPassingTest:(BOOL (^)(UIView *subview))predicate {

    if (predicate(self))
        return self;
    else
        for (UIView *subview in self.subviews) {

            UIView *result = [subview brc_findFirstSubviewPassingTest:predicate];
            if (result)
                return result;
        }

    return 0;
}

@end


NSString *const kRefrehControllerEndRefreshingNotification = @"RefrehControllerEndRefreshing";

const CGFloat kDefaultTriggerRefreshVerticalOffset = 120.;


static char kBRCManualEndRefreshingKey;
static char kTriggerVerticalOffsetKey;

@implementation UIRefreshControl (BottomRefreshControl)

+ (void)load {
    
    [self brc_swizzleMethod:@selector(endRefreshing) withMethod:@selector(brc_endRefreshing)];
}


- (void)brc_endRefreshing {
    
    if (self.brc_manualEndRefreshing)
        [[NSNotificationCenter defaultCenter] postNotificationName:kRefrehControllerEndRefreshingNotification object:self];
    else
        [self brc_endRefreshing];
}

- (void)setBrc_manualEndRefreshing:(BOOL)manual {

    objc_setAssociatedObject(self, &kBRCManualEndRefreshingKey, @(manual), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)brc_manualEndRefreshing {
    
    NSNumber *manual = objc_getAssociatedObject(self, &kBRCManualEndRefreshingKey);
    return (manual) ? [manual boolValue] : NO;
}

- (void)setTriggerVerticalOffset:(CGFloat)offset {
    
    assert(offset > 0);
    objc_setAssociatedObject(self, &kTriggerVerticalOffsetKey, @(offset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)triggerVerticalOffset {
    
    NSNumber *offset = objc_getAssociatedObject(self, &kTriggerVerticalOffsetKey);
    return (offset) ? [offset floatValue] : kDefaultTriggerRefreshVerticalOffset;
}

- (UILabel *)brc_titleLabel {
    
    return (UILabel *)[self brc_findFirstSubviewPassingTest:^BOOL(UIView *subview) {
        return ([subview isKindOfClass:[UILabel class]] && [((UILabel *)subview).attributedText isEqualToAttributedString:self.attributedTitle]);
    }];
}

@end



@interface BRCContext : NSObject

@property (nonatomic) BOOL refreshed;
@property (nonatomic) BOOL adjustBottomInset;
@property (nonatomic) BOOL wasTracking;
@property (nonatomic) NSDate *beginRefreshingDate;

@property (nonatomic, weak) UITableView *fakeTableView;

@end

@implementation BRCContext

@end





static char kBottomRefreshControlKey;
static char kBRCContextKey;

const CGFloat kMinRefershTime = 0.5;


@implementation UIScrollView (BottomRefreshControl)

+ (void)load {
    
    [self brc_swizzleMethod:@selector(didMoveToSuperview) withMethod:@selector(brc_didMoveToSuperview)];
    [self brc_swizzleMethod:@selector(setContentInset:) withMethod:@selector(brc_setContentInset:)];
    [self brc_swizzleMethod:@selector(contentInset) withMethod:@selector(brc_contentInset)];
    [self brc_swizzleMethod:@selector(setContentOffset:) withMethod:@selector(brc_setContentOffset:)];
}

- (void)brc_didMoveToSuperview {
    
    [self brc_didMoveToSuperview];
    
    if (!self.brc_context)
        return;
    
    if (self.superview)
        [self brc_insertFakeTableView];
    else
        [self.brc_context.fakeTableView removeFromSuperview];
}

- (void)brc_setContentInset:(UIEdgeInsets)insets {
    
    if (self.brc_adjustBottomInset)
        insets.bottom += self.bottomRefreshControl.frame.size.height;
        
    [self brc_setContentInset:insets];
    
    [self setNeedsUpdateConstraints];
}

- (UIEdgeInsets)brc_contentInset {
    
    UIEdgeInsets insets = [self brc_contentInset];
    
    if (self.brc_adjustBottomInset)
        insets.bottom -= self.bottomRefreshControl.frame.size.height;
    
    return insets;
}

- (void)brc_setContentOffset:(CGPoint)contentOffset {
    
    [self brc_setContentOffset:contentOffset];

    if (!self.brc_context)
        return;
    
    if (self.brc_context.wasTracking && !self.tracking)
        [self didEndTracking];
    
    self.brc_context.wasTracking = self.tracking;
    
    UIEdgeInsets contentInset = self.contentInset;
    CGFloat height = self.frame.size.height;

    CGFloat offset = (contentOffset.y + contentInset.top + height) - MAX((self.contentSize.height + contentInset.bottom + contentInset.top), height);
    
    if (offset > 0)
        [self handleBottomBounceOffset:offset];
    else
        self.brc_context.refreshed = NO;
}

- (void)brc_checkRefreshingTimeAndPerformBlock:(void (^)())block {

    NSDate *date = self.brc_context.beginRefreshingDate;
    
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

- (void)brc_insertFakeTableView {

    UITableView *tableView = self.brc_context.fakeTableView;
    
    [self.superview insertSubview:tableView aboveSubview:self];

    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:tableView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0];
    
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:tableView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0 constant:0.0];
    
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:tableView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-self.contentInset.bottom];
    
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:tableView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute: NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:kDefaultTriggerRefreshVerticalOffset];

    [tableView addConstraint:height];
    [self.superview addConstraints:@[left, right, bottom]];
}

- (void)updateConstraints {

    NSUInteger idx = [self.superview.constraints indexOfObjectPassingTest:^BOOL(__kindof NSLayoutConstraint * _Nonnull constraint, NSUInteger idx, BOOL * _Nonnull stop) {
        return (constraint.firstItem == self.brc_context.fakeTableView) &&
               (constraint.secondItem == self) &&
               (constraint.firstAttribute == NSLayoutAttributeBottom);
    }];
    
    if (idx != NSNotFound) {
        NSLayoutConstraint *bottom = self.superview.constraints[idx];
        bottom.constant = -self.contentInset.bottom;
    }

    [super updateConstraints];
}

- (void)brc_SetAdjustBottomInset:(BOOL)adjust animated:(BOOL)animated {
    
    UIEdgeInsets contentInset = self.contentInset;
    self.brc_context.adjustBottomInset = adjust;
    
    if (animated)
        [UIView beginAnimations:0 context:0];

    self.contentInset = contentInset;
    
    if (animated)
        [UIView commitAnimations];
}

- (BOOL)brc_adjustBottomInset {
    
    return self.brc_context.adjustBottomInset;
}

- (void)setBottomRefreshControl:(UIRefreshControl *)refreshControl {
    
    if (self.bottomRefreshControl) {

        [[NSNotificationCenter defaultCenter] removeObserver:self name:kRefrehControllerEndRefreshingNotification object:self.bottomRefreshControl];
        self.bottomRefreshControl.brc_manualEndRefreshing = NO;
        self.bottomRefreshControl.brc_titleLabel.transform = CGAffineTransformIdentity;
        
        [self.brc_context.fakeTableView removeFromSuperview];
        
        self.brc_context = 0;
    }
    
    if (refreshControl) {
        
        BRCContext *context = [BRCContext new];
        self.brc_context = context;
        
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        tableView.userInteractionEnabled = NO;
        tableView.translatesAutoresizingMaskIntoConstraints = NO;
        tableView.backgroundColor = [UIColor clearColor];
        tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        tableView.transform = CGAffineTransformMakeRotation(M_PI);

        refreshControl.brc_manualEndRefreshing = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(brc_didEndRefreshing) name:kRefrehControllerEndRefreshingNotification object:refreshControl];
        
        refreshControl.brc_titleLabel.transform = CGAffineTransformMakeRotation(M_PI);
        
        
        [tableView addSubview:refreshControl];

        context.fakeTableView = tableView;

        if (self.superview)
            [self brc_insertFakeTableView];
    }
    
    [self willChangeValueForKey:@"bottomRefreshControl"];
    objc_setAssociatedObject(self, &kBottomRefreshControlKey, refreshControl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"bottomRefreshControl"];
}

- (UIRefreshControl *)bottomRefreshControl {
    
    return objc_getAssociatedObject(self, &kBottomRefreshControlKey);
}

- (void)setBrc_context:(BRCContext *)context {
    
    objc_setAssociatedObject(self, &kBRCContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BRCContext *)brc_context {
    
    return objc_getAssociatedObject(self, &kBRCContextKey);
}

- (void)handleBottomBounceOffset:(CGFloat)offset {
    
    CGPoint contentOffset = self.brc_context.fakeTableView.contentOffset;
    CGFloat triggerOffset = self.bottomRefreshControl.triggerVerticalOffset;

    if (!self.brc_context.refreshed && (!self.decelerating || (contentOffset.y < 0))) {
        
        if (offset < triggerOffset) {
            
            contentOffset.y = -offset*kDefaultTriggerRefreshVerticalOffset/triggerOffset/1.5;
            self.brc_context.fakeTableView.contentOffset = contentOffset;
            
        } else if (!self.bottomRefreshControl.refreshing)
            [self brc_startRefresh];
    }
}

- (void)brc_didEndRefreshing {
    
    [self brc_checkRefreshingTimeAndPerformBlock:^{
        [self.bottomRefreshControl brc_endRefreshing];
        [self brc_stopRefresh];
    }];
}

- (void)brc_startRefresh {

    self.brc_context.beginRefreshingDate = [NSDate date];

    [self.bottomRefreshControl beginRefreshing];
    [self.bottomRefreshControl sendActionsForControlEvents:UIControlEventValueChanged];

    if (!self.tracking && !self.brc_adjustBottomInset)
        [self brc_SetAdjustBottomInset:YES animated:YES];
}

- (void)brc_stopRefresh {
    
    self.brc_context.wasTracking = self.tracking;
    
    if (!self.tracking && self.brc_adjustBottomInset) {
     
        dispatch_async(dispatch_get_main_queue(), ^{
            [self brc_SetAdjustBottomInset:NO animated:YES];
        });
    }
    
    self.brc_context.refreshed = self.tracking;
}

- (void)didEndTracking {
    
    if (self.bottomRefreshControl.refreshing && !self.brc_adjustBottomInset)
        [self brc_SetAdjustBottomInset:YES animated:YES];
    
    if (self.brc_adjustBottomInset && !self.bottomRefreshControl.refreshing)
        [self brc_SetAdjustBottomInset:NO animated:YES];
}

@end





@implementation UITableView (BottomRefreshControl)

+ (void)load {
    
    [self brc_swizzleMethod:@selector(reloadData) withMethod:@selector(brc_reloadData)];
}

- (void)brc_reloadData {
    
    if (!self.brc_context)
        [self brc_reloadData];
    else
        [self brc_checkRefreshingTimeAndPerformBlock:^{
            [self brc_reloadData];
        }];
}

@end





@implementation UICollectionView (BottomRefreshControl)

+ (void)load {
    
    [self brc_swizzleMethod:@selector(reloadData) withMethod:@selector(brc_reloadData)];
}

- (void)brc_reloadData {
    
    if (!self.brc_context)
        [self brc_reloadData];
    else
        [self brc_checkRefreshingTimeAndPerformBlock:^{
            [self brc_reloadData];
        }];
}

@end
