//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlaylistsViewController.h"

#import "PlayerViewController.h"
#import "PlaylistViewController.h"
#import "SRGUserData_demo-Swift.h"

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
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playlistsDidChange:)
                                               name:SRGPlaylistsDidChangeNotification
                                             object:SRGUserData.currentUserData.playlists];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"PlaylistCell"];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addPlaylist:)];
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
    cell.imageView.image = [playlist.uid isEqualToString:SRGPlaylistUidWatchLater] ? [UIImage imageNamed:@"watch_later_22"] : [UIImage imageNamed:@"playlist_22"];
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
    SRGPlaylist *playlist = self.playlists[indexPath.row];
    return playlist.type == SRGPlaylistTypeStandard;
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
