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

- (void)savePlaylistEntryDictionaries:(NSArray<NSDictionary *> *)playlistEntryDictionaries toPlaylistWithUid:(NSString *)playlistUid completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

@end

NS_ASSUME_NONNULL_END
