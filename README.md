CCBottomRefreshControl
======================

Category for **UIScrollView** class, that adds **bottomRefreshControl** property, that could be assigned to **UIRefreshControl** object. It implements an ability to add iOS 6/7 native bottom pull-up to refresh control to **UITableView** or **UICollectionView**. Perfectly works with top top refresh control (see example project).
Very useful for refreshing tables that contain most recent items at the bottom. For example in chats.

CocoaPods
---------

pod 'CCBottomRefreshControl'


Example
-------

    #import "UIScrollView+BottomRefreshControl.h"

    ...

    UIRefreshControl *refreshControl = [UIRefreshControl new];
    [refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.tableView.bottomRefreshControl = bottomRefreshControl;
