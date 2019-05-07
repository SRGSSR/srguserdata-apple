//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylists.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Private interface for implementation purposes.
 */
@interface SRGPlaylists (Private)

- (void)savePlaylistEntryDictionaries:(NSArray<NSDictionary *> *)playlistEntryDictionaries toPlaylistWithUid:(NSString *)playlistUid completionBlock:(void (^)(NSError * _Nullable error))completionBlock;

- (nullable NSArray<SRGPlaylistEntry *> *)playlistEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                                                     sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors;

- (NSString *)playlistEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                         sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                               completionBlock:(void (^)(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error))completionBlock;

@end

NS_ASSUME_NONNULL_END
