//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistory.h"

#import "SRGDataStore.h"
#import "SRGHistoryEntry+Private.h"
#import "SRGHistoryRequest.h"
#import "SRGUser+Private.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserObject+Private.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGNetwork/SRGNetwork.h>

typedef void (^SRGHistoryPullCompletionBlock)(NSDate * _Nullable serverDate, NSError * _Nullable error);
typedef void (^SRGHistoryPushCompletionBlock)(NSError * _Nullable error);

NSString * const SRGHistoryDidChangeNotification = @"SRGHistoryDidChangeNotification";

NSString * const SRGHistoryChangedUidsKey = @"SRGHistoryChangedUids";
NSString * const SRGHistoryPreviousUidsKey = @"SRGHistoryPreviousUids";
NSString * const SRGHistoryUidsKey = @"SRGHistoryUids";

NSString * const SRGHistoryDidStartSynchronizationNotification = @"SRGHistoryDidStartSynchronizationNotification";
NSString * const SRGHistoryDidFinishSynchronizationNotification = @"SRGHistoryDidFinishSynchronizationNotification";

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
@property (nonatomic, weak) SRGRequest *pushRequest;

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

#pragma mark Data

- (void)saveHistoryEntryDictionaries:(NSArray<NSDictionary *> *)historyEntryDictionaries withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    if (historyEntryDictionaries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    NSMutableArray<NSString *> *changedUids = [NSMutableArray array];
    
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *previousHistoryEntries = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousHistoryEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGHistoryEntry.new, uid)]];
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        for (NSDictionary *historyEntryDictionary in historyEntryDictionaries) {
            SRGHistoryEntry *historyEntry = [SRGHistoryEntry synchronizeWithDictionary:historyEntryDictionary inManagedObjectContext:managedObjectContext];
            if (historyEntry) {
                [changedUids addObject:historyEntry.uid];
                
                if (historyEntry.inserted) {
                    [uids addObject:historyEntry.uid];
                }
                else if (historyEntry.deleted) {
                    [uids removeObject:historyEntry.uid];
                }
            }
        }
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (! error && changedUids.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryChangedUidsKey : [changedUids copy],
                                                                            SRGHistoryPreviousUidsKey : previousUids,
                                                                            SRGHistoryUidsKey : currentUids }];
            });
        }
        completionBlock(error);
    }];
}

#pragma mark Requests

- (void)pullHistoryEntriesForSessionToken:(NSString *)sessionToken
                                afterDate:(NSDate *)date
                           withStartBlock:(void (^)(void))startBlock
                          completionBlock:(SRGHistoryPullCompletionBlock)completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(startBlock);
    NSParameterAssert(completionBlock);
    
    @weakify(self)
    __block SRGFirstPageRequest *firstRequest = [[[SRGHistoryRequest historyUpdatesFromServiceURL:self.serviceURL forSessionToken:sessionToken afterDate:date withDeletedEntries:YES session:self.session completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        @strongify(self)
        
        SRGHistoryPullCompletionBlock pullCompletionBlock = ^(NSDate *serverDate, NSError *error) {
            completionBlock(serverDate, error);
            firstRequest = nil;
        };
        
        if (error) {
            pullCompletionBlock(nil, error);
            return;
        }
        
        [self saveHistoryEntryDictionaries:historyEntryDictionaries withCompletionBlock:^(NSError *error) {
            if (error) {
                pullCompletionBlock(nil, error);
                return;
            }
            
            if (page.number == 0) {
                startBlock();
            }
            
            if (nextPage) {
                SRGPageRequest *nextRequest = [firstRequest requestWithPage:nextPage];
                [nextRequest resume];
                self.pullRequest = nextRequest;
            }
            else {
                pullCompletionBlock(serverDate, nil);
            }
        }];
    }] requestWithPageSize:500] requestWithOptions:SRGNetworkRequestBackgroundThreadCompletionEnabled];
    [firstRequest resume];
    self.pullRequest = firstRequest;
}

- (void)pushHistoryEntries:(NSArray<SRGHistoryEntry *> *)historyEntries
           forSessionToken:(NSString *)sessionToken
       withCompletionBlock:(SRGHistoryPushCompletionBlock)completionBlock
{
    NSParameterAssert(historyEntries);
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    if (historyEntries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    NSMutableDictionary<NSManagedObjectID *, NSDictionary *> *historyEntriesMap = [NSMutableDictionary dictionary];
    for (SRGHistoryEntry *historyEntry in historyEntries) {
        historyEntriesMap[historyEntry.objectID] = historyEntry.dictionary;
    }
    
    SRGRequest *pushRequest = [[SRGHistoryRequest postBatchOfHistoryEntryDictionaries:historyEntriesMap.allValues toServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (! error) {
            [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull mangedObjectContext) {
                for (NSManagedObjectID *historyEntryID in historyEntriesMap.allKeys) {
                    SRGHistoryEntry *historyEntry = [mangedObjectContext existingObjectWithID:historyEntryID error:NULL];
                    [historyEntry updateWithDictionary:historyEntriesMap[historyEntryID]];
                    historyEntry.dirty = NO;
                }
            } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
        } 
        completionBlock(error);
    }] requestWithOptions:SRGNetworkRequestBackgroundThreadCompletionEnabled];
    [pushRequest resume];
    self.pushRequest = pushRequest;
}

#pragma mark Subclassing hooks

- (void)synchronizeWithCompletionBlock:(void (^)(void))completionBlock
{
    NSString *sessionToken = self.identityService.sessionToken;
    
    void (^synchronizationCompletionBlock)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidFinishSynchronizationNotification object:self];
        });
        completionBlock();
    };
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user) {
        [self pullHistoryEntriesForSessionToken:sessionToken afterDate:user.historyServerSynchronizationDate withStartBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidStartSynchronizationNotification object:self];
            });
        } completionBlock:^(NSDate * _Nullable serverDate, NSError * _Nullable pullError) {
            // Remark: We want to save local history even if a pull failed for some reason. A push is threfore attempted
            //         even if the pull failed with an error (only exception: unauthorization received).
            if (! pullError) {
                NSManagedObjectID *userID = user.objectID;
                [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    SRGUser *user = [managedObjectContext existingObjectWithID:userID error:NULL];
                    user.historyServerSynchronizationDate = serverDate;
                } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
            }
            else if (SRGHistoryIsUnauthorizationError(pullError)) {
                [self.identityService reportUnauthorization];
                synchronizationCompletionBlock();
                return;
            }
            
            [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGHistoryEntry.new, dirty)];
                return [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
            } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries) {
                [self pushHistoryEntries:historyEntries forSessionToken:sessionToken withCompletionBlock:^(NSError * _Nullable pushError) {
                    if (! pushError && ! pullError) {
                        NSManagedObjectID *userID = user.objectID;
                        [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                            SRGUser *user = [managedObjectContext existingObjectWithID:userID error:NULL];
                            user.historyLocalSynchronizationDate = NSDate.date;
                        } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
                            synchronizationCompletionBlock();
                        }];
                    }
                    else if (SRGHistoryIsUnauthorizationError(pushError)) {
                        [self.identityService reportUnauthorization];
                        synchronizationCompletionBlock();
                    }
                    else {
                        synchronizationCompletionBlock();
                    }
                }];
            }];
        }];
    }];
}

- (void)userDidLogin
{
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *historyEntries = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        for (SRGHistoryEntry *historyEntry in historyEntries) {
            historyEntry.dirty = YES;
        }
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self synchronize];
        });
    }];
}

- (void)userDidLogout
{
    [self.pullRequest cancel];
    [self.pushRequest cancel];
}

- (void)clearData
{
    __block NSArray<NSString *> *previousUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *historyEntries = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [historyEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGHistoryEntry.new, uid)]];
        [SRGHistoryEntry deleteAllInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (previousUids.count > 0) {
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryChangedUidsKey : previousUids,
                                                                            SRGHistoryPreviousUidsKey : previousUids,
                                                                            SRGHistoryUidsKey : @[] }];
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

- (NSString *)historyEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGHistoryEntry *> * _Nonnull))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (SRGHistoryEntry *)historyEntryWithUid:(NSString *)uid
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry objectWithUid:uid inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)historyEntryWithUid:(NSString *)uid completionBlock:(void (^)(SRGHistoryEntry * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry objectWithUid:uid inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (NSString *)saveHistoryEntryForUid:(NSString *)uid withLastPlaybackTime:(CMTime)lastPlaybackTime deviceUid:(NSString *)deviceUid completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *previousHistoryEntries = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousHistoryEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGHistoryEntry.new, uid)]];
        
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry upsertWithUid:uid inManagedObjectContext:managedObjectContext];
        historyEntry.lastPlaybackTime = lastPlaybackTime;
        historyEntry.deviceUid = deviceUid;
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        if (historyEntry.inserted) {
            [uids addObject:uid];
        }
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryChangedUidsKey : @[uid],
                                                                            SRGHistoryPreviousUidsKey : previousUids,
                                                                            SRGHistoryUidsKey : currentUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSString *)discardHistoryEntriesWithUids:(NSArray<NSString *> *)uids completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSArray<NSString *> *changedUids = nil;
    
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *previousHistoryEntries = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousHistoryEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGHistoryEntry.new, uid)]];
        
        changedUids = [SRGHistoryEntry discardObjectsWithUids:uids inManagedObjectContext:managedObjectContext];
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        [uids removeObjectsInArray:changedUids];
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryChangedUidsKey : changedUids,
                                                                            SRGHistoryPreviousUidsKey : previousUids,
                                                                            SRGHistoryUidsKey : currentUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (void)cancelTaskWithHandle:(NSString *)handle
{
    [self.dataStore cancelBackgroundTaskWithHandle:handle];
}

@end
