//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserData.h"

#import "SRGDataStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Private interface for implementation purposes.
 */
@interface SRGUserData (Private)

/**
 *  The service supplying identities, if any.
 */
@property (nonatomic, readonly, nullable) SRGIdentityService *identityService;

/**
 *  The associated data store.
 */
@property (nonatomic, readonly) SRGDataStore *dataStore;

/**
 *  The data store file location.
 */
@property (nonatomic, readonly) NSURL *storeFileURL;

@end

NS_ASSUME_NONNULL_END
