//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylistsRequest.h"

#import <libextobjc/libextobjc.h>

@implementation SRGPlaylistsRequest

+ (SRGRequest *)playlistsFromServiceURL:(NSURL *)serviceURL
                        forSessionToken:(NSString *)sessionToken
                            withSession:(NSURLSession *)session
                        completionBlock:(SRGSRGPlaylistsCompletionBlock)completionBlock
{
    NSURL *URL = [serviceURL URLByAppendingPathComponent:@"v3"];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URLComponents.URL];
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest JSONDictionaryRequestWithURLRequest:URLRequest session:session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(JSONDictionary[@"playlists"], HTTPResponse, error);
    }];
}

+ (SRGRequest *)postPlaylistDictionary:(NSDictionary *)dictionary
                          toServiceURL:(NSURL *)serviceURL
                       forSessionToken:(NSString *)sessionToken
                           withSession:(NSURLSession *)session
                       completionBlock:(SRGSRGPlaylistPostCompletionBlock)completionBlock
{
    NSAssert(dictionary[@"businessId"] != nil, @"A business identifier is required");
    
    NSURL *URL = [[serviceURL URLByAppendingPathComponent:@"v3"] URLByAppendingPathComponent:dictionary[@"businessId"]];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URLComponents.URL];
    URLRequest.HTTPMethod = @"POST";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    [URLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    URLRequest.HTTPBody = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
    
    return [SRGRequest JSONDictionaryRequestWithURLRequest:URLRequest session:session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(JSONDictionary, HTTPResponse, error);
    }];
}

+ (SRGRequest *)deletePlaylistWithUid:(NSString *)uid
                       fromServiceURL:(NSURL *)serviceURL
                      forSessionToken:(NSString *)sessionToken
                          withSession:(NSURLSession *)session
                      completionBlock:(SRGSRGPlaylistDeleteCompletionBlock)completionBlock
{
    NSURL *URL = [[serviceURL URLByAppendingPathComponent:@"v3"] URLByAppendingPathComponent:uid];
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"DELETE";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest dataRequestWithURLRequest:URLRequest session:session completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(HTTPResponse, error);
    }];
}

@end
