//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferencesRequest.h"

@implementation SRGPreferencesRequest

+ (SRGRequest *)preferencesFromServiceURL:(NSURL *)serviceURL
                          forSessionToken:(NSString *)sessionToken
                              withSession:(NSURLSession *)session
                          completionBlock:(SRGPreferencesCompletionBlock)completionBlock
{
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:serviceURL];
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest JSONDictionaryRequestWithURLRequest:URLRequest session:session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(JSONDictionary, HTTPResponse, error);
    }];
}

+ (SRGRequest *)preferenceAtPath:(NSString *)path
                        inDomain:(NSString *)domain
                  fromServiceURL:(NSURL *)serviceURL
                 forSessionToken:(NSString *)sessionToken
                     withSession:(NSURLSession *)session
                 completionBlock:(SRGPreferencesCompletionBlock)completionBlock
{
    NSString *fullPath = [domain stringByAppendingPathComponent:path];
    NSURL *URL = [serviceURL URLByAppendingPathComponent:fullPath];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest JSONDictionaryRequestWithURLRequest:URLRequest session:session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(JSONDictionary, HTTPResponse, error);
    }];
}

+ (SRGRequest *)putPreferenceWithObject:(id)object
                                 atPath:(NSString *)path
                               inDomain:(NSString *)domain
                           toServiceURL:(NSURL *)serviceURL
                        forSessionToken:(NSString *)sessionToken
                            withSession:(NSURLSession *)session
                        completionBlock:(SRGPreferencesPutCompletionBlock)completionBlock
{
    NSString *fullPath = [domain stringByAppendingPathComponent:path];
    NSURL *URL = [serviceURL URLByAppendingPathComponent:fullPath.stringByDeletingLastPathComponent];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"PUT";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    [URLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *JSONDictionary = [NSDictionary dictionaryWithObject:object forKey:fullPath.lastPathComponent];
    URLRequest.HTTPBody = [NSJSONSerialization dataWithJSONObject:JSONDictionary options:0 error:NULL];
    
    return [SRGRequest dataRequestWithURLRequest:URLRequest session:session completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(HTTPResponse, error);
    }];
}

+ (SRGRequest *)deletePreferenceAtPath:(NSString *)path
                              inDomain:(NSString *)domain
                        fromServiceURL:(NSURL *)serviceURL
                       forSessionToken:(NSString *)sessionToken
                           withSession:(NSURLSession *)session
                       completionBlock:(SRGPreferencesDeleteCompletionBlock)completionBlock
{
    NSString *fullPath = path ? [domain stringByAppendingPathComponent:path] : domain;
    NSURL *URL = [serviceURL URLByAppendingPathComponent:fullPath];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"DELETE";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest dataRequestWithURLRequest:URLRequest session:session completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(HTTPResponse, error);
    }];
}

@end
