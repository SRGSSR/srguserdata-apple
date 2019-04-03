//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylistEntry.h"

#import <libextobjc/libextobjc.h>

@interface SRGPlaylistEntry ()

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic) BOOL discarded;
@property (nonatomic) BOOL dirty;

@property (nonatomic, nullable) SRGPlaylist *playlist;

@end

@implementation SRGPlaylistEntry

@dynamic uid;
@dynamic date;
@dynamic discarded;
@dynamic dirty;

@dynamic playlist;

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
    NSAssert(playlist, @"Playlist entry must have a playlist");
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ && %K == %@", @keypath(SRGPlaylistEntry.new, uid), uid, @keypath(SRGPlaylistEntry.new, playlist.uid), playlist.uid];
    return [self objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext].firstObject;
}

+ (SRGPlaylistEntry *)upsertWithUid:(NSString *)uid playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSAssert(playlist, @"Playlist entry must have a playlist");
    
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

@end
