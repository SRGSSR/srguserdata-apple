//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylists.h"

#import "NSArray+SRGUserData.h"
#import "NSBundle+SRGUserData.h"
#import "NSSet+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGPlaylist+Private.h"
#import "SRGPlaylistEntry+Private.h"
#import "SRGPlaylistsRequest.h"
#import "SRGUser+Private.h"
#import "SRGUserDataError.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"
#import "SRGUserObject+Private.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGNetwork/SRGNetwork.h>

static NSString *SRGPlaylistNameForPlaylistWithUid(NSString *uid)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary<NSString *, NSString *>  *s_names;
    dispatch_once(&s_onceToken, ^{
        s_names = @{ SRGPlaylistUidWatchLater : SRGUserDataLocalizedString(@"Watch later", @"Default Watch later playlist name") };
    });
    return s_names[uid];
}

static SRGPlaylistType SRGPlaylistTypeForPlaylistWithUid(NSString *uid)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary *s_types;
    dispatch_once(&s_onceToken, ^{
        s_types = @{ SRGPlaylistUidWatchLater : @(SRGPlaylistTypeWatchLater) };
    });
    
    NSNumber *typeNumber = s_types[uid];
    return typeNumber ? typeNumber.integerValue : SRGPlaylistTypeStandard;
}

NSString * const SRGPlaylistsDidChangeNotification = @"SRGPlaylistsDidChangeNotification";
NSString * const SRGPlaylistsUidsKey = @"SRGPlaylistsUids";

NSString * const SRGPlaylistEntriesDidChangeNotification = @"SRGPlaylistEntriesDidChangeNotification";
NSString * const SRGPlaylistUidKey = @"SRGPlaylistUid";
NSString * const SRGPlaylistEntriesUidsKey = @"SRGPlaylistEntriesUids";

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
        
        // Insert local objects for non-synchronizable default playlists (whose entries can be synchronized, though)
        NSArray<NSString *> *reservedUIds = SRGPlaylist.reservedUids;
        for (NSString *uid in reservedUIds) {
            [self saveSystemPlaylistWithUid:uid completionBlock:nil];
        }
    }
    return self;
}

#pragma mark Data

- (void)savePlaylistDictionaries:(NSArray<NSDictionary *> *)playlistDictionaries withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    if (playlistDictionaries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    NSMutableSet<NSString *> *changedUids = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSSet<NSString *> *> *playlistEntriesUidsIndex = [NSMutableDictionary dictionary];
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        NSArray<NSDictionary *> *replacementPlaylistDictionaries = [SRGPlaylist dictionariesForObjects:previousPlaylists replacedWithDictionaries:playlistDictionaries];
        
        if (replacementPlaylistDictionaries.count == 0) {
            return;
        }
        
        for (NSDictionary *playlistDictionary in replacementPlaylistDictionaries) {
            SRGPlaylist *playlist = [SRGPlaylist synchronizeWithDictionary:playlistDictionary matchingPredicate:nil inManagedObjectContext:managedObjectContext];
            if (playlist) {
                if (playlist.deleted) {
                    NSArray<NSString *> *discardedEntriesUids = [playlist.entries.array valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
                    if (discardedEntriesUids.count > 0) {
                        playlistEntriesUidsIndex[playlist.uid] = [NSSet setWithArray:discardedEntriesUids];
                    }
                }
                [changedUids addObject:playlist.uid];
            }
        }
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (! error && changedUids.count > 0) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [playlistEntriesUidsIndex enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull playlistUid, NSSet<NSString *> * _Nonnull playlistEntriesUids, BOOL * _Nonnull stop) {
                    [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistEntriesDidChangeNotification
                                                                      object:self
                                                                    userInfo:@{ SRGPlaylistUidKey : playlistUid,
                                                                                SRGPlaylistEntriesUidsKey : playlistEntriesUids }];
                }];
                
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsUidsKey : [changedUids copy] }];
            });
        }
        completionBlock(error);
    }];
}

- (void)savePlaylistEntryDictionaries:(NSArray<NSDictionary *> *)playlistEntryDictionaries toPlaylistWithUid:(NSString *)playlistUid completionBlock:(void (^)(NSError *error))completionBlock
{
    __block BOOL playlistFound = NO;
    NSMutableSet<NSString *> *changedUids = [NSMutableSet set];
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid matchingPredicate:nil inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        playlistFound = YES;
        
        NSArray<SRGPlaylistEntry *> *previousPlaylistEntries = playlist.entries.array;
        NSArray<NSDictionary *> *replacementPlaylistEntryDictionaries = [SRGPlaylistEntry dictionariesForObjects:previousPlaylistEntries replacedWithDictionaries:playlistEntryDictionaries];
        if (replacementPlaylistEntryDictionaries.count == 0) {
            return;
        }
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, playlist.uid), playlistUid];
        for (NSDictionary *playlistEntryDictionary in replacementPlaylistEntryDictionaries) {
            SRGPlaylistEntry *playlistEntry = [SRGPlaylistEntry synchronizeWithDictionary:playlistEntryDictionary matchingPredicate:predicate inManagedObjectContext:managedObjectContext];
            if (playlistEntry) {
                if (playlistEntry.inserted) {
                    playlistEntry.playlist = playlist;
                }
                [changedUids addObject:playlistEntry.uid];
            }
        }
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (! playlistFound) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist", @"Error message returned when removing some entries from an unknown playlist.") }];
        }
        else if (! error && changedUids.count > 0) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistEntriesDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistUidKey : playlistUid,
                                                                            SRGPlaylistEntriesUidsKey : changedUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
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
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (%K IN %@)", @keypath(SRGPlaylist.new, uid), SRGPlaylist.reservedUids];
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
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
        if (playlists.count == 0) {
            completionBlock(nil);
            return;
        }
        
        self.requestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
            if (finished) {
                completionBlock(error);
            }
        }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
        
        NSArray<NSString *> *playlistUids = [playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        for (NSString *playlistUid in playlistUids) {
            SRGRequest *request = [SRGPlaylistsRequest entriesForPlaylistWithUid:playlistUid fromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistEntryDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                [self.requestQueue reportError:error];
                
                if (! error) {
                    [self savePlaylistEntryDictionaries:playlistEntryDictionaries toPlaylistWithUid:playlistUid completionBlock:nil];
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

- (void)synchronizeWithCompletionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    NSString *sessionToken = self.identityService.sessionToken;
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (error) {
            completionBlock(error);
            return;
        }
        
        NSManagedObjectID *userID = user.objectID;
        [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGPlaylist.new, dirty)];
            return [SRGPlaylist objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
            if (error) {
                completionBlock(error);
                return;
            }
            
            [self pushPlaylists:playlists forSessionToken:sessionToken withCompletionBlock:^(NSError * _Nullable error) {
                if (error) {
                    completionBlock(error);
                    return;
                }
                
                [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGPlaylistEntry.new, dirty)];
                    return [SRGPlaylistEntry objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
                } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
                    if (error) {
                        completionBlock(error);
                        return;
                    }
                    
                    [self pushPlaylistEntries:playlistEntries forSessionToken:sessionToken withCompletionBlock:^(NSError *error) {
                        if (error) {
                            completionBlock(error);
                            return;
                        }
                        
                        [self pullPlaylistsForSessionToken:sessionToken withCompletionBlock:^(NSError * _Nullable error) {
                            if (error) {
                                completionBlock(error);
                                return;
                            }
                            
                            [self pullPlaylistEntriesForSessionToken:sessionToken withCompletionBlock:^(NSError *error) {
                                if (error) {
                                    completionBlock(error);
                                    return;
                                }
                                
                                [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                                    SRGUser *user = [managedObjectContext existingObjectWithID:userID error:NULL];
                                    user.playlistsSynchronizationDate = NSDate.date;
                                } withPriority:NSOperationQueuePriorityLow completionBlock:completionBlock];
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
}

- (void)cancelSynchronization
{
    [self.pullPlaylistsRequest cancel];
    [self.requestQueue cancel];
}

- (NSArray<SRGUserObject *> *)userObjectsInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (%K IN %@)", @keypath(SRGPlaylist.new, uid), SRGPlaylist.reservedUids];
    NSArray<SRGUserObject *> *playlists = [SRGPlaylist objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    NSArray<SRGUserObject *> *playlistEntries = [SRGPlaylistEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    return [playlists arrayByAddingObjectsFromArray:playlistEntries];
}

- (void)clearData
{
    NSMutableSet<NSString *> *deletedUids = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSSet<NSString *> *> *playlistEntriesUidsIndex = [NSMutableDictionary dictionary];
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        for (SRGPlaylist *playlist in playlists) {
            NSString *playlistUid = playlist.uid;
            
            NSArray<NSString *> *playlistEntriesUids = [playlist.entries.array valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
            if (playlistEntriesUids.count > 0) {
                playlistEntriesUidsIndex[playlist.uid] = [NSSet setWithArray:playlistEntriesUids];
            }
            
            
            if (! [SRGPlaylist.reservedUids containsObject:playlistUid]) {
                [deletedUids addObject:playlistUid];
            }
        }
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", @keypath(SRGPlaylist.new, uid), deletedUids];
        [SRGPlaylist deleteAllObjectsMatchingPredicate:predicate inManagedObjectContext:managedObjectContext];
        
        [SRGPlaylistEntry deleteAllObjectsMatchingPredicate:nil inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (! error && deletedUids.count > 0) {
                [playlistEntriesUidsIndex enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull playlistUid, NSSet<NSString *> * _Nonnull playlistEntriesUids, BOOL * _Nonnull stop) {
                    [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistEntriesDidChangeNotification
                                                                      object:self
                                                                    userInfo:@{ SRGPlaylistUidKey : playlistUid,
                                                                                SRGPlaylistEntriesUidsKey : playlistEntriesUids }];
                }];
                
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsUidsKey : [deletedUids copy] }];
            }
        });
    }];
}

#pragma mark Reads and writes

- (NSArray<SRGPlaylist *> *)playlistsMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSPredicate *playlistsPredicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylist.new, discarded)];
    if (predicate) {
        playlistsPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[playlistsPredicate, predicate]];
    }
    return [SRGPlaylist objectsMatchingPredicate:playlistsPredicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
}

- (SRGPlaylist *)playlistWithUid:(NSString *)uid inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylist.new, discarded)];
    return [SRGPlaylist objectWithUid:uid matchingPredicate:predicate inManagedObjectContext:managedObjectContext];
}

- (NSArray<SRGPlaylist *> *)playlistsMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self playlistsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)playlistsMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGPlaylist *> * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self playlistsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (SRGPlaylist *)playlistWithUid:(NSString *)uid
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self playlistWithUid:uid inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)playlistWithUid:(NSString *)uid completionBlock:(void (^)(SRGPlaylist * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self playlistWithUid:uid inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (NSString *)savePlaylistWithName:(NSString *)name uid:(NSString *)uid completionBlock:(void (^)(NSString * _Nullable, NSError * _Nullable))completionBlock
{
    return [self savePlaylistWithName:name uid:uid type:SRGPlaylistTypeStandard completionBlock:completionBlock];
}

- (void)saveSystemPlaylistWithUid:(NSString *)uid completionBlock:(void (^)(NSString * _Nullable, NSError * _Nullable))completionBlock
{
    [self savePlaylistWithName:SRGPlaylistNameForPlaylistWithUid(uid) uid:uid type:SRGPlaylistTypeForPlaylistWithUid(uid) completionBlock:completionBlock];
}

- (NSString *)savePlaylistWithName:(NSString *)name uid:(NSString *)uid type:(SRGPlaylistType)type completionBlock:(void (^)(NSString * _Nullable, NSError * _Nullable))completionBlock
{
    NSParameterAssert(name);
    
    if (! uid) {
        uid = NSUUID.UUID.UUIDString;
    }
    
    __block BOOL forbidden = NO;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        if (type != SRGPlaylistTypeForPlaylistWithUid(uid)) {
            forbidden = YES;
            return;
        }
        
        SRGPlaylist *playlist = [SRGPlaylist upsertWithUid:uid matchingPredicate:nil inManagedObjectContext:managedObjectContext];
        playlist.name = name;
        playlist.type = type;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (forbidden) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorForbidden
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist cannot be edited", @"Error message returned when attempting to edit a default read-only playlist") }];
        }
        else if (! error) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsUidsKey : [NSSet setWithObject:uid] }];
            });
        }
        completionBlock ? completionBlock(uid, error) : nil;
    }];
}

- (NSString *)discardPlaylistsWithUids:(NSArray<NSString *> *)uids completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSSet<NSString *> *changedUids = nil;
    NSMutableDictionary<NSString *, NSSet<NSString *> *> *playlistEntriesUidsIndex = [NSMutableDictionary dictionary];
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        for (NSString *uid in uids) {
            SRGPlaylist *playlist = [SRGPlaylist objectWithUid:uid matchingPredicate:nil inManagedObjectContext:managedObjectContext];
            if (! playlist) {
                continue;
            }
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, playlist.uid), playlist.uid];
            NSArray<NSString *> *discardedEntriesUids = [SRGPlaylistEntry discardObjectsWithUids:nil matchingPredicate:predicate inManagedObjectContext:managedObjectContext];
            if (discardedEntriesUids.count > 0) {
                playlistEntriesUidsIndex[uid] = [NSSet setWithArray:discardedEntriesUids];
            }
        }
        
        NSArray<NSString *> *discardedUids = [SRGPlaylist discardObjectsWithUids:uids matchingPredicate:nil inManagedObjectContext:managedObjectContext];
        changedUids = [NSSet setWithArray:discardedUids];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error && changedUids.count > 0) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [playlistEntriesUidsIndex enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull playlistUid, NSSet<NSString *> * _Nonnull playlistEntriesUids, BOOL * _Nonnull stop) {
                    [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistEntriesDidChangeNotification
                                                                      object:self
                                                                    userInfo:@{ SRGPlaylistUidKey : playlistUid,
                                                                                SRGPlaylistEntriesUidsKey : playlistEntriesUids }];
                }];
                
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsUidsKey : changedUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSArray<SRGPlaylistEntry *> *)playlistEntriesInPlaylistWithUid:(NSString *)playlistUid
                                                matchingPredicate:(NSPredicate *)predicate
                                            sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
                                           inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid matchingPredicate:nil inManagedObjectContext:managedObjectContext];
    if (! playlist) {
        return nil;
    }
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"%K == %@ AND %K == NO", @keypath(SRGPlaylistEntry.new, playlist.uid), playlistUid, @keypath(SRGPlaylistEntry.new, discarded)];
    if (predicate) {
        fetchPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[fetchPredicate, predicate]];
    }
    
    NSMutableArray<NSSortDescriptor *> *playlistEntriesSortDescriptor = [NSMutableArray array];
    if (sortDescriptors) {
        [playlistEntriesSortDescriptor addObjectsFromArray:sortDescriptors];
    }
    else {
        [playlistEntriesSortDescriptor addObject:[NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, date) ascending:YES]];
    }
    
    return [SRGPlaylistEntry objectsMatchingPredicate:fetchPredicate sortedWithDescriptors:[playlistEntriesSortDescriptor copy] inManagedObjectContext:managedObjectContext];
}

- (NSArray<SRGPlaylistEntry *> *)playlistEntriesInPlaylistWithUid:(NSString *)playlistUid matchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self playlistEntriesInPlaylistWithUid:playlistUid matchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)playlistEntriesInPlaylistWithUid:(NSString *)playlistUid matchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGPlaylistEntry *> * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self playlistEntriesInPlaylistWithUid:playlistUid matchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (NSString *)savePlaylistEntryWithUid:(NSString *)uid inPlaylistWithUid:(NSString *)playlistUid completionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    __block BOOL playlistFound = NO;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid matchingPredicate:nil inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        playlistFound = YES;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, playlist.uid), playlistUid];
        SRGPlaylistEntry *playlistEntry = [SRGPlaylistEntry upsertWithUid:uid matchingPredicate:predicate inManagedObjectContext:managedObjectContext];
        if (playlistEntry.inserted) {
            playlistEntry.playlist = playlist;
        }
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! playlistFound) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist.", @"Error message returned when adding an entry to an unknown playlist.") }];
        }
        else if (! error) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistEntriesDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistUidKey : playlistUid,
                                                                            SRGPlaylistEntriesUidsKey : [NSSet setWithObject:uid] }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSString *)discardPlaylistEntriesWithUids:(NSArray<NSString *> *)uids fromPlaylistWithUid:(NSString *)playlistUid completionBlock:(void (^)(NSError * _Nullable error))completionBlock
{
    __block BOOL playlistFound = NO;
    __block NSSet<NSString *> *changedUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid matchingPredicate:nil inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        playlistFound = YES;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, playlist.uid), playlistUid];
        NSArray<NSString *> *discardedUids = [SRGPlaylistEntry discardObjectsWithUids:uids matchingPredicate:predicate inManagedObjectContext:managedObjectContext];
        changedUids = [NSSet setWithArray:discardedUids];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! playlistFound) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist.", @"Error message returned when removing some entries from an unknown playlist.") }];
        }
        else if (! error && changedUids.count > 0) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistEntriesDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistUidKey : playlistUid,
                                                                            SRGPlaylistEntriesUidsKey : changedUids }];
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
