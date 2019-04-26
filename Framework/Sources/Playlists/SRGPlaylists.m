//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylists.h"

#import "NSArray+SRGUserData.h"
#import "NSBundle+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGPlaylist+Private.h"
#import "SRGPlaylistEntry+Private.h"
#import "SRGPlaylists+Private.h"
#import "SRGPlaylistsRequest.h"
#import "SRGUser+Private.h"
#import "SRGUserDataError+Private.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserObject+Private.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGNetwork/SRGNetwork.h>

NSString *SRGPlaylistNameForPlaylistWithUid(NSString *uid)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary *s_names;
    dispatch_once(&s_onceToken, ^{
        s_names = @{ SRGWatchLaterPlaylistUid : SRGUserDataLocalizedString(@"Watch later", @"Default Watch later playlist name") };
    });
    return s_names[uid];
}

NSString * const SRGWatchLaterPlaylistUid = @"watch_later";

NSString * const SRGPlaylistsDidChangeNotification = @"SRGPlaylistsDidChangeNotification";

NSString * const SRGPlaylistsChangedUidsKey = @"SRGPlaylistChangedUids";
NSString * const SRGPlaylistsPreviousUidsKey = @"SRGPlaylistPreviousUids";
NSString * const SRGPlaylistsUidsKey = @"SRGPlaylistUids";

NSString * const SRGPlaylistEntryChangesKey = @"SRGPlaylistEntryChanges";

NSString * const SRGPlaylistEntryChangedUidsSubKey = @"SRGPlaylistEntryChangedUids";
NSString * const SRGPlaylistEntryPreviousUidsSubKey = @"SRGPlaylistEntryPreviousUids";
NSString * const SRGPlaylistEntryUidsSubKey = @"SRGPlaylistEntryUids";

NSString * const SRGPlaylistsDidStartSynchronizationNotification = @"SRGPlaylistsDidStartSynchronizationNotification";
NSString * const SRGPlaylistsDidFinishSynchronizationNotification = @"SRGPlaylistsDidFinishSynchronizationNotification";

@interface SRGPlaylists ()

@property (nonatomic, weak) SRGRequest *pullPlaylistsRequest;
@property (nonatomic) SRGRequestQueue *requestQueue;

@property (nonatomic) NSURLSession *session;

@end;

@implementation SRGPlaylists

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super initWithServiceURL:serviceURL identityService:identityService dataStore:dataStore]) {
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
        
        // Check that the default playlists exist.
        NSArray<NSString *> *defaultPlaylistUids = @[ SRGWatchLaterPlaylistUid ];
        for (NSString *uid in defaultPlaylistUids) {
            SRGPlaylist *playlist = [self playlistWithUid:uid];
            if (! playlist) {
                dispatch_group_t group = dispatch_group_create();
                
                dispatch_group_enter(group);
                [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    SRGPlaylist *defaultPlaylist = [SRGPlaylist upsertWithUid:uid inManagedObjectContext:managedObjectContext];
                    defaultPlaylist.type = SRGPlaylistTypeSystem;
                    defaultPlaylist.name = SRGPlaylistNameForPlaylistWithUid(uid);
                } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
                    dispatch_group_leave(group);
                }];
                
                dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
            }
        }
    }
    return self;
}

#pragma mark Data

- (void)savePlaylistDictionaries:(NSArray<NSDictionary *> *)playlistDictionaries withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    NSMutableArray<NSString *> *changedUids = [NSMutableArray array];
    
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        NSArray<NSDictionary *> *replacementPlaylistDictionaries = [SRGPlaylist dictionariesForObjects:previousPlaylists replacedWithDictionaries:playlistDictionaries];
        
        if (replacementPlaylistDictionaries.count == 0) {
            return;
        }
        
        previousUids = [previousPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        for (NSDictionary *playlistDictionary in replacementPlaylistDictionaries) {
            SRGPlaylist *playlist = [SRGPlaylist synchronizeWithDictionary:playlistDictionary inManagedObjectContext:managedObjectContext];
            if (playlist) {
                [changedUids addObject:playlist.uid];
                
                if (playlist.inserted) {
                    [uids addObject:playlist.uid];
                }
                else if (playlist.deleted) {
                    [uids removeObject:playlist.uid];
                }
            }
        }
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (! error && changedUids.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : [changedUids copy],
                                                                            SRGPlaylistsPreviousUidsKey : previousUids,
                                                                            SRGPlaylistsUidsKey : currentUids }];
            });
        }
        completionBlock(error);
    }];
}

- (void)saveEntryDictionaries:(NSArray<NSDictionary *> *)playlistEntryDictionaries toPlaylistUid:(NSString *)playlistUid withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    __block NSArray<NSString *> *playlistUids = nil;
    
    __block NSMutableArray<NSString *> *changedPlaylistEntryUids = [NSMutableArray array];
    
    __block NSArray<NSString *> *previousPlaylistEntryUids = nil;
    __block NSArray<NSString *> *currentPlaylistEntryUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        playlistUids = [playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        
        NSArray<SRGPlaylistEntry *> *previousPlaylistEntries = playlist.entries.array;
        NSArray<NSDictionary *> *replacementPlaylistEntryDictionaries = [SRGPlaylistEntry dictionariesForObjects:previousPlaylistEntries replacedWithDictionaries:playlistEntryDictionaries];
        if (replacementPlaylistEntryDictionaries.count == 0) {
            return;
        }
        
        previousPlaylistEntryUids = [previousPlaylistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        
        NSMutableArray<NSString *> *uids = [previousPlaylistEntryUids mutableCopy];
        for (NSDictionary *playlistEntryDictionary in replacementPlaylistEntryDictionaries) {
            SRGPlaylistEntry *playlistEntry = [SRGPlaylistEntry synchronizeWithDictionary:playlistEntryDictionary playlist:playlist inManagedObjectContext:managedObjectContext];
            if (playlistEntry) {
                [changedPlaylistEntryUids addObject:playlistEntry.uid];
                
                if (playlistEntry.inserted) {
                    [uids addObject:playlistEntry.uid];
                }
                else if (playlistEntry.deleted) {
                    [uids removeObject:playlistEntry.uid];
                }
            }
        }
        currentPlaylistEntryUids = [uids copy];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (! error && ! playlistUids) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist.", @"Error message returned when removing some entries from an unknown playlist.") }];
        }
        
        if (! error && changedPlaylistEntryUids.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary<NSString *, NSArray<NSString *> *> *playlistEntryChanges = @{ SRGPlaylistEntryChangedUidsSubKey : [changedPlaylistEntryUids copy],
                                                                                           SRGPlaylistEntryPreviousUidsSubKey : previousPlaylistEntryUids,
                                                                                           SRGPlaylistEntryUidsSubKey : currentPlaylistEntryUids };
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : @[playlistUid],
                                                                            SRGPlaylistsPreviousUidsKey : playlistUids,
                                                                            SRGPlaylistsUidsKey : playlistUids,
                                                                            SRGPlaylistEntryChangesKey : @{ playlistUid : playlistEntryChanges }}];
            });
        }
        completionBlock(error);
    }];
}

#pragma mark Requests

- (void)pullPlaylistsForSessionToken:(NSString *)sessionToken
                 withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    SRGRequest *request = [[SRGPlaylistsRequest playlistsFromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (error) {
            completionBlock(error);
            return;
        }
        
        [self savePlaylistDictionaries:playlistDictionaries withCompletionBlock:completionBlock];
    }] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
    [request resume];
    self.pullPlaylistsRequest = request;
}

- (void)pushPlaylists:(NSArray<SRGPlaylist *> *)playlists
      forSessionToken:(NSString *)sessionToken
  withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    NSParameterAssert(playlists);
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    // System playlists cannot be pushed (read-only).
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K != %@", @keypath(SRGPlaylist.new, type), @(SRGPlaylistTypeSystem)];
    playlists = [playlists filteredArrayUsingPredicate:predicate];
    
    if (playlists.count == 0) {
        completionBlock(nil);
        return;
    }
    
    self.requestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        if (finished) {
            completionBlock(error);
        }
    }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
    
    for (SRGPlaylist *playlist in playlists) {
        NSManagedObjectID *playlistID = playlist.objectID;
        
        if (playlist.discarded) {
            SRGRequest *deleteRequest = [[SRGPlaylistsRequest deletePlaylistWithUid:playlist.uid fromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                [self.requestQueue reportError:error];
                
                if (! error) {
                    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                        SRGPlaylist *playlist = [managedObjectContext existingObjectWithID:playlistID error:NULL];
                        [managedObjectContext deleteObject:playlist];
                    } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
                }
            }] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
            [self.requestQueue addRequest:deleteRequest resume:YES];
        }
        else {
            SRGRequest *postRequest = [[SRGPlaylistsRequest postPlaylistDictionary:playlist.dictionary toServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSDictionary * _Nullable playlistDictionary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                [self.requestQueue reportError:error];
                
                if (! error) {
                    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                        SRGPlaylist *playlist = [managedObjectContext existingObjectWithID:playlistID error:NULL];
                        [playlist updateWithDictionary:playlistDictionary];
                        playlist.dirty = NO;
                    } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
                }
            }] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
            [self.requestQueue addRequest:postRequest resume:YES];
        }
    }
}

- (void)pullPlaylistEntriesForSessionToken:(NSString *)sessionToken
                       withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    self.requestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        if (finished) {
            completionBlock(error);
        }
    }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
        NSArray<NSString *> *playlistUids = [playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        for (NSString *playlistUid in playlistUids) {
            SRGRequest *request = [SRGPlaylistsRequest entriesForPlaylistWithUid:playlistUid fromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistEntryDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                [self.requestQueue reportError:error];
                
                if (! error) {
                    // TODO: Wait for all completion blocks?
                    [self saveEntryDictionaries:playlistEntryDictionaries toPlaylistUid:playlistUid withCompletionBlock:^(NSError * _Nullable error) {
                        
                    }];
                }
            }];
            [self.requestQueue addRequest:request resume:YES];
        }
    }];
}

- (void)pushPlaylistEntries:(NSArray<SRGPlaylistEntry *> *)playlistEntries
            forSessionToken:(NSString *)sessionToken
        withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    NSParameterAssert(playlistEntries);
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    if (playlistEntries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    self.requestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        if (finished) {
            completionBlock(error);
        }
    }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
    
    NSArray<NSString *> *playlistUids = [playlistEntries valueForKeyPath:[NSString stringWithFormat:@"%@.@distinctUnionOfObjects.%@", @keypath(SRGPlaylistEntry.new, playlist), @keypath(SRGPlaylist.new, uid)]];
    for (NSString *playlistUid in playlistUids) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, playlist.uid), playlistUid];
        NSArray<SRGPlaylistEntry *> *filteredPlaylistEntries = [playlistEntries filteredArrayUsingPredicate:predicate];
        
        NSPredicate *discardedPredicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGPlaylistEntry.new, discarded)];
        
        NSArray<SRGPlaylistEntry *> *discardedPlaylistEntries = [filteredPlaylistEntries filteredArrayUsingPredicate:discardedPredicate];
        if (discardedPlaylistEntries.count > 0) {
            NSArray<NSManagedObjectID *> *discardedPlaylistEntryIDs = [discardedPlaylistEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylistEntry.new, objectID)]];
            NSArray<NSString *> *discardedPlaylistEntryUids = [discardedPlaylistEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylistEntry.new, uid)]];
            
            SRGRequest *deleteRequest = [SRGPlaylistsRequest deletePlaylistEntriesWithUids:discardedPlaylistEntryUids forPlaylistWithUid:playlistUid fromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                [self.requestQueue reportError:error];
                
                if (! error) {
                    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                        for (NSManagedObjectID *playlistEntryID in discardedPlaylistEntryIDs) {
                            SRGPlaylistEntry *playlistEntry = [managedObjectContext existingObjectWithID:playlistEntryID error:NULL];
                            [managedObjectContext deleteObject:playlistEntry];
                        }
                    } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
                }
            }];
            [self.requestQueue addRequest:deleteRequest resume:YES];
        }
        
        NSArray<SRGPlaylistEntry *> *updatedPlaylistEntries = [filteredPlaylistEntries srguserdata_arrayByRemovingObjectsInArray:discardedPlaylistEntries];
        if (updatedPlaylistEntries.count > 0) {
            NSArray<NSManagedObjectID *> *updatedPlaylistEntryIDs = [updatedPlaylistEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylistEntry.new, objectID)]];
            
            NSMutableDictionary<NSString *, NSDictionary *> *updatedPlaylistEntryDictionaryIndex = [NSMutableDictionary dictionary];
            for (SRGPlaylistEntry *playlistEntry in updatedPlaylistEntries) {
                updatedPlaylistEntryDictionaryIndex[playlistEntry.uid] = playlistEntry.dictionary;
            }
            
            SRGRequest *putRequest = [SRGPlaylistsRequest putPlaylistEntryDictionaries:updatedPlaylistEntryDictionaryIndex.allValues forPlaylistWithUid:playlistUid toServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistEntryDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                [self.requestQueue reportError:error];
                
                if (! error) {
                    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                        for (NSManagedObjectID *playlistEntryID in updatedPlaylistEntryIDs) {
                            SRGPlaylistEntry *playlistEntry = [managedObjectContext existingObjectWithID:playlistEntryID error:NULL];
                            NSDictionary *playlistEntryDictionary = updatedPlaylistEntryDictionaryIndex[playlistEntry.uid];
                            [playlistEntry updateWithDictionary:playlistEntryDictionary];
                            playlistEntry.dirty = NO;
                        }
                    } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
                }
            }];
            [self.requestQueue addRequest:putRequest resume:YES];
        }
    }
}

#pragma mark Subclassing hooks

- (void)synchronizeWithCompletionBlock:(void (^)(void))completionBlock
{
    NSString *sessionToken = self.identityService.sessionToken;
    
    void (^finishSynchronization)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidFinishSynchronizationNotification object:self];
        });
        completionBlock();
    };
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidStartSynchronizationNotification object:self];
    });
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (error) {
            finishSynchronization();
            return;
        }
        
        [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGPlaylist.new, dirty)];
            return [SRGPlaylist objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
            if (error) {
                finishSynchronization();
                return;
            }
            
            [self pushPlaylists:playlists forSessionToken:sessionToken withCompletionBlock:^(NSError * _Nullable pushError) {
                if (SRGUserDataIsUnauthorizationError(pushError)) {
                    [self.identityService reportUnauthorization];
                    finishSynchronization();
                    return;
                }
                
                [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGPlaylistEntry.new, dirty)];
                    return [SRGPlaylistEntry objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
                } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
                    if (error) {
                        finishSynchronization();
                        return;
                    }
                    
                    [self pushPlaylistEntries:playlistEntries forSessionToken:sessionToken withCompletionBlock:^(NSError *error) {
                        if (SRGUserDataIsUnauthorizationError(pushError)) {
                            [self.identityService reportUnauthorization];
                            finishSynchronization();
                            return;
                        }
                        
                        [self pullPlaylistsForSessionToken:sessionToken withCompletionBlock:^(NSError * _Nullable pullError) {
                            if (SRGUserDataIsUnauthorizationError(pullError)) {
                                [self.identityService reportUnauthorization];
                                finishSynchronization();
                                return;
                            }
                            
                            [self pullPlaylistEntriesForSessionToken:sessionToken withCompletionBlock:^(NSError *error) {
                                if (SRGUserDataIsUnauthorizationError(pullError)) {
                                    [self.identityService reportUnauthorization];
                                    finishSynchronization();
                                    return;
                                }
                                
                                finishSynchronization();
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
}

- (void)userDidLogin
{
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K != %@", @keypath(SRGPlaylist.new, type), @(SRGPlaylistTypeSystem)];
        NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        for (SRGPlaylist *playlist in playlists) {
            playlist.dirty = YES;
        }
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self synchronize];
        });
    }];
}

- (void)userDidLogout
{
    [self.pullPlaylistsRequest cancel];
    [self.requestQueue cancel];
}

- (void)clearData
{
    __block NSArray<NSString *> *previousUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        [SRGPlaylist deleteAllInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (previousUids.count > 0) {
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : previousUids,
                                                                            SRGPlaylistsPreviousUidsKey : previousUids,
                                                                            SRGPlaylistsUidsKey : @[] }];
            }
        });
    }];
}

#pragma mark Reads and writes

- (NSArray<SRGPlaylist *> *)playlistsMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylist objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)playlistsMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGPlaylist *> * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylist objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (SRGPlaylist *)playlistWithUid:(NSString *)uid
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylist objectWithUid:uid inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)playlistWithUid:(NSString *)uid completionBlock:(void (^)(SRGPlaylist * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylist objectWithUid:uid inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (NSString *)addPlaylistWithName:(NSString *)name completionBlock:(void (^)(NSString * _Nullable, NSError * _Nullable))completionBlock
{
    __block NSArray<NSString *> *previousUids = nil;
    
    NSString *uid = NSUUID.UUID.UUIDString;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        
        SRGPlaylist *playlist = [SRGPlaylist upsertWithUid:uid inManagedObjectContext:managedObjectContext];
        playlist.name = name;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableArray<NSString *> *currentUids = [previousUids mutableCopy];
                [currentUids addObject:uid];
                
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : @[uid],
                                                                            SRGPlaylistsPreviousUidsKey : previousUids,
                                                                            SRGPlaylistsUidsKey : [currentUids copy] }];
            });
        }
        completionBlock ? completionBlock(uid, error) : nil;
    }];
}

- (NSString *)updatePlaylistWithUid:(NSString *)uid name:(NSString *)name completionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    __block NSArray<NSString *> *uids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:uid inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        uids = [previousPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        
        if (playlist.type != SRGPlaylistTypeSystem) {
            playlist.name = name;
            playlist.dirty = YES;
        }
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error && ! uids) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist.", @"Error message returned when updating an unknown playlist.") }];
        }
        
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : @[uid],
                                                                            SRGPlaylistsPreviousUidsKey : uids,
                                                                            SRGPlaylistsUidsKey : uids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSString *)discardPlaylistsWithUids:(NSArray<NSString *> *)uids completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSArray<NSString *> *changedUids = nil;
    
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        
        NSArray<NSString *> *discardedUids = uids ?: previousUids;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ AND %K IN %@", @keypath(SRGPlaylist.new, type), @(SRGPlaylistTypeSystem), @keypath(SRGPlaylist.new, uid), discardedUids];
        NSArray<SRGPlaylist *> *excludedPlaylists = [previousPlaylists filteredArrayUsingPredicate:predicate];
        if (excludedPlaylists.count > 0) {
            NSArray<NSString *> *excludedUids = [excludedPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
            NSMutableArray<NSString *> *mutableUids = discardedUids.mutableCopy;
            [mutableUids removeObjectsInArray:excludedUids];
            discardedUids = mutableUids.copy;
        }
        
        changedUids = [SRGPlaylist discardObjectsWithUids:discardedUids inManagedObjectContext:managedObjectContext];
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        [uids removeObjectsInArray:changedUids];
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : changedUids,
                                                                            SRGPlaylistsPreviousUidsKey : previousUids,
                                                                            SRGPlaylistsUidsKey : currentUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSArray<SRGPlaylistEntry *> *)entriesFromPlaylistWithUid:(NSString *)playlistUid matchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return nil;
        }
        NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, playlist.uid), playlistUid];
        if (predicate) {
            fetchPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[fetchPredicate, predicate]];
        }
        return [SRGPlaylistEntry objectsMatchingPredicate:fetchPredicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)entriesFromPlaylistWithUid:(NSString *)playlistUid matchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGPlaylistEntry *> * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return nil;
        }
        NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, playlist.uid), playlistUid];
        if (predicate) {
            fetchPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[fetchPredicate, predicate]];
        }
        return [SRGPlaylistEntry objectsMatchingPredicate:fetchPredicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (NSString *)addEntryWithUid:(NSString *)uid toPlaylistWithUid:(NSString *)playlistUid completionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    __block NSArray<NSString *> *playlistUids = nil;
    
    __block NSArray<NSString *> *previousPlaylistEntryUids = nil;
    __block NSArray<NSString *> *currentPlaylistEntryUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        previousPlaylistEntryUids = [playlist.entries.array valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        
        NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        playlistUids = [playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        
        NSMutableArray<NSString *> *playlistEntryUids = [previousPlaylistEntryUids mutableCopy];
        
        SRGPlaylistEntry *playlistEntry = [SRGPlaylistEntry upsertWithUid:uid playlist:playlist inManagedObjectContext:managedObjectContext];
        if (playlistEntry.inserted) {
            [playlistEntryUids addObject:uid];
        }
        currentPlaylistEntryUids = [playlistEntryUids copy];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error && ! playlistUids) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist.", @"Error message returned when adding an entry to an unknown playlist.") }];
        }
        
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary<NSString *, NSArray<NSString *> *> *playlistEntryChanges = @{ SRGPlaylistEntryChangedUidsSubKey : @[uid],
                                                                                           SRGPlaylistEntryPreviousUidsSubKey : previousPlaylistEntryUids,
                                                                                           SRGPlaylistEntryUidsSubKey : currentPlaylistEntryUids };
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : @[playlistUid],
                                                                            SRGPlaylistsPreviousUidsKey : playlistUids,
                                                                            SRGPlaylistsUidsKey : playlistUids,
                                                                            SRGPlaylistEntryChangesKey : @{ playlistUid : playlistEntryChanges }}];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSString *)removeEntriesWithUids:(NSArray<NSString *> *)uids fromPlaylistWithUid:(NSString *)playlistUid completionBlock:(void (^)(NSError * _Nullable error))completionBlock
{
    __block NSArray<NSString *> *playlistUids = nil;
    
    __block NSArray<NSString *> *changedPlaylistEntryUids = nil;
    
    __block NSArray<NSString *> *previousPlaylistEntryUids = nil;
    __block NSArray<NSString *> *currentPlaylistEntryUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        playlistUids = [playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        
        previousPlaylistEntryUids = [playlist.entries.array valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        changedPlaylistEntryUids = [SRGPlaylistEntry discardObjectsWithUids:uids playlist:playlist inManagedObjectContext:managedObjectContext];
        
        NSMutableArray<NSString *> *playlistEntryUids = [previousPlaylistEntryUids mutableCopy];
        [playlistEntryUids removeObjectsInArray:changedPlaylistEntryUids];
        currentPlaylistEntryUids = [playlistEntryUids copy];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error && ! playlistUids) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist.", @"Error message returned when removing some entries from an unknown playlist.") }];
        }
        
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary<NSString *, NSArray<NSString *> *> *playlistEntryChanges = @{ SRGPlaylistEntryChangedUidsSubKey : changedPlaylistEntryUids,
                                                                                           SRGPlaylistEntryPreviousUidsSubKey : previousPlaylistEntryUids,
                                                                                           SRGPlaylistEntryUidsSubKey : currentPlaylistEntryUids };
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : @[playlistUid],
                                                                            SRGPlaylistsPreviousUidsKey : playlistUids,
                                                                            SRGPlaylistsUidsKey : playlistUids,
                                                                            SRGPlaylistEntryChangesKey : @{ playlistUid : playlistEntryChanges }}];
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
