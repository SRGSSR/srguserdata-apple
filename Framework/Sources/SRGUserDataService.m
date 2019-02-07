//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

#import "NSTimer+SRGUserData.h"
#import "SRGDataStore.h"

#import <FXReachability/FXReachability.h>
#import <libextobjc/libextobjc.h>
#import <SRGIdentity/SRGIdentity.h>

@interface SRGUserDataService ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGDataStore *dataStore;

@property (nonatomic, getter=isSynchronizing) BOOL synchronizing;
@property (nonatomic) NSTimer *synchronizationTimer;

@end

@implementation SRGUserDataService

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        self.identityService = identityService;
        self.dataStore = dataStore;
        
        // TODO: Make sync interval a service property
        @weakify(self)
        self.synchronizationTimer = [NSTimer srguserdata_timerWithTimeInterval:60. repeats:YES block:^(NSTimer * _Nonnull timer) {
            @strongify(self)
            [self synchronize];
        }];
        [self synchronize];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(reachabilityDidChange:)
                                                   name:FXReachabilityStatusDidChangeNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationWillEnterForeground:)
                                                   name:UIApplicationWillEnterForegroundNotification
                                                 object:nil];
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

- (void)dealloc
{
    self.synchronizationTimer = nil;
}

#pragma mark Getters and setters

- (void)setSynchronizationTimer:(NSTimer *)synchronizationTimer
{
    [_synchronizationTimer invalidate];
    _synchronizationTimer = synchronizationTimer;
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

- (void)clearDataWithCompletionBlock:(void (^)(void))completionBlock
{
    completionBlock();
}

#pragma mark Public methods

- (void)synchronize
{
    if (self.synchronizing) {
        return;
    }
    
    if (! self.identityService.isLoggedIn) {
        return;
    }
    
    self.synchronizing = YES;
    [self synchronizeWithCompletionBlock:^{
        self.synchronizing = NO;
    }];
}

#pragma mark Notifications

- (void)reachabilityDidChange:(NSNotification *)notification
{
    if ([FXReachability sharedInstance].reachable) {
        [self synchronize];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self synchronize];
}

- (void)userDidLogin:(NSNotification *)notification
{
    [self userDidLogin];
}

- (void)userDidLogout:(NSNotification *)notification
{
    [self userDidLogout];
}

@end
