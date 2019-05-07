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
 *  Notification sent when one or more playlists change. Use the keys below to retrieve detailed information from the notification
 *  `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGPlaylistsDidChangeNotification;                   // Notification name.

/**
 *  Information available for `SRGPlaylistsDidChangeNotification`.
 */
OBJC_EXPORT NSString * const SRGPlaylistsUidsKey;                                 // Key to access the list of uids which have changed (inserted, updated or deleted) as an `NSSet` of `NSString` objects.

/**
 *  Notification sent when one or more playlist entries change. Use the keys below to retrieve detailed information from the notification
 *  `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGPlaylistEntriesDidChangeNotification;             // Notification name.

/**
 *  Information available for `SRGPlaylistEntriesDidChangeNotification`.
 */
OBJC_EXPORT NSString * const SRGPlaylistUidKey;                                   // Key to the uid (`NSString`) of the playlist for which entries have changed.
OBJC_EXPORT NSString * const SRGPlaylistEntriesUidsKey;                           // Key to access the list of uids which have changed (inserted, updated or deleted) as an `NSSet` of `NSString` objects.

/**
 *  Manages a local cache for playlists. Playlists are characterized by an identifier, a name and a type. Based
 *  on a local cache, this class ensures efficient playlist retrieval from a webservice and keeps local and distant
 *  playlists in sync.
 *
 *  You can register for playlists update notifications, see above. These will be sent by the `SRGPlaylists` instance
 *  itself.
 */
@interface SRGPlaylists : SRGUserDataService

/**
 *  Return playlists, optionally matching a specific predicate and / or sorted with descriptors. If no sort descriptors
 *  are provided, entries are still returned in a stable order.
 *
 *  @discussion This method can only be called from the main thread. Reads on other threads must occur asynchronously
 *              with `-playlistsMatchingPredicate:sortedWithDescriptors:completionBlock:`.
 */
- (NSArray<SRGPlaylist *> *)playlistsMatchingPredicate:(nullable NSPredicate *)predicate
                                 sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors;

/**
 *  Return playlists, optionally matching a specific predicate and / or sorted with descriptors. If no sort descriptors
 *  are provided, entries are still returned in a stable order. The read occurs asynchronously, calling the provided block
 *  on completion.
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
 *  Return the playlist matching the specified identifier, if any. The read occurs asynchronously, calling the provided
 *  block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error.
 *
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread.
 */
- (NSString *)playlistWithUid:(NSString *)uid completionBlock:(void (^)(SRGPlaylist * _Nullable playlist, NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously save a playlist for a given identifier and name, calling the specified block on completion. If no
 *  identifier is specified, a new playlist with a generated identifier will be created. If an existing identifier
 *  is specified, the corresponding playlist name will be updated.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread. Attempting to update a default playlist (@see
 *              `SRGPlaylistUid`) fails with an error.
 */
- (NSString *)savePlaylistWithName:(NSString *)name
                               uid:(nullable NSString *)uid
                   completionBlock:(nullable void (^)(NSString * _Nullable uid, NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously discard playlists matching an identifier in the list, calling the provided block on completion. If no
 *  list is provided, all playlists are discarded (except default playlists).
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread. Attempting to discard a default playlist (@see
 *              `SRGPlaylistUid`) has no effect.
 */
- (NSString *)discardPlaylistsWithUids:(nullable NSArray<NSString *> *)uids
                       completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Return playlist entries for a given playlist identifier, optionally matching a specific predicate and / or sorted with
 *  descriptors. If no sort descriptors are provided, entries are still returned in a stable order.
 *
 *  @discussion This method can only be called from the main thread. Reads on other threads must occur asynchronously
 *              with `-entriesInPlaylistWithUid:matchingPredicate:sortedWithDescriptors:completionBlock:`.
 *              This method returns `nil` if no playlist exists for the specified identifier.
 */
- (nullable NSArray<SRGPlaylistEntry *> *)entriesInPlaylistWithUid:(NSString *)playlistUid
                                                 matchingPredicate:(nullable NSPredicate *)predicate
                                             sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors;

/**
 *  Return playlist entries for a given playlist identifier, optionally matching a specific predicate and / or sorted
 *  with descriptors. If no sort descriptors are provided, entries are still returned in a stable order. The read occurs
 *  asynchronously, calling the provided block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error.
 *
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread. This method returns `nil` if no playlist exists for the specified identifier.
 */
- (NSString *)entriesInPlaylistWithUid:(NSString *)playlistUid
                     matchingPredicate:(nullable NSPredicate *)predicate
                 sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                       completionBlock:(void (^)(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously add a playlist entry with a given identifier to the specified playlist, calling the provided block on
 *  completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread. Adding an entry for an existing identifier only
 *              update its date but does not duplicate it. This method returns an error and adds nothing if the playlist
 *              does not exist.
 */
- (NSString *)saveEntryWithUid:(NSString *)uid
             inPlaylistWithUid:(NSString *)playlistUid
               completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously remove playlist entries matching an identifier in the list, calling the provided block on completion.
 *  If no list is provided, all entries in the playlist are removed.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread. This method removes nothing and returns an error
 *              if the playlist does not exist.
 */
- (NSString *)discardEntriesWithUids:(nullable NSArray<NSString *> *)uids
                 fromPlaylistWithUid:(NSString *)playlistUid
                     completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Cancel the task having the specified handle.
 */
- (void)cancelTaskWithHandle:(NSString *)handle;

@end

NS_ASSUME_NONNULL_END
