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
     *  Not specified.
     */
    SRGPlaylistTypeNone = 0,
    /**
     *  Standard user-generated playlist.
     */
    SRGPlaylistTypeStandard,
    /**
     *  System playlist.
     */
    SRGPlaylistTypeSystem
};

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
