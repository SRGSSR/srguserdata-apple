//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Playlist types.
 */
typedef NS_ENUM(NSInteger, SRGPlaylistType) {
    /**
     *  Standard user-generated playlist.
     */
    SRGPlaylistTypeStandard = 0,
    /**
     *  Watch later system playlist.
     */
    SRGPlaylistTypeWatchLater
};

/**
 *  Default playlist identifiers. Use to access system playlists widely available.
 */
typedef NSString * SRGPlaylistUid NS_TYPED_ENUM;

OBJC_EXPORT SRGPlaylistUid const SRGPlaylistUidWatchLater;                          // Watch later playlist

/**
 *  Entry in the playlist service.
 *
 *  @discussion Instances must not be shared among threads.
 */
@interface SRGPlaylist : SRGUserObject

/**
 *  A display name.
 */
@property (nonatomic, readonly, copy) NSString *name;

/**
 *  The type of the playlist.
 */
@property (nonatomic, readonly) SRGPlaylistType type;

@end

NS_ASSUME_NONNULL_END
