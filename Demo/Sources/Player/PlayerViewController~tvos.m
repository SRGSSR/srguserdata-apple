//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlayerViewController.h"

#import <SRGUserData/SRGUserData.h>

SRGLetterboxViewController *LetterboxPlayerViewController(NSString *URN, CMTime time, PlayerPlaylist *playerPlaylist)
{
    SRGLetterboxViewController *playerViewController = [[SRGLetterboxViewController alloc] init];
    
    SRGLetterboxController *controller = playerViewController.controller;
    controller.playlistDataSource = playerPlaylist;
    
    [controller addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
        if (URN) {
            [SRGUserData.currentUserData.history saveHistoryEntryWithUid:URN lastPlaybackTime:time deviceUid:UIDevice.currentDevice.name completionBlock:nil];
        }
    }];
    
    [controller playURN:URN atPosition:[SRGPosition positionBeforeTime:time] withPreferredSettings:nil];
    
    return playerViewController;
}
