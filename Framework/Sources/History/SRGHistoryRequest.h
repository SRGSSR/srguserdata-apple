//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGNetwork/SRGNetwork.h>

NS_ASSUME_NONNULL_BEGIN

// Block signatures.
typedef void (^SRGHistoryUpdatesCompletionBlock)(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGHistoryPostCompletionBlock)(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);

/**
 *  Low-level requests of the history service.
 */
@interface SRGHistoryRequest : NSObject

/**
 *  Retrieve history updates.
 */
+ (SRGFirstPageRequest *)historyUpdatesFromServiceURL:(NSURL *)serviceURL
                                      forSessionToken:(NSString *)sessionToken
                                            afterDate:(NSDate *)date
                                          withSession:(NSURLSession *)session
                                      completionBlock:(SRGHistoryUpdatesCompletionBlock)completionBlock;

/**
 *  Submit a new history entry.
 */
+ (SRGRequest *)postHistoryEntryDictionary:(NSDictionary *)dictionary
                              toServiceURL:(NSURL *)serviceURL
                           forSessionToken:(NSString *)sessionToken
                               withSession:(NSURLSession *)session
                           completionBlock:(SRGHistoryPostCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
