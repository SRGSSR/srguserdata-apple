//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObject.h"

#import "SRGUser+Private.h"
#import "SRGUserObject+Private.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>

@interface SRGUserObject ()

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic) BOOL discarded;
@property (nonatomic) BOOL dirty;

@end

@implementation SRGUserObject

@dynamic uid;
@dynamic date;
@dynamic discarded;
@dynamic dirty;

#pragma mark Class methods

+ (NSString *)uidKey
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Subclasses of 'SRGUserObject' must provide a uidKey" userInfo:nil];
}

+ (NSArray<SRGUserObject *> *)objectsMatchingPredicate:(NSPredicate *)predicate
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
    [allSortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@keypath(SRGUserObject.new, uid) ascending:NO]];
    fetchRequest.sortDescriptors = [allSortDescriptors copy];
    
    fetchRequest.fetchBatchSize = 100;
    return [managedObjectContext executeFetchRequest:fetchRequest error:NULL];
}

+ (SRGUserObject *)objectWithUid:(NSString *)uid inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGUserObject.new, uid), uid];
    return [self objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext].firstObject;
}

+ (SRGUserObject *)upsertWithUid:(NSString *)uid inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    SRGUserObject *object = [self objectWithUid:uid inManagedObjectContext:managedObjectContext];
    if (! object) {
        object = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:managedObjectContext];
        object.uid = uid;
    }
    object.dirty = YES;
    object.discarded = NO;
    object.date = NSDate.date;
    return object;
}

+ (SRGUserObject *)synchronizeWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSString *uid = dictionary[self.uidKey];
    if (! uid) {
        return nil;
    }
    
    // If the local entry is dirty and more recent than the server version, keep the local version as is.
    NSNumber *timestamp = dictionary[@"date"];
    NSDate *date = timestamp ? [NSDate dateWithTimeIntervalSince1970:timestamp.doubleValue / 1000.] : NSDate.date;
    SRGUserObject *object = [self objectWithUid:uid inManagedObjectContext:managedObjectContext];
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
    }
    
    [object updateWithDictionary:dictionary];
    object.dirty = NO;
    return object;
}

+ (NSArray<NSDictionary *> *)dictionariesForObjects:(NSArray<SRGUserObject *> *)objects replacedWithDictionaries:(NSArray<NSDictionary *> *)dictionaries
{
    NSMutableDictionary<NSString *, NSDictionary *> *dictionaryIndex = [NSMutableDictionary dictionary];
    for (NSDictionary *dictionary in dictionaries) {
        if (! [self.class isSynchronizableWithDictionary:dictionary]) {
            continue;
        }
        
        NSString *uid = dictionary[self.class.uidKey];
        if (uid) {
            dictionaryIndex[uid] = dictionary;
        }
    }
    
    NSMutableArray<NSDictionary *> *mergedDictionaries = [NSMutableArray array];
    for (SRGUserObject *object in objects) {
        if (! object.synchronizable) {
            continue;
        }
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

+ (NSArray<NSString *> *)discardObjectsWithUids:(NSArray<NSString *> *)uids inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;
{
    NSPredicate *predicate = uids ? [NSPredicate predicateWithFormat:@"%K IN %@ AND discarded == NO", @keypath(SRGUserObject.new, uid), uids] : nil;
    NSArray<SRGUserObject *> *objects = [self objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    NSArray<NSString *> *discardedUids = [objects valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGUserObject.new, uid)]];
    
    if (! [SRGUser userInManagedObjectContext:managedObjectContext].accountUid) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
        fetchRequest.predicate = predicate;
        
        NSBatchDeleteRequest *batchDeleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fetchRequest];
        [managedObjectContext executeRequest:batchDeleteRequest error:NULL];
    }
    else {
        NSBatchUpdateRequest *batchUpdateRequest = [[NSBatchUpdateRequest alloc] initWithEntityName:NSStringFromClass(self)];
        batchUpdateRequest.predicate = predicate;
        batchUpdateRequest.propertiesToUpdate = @{ @keypath(SRGUserObject.new, discarded) : @YES,
                                                   @keypath(SRGUserObject.new, dirty) : @YES,
                                                   @keypath(SRGUserObject.new, date) : NSDate.date };
        [managedObjectContext executeRequest:batchUpdateRequest error:NULL];
    }
    
    return discardedUids;
}

+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    NSBatchDeleteRequest *batchDeleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fetchRequest];
    [managedObjectContext executeRequest:batchDeleteRequest error:NULL];
}

#pragma mark Default implementations

+ (BOOL)isSynchronizableWithDictionary:(NSDictionary *)dictionary
{
    return YES;
}

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    self.uid = dictionary[self.class.uidKey];
    
    NSString *dateString = dictionary[@"date"];
    self.date = dateString ? [NSDate dateWithTimeIntervalSince1970:dateString.doubleValue / 1000.] : NSDate.date;
    
    self.discarded = [dictionary[@"deleted"] boolValue];
}

- (BOOL)isSynchronizable
{
    return YES;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    JSONDictionary[self.class.uidKey] = self.uid;
    JSONDictionary[@"date"] = @(round(self.date.timeIntervalSince1970 * 1000.));
    JSONDictionary[@"deleted"] = @(self.discarded);
    return [JSONDictionary copy];
}

#pragma mark Helpers

- (NSDictionary *)deletedDictionary
{
    NSMutableDictionary *JSONDictionary = [self.dictionary mutableCopy];
    JSONDictionary[@"deleted"] = @YES;
    return [JSONDictionary copy];
}

@end
