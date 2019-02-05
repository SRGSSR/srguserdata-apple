//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObject.h"

#import "SRGUser.h"

#import <libextobjc/libextobjc.h>

@interface SRGUserObject ()

@property (nonatomic, copy) NSString *mediaURN;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic) BOOL discarded;

@end

@implementation SRGUserObject

@dynamic mediaURN;
@dynamic date;
@dynamic discarded;
@dynamic dirty;

+ (NSString *)synchronizeWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSString *URN = dictionary[@"item_id"];
    if (! URN) {
        return nil;
    }
    
    SRGUserObject *object = [self objectWithURN:URN inManagedObjectContext:managedObjectContext];
    
    // If the local entry is dirty and more recent than server version, keep the local version as is.
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"date"] doubleValue] / 1000.];
    if (object.dirty && [object.date compare:date] == NSOrderedDescending) {
        return URN;
    }
    
    BOOL isDeleted = [dictionary[@"deleted"] boolValue];
    if (isDeleted) {
        if (object) {
            [managedObjectContext deleteObject:object];
        }
        return URN;
    }
    
    if (! object) {
        object = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:managedObjectContext];
    }
    
    [object updateWithDictionary:dictionary];
    object.dirty = NO;
    return URN;
}

+ (NSArray<SRGUserObject *> *)objectsMatchingPredicate:(NSPredicate *)predicate
                                 sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
                                inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    fetchRequest.predicate = predicate;
    
    // Ensure stable sorting using the URN as fallback (same criterium applied by the history service)
    NSMutableArray<NSSortDescriptor *> *allSortDescriptors = [NSMutableArray array];
    if (sortDescriptors) {
        [allSortDescriptors addObjectsFromArray:sortDescriptors];
    }
    [allSortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@keypath(SRGUserObject.new, mediaURN) ascending:NO]];
    fetchRequest.sortDescriptors = [allSortDescriptors copy];
    
    fetchRequest.fetchBatchSize = 100;
    return [managedObjectContext executeFetchRequest:fetchRequest error:NULL];
}

+ (SRGUserObject *)objectWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGUserObject.new, mediaURN), URN];
    return [self objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext].firstObject;
}

+ (SRGUserObject *)upsertWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    SRGUserObject *object = [self objectWithURN:URN inManagedObjectContext:managedObjectContext];
    if (! object) {
        object = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:managedObjectContext];
        object.mediaURN = URN;
    }
    object.dirty = YES;
    object.discarded = NO;
    object.date = NSDate.date;
    return object;
}

+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    NSBatchDeleteRequest *batchDeleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fetchRequest];
    [managedObjectContext executeRequest:batchDeleteRequest error:NULL];
}

- (void)discard
{
    if (! [SRGUser mainUserInManagedObjectContext:self.managedObjectContext].accountUid) {
        [self.managedObjectContext deleteObject:self];
    }
    else {
        self.discarded = YES;
        self.dirty = YES;
        self.date = NSDate.date;
    }
}

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    self.mediaURN = dictionary[@"item_id"];
    self.date = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"date"] doubleValue] / 1000.];
    self.discarded = [dictionary[@"deleted"] boolValue];
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    JSONDictionary[@"item_id"] = self.mediaURN;
    JSONDictionary[@"date"] = @(round(self.date.timeIntervalSince1970 * 1000.));
    JSONDictionary[@"deleted"] = @(self.discarded);
    return [JSONDictionary copy];
}

@end
