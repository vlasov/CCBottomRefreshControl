//
//  ViewController.m
//  BottomRefreshControlExample
//
//  Created by Nikolay Vlasov on 15.01.14.
//  Copyright (c) 2014 Nikolay Vlasov. All rights reserved.
//

#import "TableViewController.h"
#import "UIScrollView+BottomRefreshControl.h"

@interface TableViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, weak) IBOutlet UITableView *tableView;

@end


@implementation TableViewController

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.numberOfItems;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MyTableCell" forIndexPath:indexPath];
    cell.contentView.backgroundColor = (indexPath.row % 2 == 0) ? [UIColor lightGrayColor] : [UIColor whiteColor];
    
    return cell;
}

- (void)reloadData {
    
    [self.tableView reloadData];
}

@end
