//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylistEntry.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Private interface for implementation purposes.
 */
@interface SRGPlaylistEntry (Private)

/**
 *  @see `SRGPlaylistEntry.h`
 */
@property (nonatomic, nullable) SRGPlaylist *playlist;

/**
 *  Return existing entries, optionally matching a specific predicate and / or sorted with descriptors. If no sort
 *  descriptors are provided, entries are still returned in a stable order.
 */
+ (NSArray<__kindof SRGPlaylistEntry *> *)objectsMatchingPredicate:(nullable NSPredicate *)predicate
                                          sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                         inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Return an existing object for the specified identifier for a playlist, `nil` if none is found.
 */
+ (nullable __kindof SRGPlaylistEntry *)objectWithUid:(NSString *)uid playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Create an entry with the specified identifier for a playlist, or return an existing one for update purposes.
 */
+ (__kindof SRGPlaylistEntry *)upsertWithUid:(NSString *)uid playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end

NS_ASSUME_NONNULL_END
