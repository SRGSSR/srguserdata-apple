//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylist.h"

#import "NSBundle+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGPlaylistEntry+Private.h"
#import "SRGUser+Private.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserObject+Private.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGNetwork/SRGNetwork.h>

typedef void (^SRGPlaylistPullCompletionBlock)(NSDate * _Nullable serverDate, NSError * _Nullable error);
typedef void (^SRGPlaylistPushCompletionBlock)(NSError * _Nullable error);

NSString * const SRGSystemPlaylistWatchItLaterUid = @"watch_it_later";

NSString * const SRGPlaylistDidChangeNotification = @"SRGPlaylistDidChangeNotification";

NSString * const SRGPlaylistChangedUidsKey = @"SRGPlaylistChangedUids";
NSString * const SRGPlaylistPreviousUidsKey = @"SRGPlaylistPreviousUids";
NSString * const SRGPlaylistUidsKey = @"SRGPlaylistUids";

NSString * const SRGPlaylistDidStartSynchronizationNotification = @"SRGPlaylistDidStartSynchronizationNotification";
NSString * const SRGPlaylistDidFinishSynchronizationNotification = @"SRGPlaylistDidFinishSynchronizationNotification";

@interface SRGPlaylist ()

@property (nonatomic, weak) SRGPageRequest *pullRequest;
@property (nonatomic, weak) SRGRequest *pushRequest;

@property (nonatomic) NSURLSession *session;

@end;

@implementation SRGPlaylist

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super initWithServiceURL:serviceURL identityService:identityService dataStore:dataStore]) {
        self.session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
        
        // Check that system playlist exists.
        SRGPlaylistEntry *watchItLaterPlaylistEntry = [self playlistEntryWithUid:SRGSystemPlaylistWatchItLaterUid];
        if (! watchItLaterPlaylistEntry) {
            dispatch_group_t group = dispatch_group_create();
            
            dispatch_group_enter(group);
            [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                SRGPlaylistEntry *systemPlaylistEntry = [SRGPlaylistEntry upsertWithUid:SRGSystemPlaylistWatchItLaterUid inManagedObjectContext:managedObjectContext];
                systemPlaylistEntry.system = @YES;
                systemPlaylistEntry.name = SRGUserDataLocalizedString(@"Watch it later", @"Default Watch it later playlist name");
            } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }
    }
    return self;
}

#pragma mark Data

- (void)savePlaylistEntryDictionaries:(NSArray<NSDictionary *> *)playlistEntryDictionaries withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    if (playlistEntryDictionaries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    NSMutableArray<NSString *> *changedUids = [NSMutableArray array];
    
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylistEntry *> *previousPlaylistEntries = [SRGPlaylistEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousPlaylistEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylistEntry.new, uid)]];
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        for (NSDictionary *playlistEntryDictionary in playlistEntryDictionaries) {
            SRGPlaylistEntry *playlistEntry = [SRGPlaylistEntry synchronizeWithDictionary:playlistEntryDictionary inManagedObjectContext:managedObjectContext];
            if (playlistEntry) {
                [changedUids addObject:playlistEntry.uid];
                
                if (playlistEntry.inserted) {
                    [uids addObject:playlistEntry.uid];
                }
                else if (playlistEntry.deleted) {
                    [uids removeObject:playlistEntry.uid];
                }
            }
        }
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (! error && changedUids.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : [changedUids copy],
                                                                            SRGPlaylistPreviousUidsKey : previousUids,
                                                                            SRGPlaylistUidsKey : currentUids }];
            });
        }
        completionBlock(error);
    }];
}

#pragma mark Subclassing hooks

- (void)synchronizeWithCompletionBlock:(void (^)(void))completionBlock
{
    void (^finishSynchronization)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistDidFinishSynchronizationNotification object:self];
        });
        completionBlock();
    };
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistDidStartSynchronizationNotification object:self];
    });
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (error) {
            finishSynchronization();
            return;
        }
        
        finishSynchronization();
    }];
}

- (void)userDidLogin
{
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylistEntry *> *playlistEntries = [SRGPlaylistEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        for (SRGPlaylistEntry *playlistEntry in playlistEntries) {
            playlistEntry.dirty = YES;
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
        NSArray<SRGPlaylistEntry *> *playlistEntries = [SRGPlaylistEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [playlistEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylistEntry.new, uid)]];
        [SRGPlaylistEntry deleteAllInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (previousUids.count > 0) {
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : previousUids,
                                                                            SRGPlaylistPreviousUidsKey : previousUids,
                                                                            SRGPlaylistUidsKey : @[] }];
            }
        });
    }];
}

#pragma mark Reads and writes

- (NSString *)playlistEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGPlaylistEntry *> * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylistEntry objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (SRGPlaylistEntry *)playlistEntryWithUid:(NSString *)uid
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylistEntry objectWithUid:uid inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)playlistEntryWithUid:(NSString *)uid completionBlock:(void (^)(SRGPlaylistEntry * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylistEntry objectWithUid:uid inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (NSString *)savePlaylistEntryForUid:(NSString *)uid withName:(NSString *)name completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylistEntry *> *previousPlaylistEntries = [SRGPlaylistEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousPlaylistEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylistEntry.new, uid)]];
        
        SRGPlaylistEntry *playlistEntry = [SRGPlaylistEntry upsertWithUid:uid inManagedObjectContext:managedObjectContext];
        if (! playlistEntry.system) {
            playlistEntry.name = name;
        }
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        if (playlistEntry.inserted) {
            [uids addObject:uid];
        }
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : @[uid],
                                                                            SRGPlaylistPreviousUidsKey : previousUids,
                                                                            SRGPlaylistUidsKey : currentUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSString *)discardPlaylistEntriesWithUids:(NSArray<NSString *> *)uids completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSArray<NSString *> *changedUids = nil;
    
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylistEntry *> *previousPlaylistEntries = [SRGPlaylistEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousPlaylistEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylistEntry.new, uid)]];
        
        changedUids = [SRGPlaylistEntry discardObjectsWithUids:uids inManagedObjectContext:managedObjectContext];
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        [uids removeObjectsInArray:changedUids];
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : changedUids,
                                                                            SRGPlaylistPreviousUidsKey : previousUids,
                                                                            SRGPlaylistUidsKey : currentUids }];
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
