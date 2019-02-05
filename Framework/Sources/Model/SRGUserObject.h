//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRGUserObject : NSManagedObject

/**
 *  The item unique identifier.
 */
// TODO: Rename as itemUid
@property (nonatomic, readonly, copy, nullable) NSString *mediaURN;

/**
 *  The date at which the entry was updated.
 */
@property (nonatomic, readonly, copy, nullable) NSDate *date;

/**
 *  `YES` iff the entry has been marked as discarded.
 */
@property (nonatomic, readonly) BOOL discarded;

@property (nonatomic) BOOL dirty;

@end

@interface SRGUserObject (Queries)

+ (NSArray<__kindof SRGUserObject *> *)objectsMatchingPredicate:(nullable NSPredicate *)predicate
                                          sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                         inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Insert a new entry, or return the existing one for update purposes.
 *
 *  @discussion The entry is properly setup for synchronization purposes.
 */
+ (__kindof SRGUserObject *)objectWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Delete all history entries.
 */
+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Discard the entry (actual deletion takes place when synchronizing with the service).
 */
- (void)discard;

@end

NS_ASSUME_NONNULL_END
