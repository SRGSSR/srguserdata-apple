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
 *  Return the suggested name for a system playlist uid, `nil` if none or the uid is unknown.
 */
OBJC_EXPORT NSString * _Nullable SRGPlaylistNameForPlaylistWithUid(NSString *uid);

/**
 *  Watch later playlist uid.
 */
OBJC_EXPORT NSString * const SRGWatchLaterPlaylistUid;

/**
 *  Notification sent when one or more playlists change. Use the keys below to retrieve detailed information from the notification
 *  `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGPlaylistsDidChangeNotification;                   // Notification name.

OBJC_EXPORT NSString * const SRGPlaylistsChangedUidsKey;                          // Key to access the list of playlist uids which have changed as an `NSArray` of `NSString` objects.
OBJC_EXPORT NSString * const SRGPlaylistsPreviousUidsKey;                         // Key to access the previous playlist uid list as an `NSArray` of `NSString` objects.
OBJC_EXPORT NSString * const SRGPlaylistsUidsKey;                                 // Key to access the current playlist uid list as an `NSArray` of `NSString` objects.

/**
 *  Additionnal keys sent in the playlist notification when one or more playlist entries change. Use the key below to
 *  retrieve detailed information from the notification `userInfo` dictionary, and sub keys in each sub dictionnaries.
 */
OBJC_EXPORT NSString * const SRGPlaylistEntryChangesKey;                          // Key to access the list of playlist entry uids which have changed as an `NSDictionnary` of `NSDictionnary` objects, which is a playlist uid to a dictionnary of playlist entry keys.

OBJC_EXPORT NSString * const SRGPlaylistEntryChangedUidsSubKey;                   // Key to access the list of entry uids which have changed as an `NSArray` of `NSString` objects.
OBJC_EXPORT NSString * const SRGPlaylistEntryPreviousUidsSubKey;                  // Key to access the previous entry uid list as an `NSArray` of `NSString` objects.
OBJC_EXPORT NSString * const SRGPlaylistEntryUidsSubKey;                          // Key to access the current entry uid list as an `NSArray` of `NSString` objects.

/**
 *  Notification sent when playlists synchronization has started.
 */
OBJC_EXPORT NSString * const SRGPlaylistsDidStartSynchronizationNotification;

/**
 *  Notification sent when playlists synchronization has finished.
 */
OBJC_EXPORT NSString * const SRGPlaylistsDidFinishSynchronizationNotification;

/**
 *  Manages a local cache for playlists. Playlists are characterized by an identifier, a system flag and a name. Based
 *  on a local cache, this class ensures efficient playlist retrieval from a webservice and keeps local and distant
 *  playlists in sync.
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
 *  Asynchronously save a playlist for a given name and identifier, calling the specified block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread. Attempting to set a name for a system playlist
 *              has no effect.
 */
- (NSString *)savePlaylistForUid:(NSString *)uid
                        withName:(NSString *)name
                 completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously discard playlists matching an identifier in the list, calling the provided block on completion. If no
 *  list is provided, all playlists are discarded, system playlists excepted.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread. Attempting to discard a system playlist has no effect.
 */
- (NSString *)discardPlaylistsWithUids:(nullable NSArray<NSString *> *)uids
                       completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Return playlist entries for a given playlist identifier, optionally matching a specific predicate and / or sorted with
 *  descriptors. If no sort descriptors are provided, entries are still returned in a stable order.
 *
 *  @discussion This method can only be called from the main thread. Reads on other threads must occur asynchronously
 *              with `-entriesFromPlaylistWithUid:matchingPredicate:sortedWithDescriptors:completionBlock:`.
 *              This method returns `nil` if the playlist identifier does not exist.
 */
- (nullable NSArray<SRGPlaylistEntry *> *)entriesFromPlaylistWithUid:(NSString *)playlistUid
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
 *              thread. This method returns `nil` if the playlist identifier does not exist.
 */
- (NSString *)entriesFromPlaylistWithUid:(NSString *)playlistUid
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
- (NSString *)addEntryWithUid:(NSString *)uid
            toPlaylistWithUid:(NSString *)playlistUid
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
- (NSString *)removeEntriesWithUids:(nullable NSArray<NSString *> *)uids
                fromPlaylistWithUid:(NSString *)playlistUid
                    completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Cancel the task having the specified handle.
 */
- (void)cancelTaskWithHandle:(NSString *)handle;

@end

NS_ASSUME_NONNULL_END
