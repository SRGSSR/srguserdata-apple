//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserData.h"

#import "NSBundle+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGHistory.h"
#import "SRGUser+Private.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"
#import "SRGUserObject+Private.h"

#import <libextobjc/libextobjc.h>

typedef NSString * SRGUserDataServiceType NS_TYPED_ENUM;
static SRGUserDataServiceType const SRGUserDataServiceTypeHistory = @"History";

static SRGUserData *s_currentUserData = nil;

NSString *SRGUserDataMarketingVersion(void)
{
    return NSBundle.srg_userDataBundle.infoDictionary[@"CFBundleShortVersionString"];
}

@interface SRGUserData ()

@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGDataStore *dataStore;
@property (nonatomic) NSDictionary<SRGUserDataServiceType, SRGUserDataService *> *services;

@end

@implementation SRGUserData

#pragma mark Class methods

+ (SRGUserData *)currentUserData
{
    return s_currentUserData;
}

+ (void)setCurrentUserData:(SRGUserData *)currentUserData
{
    s_currentUserData = currentUserData;
}

#pragma mark Object lifecycle

- (instancetype)initWithIdentityService:(SRGIdentityService *)identityService
                      historyServiceURL:(NSURL *)historyServiceURL
                           storeFileURL:(NSURL *)storeFileURL
{
    if (self = [super init]) {
        self.identityService = identityService;
        
        // Bundling the model file in a resource bundle requires a few things:
        //  - Code generation with categories must not be enabled.
        //  - At least one class must use class code generation (see https://forums.developer.apple.com/thread/107819)
        //    to suppress warnings, if we want to stick with Xcode new build system.
        // If no class wants to use code generation, a dummy class can be used (`SRGUserDataDummyClassForWarningSuppression`
        // in our model).
        NSString *modelFilePath = [NSBundle.srg_userDataBundle pathForResource:@"SRGUserData" ofType:@"momd"];
        NSAssert(modelFilePath, @"The model is missing");
        
        NSURL *modelFileURL = [NSURL fileURLWithPath:modelFilePath];
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelFileURL];
        self.dataStore = [[SRGDataStore alloc] initWithFileURL:storeFileURL model:model];
        
        [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
            [SRGUser upsertInManagedObjectContext:managedObjectContext];
            return YES;
        } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
            NSMutableDictionary<SRGUserDataServiceType, SRGUserDataService *> *services = [NSMutableDictionary dictionary];
            services[SRGUserDataServiceTypeHistory] = [[SRGHistory alloc] initWithServiceURL:historyServiceURL identityService:identityService dataStore:self.dataStore];
            self.services = [services copy];
        }];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidLogout:)
                                                   name:SRGIdentityServiceUserDidLogoutNotification
                                                 object:identityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(didUpdateAccount:)
                                                   name:SRGIdentityServiceDidUpdateAccountNotification
                                                 object:identityService];
    }
    return self;
}

#pragma mark Getters and setters

- (SRGUser *)user
{    
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    }];
}

- (SRGHistory *)history
{
    SRGUserDataService *history = self.services[SRGUserDataServiceTypeHistory];
    NSAssert([history isKindOfClass:SRGHistory.class], @"History service expected");
    return (SRGHistory *)history;
}

#pragma mark Notifications

- (void)userDidLogout:(NSNotification *)notification
{
    [self.dataStore cancelAllBackgroundTasks];
    
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *mainUser = [SRGUser userInManagedObjectContext:managedObjectContext];
        [mainUser detach];
        return YES;
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        BOOL unexpectedLogout = [notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue];
        if (! unexpectedLogout) {
            [self.services enumerateKeysAndObjectsUsingBlock:^(SRGUserDataServiceType _Nonnull type, SRGUserDataService * _Nonnull service, BOOL * _Nonnull stop) {
                [service clearData];
            }];
        }
    }];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    SRGAccount *account = notification.userInfo[SRGIdentityServiceAccountKey];
    
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *mainUser = [SRGUser userInManagedObjectContext:managedObjectContext];
        [mainUser attachToAccountUid:account.uid];
        return YES;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:nil];
}

@end
