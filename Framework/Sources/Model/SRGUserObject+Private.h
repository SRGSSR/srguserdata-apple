//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Private interface for implementation purposes.
 */
@interface SRGUserObject (Private)

/**
 *  Return existing entries, optionally matching a specific predicate and / or sorted with descriptors. If no sort
 *  descriptors are provided, entries are still returned in a stable order.
 */
+ (NSArray<__kindof SRGUserObject *> *)objectsMatchingPredicate:(nullable NSPredicate *)predicate
                                          sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                         inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Return an existing object for the specified identifier, `nil` if none is found.
 */
+ (nullable __kindof SRGUserObject *)objectWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Create an entry with the specified URN, or return an existing one for update purposes.
 */
+ (__kindof SRGUserObject *)upsertWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Synchronize the receiver with the information from the provided dictionary. The entry might be created, updated
 *  or deleted automatically, in which case its identifier is returned. If the dictionary data is invalid, the method
 *  returns `nil`.
 *
 *  @discussion To persist changes, the Core Data managed object context needs to be saved.
 */
+ (nullable NSString *)synchronizeWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Discard the objects with the specified identifiers. Since some of them might not be found, the method returns the actual
 *  list of identifiers which could be successfully removed.
 */
+ (NSArray<NSString *> *)discardObjectsWithURNs:(NSArray<NSString *> *)URNs inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Discard all objects.
 */
+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end

NS_ASSUME_NONNULL_END
