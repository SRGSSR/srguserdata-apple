//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <CoreMedia/CoreMedia.h>

@class SRGUser;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Entry in the media playback history.
 */
@interface SRGHistoryEntry : NSManagedObject

// TODO: Hide implementation details, provide only read-only objects to SDK users

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
 *  Return history entries, optionally matching a specific predicate and / or sorted with descriptors.
 *
 *  @discussion If no sort descriptors are provided, entries are still returned in a stable order.
 */
+ (NSArray<SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                                       sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                      inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Return an entry matching the specified URN, `nil` if none is found.
 */
+ (nullable SRGHistoryEntry *)historyEntryWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

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

/**
 *  Return a dictionary representation of the entry and which can be sent to the history service.
 */
@property (nonatomic, readonly) NSDictionary *dictionary;

@end

NS_ASSUME_NONNULL_END

#import "SRGHistoryEntry+CoreDataProperties.h"          // Generated and managed by Xcode
