//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlayerViewController.h"

#import <libextobjc/libextobjc.h>
#import <SRGLetterbox/SRGLetterbox.h>
#import <SRGUserData/SRGUserData.h>

@interface PlayerViewController ()

@property (nonatomic, copy) NSString *URN;

@property (nonatomic, weak) IBOutlet SRGLetterboxView *letterboxView;
@property (nonatomic) IBOutlet SRGLetterboxController *letterboxController;     // top-level object, retained

@end

@implementation PlayerViewController

#pragma mark Object lifecycle

- (instancetype)initWithURN:(NSString *)URN
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    PlayerViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.URN = URN;
    return viewController;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.URN) {
        [self.letterboxController playURN:self.URN atPosition:nil withPreferredSettings:nil];
    }
    
    @weakify(self)
    [self.letterboxController addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
        @strongify(self)
        [SRGUserData.currentUserData.history saveHistoryEntryForUid:self.URN withLastPlaybackTime:time deviceUid:UIDevice.currentDevice.name completionBlock:nil];
    }];
}

#pragma mark Home indicator

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return self.letterboxView.userInterfaceHidden;
}

#pragma mark SRGLetterboxViewDelegate protocol

- (void)letterboxViewWillAnimateUserInterface:(SRGLetterboxView *)letterboxView
{
    [letterboxView animateAlongsideUserInterfaceWithAnimations:nil completion:^(BOOL finished) {
        if (@available(iOS 11, *)) {
            [self setNeedsUpdateOfHomeIndicatorAutoHidden];
        }
    }];
}

@end
