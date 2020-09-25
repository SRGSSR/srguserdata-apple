//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Methods hooks for service subclass implementations.
 */
@interface SRGUserObjectService (Subclassing)

/**
 *  Services must implement this method to return the objects they are responsible to synchronize.
 */
- (NSArray<SRGUserObject *> *)userObjectsInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  @see `SRGUserDataService`
 */
- (void)prepareDataForInitialSynchronizationWithCompletionBlock:(void (^)(void))completionBlock NS_REQUIRES_SUPER;

@end

NS_ASSUME_NONNULL_END
