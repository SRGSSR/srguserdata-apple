//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlayerViewController.h"

@import libextobjc;
@import SRGUserData;

SRGLetterboxViewController *LetterboxPlayerViewController(NSString *URN, CMTime time, PlayerPlaylist *playerPlaylist)
{
    SRGLetterboxViewController *playerViewController = [[SRGLetterboxViewController alloc] init];
    
    SRGLetterboxController *controller = playerViewController.controller;
    controller.playlistDataSource = playerPlaylist;
    
    @weakify(controller)
    [controller addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
        @strongify(controller)
        
        if (URN) {
            SRGSubdivision *subdivision = controller.subdivision;
            if ([subdivision isKindOfClass:SRGSegment.class]) {
                SRGSegment *segment = (SRGSegment *)subdivision;
                CMTime segmentPlaybackTime = CMTimeMaximum(CMTimeSubtract(time, CMTimeMakeWithSeconds(segment.markIn / 1000., NSEC_PER_SEC)), kCMTimeZero);
                [SRGUserData.currentUserData.history saveHistoryEntryWithUid:URN lastPlaybackTime:segmentPlaybackTime deviceUid:UIDevice.currentDevice.name completionBlock:nil];
            }
            else {
                [SRGUserData.currentUserData.history saveHistoryEntryWithUid:URN lastPlaybackTime:time deviceUid:UIDevice.currentDevice.name completionBlock:nil];
            }
        }
    }];
    
    [controller playURN:URN atPosition:[SRGPosition positionAtTime:time] withPreferredSettings:nil];
    
    return playerViewController;
}
