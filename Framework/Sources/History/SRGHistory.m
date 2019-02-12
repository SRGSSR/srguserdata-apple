//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistory.h"

#import "SRGDataStore.h"
#import "SRGHistoryEntry+Private.h"
#import "SRGUser+Private.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserObject+Private.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGNetwork/SRGNetwork.h>

typedef void (^SRGHistoryUpdatesCompletionBlock)(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGHistoryPullCompletionBlock)(NSDate * _Nullable serverDate, NSError * _Nullable error);

NSString * const SRGHistoryDidChangeNotification = @"SRGHistoryDidChangeNotification";
NSString * const SRGHistoryUidsKey = @"SRGHistoryUidsKey";

NSString * const SRGHistoryDidStartSynchronizationNotification = @"SRGHistoryDidStartSynchronizationNotification";
NSString * const SRGHistoryDidFinishSynchronizationNotification = @"SRGHistoryDidFinishSynchronizationNotification";
NSString * const SRGHistoryDidClearNotification = @"SRGHistoryDidClearNotification";

static BOOL SRGHistoryIsUnauthorizationError(NSError *error)
{
    if ([error.domain isEqualToString:SRGNetworkErrorDomain] && error.code == SRGNetworkErrorMultiple) {
        NSArray<NSError *> *errors = error.userInfo[SRGNetworkErrorsKey];
        for (NSError *error in errors) {
            if (SRGHistoryIsUnauthorizationError(error)) {
                return YES;
            }
        }
        return NO;
    }
    else {
        return [error.domain isEqualToString:SRGNetworkErrorDomain] && error.code == SRGNetworkErrorHTTP && [error.userInfo[SRGNetworkHTTPStatusCodeKey] integerValue] == 401;
    }
}

@interface SRGHistory ()

@property (nonatomic, weak) SRGPageRequest *pullRequest;
@property (nonatomic) SRGRequestQueue *pushRequestQueue;

@property (nonatomic) NSURLSession *session;

@end;

@implementation SRGHistory

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super initWithServiceURL:serviceURL identityService:identityService dataStore:dataStore]) {
        self.session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    }
    return self;
}

#pragma clang diagnostic pop

#pragma mark Requests

- (SRGFirstPageRequest *)historyUpdatesForSessionToken:(NSString *)sessionToken
                                             afterDate:(NSDate *)date
                                   withCompletionBlock:(SRGHistoryUpdatesCompletionBlock)completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    NSURL *URL = [self.serviceURL URLByAppendingPathComponent:@"historyapi/v2"];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    
    NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"with_deleted" value:@"true"]];
    if (date) {
        NSTimeInterval timestamp = round(date.timeIntervalSince1970 * 1000.);
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"after" value:@(timestamp).stringValue]];
    }
    URLComponents.queryItems = [queryItems copy];
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URLComponents.URL];
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGFirstPageRequest JSONDictionaryRequestWithURLRequest:URLRequest session:self.session sizer:^NSURLRequest *(NSURLRequest * _Nonnull URLRequest, NSUInteger size) {
        NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URLRequest.URL resolvingAgainstBaseURL:NO];
        NSMutableArray<NSURLQueryItem *> *queryItems = URLComponents.queryItems ? [NSMutableArray arrayWithArray:URLComponents.queryItems]: [NSMutableArray array];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K != %@", @keypath(NSURLQueryItem.new, name), @"limit"];
        [queryItems filterUsingPredicate:predicate];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"limit" value:@(size).stringValue]];
        URLComponents.queryItems = [queryItems copy];
        
        NSMutableURLRequest *request = [URLRequest mutableCopy];
        request.URL = URLComponents.URL;
        return [request copy];
    } paginator:^NSURLRequest * _Nullable(NSURLRequest * _Nonnull URLRequest, NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSUInteger size, NSUInteger number) {
        NSString *nextURLComponent = JSONDictionary[@"next"];
        NSString *nextURLString = nextURLComponent ? [URL.absoluteString stringByAppendingString:nextURLComponent] : nil;
        NSURL *nextURL = nextURLString ? [NSURL URLWithString:nextURLString] : nil;
        if (nextURL) {
            NSMutableURLRequest *request = [URLRequest mutableCopy];
            request.URL = nextURL;
            return [request copy];
        }
        else {
            return nil;
        };
    } completionBlock:^(NSDictionary * _Nullable JSONDictionary, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSNumber *serverTimestamp = JSONDictionary[@"last_update"];
        NSDate *serverDate = serverTimestamp ? [NSDate dateWithTimeIntervalSince1970:serverTimestamp.doubleValue / 1000.] : nil;
        completionBlock(JSONDictionary[@"data"], serverDate, page, nextPage, HTTPResponse, error);
    }];
}

- (void)pullHistoryEntriesForSessionToken:(NSString *)sessionToken
                                afterDate:(NSDate *)date
                          completionBlock:(SRGHistoryPullCompletionBlock)completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    @weakify(self)
    __block SRGFirstPageRequest*firstRequest = [[[self historyUpdatesForSessionToken:sessionToken afterDate:date withCompletionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        @strongify(self)
        
        if (error) {
            completionBlock(nil, error);
            return;
        }
        
        if (historyEntryDictionaries.count != 0) {
            NSMutableArray<NSString *> *uids = [NSMutableArray array];
            [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
                for (NSDictionary *historyEntryDictionary in historyEntryDictionaries) {
                    NSString *uid = [SRGHistoryEntry synchronizeWithDictionary:historyEntryDictionary inManagedObjectContext:managedObjectContext];
                    if (uid) {
                        [uids addObject:uid];
                    }
                }
                return YES;
            } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        return;
                    }
                    
                    if (page.number == 0) {
                        [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidStartSynchronizationNotification object:self];
                    }
                    
                    if (uids.count > 0) {
                        [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                          object:self
                                                                        userInfo:@{ SRGHistoryUidsKey : [uids copy] }];
                    }
                });
            }];
        }
        else if (page.number == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidStartSynchronizationNotification object:self];
            });
        }
        
        if (nextPage) {
            SRGPageRequest *nextRequest = [firstRequest requestWithPage:nextPage];
            [nextRequest resume];
            self.pullRequest = nextRequest;
        }
        else {
            completionBlock(serverDate, nil);
        }
    }] requestWithPageSize:100] requestWithOptions:SRGNetworkRequestBackgroundThreadCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
    [firstRequest resume];
    self.pullRequest = firstRequest;
}

- (SRGRequest *)pushHistoryEntry:(SRGHistoryEntry *)historyEntry
                 forSessionToken:(NSString *)sessionToken
             withCompletionBlock:(void (^)(NSHTTPURLResponse * _Nonnull HTTPResponse, NSError * _Nullable error))completionBlock
{
    NSParameterAssert(historyEntry);
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    NSURL *URL = [self.serviceURL URLByAppendingPathComponent:@"historyapi/v2"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:historyEntry.dictionary options:0 error:NULL];
    
    NSManagedObjectID *historyEntryID = historyEntry.objectID;
    return [SRGRequest JSONDictionaryRequestWithURLRequest:request session:self.session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        if (! error) {
            [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull mangedObjectContext) {
                SRGHistoryEntry *historyEntry = [mangedObjectContext existingObjectWithID:historyEntryID error:NULL];
                if (JSONDictionary) {
                    [historyEntry updateWithDictionary:JSONDictionary];
                }
                historyEntry.dirty = NO;
                return YES;
            } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
        }
        completionBlock(HTTPResponse, error);
    }];
}

- (void)pushHistoryEntries:(NSArray<SRGHistoryEntry *> *)historyEntries
           forSessionToken:(NSString *)sessionToken
       withCompletionBlock:(void (^)(NSError * _Nullable error))completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    if (historyEntries.count == 0) {
        completionBlock(nil);
    }
    
    self.pushRequestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        if (finished) {
            completionBlock(error);
        }
    }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
    
    for (SRGHistoryEntry *historyEntry in historyEntries) {
        SRGRequest *request = [[self pushHistoryEntry:historyEntry forSessionToken:sessionToken withCompletionBlock:^(NSHTTPURLResponse * _Nonnull HTTPResponse, NSError * _Nullable error) {
            [self.pushRequestQueue reportError:error];
        }] requestWithOptions:SRGNetworkRequestBackgroundThreadCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
        [self.pushRequestQueue addRequest:request resume:NO /* see below */];
    }
    
    // TODO: Temporary workaround to SRG Network not being thread safe. Attempting to add & start requests leads
    //       to an concurrent resource in SRG Network, which we can avoided by starting all requests at once.
    // FIXME: We should fix the issue by copying the list which gets enumerated instead. This is not perfect thread-safety,
    //        but will be better until we properly implement it.
    [self.pushRequestQueue resume];
}

#pragma mark Subclassing hooks

- (void)synchronizeWithCompletionBlock:(void (^)(void))completionBlock
{
    NSString *sessionToken = self.identityService.sessionToken;
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user) {
        [self pullHistoryEntriesForSessionToken:sessionToken afterDate:user.historyServerSynchronizationDate completionBlock:^(NSDate * _Nullable serverDate, NSError * _Nullable pullError) {
            if (! pullError) {
                NSManagedObjectID *userID = user.objectID;
                [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    SRGUser *user = [managedObjectContext existingObjectWithID:userID error:NULL];
                    user.historyServerSynchronizationDate = serverDate;
                    return YES;
                } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
            }
            else if (SRGHistoryIsUnauthorizationError(pullError)) {
                [self.identityService reportUnauthorization];
                completionBlock();
                return;
            }
            
            [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGHistoryEntry.new, dirty)];
                return [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
            } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries) {
                [self pushHistoryEntries:historyEntries forSessionToken:sessionToken withCompletionBlock:^(NSError * _Nullable pushError) {
                    completionBlock();
                    
                    if (SRGHistoryIsUnauthorizationError(pushError)) {
                        [self.identityService reportUnauthorization];
                    }
                    else if (! pushError && ! pullError) {
                        NSManagedObjectID *userID = user.objectID;
                        [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
                            SRGUser *user = [managedObjectContext existingObjectWithID:userID error:NULL];
                            user.historyLocalSynchronizationDate = NSDate.date;
                            return YES;
                        } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
                            if (! error) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidFinishSynchronizationNotification object:self];
                                });
                            }
                        }];
                    }
                }];
            }];
        }];
    }];
}

- (void)userDidLogin
{
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *historyEntries = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        for (SRGHistoryEntry *historyEntry in historyEntries) {
            historyEntry.dirty = YES;
        }
        return YES;
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self synchronize];
        });
    }];
}

- (void)userDidLogout
{
    [self.pullRequest cancel];
    [self.pushRequestQueue cancel];
}

- (void)clearData
{
    __block NSSet<NSString *> *uids = nil;
    
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *historyEntries = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        uids = [historyEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGHistoryEntry.new, uid)]];
        
        [SRGHistoryEntry deleteAllInManagedObjectContext:managedObjectContext];
        return YES;
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (uids.count > 0) {
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryUidsKey : uids.allObjects }];
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidClearNotification
                                                                  object:self
                                                                userInfo:nil];
            }
        });
    }];
}

#pragma mark Reads and writes

- (NSArray<SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    }];
}

- (void)historyEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGHistoryEntry *> * _Nonnull))completionBlock
{
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (SRGHistoryEntry *)historyEntryWithUid:(NSString *)uid
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry objectWithUid:uid inManagedObjectContext:managedObjectContext];
    }];
}

- (void)historyEntryWithUid:(NSString *)uid completionBlock:(void (^)(SRGHistoryEntry * _Nullable))completionBlock
{
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry objectWithUid:uid inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (void)saveHistoryEntryForUid:(NSString *)uid withLastPlaybackTime:(CMTime)lastPlaybackTime deviceUid:(NSString *)deviceUid completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry upsertWithUid:uid inManagedObjectContext:managedObjectContext];
        historyEntry.lastPlaybackTime = lastPlaybackTime;
        historyEntry.deviceUid = deviceUid;
        return YES;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryUidsKey : @[ uid ] }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (void)discardHistoryEntriesWithUids:(NSArray<NSString *> *)uids completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSArray<NSString *> *discardedUids = nil;
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        discardedUids = [SRGHistoryEntry discardObjectsWithUids:uids inManagedObjectContext:managedObjectContext];
        return YES;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryUidsKey : discardedUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

@end
