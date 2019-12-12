//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DataViewController.h"

@interface DataViewController ()

#if TARGET_OS_IOS
@property (nonatomic, weak) UIRefreshControl *refreshControl;
#endif

@property (nonatomic, getter=isRefreshTriggered) BOOL refreshTriggered;

@end

@implementation DataViewController

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.dataSource = self;
    tableView.delegate = self;
    [self.view addSubview:tableView];
    self.tableView = tableView;
    
#if TARGET_OS_IOS
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.layer.zPosition = -1.f;          // Ensure the refresh control appears behind the cells, see http://stackoverflow.com/a/25829016/760435
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.tableView insertSubview:refreshControl atIndex:0];
    self.refreshControl = refreshControl;
#endif
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.movingFromParentViewController || self.beingDismissed) {
        [self cancelRefresh];
    }
}

#pragma mark Default implementations

- (void)refresh
{}

- (void)cancelRefresh
{}

#pragma mark UIScrollViewDelegate protocol

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (self.refreshTriggered) {
        [self refresh];
        self.refreshTriggered = NO;
    }
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSAssert(NO, @"Not implemented");
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"Not implemented");
    return nil;
}

#pragma mark Actions

- (void)refresh:(id)sender
{
#if TARGET_OS_IOS
    // When reloading a table view with animations and if a refresh control is used to trigger the reload,
    // a glitch makes the table jump down when the refresh control value changed event is triggered. To
    // solve this issue, we only mark the table as required a refresh when this event is triggered, and
    // perform the refresh when the table is released.
    //
    // Note that applying the same strategy with a UITableViewController does not work, we have to build
    // the table and the refresh control ourselves.
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
    }
#endif
    self.refreshTriggered = YES;
}

@end
