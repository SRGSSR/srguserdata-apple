//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

#import <SRGIdentity/SRGIdentity.h>

@interface SRGUserDataService (Subclassing)

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore;

@property (nonatomic, readonly) NSURL *serviceURL;
@property (nonatomic, readonly) SRGIdentityService *identityService;
@property (nonatomic, readonly) SRGDataStore *dataStore;

- (void)synchronize;

@end

@interface SRGUserDataService (SubclassingHooks)

- (void)synchronizeWithCompletionBlock:(void (^)(void))completionBlock;

- (void)userDidLogin;
- (void)userDidLogout;

- (void)clearDataWithCompletionBlock:(void (^)(void))completionBlock;

@end
