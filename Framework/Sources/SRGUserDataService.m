//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

#import "SRGDataStore.h"

#import <libextobjc/libextobjc.h>
#import <SRGIdentity/SRGIdentity.h>

@interface SRGUserDataService ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGDataStore *dataStore;

@end

@implementation SRGUserDataService

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        self.identityService = identityService;
        self.dataStore = dataStore;
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidLogin:)
                                                   name:SRGIdentityServiceUserDidLoginNotification
                                                 object:identityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidLogout:)
                                                   name:SRGIdentityServiceUserDidLogoutNotification
                                                 object:identityService];
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithServiceURL:[NSURL new] identityService:[SRGIdentityService new] dataStore:[SRGDataStore new]];
}

#pragma mark Subclassing hooks

- (void)synchronizeWithCompletionBlock:(void (^)(void))completionBlock
{
    completionBlock();
}

- (void)userDidLogin
{}

- (void)userDidLogout
{}

- (void)clearData
{}

#pragma mark Notifications

- (void)userDidLogin:(NSNotification *)notification
{
    [self userDidLogin];
}

- (void)userDidLogout:(NSNotification *)notification
{
    [self userDidLogout];
}

@end
