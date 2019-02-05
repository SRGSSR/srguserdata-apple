//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

@interface SRGUserDataService ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGDataStore *dataStore;

@end

@implementation SRGUserDataService

- (instancetype)initWithServiceURL:(NSURL *)serviceURL
                   identityService:(SRGIdentityService *)identityService
                         dataStore:(SRGDataStore *)dataStore
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        self.identityService = identityService;
        self.dataStore = dataStore;
        
        // TODO: Register for notifications, provide hooks (login, logout, user update). Manage sync timer
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithServiceURL:[NSURL new] identityService:[SRGIdentityService new] dataStore:[SRGDataStore new]];
}

@end
