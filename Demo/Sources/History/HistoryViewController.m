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

static NSUInteger HistoryPageSize = 50;

@interface HistoryViewController ()

@property (nonatomic) NSArray<NSString *> *mediaURNs;
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
                                           selector:@selector(historyDidChange:)
                                               name:SRGHistoryEntriesDidChangeNotification
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

#pragma mark UI

- (void)updateNavigationBar
{
    if (! SRGIdentityService.currentIdentityService.loggedIn) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Login", nil)
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(login:)];
    }
    else {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Account", nil)
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(showAccount:)];
    }
}

#pragma mark Data

- (void)refresh
{
    [self.request cancel];
    
    [self updateMediaURNsWithCompletionBlock:^(NSArray<NSString *> *URNs, NSArray<NSString *> *previousURNs) {
        SRGBaseRequest *request = [[SRGDataProvider.currentDataProvider mediasWithURNs:URNs completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
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

- (void)updateMediaURNsWithCompletionBlock:(void (^)(NSArray<NSString *> *URNs, NSArray<NSString *> *previousURNs))completionBlock
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    
    [SRGUserData.currentUserData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:@[sortDescriptor] completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        NSArray<NSString *> *mediaURNs = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray<NSString *> *previousMediaURNs = self.mediaURNs;
            self.mediaURNs = mediaURNs;
            completionBlock(mediaURNs, previousMediaURNs);
        });
    }];
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

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete){
        SRGMedia *media = self.medias[indexPath.row];
        [SRGUserData.currentUserData.history discardHistoryEntriesWithUids:@[media.URN] completionBlock:^(NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableArray<SRGMedia *> *medias = [self.medias mutableCopy];
                [medias removeObjectAtIndex:indexPath.row];
                self.medias = [medias copy];
                
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            });
        }];
    }
}

#pragma mark Actions

- (void)login:(id)sender
{
    [SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
}

- (void)showAccount:(id)sender
{
    [SRGIdentityService.currentIdentityService showAccountView];
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

- (void)historyDidChange:(NSNotification *)notification
{
    [self updateMediaURNsWithCompletionBlock:^(NSArray<NSString *> *URNs, NSArray<NSString *> *previousURNs) {
        if (! [previousURNs isEqual:self.mediaURNs] && (previousURNs.count <= HistoryPageSize || self.mediaURNs.count <= HistoryPageSize)) {
            [self refresh];
        }
    }];
}

@end
