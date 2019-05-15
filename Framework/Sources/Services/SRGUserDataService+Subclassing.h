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
@interface SRGUserDataService (Subclassing)

/**
 *  This method provides a way for the service to prepare existing local data for initial synchronization, so that it
 *  can be properly merged with existing remote data.
 *
 *  The provided completion block must be called on completion, otherwise the behavior is undefined. The block can
 *  be called from any thread.
 */
- (void)prepareDataForInitialSynchronizationWithCompletionBlock:(void (^)(void))completionBlock;

/**
 *  This method is called when synchronization starts, from any thread. Services can implement their logic here (usually
 *  retrieve data with network requests and save it).
 *
 *  The provided completion block must be called on completion, otherwise the behavior is undefined. The block can
 *  be called from any thread.
 */
- (void)synchronizeWithCompletionBlock:(void (^)(NSError * _Nullable error))completionBlock;

/**
 *  This method is called when synchronization is cancelled. Services can implement their logic here (usually cancel
 *  network requests retrieving and sending data).
 */
- (void)cancelSynchronization;

/**
 *  Method called when local service data needs to be cleared.
 */
- (void)clearData;

@end

NS_ASSUME_NONNULL_END
