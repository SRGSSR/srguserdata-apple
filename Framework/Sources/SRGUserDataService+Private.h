//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

#import <SRGIdentity/SRGIdentity.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Private interface for implementation purposes.
 */
@interface SRGUserDataService (Private)

/**
 *  Instantiate a service retrieving data from the specified URL on behalf of a user provided by an identity service
 *  (if any), saving data to the given store.
 *
 *  If no service URL or identity providers are supplied, the data will be kept locally only and no synchronization
 *  will be made.
 */
- (instancetype)initWithServiceURL:(nullable NSURL *)serviceURL identityService:(nullable SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore;

/**
 *  The service URL.
 */
@property (nonatomic, readonly, nullable) NSURL *serviceURL;

/**
 *  The service which identities are retrieved from.
 */
@property (nonatomic, readonly, nullable) SRGIdentityService *identityService;

/**
 *  The store where data is saved.
 */
@property (nonatomic, readonly) SRGDataStore *dataStore;

@end

NS_ASSUME_NONNULL_END
