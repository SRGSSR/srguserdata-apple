//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylist.h"
#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Entry in a playlist.
 *
 *  @discussion Instances must not be shared among threads.
 */
@interface SRGPlaylistEntry : SRGUserObject

/**
 *  The related playlist.
 */
@property (nonatomic, readonly, nullable) SRGPlaylist *playlist;

@end

NS_ASSUME_NONNULL_END

