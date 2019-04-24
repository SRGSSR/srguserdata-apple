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
+ (nullable __kindof SRGUserObject *)objectWithUid:(NSString *)uid inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Create an entry with the specified identifier, or return an existing one for update purposes.
 */
+ (__kindof SRGUserObject *)upsertWithUid:(NSString *)uid inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Synchronize the receiver with the information from the provided dictionary. The entry might be created, updated
 *  or deleted automatically, in which case it is returned by the method. If the dictionary data is invalid, the method
 *  returns `nil`.
 *
 *  @discussion To persist changes, the Core Data managed object context needs to be saved.
 */
+ (nullable __kindof SRGUserObject *)synchronizeWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Discard the objects with the specified identifiers. Since some of them might not be found, the method returns the actual
 *  list of identifiers which will be discarded. For logged in users, objects will be deleted when the next synchronization
 *  is performed. For offline users, objects are removed immediately.
 *
 *  @discussion Order is not preserved in the rerturned list (in comparison to the original list). Already discarded objects
 *              are omitted.
 */
+ (NSArray<NSString *> *)discardObjectsWithUids:(NSArray<NSString *> *)uids inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Delete all objects, removing them from the database directly. No synchronization will be triggered for logged in users.
 */
+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Set to `YES` to flag the object as requiring a synchronization for the currently logged in user.
 *
 *  @discussion The value of this flag is unspecified when no user is logged in.
 */
@property (nonatomic) BOOL dirty;

@end

NS_ASSUME_NONNULL_END
