//
//  ViewController.m
//  BottomRefreshControlExample
//
//  Created by Nikolay Vlasov on 15.01.14.
//  Copyright (c) 2014 nickvlasov. All rights reserved.
//

#import "ViewController.h"
#import "UITableView+BottomRefreshControl.h"

@interface ViewController ()

- (IBAction)actionPressed:(UIBarButtonItem *)button;

@end


@implementation ViewController {
    
    NSInteger _numberOfRows;
}

- (void)viewDidLoad {

    [super viewDidLoad];
    
    UIRefreshControl *topRefreshControl = [UIRefreshControl new];
    [self.tableView addSubview:topRefreshControl];
    
	self.tableView.bottomRefreshControl = [UIRefreshControl new];
    
    @weakify(self, topRefreshControl);
    [[self.tableView.bottomRefreshControl rac_signalForControlEvents:UIControlEventValueChanged] subscribeNext:^(id x) {
        
        double delayInSeconds = 1.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            
            @strongify(self);
            _numberOfRows += 5;
//            [self.tableView reloadData];
            
            CGFloat contentOffsetY = self.tableView.contentOffsetY;
            CGFloat contentHeight = self.tableView.contentHeight;
            [self.tableView reloadData];
            self.tableView.contentOffsetY = contentOffsetY + (self.tableView.contentHeight - contentHeight);
            
            [self.tableView.bottomRefreshControl endRefreshing];
        });
    }];

    [[topRefreshControl rac_signalForControlEvents:UIControlEventValueChanged] subscribeNext:^(id x) {
        
        double delayInSeconds = 1.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            
            @strongify(self, topRefreshControl);
            _numberOfRows -= 3;
            _numberOfRows = MAX(0, _numberOfRows);
            [self.tableView reloadData];
            [topRefreshControl endRefreshing];
        });
    }];
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

    self.tableView.contentInsetBottom = (button.tag == 0) ? 100 : 0;
    button.tag = (button.tag == 0) ? 1 : 0;
}

@end
