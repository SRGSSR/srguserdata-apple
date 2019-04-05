//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylist.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Private interface for implementation purposes.
 */
@interface SRGPlaylist (Private)

/**
 *  @see `SRGPlaylist.h`
 */
@property (nonatomic, copy) NSString *name;
@property (nonatomic) BOOL system;

@property (nonatomic, nullable) NSOrderedSet<SRGPlaylistEntry *> *entries;

@end

NS_ASSUME_NONNULL_END
