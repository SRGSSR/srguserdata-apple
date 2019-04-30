//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistory.h"

#import "NSArray+SRGUserData.h"
#import "NSBundle+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGHistoryEntry+Private.h"
#import "SRGHistoryRequest.h"
#import "SRGUser+Private.h"
#import "SRGUserDataError+Private.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserObject+Private.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGNetwork/SRGNetwork.h>

NSString * const SRGHistoryDidChangeNotification = @"SRGHistoryDidChangeNotification";

NSString * const SRGHistoryChangedUidsKey = @"SRGHistoryChangedUids";
NSString * const SRGHistoryPreviousUidsKey = @"SRGHistoryPreviousUids";
NSString * const SRGHistoryUidsKey = @"SRGHistoryUids";

NSString * const SRGHistoryDidStartSynchronizationNotification = @"SRGHistoryDidStartSynchronizationNotification";
NSString * const SRGHistoryDidFinishSynchronizationNotification = @"SRGHistoryDidFinishSynchronizationNotification";

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
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    }
    return self;
}

#pragma mark Data

- (void)saveHistoryEntryDictionaries:(NSArray<NSDictionary *> *)historyEntryDictionaries withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    NSMutableArray<NSString *> *changedUids = [NSMutableArray array];
    
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *previousHistoryEntries = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        
        if (historyEntryDictionaries.count == 0) {
            return;
        }
        
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
                      withCompletionBlock:(void (^)(NSDate *serverDate, NSError *error))completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    @weakify(self)
    __block SRGFirstPageRequest *firstRequest = [[[SRGHistoryRequest historyUpdatesFromServiceURL:self.serviceURL forSessionToken:sessionToken afterDate:date withDeletedEntries:YES session:self.session completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        @strongify(self)
        
        void (^pullCompletionBlock)(NSDate *, NSError *) = ^(NSDate *serverDate, NSError *error) {
            completionBlock(serverDate, error);
            firstRequest = nil;
        };
        
        if (error) {
            if (SRGUserDataIsUnauthorizationError(error)) {
                [self.identityService reportUnauthorization];
            }
            pullCompletionBlock(nil, error);
            return;
        }
        
        [self saveHistoryEntryDictionaries:historyEntryDictionaries withCompletionBlock:^(NSError *error) {
            if (error) {
                pullCompletionBlock(nil, error);
                return;
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
    }] requestWithPageSize:500] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
    [firstRequest resume];
    self.pullRequest = firstRequest;
}

- (void)pushHistoryEntries:(NSArray<SRGHistoryEntry *> *)historyEntries
           forSessionToken:(NSString *)sessionToken
       withCompletionBlock:(void (^)(NSError *error))completionBlock
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
        if (error) {
            if (SRGUserDataIsUnauthorizationError(error)) {
                [self.identityService reportUnauthorization];
            }
            completionBlock(error);
            return;
        }
        
        [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
            for (NSManagedObjectID *historyEntryID in historyEntriesMap.allKeys) {
                SRGHistoryEntry *historyEntry = [managedObjectContext existingObjectWithID:historyEntryID error:NULL];
                if (historyEntry.discarded) {
                    [managedObjectContext deleteObject:historyEntry];
                }
                else {
                    [historyEntry updateWithDictionary:historyEntriesMap[historyEntryID]];
                    historyEntry.dirty = NO;
                }
            }
        } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
            completionBlock(error);
        }];
    }] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
    [pushRequest resume];
    self.pushRequest = pushRequest;
}

#pragma mark Subclassing hooks

- (void)synchronizeWithCompletionBlock:(void (^)(void))completionBlock
{
    NSString *sessionToken = self.identityService.sessionToken;
    
    void (^finishSynchronization)(NSError *error) = ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            
            if (error) {
                NSError *friendlyError = [NSError errorWithDomain:SRGUserDataErrorDomain
                                                             code:SRGUserDataErrorFailed
                                                         userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"History synchronization has failed.", @"Error message returned when history synchronization failed for some reason"),
                                                                     NSUnderlyingErrorKey : error }];
                userInfo[NSUnderlyingErrorKey] = friendlyError;
            }
            
            [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidFinishSynchronizationNotification object:self userInfo:[userInfo copy]];
        });
        
        completionBlock();
    };
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidStartSynchronizationNotification object:self];
    });
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGHistoryEntry.new, dirty)];
        return [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries, NSError * _Nullable error) {
        if (error) {
            finishSynchronization(error);
            return;
        }
        
        [self pushHistoryEntries:historyEntries forSessionToken:sessionToken withCompletionBlock:^(NSError *error) {
            if (error) {
                finishSynchronization(error);
                return;
            }
            
            [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                return [SRGUser userInManagedObjectContext:managedObjectContext];
            } withPriority:NSOperationQueuePriorityLow completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
                if (error) {
                    finishSynchronization(error);
                    return;
                }
                
                NSManagedObjectID *userID = user.objectID;
                [self pullHistoryEntriesForSessionToken:sessionToken afterDate:user.historySynchronizationDate withCompletionBlock:^(NSDate * _Nullable serverDate, NSError * _Nullable error) {
                    if (error) {
                        finishSynchronization(error);
                        return;
                    }
                    
                    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                        SRGUser *user = [managedObjectContext existingObjectWithID:userID error:NULL];
                        user.historySynchronizationDate = serverDate;
                    } withPriority:NSOperationQueuePriorityLow completionBlock:finishSynchronization];
                }];
            }];
        }];
    }];
}

- (void)cancelSynchronization
{
    [self.pullRequest cancel];
    [self.pushRequest cancel];
}

- (NSArray<SRGUserObject *> *)userObjectsInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    return [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
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

- (NSString *)historyEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGHistoryEntry *> * _Nullable, NSError * _Nullable))completionBlock
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

- (NSString *)historyEntryWithUid:(NSString *)uid completionBlock:(void (^)(SRGHistoryEntry * _Nullable, NSError * _Nullable))completionBlock
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
        
        currentUids = [previousUids srguserdata_arrayByRemovingObjectsInArray:changedUids];
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
