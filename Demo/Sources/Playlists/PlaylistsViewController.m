//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlaylistsViewController.h"

#import "PlayerViewController.h"
#import "PlaylistViewController.h"

#import <libextobjc/libextobjc.h>
#import <SRGUserData/SRGUserData.h>

@interface PlaylistsViewController ()

@property (nonatomic) NSArray<SRGPlaylist *> *playlists;

@end

@implementation PlaylistsViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"Playlists", nil);
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
                                           selector:@selector(playlistsDidChange:)
                                               name:SRGPlaylistsDidChangeNotification
                                             object:SRGUserData.currentUserData.playlists];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"PlaylistCell"];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addPlaylist:)];
    
    [self updateNavigationBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self refresh];
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
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylist.new, discarded)];
    NSSortDescriptor *systemSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, system) ascending:NO];
    NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, name) ascending:YES];
    self.playlists = [SRGUserData.currentUserData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:@[systemSortDescriptor, nameSortDescriptor]];
    
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
    }
    
    [self.tableView reloadData];
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.playlists.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:@"PlaylistCell"];
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    SRGPlaylist *playlist = self.playlists[indexPath.row];
    cell.textLabel.text = playlist.name;
    cell.imageView.image = [playlist.uid isEqualToString:SRGWatchLaterPlaylistUid] ? [UIImage imageNamed:@"watch_later_22"] : [UIImage imageNamed:@"playlist_22"];
    cell.imageView.tintColor = UIColor.blackColor;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SRGPlaylist *playlist = self.playlists[indexPath.row];
    PlaylistViewController *playlistViewController = [[PlaylistViewController alloc] initWithPlaylist:playlist];
    [self.navigationController pushViewController:playlistViewController animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ! self.playlists[indexPath.row].system;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete){
        SRGPlaylist *playlist = self.playlists[indexPath.row];
        [SRGUserData.currentUserData.playlists discardPlaylistsWithUids:@[playlist.uid] completionBlock:^(NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableArray<SRGPlaylist *> *playlists = [self.playlists mutableCopy];
                [playlists removeObjectAtIndex:indexPath.row];
                self.playlists = [playlists copy];
                
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            });
        }];
    }
}

#pragma mark Actions

- (void)addPlaylist:(id)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Create a new playlist", nil)
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"Playlist name", nil);
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleDefault handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Create", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alertController.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length > 0) {
            NSString *uid = NSUUID.UUID.UUIDString;
            [SRGUserData.currentUserData.playlists savePlaylistForUid:uid withName:name completionBlock:^(NSError * _Nullable error) {
                if (! error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self refresh];
                    });
                }
            }];
        }
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

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

- (void)playlistsDidChange:(NSNotification *)notification
{
    NSArray<NSString *> *previousUids = notification.userInfo[SRGPlaylistsPreviousUidsKey];
    NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistsUidsKey];
    if (uids.count == 0 || previousUids.count == 0) {
        [self refresh];
    }
}

@end
