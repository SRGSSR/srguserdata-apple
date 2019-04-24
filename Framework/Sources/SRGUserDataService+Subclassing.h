//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

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
 *  Method called when the user logged in.
 */
- (void)userDidLogin;

/**
 *  Method called when user logged out.
 */
- (void)userDidLogout;

/**
 *  Method called when local service data needs to be cleared.
 */
- (void)clearData;

@end
