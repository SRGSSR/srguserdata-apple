//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylistEntry.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Private interface for implementation purposes.
 */
@interface SRGPlaylistEntry (Private)

/**
 *  @see `SRGPlaylistEntry.h`
 */
@property (nonatomic, nullable) SRGPlaylist *playlist;

/**
 *  Return existing entries, optionally matching a specific predicate and / or sorted with descriptors. If no sort
 *  descriptors are provided, entries are still returned in a stable order.
 */
+ (NSArray<__kindof SRGPlaylistEntry *> *)objectsMatchingPredicate:(nullable NSPredicate *)predicate
                                             sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                            inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Return an existing object with the specified identifier appearing in a playlist, `nil` if none is found.
 */
+ (nullable __kindof SRGPlaylistEntry *)objectWithUid:(NSString *)uid playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Create an entry with the given identifier in the specified playlist, or return an existing one for update purposes.
 */
+ (__kindof SRGPlaylistEntry *)upsertWithUid:(NSString *)uid playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Synchronize the receiver with the information from the provided dictionary. The entry might be created, updated
 *  or deleted automatically, in which case it is returned by the method. If the dictionary data is invalid, the method
 *  returns `nil`.
 *
 *  @discussion To persist changes, the Core Data managed object context needs to be saved.
 */
+ (nullable __kindof SRGPlaylistEntry *)synchronizeWithDictionary:(NSDictionary *)dictionary playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Return the list of dictionaries which would need to be saved in order to replace a list of objects with a list of
 *  dictionaries representing another object list.
 */
+ (NSArray<NSDictionary *> *)dictionariesForObjects:(NSArray<SRGPlaylistEntry *> *)objects replacedWithDictionaries:(NSArray<NSDictionary *> *)dictionaries;

/**
 *  Discard the entries with the specified identifiers in a playlist. Since some of them might not be found, the method returns
 *  the actual list of identifiers which will be discarded. For logged in users, objects will be deleted when the next synchronization
 *  is performed. For offline users, objects are removed immediately.
 *
 *  @discussion Order is not preserved in the returned list (in comparison to the original list). Already discarded objects
 *              are omitted.
 */
+ (NSArray<NSString *> *)discardObjectsWithUids:(NSArray<NSString *> *)uids playlist:(SRGPlaylist *)playlist inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Set to `YES` to flag the object as requiring a synchronization for the currently logged in user.
 *
 *  @discussion The value of this flag is unspecified when no user is logged in.
 */
@property (nonatomic) BOOL dirty;

/**
 *  Update the current entry using the provided dictionary, in the format delivered by the associated service.
 */
- (void)updateWithDictionary:(NSDictionary *)dictionary;

/**
 *  Return a dictionary representation of the entry, which can be sent to the associated service.
 */
@property (nonatomic, readonly) NSDictionary *dictionary;

@end

NS_ASSUME_NONNULL_END
