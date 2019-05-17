//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGNetwork/SRGNetwork.h>

NS_ASSUME_NONNULL_BEGIN

// Block signatures.
typedef void (^SRGPreferenceDomainsCompletionBlock)(NSArray<NSString *> * _Nullable domains, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGPreferencesCompletionBlock)(NSDictionary * _Nullable dictionary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGPreferencesPutCompletionBlock)(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGPreferencesDeleteCompletionBlock)(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);

/**
 *  Low-level requests of the preferences service.
 */
@interface SRGPreferencesRequest : NSObject

/**
 *  List all available preferences domain.
 */
+ (SRGRequest *)domainsFromServiceURL:(NSURL *)serviceURL
                      forSessionToken:(NSString *)sessionToken
                          withSession:(NSURLSession *)session
                      completionBlock:(SRGPreferenceDomainsCompletionBlock)completionBlock;

/**
 *  Retrieve preferences at a specific path in a domain.
 */
+ (SRGRequest *)preferencesAtPath:(nullable NSString *)path
                         inDomain:(NSString *)domain
                   fromServiceURL:(NSURL *)serviceURL
                  forSessionToken:(NSString *)sessionToken
                      withSession:(NSURLSession *)session
                  completionBlock:(SRGPreferencesCompletionBlock)completionBlock;

/**
 *  Create or update a preference at a specific path in a domain.
 *
 *  @discussion Only strings, numbers and JSON-serializable objects are supported.
 */
+ (SRGRequest *)putPreferenceWithObject:(id)object
                                 atPath:(NSString *)path
                               inDomain:(NSString *)domain
                           toServiceURL:(NSURL *)serviceURL
                        forSessionToken:(NSString *)sessionToken
                            withSession:(NSURLSession *)session
                        completionBlock:(SRGPreferencesPutCompletionBlock)completionBlock;

/**
 *  Delete a preference at a specific path in a domain.
 */
+ (SRGRequest *)deletePreferenceAtPath:(nullable NSString *)path
                              inDomain:(NSString *)domain
                        fromServiceURL:(NSURL *)serviceURL
                       forSessionToken:(NSString *)sessionToken
                           withSession:(NSURLSession *)session
                       completionBlock:(SRGPreferencesDeleteCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
