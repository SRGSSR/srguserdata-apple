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

SRGPlaylistUid const SRGPlaylistUidWatchLater = @"watch_later";

NSString * const SRGPlaylistsDidChangeNotification = @"SRGPlaylistsDidChangeNotification";

NSString * const SRGPlaylistsChangedUidsKey = @"SRGPlaylistsChangedUids";
NSString * const SRGPlaylistsUidsKey = @"SRGPlaylistUids";
NSString * const SRGPlaylistsPreviousUidsKey = @"SRGPlaylistPreviousUids";

NSString * const SRGPlaylistEntriesDidChangeNotification = @"SRGPlaylistEntriesDidChangeNotification";

NSString * const SRGPlaylistEntriesChangedUidsKey = @"SRGPlaylistEntriesChangedUids";
NSString * const SRGPlaylistEntriesUidsKey = @"SRGPlaylistEntriesUids";
NSString * const SRGPlaylistEntriesPreviousUidsKey = @"SRGPlaylistEntriesPreviousUids";

@interface SRGPlaylists ()

@property (nonatomic, weak) SRGRequest *pullPlaylistsRequest;
@property (nonatomic) SRGRequestQueue *requestQueue;

@property (nonatomic) NSURLSession *session;

@end;

@implementation SRGPlaylists

#pragma mark Class methods

+ (NSArray<NSString *> *)defaultPlaylistUids
{
    return @[ SRGPlaylistUidWatchLater ];
}

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super initWithServiceURL:serviceURL identityService:identityService dataStore:dataStore]) {
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
        
        [self insertDefaultData];
    }
    return self;
}

#pragma mark Data

// TODO: Move as service subclassing hook
- (void)insertDefaultData
{
    NSArray<NSString *> *defaultPlaylistUids = [SRGPlaylists defaultPlaylistUids];
    for (NSString *uid in defaultPlaylistUids) {
        [self savePlaylistWithName:@"" /* overridden */ uid:uid completionBlock:nil];
    }
}

- (void)savePlaylistDictionaries:(NSArray<NSDictionary *> *)playlistDictionaries withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    if (playlistDictionaries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    __block NSSet<NSString *> *changedUids = nil;
    __block NSSet<NSString *> *currentUids = nil;
    __block NSSet<NSString *> *previousUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        NSArray<NSDictionary *> *replacementPlaylistDictionaries = [SRGPlaylist dictionariesForObjects:previousPlaylists replacedWithDictionaries:playlistDictionaries];
        
        if (replacementPlaylistDictionaries.count == 0) {
            return;
        }
        
        previousUids = [NSSet setWithArray:[previousPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]]];
        
        NSMutableSet<NSString *> *mutableChangedUids = [NSMutableSet set];
        NSMutableSet<NSString *> *mutableCurrentUids = [previousUids mutableCopy];
        for (NSDictionary *playlistDictionary in replacementPlaylistDictionaries) {
            SRGPlaylist *playlist = [SRGPlaylist synchronizeWithDictionary:playlistDictionary inManagedObjectContext:managedObjectContext];
            if (playlist) {
                [mutableChangedUids addObject:playlist.uid];
                
                if (playlist.inserted) {
                    [mutableCurrentUids addObject:playlist.uid];
                }
                else if (playlist.deleted) {
                    [mutableCurrentUids removeObject:playlist.uid];
                }
            }
        }
        changedUids = [mutableChangedUids copy];
        currentUids = [mutableCurrentUids copy];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (! error && changedUids.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : changedUids,
                                                                            SRGPlaylistsUidsKey : currentUids,
                                                                            SRGPlaylistsPreviousUidsKey : previousUids }];
            });
        }
        completionBlock(error);
    }];
}

- (void)saveEntryDictionaries:(NSArray<NSDictionary *> *)playlistEntryDictionaries toPlaylistUid:(NSString *)playlistUid withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    __block BOOL playlistFound = NO;
    
    __block NSSet<NSString *> *changedUids = nil;
    __block NSSet<NSString *> *currentUids = nil;
    __block NSSet<NSString *> *previousUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        playlistFound = YES;
        
        NSArray<SRGPlaylistEntry *> *previousPlaylistEntries = playlist.entries.array;
        NSArray<NSDictionary *> *replacementPlaylistEntryDictionaries = [SRGPlaylistEntry dictionariesForObjects:previousPlaylistEntries replacedWithDictionaries:playlistEntryDictionaries];
        if (replacementPlaylistEntryDictionaries.count == 0) {
            return;
        }
        
        previousUids = [NSSet setWithArray:[previousPlaylistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)]];
        
        NSMutableSet<NSString *> *mutableChangedUids = [NSMutableSet set];
        NSMutableSet<NSString *> *mutableCurrentUids = [previousUids mutableCopy];
        for (NSDictionary *playlistEntryDictionary in replacementPlaylistEntryDictionaries) {
            SRGPlaylistEntry *playlistEntry = [SRGPlaylistEntry synchronizeWithDictionary:playlistEntryDictionary playlist:playlist inManagedObjectContext:managedObjectContext];
            if (playlistEntry) {
                [mutableChangedUids addObject:playlistEntry.uid];

                if (playlistEntry.inserted) {
                    [mutableCurrentUids addObject:playlistEntry.uid];
                }
                else if (playlistEntry.deleted) {
                    [mutableCurrentUids removeObject:playlistEntry.uid];
                }
            }
        }
        changedUids = [mutableChangedUids copy];
        currentUids = [mutableCurrentUids copy];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (! error && ! playlistFound) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist.", @"Error message returned when removing some entries from an unknown playlist.") }];
        }
        
        if (! error && changedUids.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
                    [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistEntriesDidChangeNotification
                                                                      object:playlist
                                                                    userInfo:@{ SRGPlaylistEntriesChangedUidsKey : changedUids,
                                                                                SRGPlaylistEntriesUidsKey : currentUids,
                                                                                SRGPlaylistEntriesPreviousUidsKey : previousUids }];
                    return nil;
                }];
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
            if (SRGUserDataIsUnauthorizationError(error)) {
                [self.identityService reportUnauthorization];
            }
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
    
    // Only standard playlists can be updated (entries can be edited for any kind of playlist, though)
    // TODO: Is an abstraction possible? (filtering out non-synchronizable objects)
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylist.new, type), @(SRGPlaylistTypeStandard)];
    playlists = [playlists filteredArrayUsingPredicate:predicate];
    
    if (playlists.count == 0) {
        completionBlock(nil);
        return;
    }
    
    self.requestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        if (finished) {
            if (SRGUserDataIsUnauthorizationError(error)) {
                [self.identityService reportUnauthorization];
            }
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
                if (SRGUserDataIsUnauthorizationError(error)) {
                    [self.identityService reportUnauthorization];
                }
                completionBlock(error);
            }
        }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
        
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
            if (SRGUserDataIsUnauthorizationError(error)) {
                [self.identityService reportUnauthorization];
            }
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
    // TODO: Is an abstraction possible? (filtering out non-synchronizable objects)
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylist.new, type), @(SRGPlaylistTypeStandard)];
    NSArray<SRGUserObject *> *playlists = [SRGPlaylist objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    // TODO: <SRGPlaylistEntry *>, no cast
    NSArray<SRGUserObject *> *playlistEntries = (NSArray<SRGUserObject *> *)[SRGPlaylistEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    return [playlists arrayByAddingObjectsFromArray:playlistEntries];
}

- (void)clearData
{
    __block NSSet<NSString *> *previousUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [NSSet setWithArray:[playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]]];
        [SRGPlaylist deleteAllInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (previousUids.count > 0) {
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : previousUids,
                                                                            SRGPlaylistsUidsKey : @[],
                                                                            SRGPlaylistsPreviousUidsKey : previousUids }];
            }
            
            // TODO: Move to parent class
            [self insertDefaultData];
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

- (NSString *)savePlaylistWithName:(NSString *)name uid:(NSString *)uid completionBlock:(void (^)(NSString * _Nullable, NSError * _Nullable))completionBlock
{
    SRGPlaylistType type = SRGPlaylistTypeForPlaylistWithUid(uid);
    if (type != SRGPlaylistTypeStandard) {
        name = SRGPlaylistNameForPlaylistWithUid(uid);
    }
    return [self savePlaylistWithName:name uid:uid type:type completionBlock:completionBlock];
}

- (NSString *)savePlaylistWithName:(NSString *)name uid:(NSString *)uid type:(SRGPlaylistType)type completionBlock:(void (^)(NSString * _Nullable, NSError * _Nullable))completionBlock
{
    NSParameterAssert(name);
    
    if (! uid) {
        uid = NSUUID.UUID.UUIDString;
    }
    
    __block NSSet<NSString *> *changedUids = nil;
    __block NSSet<NSString *> *currentUids = nil;
    __block NSSet<NSString *> *previousUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [NSSet setWithArray:[previousPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]]];
        
        SRGPlaylist *playlist = [SRGPlaylist upsertWithUid:uid inManagedObjectContext:managedObjectContext];
        // TODO Don't allow to edit non standard playlist?
        playlist.name = name;
        playlist.type = type;
        
        NSMutableSet<NSString *> *mutableCurrentUids = [previousUids mutableCopy];
        if (playlist.inserted) {
            [mutableCurrentUids addObject:playlist.uid];
        }
        currentUids = [mutableCurrentUids copy];
        changedUids = [NSSet setWithObject:uid];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableDictionary<NSString *, NSSet<NSString *> *> *userInfo = @{ SRGPlaylistsUidsKey : currentUids }.mutableCopy;
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : changedUids,
                                                                            SRGPlaylistsUidsKey : currentUids,
                                                                            SRGPlaylistsPreviousUidsKey : previousUids }];
            });
        }
        completionBlock ? completionBlock(uid, error) : nil;
    }];
}

- (NSString *)discardPlaylistsWithUids:(NSArray<NSString *> *)uids completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSSet<NSString *> *changedUids = nil;
    __block NSSet<NSString *> *currentUids = nil;
    __block NSSet<NSString *> *previousUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [NSSet setWithArray:[previousPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]]];
        
        NSSet<NSString *> *toDiscardedUids = uids ? [NSSet setWithArray:uids] : previousUids;
        
        // TODO: Is an abstraction possible? (filtering out non-synchronizable objects)
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K != %@ AND %K IN %@", @keypath(SRGPlaylist.new, type), @(SRGPlaylistTypeStandard), @keypath(SRGPlaylist.new, uid), toDiscardedUids];
        NSArray<SRGPlaylist *> *excludedPlaylists = [previousPlaylists filteredArrayUsingPredicate:predicate];
        if (excludedPlaylists.count > 0) {
            NSSet<NSString *> *excludedUids = [NSSet setWithArray:[excludedPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]]];
            NSMutableSet<NSString *> *mutableUids = toDiscardedUids.mutableCopy;
            [mutableUids minusSet:excludedUids];
            toDiscardedUids = mutableUids.copy;
        }
        
        NSArray<NSString *> *discardedUids = [SRGPlaylist discardObjectsWithUids:toDiscardedUids.allObjects inManagedObjectContext:managedObjectContext];
        
        currentUids = [previousUids srguserdata_setByRemovingObjectsInArray:discardedUids];
        changedUids = [NSSet setWithArray:discardedUids];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistsChangedUidsKey : changedUids,
                                                                            SRGPlaylistsUidsKey : currentUids,
                                                                            SRGPlaylistsPreviousUidsKey : previousUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSArray<SRGPlaylistEntry *> *)entriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylistEntry objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    }];
}

- (NSArray<SRGPlaylistEntry *> *)entriesInPlaylistWithUid:(NSString *)playlistUid matchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
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

- (NSString *)entriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGPlaylistEntry *> * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGPlaylistEntry objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (NSString *)entriesInPlaylistWithUid:(NSString *)playlistUid matchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGPlaylistEntry *> * _Nullable, NSError * _Nullable))completionBlock
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

- (NSString *)saveEntryWithUid:(NSString *)uid inPlaylistWithUid:(NSString *)playlistUid completionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    __block BOOL playlistFound = NO;
    
    __block NSSet<NSString *> *changedUids = nil;
    __block NSSet<NSString *> *currentUids = nil;
    __block NSSet<NSString *> *previousUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        playlistFound = YES;
        
        previousUids = [playlist.entries.set valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        
        SRGPlaylistEntry *playlistEntry = [SRGPlaylistEntry upsertWithUid:uid playlist:playlist inManagedObjectContext:managedObjectContext];
        
        NSMutableSet<NSString *> *mutableCurrentUids = [previousUids mutableCopy];
        if (playlistEntry.inserted) {
            [mutableCurrentUids addObject:uid];
        }
        currentUids = [mutableCurrentUids copy];
        changedUids = [NSSet setWithObject:uid];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error && ! playlistFound) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist.", @"Error message returned when adding an entry to an unknown playlist.") }];
        }
        
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
                    [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistEntriesDidChangeNotification
                                                                      object:playlist
                                                                    userInfo:@{ SRGPlaylistEntriesChangedUidsKey : changedUids,
                                                                                SRGPlaylistEntriesUidsKey : currentUids,
                                                                                SRGPlaylistEntriesPreviousUidsKey : previousUids }];
                    return nil;
                }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSString *)discardEntriesWithUids:(NSArray<NSString *> *)uids fromPlaylistWithUid:(NSString *)playlistUid completionBlock:(void (^)(NSError * _Nullable error))completionBlock
{
    __block BOOL playlistFound = NO;
    
    __block NSSet<NSString *> *changedUids = nil;
    __block NSSet<NSString *> *currentUids = nil;
    __block NSSet<NSString *> *previousUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (! playlist) {
            return;
        }
        
        playlistFound = YES;
        
        previousUids = [playlist.entries.set valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        
        NSArray<NSString *> *discardedUids = [SRGPlaylistEntry discardObjectsWithUids:uids playlist:playlist inManagedObjectContext:managedObjectContext];
        
        currentUids = [previousUids srguserdata_setByRemovingObjectsInArray:discardedUids];
        changedUids = [NSSet setWithArray:discardedUids];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error && ! playlistFound) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The playlist does not exist.", @"Error message returned when removing some entries from an unknown playlist.") }];
        }
        
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
                    [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistEntriesDidChangeNotification
                                                                      object:playlist
                                                                    userInfo:@{ SRGPlaylistEntriesChangedUidsKey : changedUids,
                                                                                SRGPlaylistEntriesUidsKey : currentUids,
                                                                                SRGPlaylistEntriesPreviousUidsKey : previousUids }];
                    return nil;
                }];
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
