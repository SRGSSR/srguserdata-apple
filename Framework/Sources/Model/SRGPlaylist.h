//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

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
 *  `YES` iff the playlist is a system mandatory one, otherwise, it's a user playlist.
 */
@property (nonatomic, readonly) BOOL system;

@end

NS_ASSUME_NONNULL_END
