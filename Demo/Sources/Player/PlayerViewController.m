//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlayerViewController.h"

#import "PlayerPlaylist.h"

#import <libextobjc/libextobjc.h>
#import <SRGLetterbox/SRGLetterbox.h>
#import <SRGUserData/SRGUserData.h>

@interface PlayerViewController ()

@property (nonatomic, copy) NSString *URN;
@property (nonatomic) SRGPosition *position;
@property (nonatomic) PlayerPlaylist *playerPlaylist;

@property (nonatomic, weak) IBOutlet SRGLetterboxView *letterboxView;
@property (nonatomic) IBOutlet SRGLetterboxController *letterboxController;     // top-level object, retained

@property (nonatomic, weak) IBOutlet UIButton *closeButton;
@property (nonatomic, weak) IBOutlet UIButton *playlistsButton;

@end

@implementation PlayerViewController

#pragma mark Object lifecycle

- (instancetype)initWithURN:(nullable NSString *)URN time:(CMTime)time playerPlaylist:(nullable PlayerPlaylist *)playerPlaylist
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    PlayerViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.URN = URN;
    viewController.position = [SRGPosition positionBeforeTime:time];
    viewController.playerPlaylist = playerPlaylist;
    return viewController;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.letterboxController.playlistDataSource = self.playerPlaylist;
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(metadataDidChange:)
                                               name:SRGLetterboxMetadataDidChangeNotification
                                             object:self.letterboxController];
    
    @weakify(self)
    [self.letterboxController addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
        @strongify(self)
        
        NSString *URN = self.letterboxController.URN;
        if (URN) {
            [SRGUserData.currentUserData.history saveHistoryEntryWithUid:URN lastPlaybackTime:time deviceUid:UIDevice.currentDevice.name completionBlock:nil];
        }
    }];
    
    if (self.URN) {
        [self.letterboxController playURN:self.URN atPosition:self.position withPreferredSettings:nil];
    }
    
    [self reloadData];
}

#pragma mark Home indicator

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return self.letterboxView.userInterfaceHidden;
}

#pragma mark UI

- (void)reloadData
{
    self.playlistsButton.hidden = (self.letterboxController.media == nil);
}

#pragma mark SRGLetterboxViewDelegate protocol

- (void)letterboxViewWillAnimateUserInterface:(SRGLetterboxView *)letterboxView
{
    [self.view layoutIfNeeded];
    [letterboxView animateAlongsideUserInterfaceWithAnimations:^(BOOL hidden, BOOL minimal, CGFloat heightOffset) {
        CGFloat alpha = (minimal || ! hidden) ? 1.f : 0.f;
        self.closeButton.alpha = alpha;
        self.playlistsButton.alpha = alpha;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (@available(iOS 11, *)) {
            [self setNeedsUpdateOfHomeIndicatorAutoHidden];
        }
    }];
}

#pragma mark Actions

- (IBAction)close:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)addToPlaylist:(id)sender
{
    SRGMedia *media = self.letterboxController.media;
    NSAssert(media, @"A media must be available");
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add to playlist", nil)
                                                                             message:media.title
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSSortDescriptor *typeSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, type) ascending:NO];
    NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, name) ascending:YES];
    NSArray<SRGPlaylist *> *playlists = [SRGUserData.currentUserData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:@[typeSortDescriptor, nameSortDescriptor]];
    
    for (SRGPlaylist *playlist in playlists) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:playlist.name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [SRGUserData.currentUserData.playlists savePlaylistEntryWithUid:media.URN inPlaylistWithUid:playlist.uid completionBlock:nil];
        }];
        [alertController addAction:action];
        
        if ([playlist.uid isEqualToString:SRGPlaylistUidWatchLater]) {
            alertController.preferredAction = action;
        }
    }
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark Notifications

- (void)metadataDidChange:(NSNotification *)reloadData
{
    [self reloadData];
}

@end
