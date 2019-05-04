//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistoryEntry.h"
#import "SRGUserDataService.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notification sent when the history changes. Use the keys below to retrieve detailed information from the notification
 *  `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGHistoryEntriesDidChangeNotification;             // Notification name.

OBJC_EXPORT NSString * const SRGHistoryChangedUidsKey;                           // Key to access the list of uids which have changed as an `NSSet` of `NSString` objects.

/**
 *  Manages a local cache for history entries. History entries are characterized by an identifier and an associated
 *  playback position. Based on a local cache, this class ensures efficient history retrieval from a webservice and
 *  keeps local and distant histories in sync.
 *
 *  You can register for history update notifications, see above. These will be sent by the `SRGHistory` instance
 *  itself.
 */
@interface SRGHistory : SRGUserDataService

/**
 *  Return history entries, optionally matching a specific predicate and / or sorted with descriptors. If no sort
 *  descriptors are provided, entries are still returned in a stable order.
 *
 *  @discussion This method can only be called from the main thread. Reads on other threads must occur asynchronously
 *              with `-historyEntriesMatchingPredicate:sortedWithDescriptors:completionBlock:`.
 */
- (NSArray<SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                                          sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors;

/**
 *  Return history entries, optionally matching a specific predicate and / or sorted with descriptors. If no sort
 *  descriptors are provided, entries are still returned in a stable order. The read occurs asynchronously, calling
 *  the provided block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error.
 *
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread.
 */
- (NSString *)historyEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                        sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                              completionBlock:(void (^)(NSArray<SRGHistoryEntry *> * _Nullable historyEntries, NSError * _Nullable error))completionBlock;

/**
 *  Return the history entry matching the specified identifier, if any.
 *
 *  @discussion This method can only be called from the main thread.
 */
- (nullable SRGHistoryEntry *)historyEntryWithUid:(NSString *)uid;

/**
 *  Return the history entry matching the specified identifier, if any. The read occurs asynchronously, calling the
 *  provided block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error.
 *
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread.
 */
- (NSString *)historyEntryWithUid:(NSString *)uid completionBlock:(void (^)(SRGHistoryEntry * _Nullable historyEntry, NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously save a history entry for a given identifier, calling the specified block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread.
 */
- (NSString *)saveHistoryEntryWithUid:(NSString *)uid
                     lastPlaybackTime:(CMTime)lastPlaybackTime
                            deviceUid:(nullable NSString *)deviceUid
                      completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously discard history entries matching an identifier list, calling the provided block on completion. If no
 *  list is provided, all entries are discarded.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread.
 */
- (NSString *)discardHistoryEntriesWithUids:(nullable NSArray<NSString *> *)uids
                            completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;


/**
 *  Cancel the task having the specified handle.
 */
- (void)cancelTaskWithHandle:(NSString *)handle;

@end

NS_ASSUME_NONNULL_END
