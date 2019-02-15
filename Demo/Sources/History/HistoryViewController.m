//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HistoryViewController.h"

#import "PlayerViewController.h"

#import <libextobjc/libextobjc.h>
#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>

@interface HistoryViewController ()

@property (nonatomic) NSArray<SRGMedia *> *medias;
@property (nonatomic, weak) SRGBaseRequest *request;

@end

@implementation HistoryViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"History", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didLogin:)
                                               name:SRGIdentityServiceUserDidLoginNotification
                                             object:SRGIdentityService.currentIdentityService];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didUpdateAccount:)
                                               name:SRGIdentityServiceDidUpdateAccountNotification
                                             object:SRGIdentityService.currentIdentityService];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(historyDidStartSynchronization:)
                                               name:SRGHistoryDidStartSynchronizationNotification
                                             object:SRGUserData.currentUserData.history];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(historyDidClear:)
                                               name:SRGHistoryDidClearNotification
                                             object:SRGUserData.currentUserData.history];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"MediaCell"];
    
    [self updateNavigationBar];
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
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    [SRGUserData.currentUserData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:@[sortDescriptor] completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries) {
        NSArray<NSString *> *mediaURNs = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        SRGBaseRequest *request = [[SRGDataProvider.currentDataProvider mediasWithURNs:mediaURNs completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
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
    }];
}

#pragma mark User interface

- (void)updateNavigationBar
{
    if (! SRGIdentityService.currentIdentityService.loggedIn) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Login", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(login:)];
    }
    else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Logout", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(logout:)];
    }
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
    SRGHistoryEntry *historyEntry = [SRGUserData.currentUserData.history historyEntryWithUid:media.URN];
    
    PlayerViewController *playerViewController = [[PlayerViewController alloc] initWithURN:media.URN time:historyEntry.lastPlaybackTime];
    [self presentViewController:playerViewController animated:YES completion:nil];
}

#pragma mark Actions

- (void)login:(id)sender
{
    [SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
}

- (void)logout:(id)sender
{
    [SRGIdentityService.currentIdentityService logout];
}

- (void)refresh:(id)sender
{
    [self refresh];
}

#pragma mark Notifications

- (void)didLogin:(NSNotification *)notification
{
    [self updateNavigationBar];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    [self updateNavigationBar];
}

- (void)historyDidStartSynchronization:(NSNotification *)notification
{
    [self refresh];
}

- (void)historyDidClear:(NSNotification *)notification
{
    [self refresh];
}

@end
