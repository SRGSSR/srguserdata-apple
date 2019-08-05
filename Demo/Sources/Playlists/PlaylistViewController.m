//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlaylistViewController.h"

#import "PlayerViewController.h"
#import "SRGUserData_demo-Swift.h"

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
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    PlaylistViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.playlist = playlist;
    return viewController;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playlistEntriesDidChange:)
                                               name:SRGPlaylistEntriesDidChangeNotification
                                             object:SRGUserData.currentUserData.playlists];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"MediaCell"];
    
    if (self.playlist.type == SRGPlaylistTypeStandard) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                               target:self
                                                                                               action:@selector(updatePlaylist:)];
    }
    
    [self reloadTitle];
}

#pragma mark Data

- (void)reloadTitle
{
    NSString *title = self.playlist.name;
    self.title = title;
}

#pragma mark Subclassing hooks

- (void)refresh
{
    if (self.request.running) {
        return;
    }
    
    BOOL ascending = ! [self.playlist.uid isEqualToString:SRGPlaylistUidWatchLater];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, date) ascending:ascending];
    [SRGUserData.currentUserData.playlists playlistEntriesInPlaylistWithUid:self.playlist.uid matchingPredicate:nil sortedWithDescriptors:@[sortDescriptor] completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        NSArray<NSString *> *mediaURNs = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        SRGBaseRequest *request = [[SRGDataProvider.currentDataProvider mediasWithURNs:mediaURNs completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            if (error) {
                return;
            }
            
            [self.tableView reloadDataAnimatedWithOldObjects:self.medias newObjects:medias section:0 updateData:^{
                self.medias = medias;
            }];
        }] requestWithPageSize:50];
        [request resume];
        self.request = request;
    }];
}

- (void)cancelRefresh
{
    [self.request cancel];
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
    
    PlayerPlaylist *playerPlaylist = [[PlayerPlaylist alloc] initWithMedias:self.medias currentIndex:indexPath.row];
    PlayerViewController *playerViewController = [[PlayerViewController alloc] initWithURN:media.URN time:historyEntry.lastPlaybackTime playerPlaylist:playerPlaylist];
    playerViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:playerViewController animated:YES completion:nil];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        SRGMedia *media = self.medias[indexPath.row];
        [SRGUserData.currentUserData.playlists discardPlaylistEntriesWithUids:@[media.URN] fromPlaylistWithUid:self.playlist.uid completionBlock:nil];
    }
}

#pragma mark Actions

- (void)updatePlaylist:(id)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Update playlist name", nil)
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"Playlist name", nil);
        textField.text = self.playlist.name;
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Update", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alertController.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length > 0) {
            [SRGUserData.currentUserData.playlists savePlaylistWithName:name uid:self.playlist.uid completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (! error) {
                        [self reloadTitle];
                    }
                });
            }];
        }
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark Notifications

- (void)playlistEntriesDidChange:(NSNotification *)notification
{
    [self refresh];
}

@end
