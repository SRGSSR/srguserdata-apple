//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylistEntry.h"
#import "SRGUserDataService.h"

NS_ASSUME_NONNULL_BEGIN

OBJC_EXPORT NSString * const SRGSystemPlaylistWatchItLaterUid;                    // Watch it later unique id playlist

/**
 *  Notification sent when one or more playlists change. Use the keys below to retrieve detailed information from the notification
 *  `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGPlaylistDidChangeNotification;                    // Notification name.

OBJC_EXPORT NSString * const SRGPlaylistChangedUidsKey;                           // Key to access the list of uids which have changed as an `NSArray` of `NSString` objects.
OBJC_EXPORT NSString * const SRGPlaylistPreviousUidsKey;                          // Key to access the previous uid list as an `NSArray` of `NSString` objects.
OBJC_EXPORT NSString * const SRGPlaylistUidsKey;                                  // Key to access the current uid list as an `NSArray` of `NSString` objects.

/**
 *  Notification sent when playlist synchronization has started.
 */
OBJC_EXPORT NSString * const SRGPlaylistDidStartSynchronizationNotification;

/**
 *  Notification sent when playlist synchronization has finished.
 */
OBJC_EXPORT NSString * const SRGPlaylistDidFinishSynchronizationNotification;

/**
 *  Manages a local cache for playlist entries. Playlist entries are characterized by an identifier, a system flag and
 *  a name. Based on a local cache, this class ensures efficient playlist retrieval from a webservice and keeps local and
 *  distant playlists in sync.
 *
 *  You can register for playlist update notifications, see above. These will be sent by the `SRGPlaylist` instance
 *  itself.
 */
@interface SRGPlaylist : SRGUserDataService

/**
 *  Return the playlist entry matching the specified identifier, if any.
 *
 *  @discussion This method can only be called from the main thread.
 */
- (nullable SRGPlaylistEntry *)playlistEntryWithUid:(NSString *)uid;

/**
 *  Return the playlist entry matching the specified identifier, if any. The read occurs asynchronously, calling the
 *  provided block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error.
 *
 *  @discussion The completion block is called on a background thread. You can only use the returned object on this
 *              thread.
 */
- (NSString *)playlistEntryWithUid:(NSString *)uid completionBlock:(void (^)(SRGPlaylistEntry * _Nullable playlistEntry, NSError * _Nullable error))completionBlock;

/**
 *  Asynchronously save a playlist entry for a given name, calling the specified block on completion.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion The completion block is called on a background thread.
 *              Set aname to a system playlist has no effect.
 */
- (NSString *)savePlaylistEntryForUid:(NSString *)uid
                             withName:(NSString *)name
                     completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Cancel the task having the specified handle.
 */
- (void)cancelTaskWithHandle:(NSString *)handle;

@end

NS_ASSUME_NONNULL_END
