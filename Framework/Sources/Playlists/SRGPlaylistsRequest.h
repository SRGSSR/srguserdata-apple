//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGNetwork/SRGNetwork.h>

NS_ASSUME_NONNULL_BEGIN

// Block signatures.
typedef void (^SRGPlaylistsCompletionBlock)(NSArray<NSDictionary *> * _Nullable playlistDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGPlaylistPostCompletionBlock)(NSDictionary * _Nullable playlistDictionary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGPlaylistEntriesCompletionBlock)(NSArray<NSDictionary *> * _Nullable playlistEntryDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGPlaylistDeleteCompletionBlock)(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);

/**
 *  Low-level requests of the playlists service.
 */
@interface SRGPlaylistsRequest : NSObject

/**
 *  Retrieve playlists.
 */
+ (SRGRequest *)playlistsFromServiceURL:(NSURL *)serviceURL
                        forSessionToken:(NSString *)sessionToken
                            withSession:(NSURLSession *)session
                        completionBlock:(SRGPlaylistsCompletionBlock)completionBlock;

/**
 *  Submit a playlist.
 */
+ (SRGRequest *)postPlaylistDictionary:(NSDictionary *)dictionary
                          toServiceURL:(NSURL *)serviceURL
                       forSessionToken:(NSString *)sessionToken
                           withSession:(NSURLSession *)session
                       completionBlock:(SRGPlaylistPostCompletionBlock)completionBlock;

/**
 *  Delete a playlist.
 */
+ (SRGRequest *)deletePlaylistWithUid:(NSString *)uid
                       fromServiceURL:(NSURL *)serviceURL
                      forSessionToken:(NSString *)sessionToken
                          withSession:(NSURLSession *)session
                      completionBlock:(SRGPlaylistDeleteCompletionBlock)completionBlock;

/**
 *  Retrieve entries for the specified playlist.
 */
+ (SRGRequest *)entriesForPlaylistWithUid:(NSString *)playlistUid
                           fromServiceURL:(NSURL *)serviceURL
                          forSessionToken:(NSString *)sessionToken
                              withSession:(NSURLSession *)session
                          completionBlock:(SRGPlaylistEntriesCompletionBlock)completionBlock;

/**
 *  Update entries for the specified playlist.
 */
+ (SRGRequest *)putPlaylistEntryDictionaries:(NSArray<NSDictionary *> *)dictionaries
                          forPlaylistWithUid:(NSString *)playlistUid
                                toServiceURL:(NSURL *)serviceURL
                             forSessionToken:(NSString *)sessionToken
                                 withSession:(NSURLSession *)session
                             completionBlock:(SRGPlaylistEntriesCompletionBlock)completionBlock;

/**
 *  Update entries for the specified playlist.
 */
+ (SRGRequest *)deletePlaylistEntriesWithUids:(nullable NSArray<NSString *> *)uids
                           forPlaylistWithUid:(NSString *)playlistUid
                               fromServiceURL:(NSURL *)serviceURL
                              forSessionToken:(NSString *)sessionToken
                                  withSession:(NSURLSession *)session
                              completionBlock:(SRGPlaylistDeleteCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
