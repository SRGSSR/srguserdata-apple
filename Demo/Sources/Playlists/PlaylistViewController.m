//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlaylistViewController.h"

#import "PlayerViewController.h"

#import <libextobjc/libextobjc.h>
#import <SRGDataProvider/SRGDataProvider.h>

@interface PlaylistViewController ()

@property (nonatomic) SRGPlaylist *playlist;

@property (nonatomic) NSArray<SRGMedia *> *medias;
@property (nonatomic, weak) SRGBaseRequest *request;

@end

@implementation PlaylistViewController

#pragma mark Object lifecycle

- (instancetype)initWithPlaylist:(SRGPlaylist *)playlist
{
    self = [self init];
    if (self) {
        self.playlist = playlist;
    }
    return self;
}

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return self.playlist.name;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playlistsDidChange:)
                                               name:SRGPlaylistsDidChangeNotification
                                             object:SRGUserData.currentUserData.playlists];
    
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
    [self.request cancel];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylistEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, date) ascending:![self.playlist.uid isEqualToString:SRGWatchLaterPlaylistUid]];
    [SRGUserData.currentUserData.playlists entriesFromPlaylistWithUid:self.playlist.uid matchingPredicate:predicate sortedWithDescriptors:@[sortDescriptor] completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        NSArray<NSString *> *mediaURNs = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
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
        [SRGUserData.currentUserData.playlists removeEntriesWithUids:@[media.URN] fromPlaylistWithUid:self.playlist.uid completionBlock:^(NSError * _Nonnull error) {
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

- (void)refresh:(id)sender
{
    [self refresh];
}

#pragma mark Notifications

- (void)playlistsDidChange:(NSNotification *)notification
{
    if ([notification.userInfo[SRGPlaylistChangedUidsKey] containsObject:self.playlist.uid]) {
        NSDictionary<NSString *, NSArray<NSString *> *> *playlistEntryChanges = notification.userInfo[SRGPlaylistEntryChangesKey][self.playlist.uid];
        if (playlistEntryChanges) {
            NSArray<NSString *> *previousURNs = playlistEntryChanges[SRGPlaylistEntryPreviousUidsSubKey];
            NSArray<NSString *> *URNs = playlistEntryChanges[SRGPlaylistEntryUidsSubKey];
            if (URNs.count == 0 || previousURNs.count == 0) {
                [self refresh];
            }
        }
    }
}

@end
