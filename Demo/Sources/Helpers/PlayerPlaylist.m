//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlayerPlaylist.h"

#import <SRGUserData/SRGUserData.h>

@interface PlayerPlaylist ()

@property (nonatomic) NSArray<SRGMedia *> *medias;
@property (nonatomic) NSInteger currentIndex;

@end

@implementation PlayerPlaylist

#pragma mark Object lifecycle

- (instancetype)initWithMedias:(NSArray<SRGMedia *> *)medias currentIndex:(NSInteger)currentIndex
{
    if (self = [super init]) {
        self.medias = medias;
        self.currentIndex = (currentIndex < medias.count) ? currentIndex : -1;
    }
    return self;
}

#pragma SRGLetterboxControllerPlaylistDataSource protocol

- (SRGMedia *)previousMediaForController:(SRGLetterboxController *)controller
{
    return (self.currentIndex > 0) ? self.medias[self.currentIndex - 1] : nil;
}

- (SRGMedia *)nextMediaForController:(SRGLetterboxController *)controller
{
    return (self.currentIndex < self.medias.count - 1) ? self.medias[self.currentIndex + 1] : nil;
}

- (NSTimeInterval)continuousPlaybackTransitionDurationForController:(SRGLetterboxController *)controller
{
    return 5.f;
}

- (nullable SRGPosition *)controller:(SRGLetterboxController *)controller startPositionForMedia:(SRGMedia *)media
{
    SRGHistoryEntry *historyEntry = [SRGUserData.currentUserData.history historyEntryWithUid:media.URN];
    if (historyEntry) {
        return [SRGPosition positionBeforeTime:historyEntry.lastPlaybackTime];
    }
    else {
        return nil;
    }
}

- (void)controller:(SRGLetterboxController *)controller didTransitionToMedia:(SRGMedia *)media automatically:(BOOL)automatically
{
    if ([media isEqual:[self previousMediaForController:controller]]) {
        self.currentIndex -= 1;
    }
    else if ([media isEqual:[self nextMediaForController:controller]]) {
        self.currentIndex += 1;
    }
}

@end
