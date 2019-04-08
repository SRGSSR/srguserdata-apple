//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylists.h"
#import "SRGPlaylists+Private.h"

#import "NSBundle+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGPlaylist+Private.h"
#import "SRGPlaylistEntry+Private.h"
#import "SRGUser+Private.h"
#import "SRGUserDataError.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserObject+Private.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGNetwork/SRGNetwork.h>

typedef void (^SRGPlaylistPullCompletionBlock)(NSDate * _Nullable serverDate, NSError * _Nullable error);
typedef void (^SRGPlaylistPushCompletionBlock)(NSError * _Nullable error);

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

NSString * const SRGPlaylistChangedUidsKey = @"SRGPlaylistChangedUids";
NSString * const SRGPlaylistPreviousUidsKey = @"SRGPlaylistPreviousUids";
NSString * const SRGPlaylistUidsKey = @"SRGPlaylistUids";

NSString * const SRGPlaylistEntryChangesKey = @"SRGPlaylistEntryChanges";

NSString * const SRGPlaylistEntryChangedUidsSubKey = @"SRGPlaylistEntryChangedUids";
NSString * const SRGPlaylistEntryPreviousUidsSubKey = @"SRGPlaylistEntryPreviousUids";
NSString * const SRGPlaylistEntryUidsSubKey = @"SRGPlaylistEntryUids";

NSString * const SRGPlaylistsDidStartSynchronizationNotification = @"SRGPlaylistsDidStartSynchronizationNotification";
NSString * const SRGPlaylistDidFinishSynchronizationNotification = @"SRGPlaylistsDidFinishSynchronizationNotification";

@interface SRGPlaylists ()

@property (nonatomic, weak) SRGPageRequest *pullRequest;
@property (nonatomic, weak) SRGRequest *pushRequest;

@property (nonatomic) NSURLSession *session;

@end;

@implementation SRGPlaylists

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super initWithServiceURL:serviceURL identityService:identityService dataStore:dataStore]) {
        self.session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
        
        // Check that the default playlists exists.
        NSArray<NSString *> *defaultPlaylistUids = @[ SRGWatchLaterPlaylistUid ];
        for (NSString *uid in defaultPlaylistUids) {
            SRGPlaylist *playlist = [self playlistWithUid:uid];
            if (! playlist) {
                dispatch_group_t group = dispatch_group_create();
                
                dispatch_group_enter(group);
                [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    SRGPlaylist *defaultlaylist = [SRGPlaylist upsertWithUid:uid inManagedObjectContext:managedObjectContext];
                    defaultlaylist.system = @YES;
                    defaultlaylist.name = SRGPlaylistNameForPlaylistWithUid(uid);
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
    if (playlistDictionaries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    NSMutableArray<NSString *> *changedUids = [NSMutableArray array];
    
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        for (NSDictionary *playlistDictionary in playlistDictionaries) {
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
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : [changedUids copy],
                                                                            SRGPlaylistPreviousUidsKey : previousUids,
                                                                            SRGPlaylistUidsKey : currentUids }];
            });
        }
        completionBlock(error);
    }];
}

- (void)saveEntryDictionaries:(NSArray<NSDictionary *> *)playlistEntryDictionaries toPlaylistUid:(NSString *)playlistUid withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    if (playlistEntryDictionaries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    __block NSArray<NSString *> *previousPlaylistUids = nil;
    __block NSArray<NSString *> *currentPlaylistUids = nil;
    
    __block NSMutableArray<NSString *> *changedPlaylistEntryUids = [NSMutableArray array];
    
    __block NSArray<NSString *> *previousPlaylistEntryUids = nil;
    __block NSArray<NSString *> *currentPlaylistEntryUids = nil;
    
    __block BOOL isPlaylistFound = NO;
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (playlist) {
            isPlaylistFound = YES;
            
            NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
            previousPlaylistUids = currentPlaylistUids = [playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
            
            NSOrderedSet<SRGPlaylistEntry *> *previousPlaylistEntries = playlist.entries;
            NSOrderedSet<NSString *> *previousPlaylistEntryUidsOrderedSet = [previousPlaylistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
            previousPlaylistEntryUids = previousPlaylistEntryUidsOrderedSet.array;
            
            NSMutableArray<NSString *> *uids = [previousPlaylistEntryUids mutableCopy];
            for (NSDictionary *playlistEntryDictionary in playlistEntryDictionaries) {
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
        }
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (!error && !isPlaylistFound) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"Playlist does not exist.", @"Error message returned when removing some entries from an unknown playlist.") }];
        }
        
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary<NSString *, NSArray<NSString *> *> *playlistEntryChanges = @{ SRGPlaylistEntryChangedUidsSubKey : [changedPlaylistEntryUids copy],
                                                                                           SRGPlaylistEntryPreviousUidsSubKey : previousPlaylistEntryUids,
                                                                                           SRGPlaylistEntryUidsSubKey : currentPlaylistEntryUids };
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : @[playlistUid],
                                                                            SRGPlaylistPreviousUidsKey : previousPlaylistUids,
                                                                            SRGPlaylistUidsKey : currentPlaylistUids,
                                                                            SRGPlaylistEntryChangesKey : @{ playlistUid : playlistEntryChanges }
                                                                            }];
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
        [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidStartSynchronizationNotification object:self];
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
        NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
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
    [self.pullRequest cancel];
    [self.pushRequest cancel];
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
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : previousUids,
                                                                            SRGPlaylistPreviousUidsKey : previousUids,
                                                                            SRGPlaylistUidsKey : @[] }];
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

- (NSString *)savePlaylistForUid:(NSString *)uid withName:(NSString *)name completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSArray<NSString *> *previousUids = nil;
    __block NSArray<NSString *> *currentUids = nil;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGPlaylist *> *previousPlaylists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        previousUids = [previousPlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
        
        SRGPlaylist *playlist = [SRGPlaylist upsertWithUid:uid inManagedObjectContext:managedObjectContext];
        if (! playlist.system) {
            playlist.name = name;
        }
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        if (playlist.inserted) {
            [uids addObject:uid];
        }
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : @[uid],
                                                                            SRGPlaylistPreviousUidsKey : previousUids,
                                                                            SRGPlaylistUidsKey : currentUids }];
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
        
        NSArray<NSString *> *discardUids = uids ?: previousUids;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ && %K IN %@", @keypath(SRGPlaylist.new, system), @(YES), @keypath(SRGPlaylist.new, uid), discardUids];
        NSArray<SRGPlaylist *> *excludePlaylists = [previousPlaylists filteredArrayUsingPredicate:predicate];
        if (excludePlaylists.count > 0) {
            NSArray<NSString *> *excludeUids = [excludePlaylists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
            NSMutableArray<NSString *> *mutableUids = discardUids.mutableCopy;
            [mutableUids removeObjectsInArray:excludeUids];
            discardUids = mutableUids.copy;
        }
        
        changedUids = [SRGPlaylist discardObjectsWithUids:discardUids inManagedObjectContext:managedObjectContext];
        
        NSMutableArray<NSString *> *uids = [previousUids mutableCopy];
        [uids removeObjectsInArray:changedUids];
        currentUids = [uids copy];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : changedUids,
                                                                            SRGPlaylistPreviousUidsKey : previousUids,
                                                                            SRGPlaylistUidsKey : currentUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSArray<SRGPlaylistEntry *> *)entriesFromPlaylistWithUid:(NSString *)playlistUid matchingPredicate:(nullable NSPredicate *)predicate sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (!playlist) {
            return nil;
        }
        NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, playlist.uid), playlistUid];
        if (predicate) {
            fetchPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[fetchPredicate, predicate]];
        }
        return [SRGPlaylistEntry objectsMatchingPredicate:fetchPredicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)entriesFromPlaylistWithUid:(NSString *)playlistUid matchingPredicate:(nullable NSPredicate *)predicate sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGPlaylistEntry *> * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (!playlist) {
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
    __block NSArray<NSString *> *previousPlaylistUids = nil;
    __block NSArray<NSString *> *currentPlaylistUids = nil;
    
    __block NSArray<NSString *> *previousPlaylistEntryUids = nil;
    __block NSArray<NSString *> *currentPlaylistEntryUids = nil;
    
    __block BOOL isPlaylistFound = NO;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (playlist) {
            isPlaylistFound = YES;
            
            NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
            previousPlaylistUids = currentPlaylistUids = [playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
            
            NSOrderedSet<SRGPlaylistEntry *> *previousPlaylistEntries = playlist.entries;
            NSOrderedSet<NSString *> *previousPlaylistEntryUidsOrderedSet = [previousPlaylistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
            previousPlaylistEntryUids = previousPlaylistEntryUidsOrderedSet.array;
            
            SRGPlaylistEntry *playlistEntry = [SRGPlaylistEntry upsertWithUid:uid playlist:playlist inManagedObjectContext:managedObjectContext];
            
            NSMutableArray<NSString *> *playlistEntryUids = [previousPlaylistEntryUids mutableCopy];
            if (playlistEntry.inserted) {
                [playlistEntryUids addObject:uid];
            }
            currentPlaylistEntryUids = [playlistEntryUids copy];
        }
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (!error && !isPlaylistFound) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"Playlist does not exist.", @"Error message returned when adding an entry to an unknown playlist.") }];
        }
        
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary<NSString *, NSArray<NSString *> *> *playlistEntryChanges = @{ SRGPlaylistEntryChangedUidsSubKey : @[uid],
                                                                                           SRGPlaylistEntryPreviousUidsSubKey : previousPlaylistEntryUids,
                                                                                           SRGPlaylistEntryUidsSubKey : currentPlaylistEntryUids };
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : @[playlistUid],
                                                                            SRGPlaylistPreviousUidsKey : previousPlaylistUids,
                                                                            SRGPlaylistUidsKey : currentPlaylistUids,
                                                                            SRGPlaylistEntryChangesKey : @{ playlistUid : playlistEntryChanges }
                                                                            }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSString *)removeEntriesWithUids:(NSArray<NSString *> *)uids fromPlaylistWithUid:(NSString *)playlistUid completionBlock:(void (^)(NSError * _Nullable error))completionBlock
{
    __block NSArray<NSString *> *previousPlaylistUids = nil;
    __block NSArray<NSString *> *currentPlaylistUids = nil;
    
    __block NSArray<NSString *> *changedPlaylistEntryUids = nil;
    
    __block NSArray<NSString *> *previousPlaylistEntryUids = nil;
    __block NSArray<NSString *> *currentPlaylistEntryUids = nil;
    
    __block BOOL isPlaylistFound = NO;
    
    return [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGPlaylist *playlist = [SRGPlaylist objectWithUid:playlistUid inManagedObjectContext:managedObjectContext];
        if (playlist) {
            isPlaylistFound = YES;
            
            NSArray<SRGPlaylist *> *playlists = [SRGPlaylist objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
            previousPlaylistUids = currentPlaylistUids = [playlists valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylist.new, uid)]];
            
            NSOrderedSet<SRGPlaylistEntry *> *previousPlaylistEntries = playlist.entries;
            NSOrderedSet<NSString *> *previousPlaylistEntryUidsOrderedSet = [previousPlaylistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
            previousPlaylistEntryUids = previousPlaylistEntryUidsOrderedSet.array;
            
            changedPlaylistEntryUids = [SRGPlaylistEntry discardObjectsWithUids:uids playlist:playlist inManagedObjectContext:managedObjectContext];
            
            NSMutableArray<NSString *> *playlistEntryUids = [previousPlaylistEntryUids mutableCopy];
            [playlistEntryUids removeObjectsInArray:changedPlaylistEntryUids];
            currentPlaylistEntryUids = [playlistEntryUids copy];
        }
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (!error && !isPlaylistFound) {
            error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                        code:SRGUserDataErrorNotFound
                                    userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"Playlist does not exist.", @"Error message returned when removing some entries from an unknown playlist.") }];
        }
        
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary<NSString *, NSArray<NSString *> *> *playlistEntryChanges = @{ SRGPlaylistEntryChangedUidsSubKey : changedPlaylistEntryUids,
                                                                                           SRGPlaylistEntryPreviousUidsSubKey : previousPlaylistEntryUids,
                                                                                           SRGPlaylistEntryUidsSubKey : currentPlaylistEntryUids };
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPlaylistsDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPlaylistChangedUidsKey : @[playlistUid],
                                                                            SRGPlaylistPreviousUidsKey : previousPlaylistUids,
                                                                            SRGPlaylistUidsKey : currentPlaylistUids,
                                                                            SRGPlaylistEntryChangesKey : @{ playlistUid : playlistEntryChanges }
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
