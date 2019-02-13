//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObject.h"

#import "SRGUser+Private.h"
#import "SRGUserObject+Private.h"

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

+ (NSString *)synchronizeWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSString *uid = dictionary[@"item_id"];
    if (! uid) {
        return nil;
    }
    
    SRGUserObject *object = [self objectWithUid:uid inManagedObjectContext:managedObjectContext];
    
    // If the local entry is dirty and more recent than server version, keep the local version as is.
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"date"] doubleValue] / 1000.];
    if (object.dirty && [object.date compare:date] == NSOrderedDescending) {
        return uid;
    }
    
    BOOL isDeleted = [dictionary[@"deleted"] boolValue];
    if (isDeleted) {
        if (object) {
            [managedObjectContext deleteObject:object];
        }
        return uid;
    }
    
    if (! object) {
        object = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:managedObjectContext];
    }
    
    [object updateWithDictionary:dictionary];
    object.dirty = NO;
    return uid;
}

+ (NSArray<NSString *> *)discardObjectsWithUids:(NSArray<NSString *> *)uids inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;
{
    NSPredicate *predicate = uids ? [NSPredicate predicateWithFormat:@"%K IN %@ AND discarded == NO", @keypath(SRGUserObject.new, uid), uids] : nil;
    NSArray<SRGUserObject *> *objects = [self objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    NSArray<NSString *> *discardedUids = [objects valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGUserObject.new, uid)]];
    
    for (SRGUserObject *object in objects) {
        if (! [SRGUser userInManagedObjectContext:managedObjectContext].accountUid) {
            [managedObjectContext deleteObject:object];
        }
        else {
            object.discarded = YES;
            object.dirty = YES;
            object.date = NSDate.date;
        }
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

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    self.uid = dictionary[@"item_id"];
    self.date = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"date"] doubleValue] / 1000.];
    self.discarded = [dictionary[@"deleted"] boolValue];
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    JSONDictionary[@"item_id"] = self.uid;
    JSONDictionary[@"date"] = @(round(self.date.timeIntervalSince1970 * 1000.));
    JSONDictionary[@"deleted"] = @(self.discarded);
    return [JSONDictionary copy];
}

@end
