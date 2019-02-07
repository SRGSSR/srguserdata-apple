//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRGUserObject (Subclassing)

/**
 *  Synchronize the receiver with the information from the provided dictionary. The entry might be created, updated
 *  or deleted automatically, in which case its identifier is returned. If the dictionary data is invalid, the method
 *  returns `nil`.
 *
 *  @discussion To persist changes, the Core Data managed object context needs to be saved.
 */
+ (nullable NSString *)synchronizeWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end

@interface SRGUserObject (SubclassingHooks)

/**
 *  Update the current entry using the provided dictionary, in the format delivered by the history service.
 */
- (void)updateWithDictionary:(NSDictionary *)dictionary;

/**
 *  Return a dictionary representation of the entry and which can be sent to the history service.
 */
@property (nonatomic, readonly) NSDictionary *dictionary;

@end

@interface SRGUserObject (Queries)

+ (NSArray<__kindof SRGUserObject *> *)objectsMatchingPredicate:(nullable NSPredicate *)predicate
                                          sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                         inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

// TODO: Nullability
/**
 *  Insert a new entry, or return the existing one for update purposes.
 *
 *  @discussion The entry is properly setup for synchronization purposes.
 */
+ (__kindof SRGUserObject *)objectWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

+ (__kindof SRGUserObject *)upsertWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

// Returns the URNs which where deleted
+ (NSArray<NSString *> *)discardObjectsWithURNs:(NSArray<NSString *> *)URNs inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end

NS_ASSUME_NONNULL_END
