//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlaylistsViewController.h"

#import "PlayerViewController.h"
#import "PlaylistViewController.h"
#import "SRGUserData_demo-Swift.h"

@import libextobjc;
@import SRGUserData;

@interface PlaylistsViewController ()

@property (nonatomic) NSArray<SRGPlaylist *> *playlists;

@end

@implementation PlaylistsViewController

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"Playlists", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playlistsDidChange:)
                                               name:SRGPlaylistsDidChangeNotification
                                             object:SRGUserData.currentUserData.playlists];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"PlaylistCell"];
    
#if TARGET_OS_IOS
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addPlaylist:)];
#endif
}

#pragma mark Subclassing hooks

- (void)refresh
{
    NSSortDescriptor *typeSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, type) ascending:NO];
    NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, name) ascending:YES];
    NSArray<SRGPlaylist *> *playlists = [SRGUserData.currentUserData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:@[typeSortDescriptor, nameSortDescriptor]];
    
    [self.tableView reloadDataAnimatedWithOldObjects:self.playlists newObjects:playlists section:0 updateData:^{
        self.playlists = playlists;
    }];
}

#pragma mark UITableViewDataSource protocol

#if TARGET_OS_TV

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

#endif

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (section == 0) ? self.playlists.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:@"PlaylistCell"];
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        SRGPlaylist *playlist = self.playlists[indexPath.row];
        cell.textLabel.text = playlist.name;
        cell.imageView.image = [playlist.uid isEqualToString:SRGPlaylistUidWatchLater] ? [UIImage imageNamed:@"watch_later"] : [UIImage imageNamed:@"playlist"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    else {
        cell.textLabel.text = NSLocalizedString(@"Add playlist", nil);
        cell.imageView.image = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        SRGPlaylist *playlist = self.playlists[indexPath.row];
        PlaylistViewController *playlistViewController = [[PlaylistViewController alloc] initWithPlaylist:playlist];
        [self.navigationController pushViewController:playlistViewController animated:YES];
    }
    else {
        [self addPlaylist:nil];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        SRGPlaylist *playlist = self.playlists[indexPath.row];
        return playlist.type == SRGPlaylistTypeStandard;
    }
    else {
        return NO;
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        SRGPlaylist *playlist = self.playlists[indexPath.row];
        [SRGUserData.currentUserData.playlists discardPlaylistsWithUids:@[playlist.uid] completionBlock:nil];
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
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Create", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alertController.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length > 0) {
            [SRGUserData.currentUserData.playlists savePlaylistWithName:name uid:nil completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
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

#pragma mark Notifications

- (void)playlistsDidChange:(NSNotification *)notification
{
    [self refresh];
}

@end
