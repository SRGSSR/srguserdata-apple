//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistoryEntry.h"
#import "SRGUserDataService.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notification sent when the history changes. Use the `SRGHistoryUidsKey` to retrieve the updated uids from the
 *  notification `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGHistoryDidChangeNotification;                    // Notification name.

OBJC_EXPORT NSString * const SRGHistoryPreviousUidsKey;                          // Key to access the previous uid list as an `NSArray` of `NSString` objects.
OBJC_EXPORT NSString * const SRGHistoryUidsKey;                                  // Key to access the current uid list as an `NSArray` of `NSString` objects.

/**
 *  Notification sent when history synchronization has started.
 */
OBJC_EXPORT NSString * const SRGHistoryDidStartSynchronizationNotification;

/**
 *  Notification sent when history synchronization has finished.
 */
OBJC_EXPORT NSString * const SRGHistoryDidFinishSynchronizationNotification;

/**
 *  Notification sent when the history has been cleared.
 */
OBJC_EXPORT NSString * const SRGHistoryDidClearNotification;

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
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread.
 */
- (void)historyEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                  sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                        completionBlock:(void (^)(NSArray<SRGHistoryEntry *> *historyEntries))completionBlock;

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
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread.
 */
- (void)historyEntryWithUid:(NSString *)uid completionBlock:(void (^)(SRGHistoryEntry * _Nullable historyEntry))completionBlock;

/**
 *  Asynchronously save a history entry for a given identifier, calling the specified block on completion.
 *
 *  @discussion The completion block is called on a background thread.
 */
- (void)saveHistoryEntryForUid:(NSString *)Uid
          withLastPlaybackTime:(CMTime)lastPlaybackTime
                     deviceUid:(nullable NSString *)deviceUid
               completionBlock:(nullable void (^)(NSError *error))completionBlock;

/**
 *  Asynchronously discard history entries matching an identifier list, calling the provided block on completion. If no
 *  list is provided, all entries are discarded.
 *
 *  @discussion The completion block is called on a background thread.
 */
- (void)discardHistoryEntriesWithUids:(nullable NSArray<NSString *> *)uids
                      completionBlock:(nullable void (^)(NSError *error))completionBlock;

@end

NS_ASSUME_NONNULL_END
