//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistoryEntry.h"

#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRGHistoryEntry (Private)

/**
 *  Synchronize the local history with the information from the provided dictionary, in the format delivered by the
 *  history service. Entries are created, updated or deleted appropriately to synchronize the local history status
 *  with the one obtained from the history service. If a local entry was created, updated or deleted, its URN
 *  is returned. If the dictionary data is invalid, the method returns `nil`.
 *
 *  @discussion To persist changes, the Core Data managed object context needs to be saved.
 */
+ (nullable NSString *)synchronizeWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Insert a new entry, or return the existing one for update purposes.
 *
 *  @discussion The entry is properly setup for synchronization purposes.
 */
+ (SRGHistoryEntry *)upsertWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Delete all history entries.
 */
+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Update the current entry using the provided dictionary, in the format delivered by the history service.
 */
- (void)updateWithDictionary:(NSDictionary *)dictionary;

/**
 *  Discard the entry (actual deletion takes place when synchronizing with the service).
 */
- (void)discard;

/**
 *  The last playback time associated with the URN.
 */
@property (nonatomic) CMTime lastPlaybackTime;


@property (nonatomic) BOOL dirty;

/**
 *  Return a dictionary representation of the entry and which can be sent to the history service.
 */
@property (nonatomic, readonly) NSDictionary *dictionary;

@end

NS_ASSUME_NONNULL_END
