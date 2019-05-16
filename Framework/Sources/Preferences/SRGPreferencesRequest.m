//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferencesRequest.h"

static NSNumberFormatter *SRGLocaleIndependentNumberFormatter(void)
{
    static dispatch_once_t s_onceToken;
    static NSNumberFormatter *s_numberFormatter;
    dispatch_once(&s_onceToken, ^{
        s_numberFormatter = [[NSNumberFormatter alloc] init];
        s_numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        s_numberFormatter.usesGroupingSeparator = NO;
        s_numberFormatter.decimalSeparator = @".";
    });
    return s_numberFormatter;
}

@implementation SRGPreferencesRequest

+ (SRGRequest *)domainsFromServiceURL:(NSURL *)serviceURL
                      forSessionToken:(NSString *)sessionToken
                          withSession:(NSURLSession *)session
                      completionBlock:(SRGPreferenceDomainsCompletionBlock)completionBlock
{
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:serviceURL];
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest JSONArrayRequestWithURLRequest:URLRequest session:session completionBlock:^(NSArray * _Nullable JSONArray, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(JSONArray, HTTPResponse, error);
    }];
}

+ (SRGRequest *)preferencesAtPath:(NSString *)path
                         inDomain:(NSString *)domain
                   fromServiceURL:(NSURL *)serviceURL
                  forSessionToken:(NSString *)sessionToken
                      withSession:(NSURLSession *)session
                  completionBlock:(SRGPreferencesCompletionBlock)completionBlock
{
    NSString *fullPath = path ? [domain stringByAppendingPathComponent:path] : domain;
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
    NSURL *URL = [serviceURL URLByAppendingPathComponent:fullPath];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"PUT";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    // FIXME: For the request to work the content type must currently always be JSON (this is a known server bug). When
    //        the bug has been fixed, provide correct content types
    [URLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    if ([NSJSONSerialization isValidJSONObject:object]) {
        URLRequest.HTTPBody = [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    }
    else if ([object isKindOfClass:NSString.class]) {
        NSString *bodyString = [NSString stringWithFormat:@"\"%@\"", object];
        URLRequest.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    }
    else if ([object isKindOfClass:NSNumber.class]) {
        NSString *numberString = [SRGLocaleIndependentNumberFormatter() stringFromNumber:object];
        URLRequest.HTTPBody = [numberString dataUsingEncoding:NSUTF8StringEncoding];
    }
    else {
        NSAssert(NO, @"Only types appearing in a JSON are supported");
    }
    
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
