//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGNetwork/SRGNetwork.h>

NS_ASSUME_NONNULL_BEGIN

// Block signatures.
typedef void (^SRGSRGPlaylistsCompletionBlock)(NSArray<NSDictionary *> * _Nullable playlistDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGSRGPlaylistPostCompletionBlock)(NSDictionary * _Nullable playlistDictionnary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGSRGPlaylistEntriesCompletionBlock)(NSArray<NSDictionary *> * _Nullable playlistEntryDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGSRGPlaylistDeleteCompletionBlock)(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);

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
                        completionBlock:(SRGSRGPlaylistsCompletionBlock)completionBlock;

/**
 *  Submit a playlist.
 */
+ (SRGRequest *)postPlaylistDictionary:(NSDictionary *)dictionary
                          toServiceURL:(NSURL *)serviceURL
                       forSessionToken:(NSString *)sessionToken
                           withSession:(NSURLSession *)session
                       completionBlock:(SRGSRGPlaylistPostCompletionBlock)completionBlock;

/**
 *  Delete a playlist.
 */
+ (SRGRequest *)deletePlaylistWithUid:(NSString *)uid
                       fromServiceURL:(NSURL *)serviceURL
                      forSessionToken:(NSString *)sessionToken
                          withSession:(NSURLSession *)session
                      completionBlock:(SRGSRGPlaylistDeleteCompletionBlock)completionBlock;

/**
 *  Retrieve entries for the specified playlist.
 */
+ (SRGRequest *)entriesForPlaylistWithUid:(NSString *)playlistUid
                           fromServiceURL:(NSURL *)serviceURL
                          forSessionToken:(NSString *)sessionToken
                              withSession:(NSURLSession *)session
                          completionBlock:(SRGSRGPlaylistEntriesCompletionBlock)completionBlock;

/**
 *  Update entries for the specified playlist.
 */
+ (SRGRequest *)putPlaylistEntryDictionaries:(NSArray<NSDictionary *> *)dictionaries
                          forPlaylistWithUid:(NSString *)playlistUid
                                toServiceURL:(NSURL *)serviceURL
                             forSessionToken:(NSString *)sessionToken
                                 withSession:(NSURLSession *)session
                             completionBlock:(SRGSRGPlaylistEntriesCompletionBlock)completionBlock;

/**
 *  Update entries for the specified playlist.
 */
+ (SRGRequest *)deletePlaylistEntriesWithUids:(nullable NSArray<NSString *> *)uids
                           forPlaylistWithUid:(NSString *)playlistUid
                               fromServiceURL:(NSURL *)serviceURL
                              forSessionToken:(NSString *)sessionToken
                                  withSession:(NSURLSession *)session
                              completionBlock:(SRGSRGPlaylistDeleteCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
