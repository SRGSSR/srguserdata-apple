//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGNetwork/SRGNetwork.h>

NS_ASSUME_NONNULL_BEGIN

// Block signatures.
typedef void (^SRGSRGPlaylistsCompletionBlock)(NSArray<NSDictionary *> * _Nullable playlistsDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGSRGPlaylistPostCompletionBlock)(NSDictionary * _Nullable playlistDictionnary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
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
                                session:(NSURLSession *)session
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
+ (SRGRequest *)deletePlaylistUid:(NSString *)uid
                     toServiceURL:(NSURL *)serviceURL
                  forSessionToken:(NSString *)sessionToken
                      withSession:(NSURLSession *)session
                  completionBlock:(SRGSRGPlaylistDeleteCompletionBlock)completionBlock;
@end

NS_ASSUME_NONNULL_END
