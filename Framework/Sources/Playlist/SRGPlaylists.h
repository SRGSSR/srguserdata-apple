//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylist.h"
#import "SRGPlaylistEntry.h"
#import "SRGUserDataService.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Return a suggested name for a system playlist, `nil` if none or unknown uid.
 */
OBJC_EXPORT NSString * _Nullable SRGPlaylistNameForPlaylistWithUid(NSString *uid);

/**
 *  Watch later system playlist uid
 */
OBJC_EXPORT NSString * const SRGPlaylistSystemWatchLaterUid;

/**
 *  Notification sent when one or more playlists change. Use the keys below to retrieve detailed information from the notification
 *  `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGPlaylistsDidChangeNotification;                   // Notification name.

OBJC_EXPORT NSString * const SRGPlaylistChangedUidsKey;                           // Key to access the list of uids which have changed as an `NSArray` of `NSString` objects.
OBJC_EXPORT NSString * const SRGPlaylistPreviousUidsKey;                          // Key to access the previous uid list as an `NSArray` of `NSString` objects.
OBJC_EXPORT NSString * const SRGPlaylistUidsKey;                                  // Key to access the current uid list as an `NSArray` of `NSString` objects.

/**
 *  Notification sent when playlists synchronization has started.
 */
OBJC_EXPORT NSString * const SRGPlaylistsDidStartSynchronizationNotification;

/**
 *  Notification sent when playlists synchronization has finished.
 */
OBJC_EXPORT NSString * const SRGPlaylistDidFinishSynchronizationNotification;

/**
 *  Manages a local cache for playlists. Playlists are characterized by an identifier, a system flag and
 *  a name. Based on a local cache, this class ensures efficient playlist retrieval from a webservice and keeps local and
 *  distant playlists in sync.
 *
 *  You can register for playlists update notifications, see above. These will be sent by the `SRGPlaylists` instance
 *  itself.
 */
@interface SRGPlaylists : SRGUserDataService

/**
 *  Return playlists, optionally matching a specific predicate and / or sorted with descriptors. If no sort
 *  descriptors are provided, entries are still returned in a stable order.
 *
 *  @discussion This method can only be called from the main thread. Reads on other threads must occur asynchronously
 *              with `-playlistsMatchingPredicate:sortedWithDescriptors:completionBlock:`.
 */
- (NSArray<SRGPlaylist *> *)playlistsMatchingPredicate:(nullable NSPredicate *)predicate
                                 sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors;

/**
 *  Return playlists, optionally matching a specific predicate and / or sorted with descriptors. If no sort
 *  descriptors are provided, entries are still returned in a stable order. The read occurs asynchronously, calling
 *  the provided block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error.
 *
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread.
 */
- (NSString *)playlistsMatchingPredicate:(nullable NSPredicate *)predicate
                   sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                         completionBlock:(void (^)(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error))completionBlock;

/**
 *  Return the playlist matching the specified identifier, if any.
 *
 *  @discussion This method can only be called from the main thread.
 */
- (nullable SRGPlaylist *)playlistWithUid:(NSString *)uid;

/**
 *  Return the playlist matching the specified identifier, if any. The read occurs asynchronously, calling the
 *  provided block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error.
 *
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread.
 */
- (NSString *)playlistWithUid:(NSString *)uid completionBlock:(void (^)(SRGPlaylist * _Nullable playlist, NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously save a playlist for a given name, calling the specified block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread.
 *              Set a name to a system playlist has no effect.
 */
- (NSString *)savePlaylistForUid:(NSString *)uid
                        withName:(NSString *)name
                 completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously discard playlists matching an identifier list, calling the provided block on completion. If no
 *  list is provided, all entries are discarded, expect system playlists.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread.
 *              Discard a system playlist has no effect.
 */
- (NSString *)discardPlaylistsWithUids:(nullable NSArray<NSString *> *)uids
                       completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Return playlist entries for a given playlist uid, optionally matching a specific predicate and / or sorted with descriptors. If no sort
 *  descriptors are provided, entries are still returned in a stable order.
 *
 *  @discussion This method can only be called from the main thread. Reads on other threads must occur asynchronously
 *              with `-entriesFromPlaylistWithUid:matchingPredicate:sortedWithDescriptors:completionBlock:`.
 *              This method returns `nil` if the playlist uid does not exist.
 */
- (nullable NSArray<SRGPlaylistEntry *> *)entriesFromPlaylistWithUid:(NSString *)playlistUid
                                          matchingPredicate:(nullable NSPredicate *)predicate
                                      sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors;

/**
 *  Return playlist entries for a given playlist uid, optionally matching a specific predicate and / or sorted with descriptors. If no sort
 *  descriptors are provided, entries are still returned in a stable order. The read occurs asynchronously, calling
 *  the provided block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error.
 *
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread.
 *              This method returns `nil` if the playlist uid does not exist.
 */
- (NSString *)entriesFromPlaylistWithUid:(NSString *)playlistUid
                       matchingPredicate:(nullable NSPredicate *)predicate
                   sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                         completionBlock:(void (^)(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously add a playlist entry for a given uid to the given playlist, calling the specified block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread.
 *              Adding an already added entry with the same uid will just update the added date, not duplicate the entry.
 */
- (NSString *)addEntryWithUid:(NSString *)uid
            toPlaylistWithUid:(NSString *)playlistUid
              completionBlock:(void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Cancel the task having the specified handle.
 */
- (void)cancelTaskWithHandle:(NSString *)handle;

@end

NS_ASSUME_NONNULL_END
