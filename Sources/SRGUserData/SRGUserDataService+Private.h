//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"
#import "SRGUserData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Private interface for implementation purposes.
 */
@interface SRGUserDataService (Private)

/**
 *  Instantiate a service retrieving data from the specified URL, for the specified `SRGUserData` instance.
 *
 *  If no service URL or if no user is logged in, the data will be kept locally only and no synchronization will be made.
 */
- (instancetype)initWithServiceURL:(NSURL *)serviceURL userData:(SRGUserData *)userData;

/**
 *  The service URL.
 */
@property (nonatomic, readonly, nullable) NSURL *serviceURL;

/**
 *  The user data instance which manages the service.
 */
@property (nonatomic, readonly, weak) SRGUserData *userData;

@end

NS_ASSUME_NONNULL_END
