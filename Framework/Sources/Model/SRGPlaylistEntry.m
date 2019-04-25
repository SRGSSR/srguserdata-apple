//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylistEntry.h"

#import "SRGUser+Private.h"

#import <libextobjc/libextobjc.h>

@interface SRGPlaylistEntry ()

@property (nonatomic, copy) NSString *uid;
@property (nonatomic) NSDate *date;
@property (nonatomic) BOOL discarded;
@property (nonatomic) BOOL dirty;

@property (nonatomic) SRGPlaylist *playlist;

@end

@implementation SRGPlaylistEntry

@dynamic uid;
@dynamic date;
@dynamic discarded;
@dynamic dirty;

@dynamic playlist;

#pragma mark Class methods

+ (NSArray<SRGPlaylistEntry *> *)objectsMatchingPredicate:(NSPredicate *)predicate
                                    sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
                                   inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    fetchRequest.predicate = predicate;
    
    // Ensure stable sorting using the identifier as fallback (same criterium applied by the history service)
    NSMutableArray<NSSortDescriptor *> *allSortDescriptors = [NSMutableArray array];
    if (sortDescriptors) {
        [allSortDescriptors addObjectsFromArray:sortDescriptors];
    }
    [allSortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@keypath(SRGUserObject.new, date) ascending:YES]];
    [allSortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@keypath(SRGUserObject.new, uid) ascending:YES]];
    fetchRequest.sortDescriptors = [allSortDescriptors copy];
    
    fetchRequest.fetchBatchSize = 100;
    return [managedObjectContext executeFetchRequest:fetchRequest error:NULL];
}

+ (SRGPlaylistEntry *)objectWithUid:(NSString *)uid playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ AND %K == %@", @keypath(SRGPlaylistEntry.new, uid), uid, @keypath(SRGPlaylistEntry.new, playlist.uid), playlist.uid];
    return [self objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext].firstObject;
}

+ (SRGPlaylistEntry *)upsertWithUid:(NSString *)uid playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    SRGPlaylistEntry *object = [self objectWithUid:uid playlist:playlist inManagedObjectContext:managedObjectContext];
    if (! object) {
        object = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:managedObjectContext];
        object.uid = uid;
        object.playlist = playlist;
    }
    object.dirty = YES;
    object.discarded = NO;
    object.date = NSDate.date;
    return object;
}

+ (SRGPlaylistEntry *)synchronizeWithDictionary:(NSDictionary *)dictionary playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSString *uid = dictionary[@"itemId"];
    if (! uid) {
        return nil;
    }
    
    // If the local entry is dirty and more recent than the server version, keep the local version as is.
    NSNumber *timestamp = dictionary[@"date"];
    NSDate *date = timestamp ? [NSDate dateWithTimeIntervalSince1970:timestamp.doubleValue / 1000.] : NSDate.date;
    SRGPlaylistEntry *object = [self objectWithUid:uid playlist:playlist inManagedObjectContext:managedObjectContext];
    if (object.dirty && [object.date compare:date] == NSOrderedDescending) {
        return object;
    }
    
    BOOL isDeleted = [dictionary[@"deleted"] boolValue];
    if (isDeleted) {
        if (object) {
            [managedObjectContext deleteObject:object];
        }
        return object;
    }
    
    if (! object) {
        object = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:managedObjectContext];
        object.playlist = playlist;
    }
    
    [object updateWithDictionary:dictionary];
    object.dirty = NO;
    return object;
}

+ (NSArray<NSDictionary *> *)dictionariesForObjects:(NSArray<SRGPlaylistEntry *> *)objects replacedWithDictionaries:(NSArray<NSDictionary *> *)dictionaries
{
    NSMutableDictionary<NSString *, NSDictionary *> *dictionaryIndex = [NSMutableDictionary dictionary];
    for (NSDictionary *dictionary in dictionaries) {
        NSString *uid = dictionary[@"itemId"];
        if (uid) {
            dictionaryIndex[uid] = dictionary;
        }
    }
    
    NSMutableArray<NSDictionary *> *mergedDictionaries = [NSMutableArray array];
    for (SRGPlaylistEntry *object in objects) {
        if (object.dirty) {
            [mergedDictionaries addObject:object.dictionary];
        }
        else if ([dictionaryIndex.allKeys containsObject:object.uid]) {
            [mergedDictionaries addObject:dictionaryIndex[object.uid]];
        }
        else {
            [mergedDictionaries addObject:object.deletedDictionary];
        }
        
        dictionaryIndex[object.uid] = nil;
    }
    
    [mergedDictionaries addObjectsFromArray:dictionaryIndex.allValues];
    return [mergedDictionaries copy];
}

+ (NSArray<NSString *> *)discardObjectsWithUids:(NSArray<NSString *> *)uids playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;
{
    NSPredicate *predicate = uids ? [NSPredicate predicateWithFormat:@"%K IN %@ AND discarded == NO AND %K == %@", @keypath(SRGPlaylistEntry.new, uid), uids, @keypath(SRGPlaylistEntry.new, playlist.uid), playlist.uid] : [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, playlist.uid), playlist.uid];
    NSArray<SRGPlaylistEntry *> *objects = [self objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    NSArray<NSString *> *discardedUids = [objects valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGPlaylistEntry.new, uid)]];
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    fetchRequest.predicate = predicate;
    
    if (! [SRGUser userInManagedObjectContext:managedObjectContext].accountUid) {
        NSBatchDeleteRequest *batchDeleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fetchRequest];
        [managedObjectContext executeRequest:batchDeleteRequest error:NULL];
    }
    else {
        // TODO: Predicates which lead to two tables being joined (here playlist entry / playlist) are not supported
        //       by batch update requests. Check if we can still do something to use them anyway.
        NSArray<SRGPlaylistEntry *> *playlistEntries = [managedObjectContext executeFetchRequest:fetchRequest error:NULL];
        [playlistEntries enumerateObjectsUsingBlock:^(SRGPlaylistEntry * _Nonnull playlistEntry, NSUInteger idx, BOOL * _Nonnull stop) {
            playlistEntry.discarded = YES;
            playlistEntry.dirty = YES;
            playlistEntry.date = NSDate.date;
        }];
    }
    
    return discardedUids;
}

#pragma mark Updates

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    self.uid = dictionary[@"itemId"];
    
    NSString *dateString = dictionary[@"date"];
    self.date = dateString ? [NSDate dateWithTimeIntervalSince1970:dateString.doubleValue / 1000.] : NSDate.date;
    
    self.discarded = [dictionary[@"deleted"] boolValue];
}

#pragma mark JSON construction

- (NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    JSONDictionary[@"itemId"] = self.uid;
    JSONDictionary[@"date"] = @(round(self.date.timeIntervalSince1970 * 1000.));
    JSONDictionary[@"deleted"] = @(self.discarded);
    return [JSONDictionary copy];
}

- (NSDictionary *)deletedDictionary
{
    NSMutableDictionary *JSONDictionary = [self.dictionary mutableCopy];
    JSONDictionary[@"deleted"] = @YES;
    return [JSONDictionary copy];
}

@end
