//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGNetwork/SRGNetwork.h>

NS_ASSUME_NONNULL_BEGIN

// Block signatures.
typedef void (^SRGPreferencesCompletionBlock)(NSDictionary * _Nullable preferencesDictionary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGPreferencesPutCompletionBlock)(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGPreferencesDeleteCompletionBlock)(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);

@interface SRGPreferencesRequest : NSObject

+ (SRGRequest *)preferencesFromServiceURL:(NSURL *)serviceURL
                          forSessionToken:(NSString *)sessionToken
                              withSession:(NSURLSession *)session
                          completionBlock:(SRGPreferencesCompletionBlock)completionBlock;

+ (SRGRequest *)preferenceAtKeyPath:(NSString *)keyPath
                           inDomain:(NSString *)domain
                     fromServiceURL:(NSURL *)serviceURL
                    forSessionToken:(NSString *)sessionToken
                        withSession:(NSURLSession *)session
                    completionBlock:(SRGPreferencesCompletionBlock)completionBlock;

+ (SRGRequest *)putPreferenceWithObject:(id)object
                              atKeyPath:(NSString *)keyPath
                               inDomain:(NSString *)domain
                           toServiceURL:(NSURL *)serviceURL
                        forSessionToken:(NSString *)sessionToken
                            withSession:(NSURLSession *)session
                        completionBlock:(SRGPreferencesPutCompletionBlock)completionBlock;

+ (SRGRequest *)deletePreferenceAtKeyPath:(NSString *)keyPath
                                 inDomain:(NSString *)domain
                           fromServiceURL:(NSURL *)serviceURL
                          forSessionToken:(NSString *)sessionToken
                              withSession:(NSURLSession *)session
                          completionBlock:(SRGPreferencesDeleteCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
