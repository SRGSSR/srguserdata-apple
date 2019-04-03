//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>

#import "SRGPlaylist.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Bookmark in a playlist.
 *
 *  @discussion Instances must not be shared among threads.
 */
@interface SRGPlaylistEntry : NSManagedObject

/**
 *  The item unique identifier.
 */
@property (nonatomic, readonly, copy, nullable) NSString *uid;

/**
 *  The date at which the entry was updated for the last time.
 */
@property (nonatomic, readonly, copy, nullable) NSDate *date;

/**
 *  `YES` iff the entry has been marked as discarded.
 */
@property (nonatomic, readonly) BOOL discarded;

/**
 *  The related playlist.
 */
@property (nonatomic, readonly, nullable) SRGPlaylist *playlist;

@end

NS_ASSUME_NONNULL_END

