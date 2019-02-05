//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGDataStore.h"

#import <Foundation/Foundation.h>
#import <SRGIdentity/SRGIdentity.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRGUserDataService : NSObject

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSURL *serviceURL;
@property (nonatomic, readonly) SRGIdentityService *identityService;
@property (nonatomic, readonly) SRGDataStore *dataStore;

@end

NS_ASSUME_NONNULL_END
