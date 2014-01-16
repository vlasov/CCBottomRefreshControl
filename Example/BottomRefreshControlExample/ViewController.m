//
//  ViewController.m
//  BottomRefreshControlExample
//
//  Created by Nikolay Vlasov on 15.01.14.
//  Copyright (c) 2014 Nikolay Vlasov. All rights reserved.
//

#import "ViewController.h"
#import "UITableView+BottomRefreshControl.h"

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UIView *bottomView;

- (IBAction)actionPressed:(UIBarButtonItem *)button;

@end


@implementation ViewController {
    
    NSInteger _numberOfRows;
}

- (void)viewDidLoad {

    [super viewDidLoad];
    
    _numberOfRows = 12;
    
    UIRefreshControl *topRefreshControl = [UIRefreshControl new];
    [self.tableView addSubview:topRefreshControl];
    
	self.tableView.bottomRefreshControl = [UIRefreshControl new];
    
    @weakify(self, topRefreshControl);
    [[self.tableView.bottomRefreshControl rac_signalForControlEvents:UIControlEventValueChanged] subscribeNext:^(id x) {
        
        double delayInSeconds = 2.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            
            @strongify(self);
            _numberOfRows = MAX(0, _numberOfRows-5);
            [self.tableView reloadData];
            [self.tableView.bottomRefreshControl endRefreshing];
        });
    }];

    [[topRefreshControl rac_signalForControlEvents:UIControlEventValueChanged] subscribeNext:^(id x) {
        
        double delayInSeconds = 2.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            
            @strongify(self, topRefreshControl);
            _numberOfRows += 5;
            [self.tableView reloadData];
            [topRefreshControl endRefreshing];
        });
    }];
    
    self.bottomView.yOrigin = self.view.height;
}



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return _numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MyTableCell" forIndexPath:indexPath];
    cell.textLabel.text = [NSString stringWithFormat:@"%d", indexPath.row];
    
    return cell;
}

- (IBAction)actionPressed:(UIBarButtonItem *)button {

    [UIView beginAnimations:0 context:0];
    
    if (self.bottomView.yOrigin < self.view.height) {
        
        self.bottomView.yOrigin = self.view.height;
        self.tableView.contentInsetBottom = 0;

    } else {

        self.bottomView.maxY = self.view.height;
        self.tableView.contentInsetBottom = self.bottomView.height;
    }
    
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    
    [UIView commitAnimations];
}

@end
