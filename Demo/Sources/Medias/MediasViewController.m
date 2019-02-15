//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediasViewController.h"

#import "PlayerViewController.h"

#import <SRGDataProvider/SRGDataProvider.h>

@interface MediasViewController ()

@property (nonatomic) NSArray<SRGMedia *> *medias;
@property (nonatomic, weak) SRGBaseRequest *request;

@end

@implementation MediasViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"Medias", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;

    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"MediaCell"];
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
        [self.request cancel];
    }
}

#pragma mark Data

- (void)refresh
{
    if (self.request) {
        return;
    }
    
    SRGBaseRequest *request = [[SRGDataProvider.currentDataProvider tvMostPopularMediasForVendor:SRGVendorRTS withCompletionBlock:^(NSArray<SRGMedia *> * _Nullable medias, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (self.refreshControl.refreshing) {
            [self.refreshControl endRefreshing];
        }
        
        if (error) {
            return;
        }
        
        self.medias = medias;
        [self.tableView reloadData];
    }] requestWithPageSize:50];
    [request resume];
    self.request = request;
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.medias.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:@"MediaCell"];
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.textLabel.text = self.medias[indexPath.row].title;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SRGMedia *media = self.medias[indexPath.row];
    PlayerViewController *playerViewController = [[PlayerViewController alloc] initWithURN:media.URN];
    [self.navigationController pushViewController:playerViewController animated:YES];
}

#pragma mark Actions

- (void)refresh:(id)sender
{
    [self refresh];
}

@end
