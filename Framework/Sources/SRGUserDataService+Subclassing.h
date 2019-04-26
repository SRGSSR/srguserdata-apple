//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"
#import "SRGUserObject.h"

#import <SRGIdentity/SRGIdentity.h>

/**
 *  Methods hooks for service subclass implementations.
 */
@interface SRGUserDataService (Subclassing)

/**
 *  This method is called when synchronization starts, from any thread. Services can implement their logic here (usually
 *  retrieve data with network requests and save it).
 *
 *  The provided completion block must be called on completion, otherwise the behavior is undefined. The block can
 *  be called from any thread.
 */
- (void)synchronizeWithCompletionBlock:(void (^)(void))completionBlock;

/**
 *  This method is called when synchronization is cancelled. Services can implement their logic here (usually cancel
 *  network requests retrieving and sending data).
 */
- (void)cancelSynchronization;

/**
 *  Services must implement this method to return the objects they are responsible to synchronize.
 */
- (NSArray<SRGUserObject *> *)userObjectsInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Method called when local service data needs to be cleared.
 */
- (void)clearData;

@end
