//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserData.h"

#import "NSBundle+SRGUserData.h"
#import "NSTimer+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGHistory.h"
#import "SRGUser+Private.h"
#import "SRGUserDataLogger.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"
#import "SRGUserObject+Private.h"

#import <FXReachability/FXReachability.h>
#import <libextobjc/libextobjc.h>

static NSUInteger s_currentPersistentStoreVersion = 7;

typedef NSString * SRGUserDataServiceType NS_TYPED_ENUM;
static SRGUserDataServiceType const SRGUserDataServiceTypeHistory = @"History";
static SRGUserDataServiceType const SRGUserDataServiceTypePlaylists = @"Playlists";

static SRGUserData *s_currentUserData = nil;

NSString * const SRGUserDataDidStartSynchronizationNotification = @"SRGUserDataDidStartSynchronizationNotification";
NSString * const SRGUserDataDidFinishSynchronizationNotification = @"SRGUserDataDidFinishSynchronizationNotification";

NSString *SRGUserDataMarketingVersion(void)
{
    return NSBundle.srg_userDataBundle.infoDictionary[@"CFBundleShortVersionString"];
}

@interface SRGUserData ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) SRGIdentityService *identityService;

@property (nonatomic) SRGDataStore *dataStore;
@property (nonatomic) NSDictionary<SRGUserDataServiceType, SRGUserDataService *> *services;

@property (nonatomic, getter=isSynchronizing) BOOL synchronizing;
@property (nonatomic) NSTimer *synchronizationTimer;

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

- (instancetype)initWithStoreFileURL:(NSURL *)storeFileURL
                          serviceURL:(NSURL *)serviceURL
                     identityService:(SRGIdentityService *)identityService
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
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
        
        id<SRGPersistentContainer> persistentContainer = nil;
        if (@available(iOS 10, *)) {
            NSPersistentContainer *nativePersistentContainer = [NSPersistentContainer persistentContainerWithName:storeFileURL.lastPathComponent managedObjectModel:model];
            
            NSPersistentStoreDescription *persistentStoreDescription = [NSPersistentStoreDescription persistentStoreDescriptionWithURL:storeFileURL];
            persistentStoreDescription.shouldInferMappingModelAutomatically = NO;
            persistentStoreDescription.shouldMigrateStoreAutomatically = NO;
            nativePersistentContainer.persistentStoreDescriptions = @[ persistentStoreDescription ];
            
            persistentContainer = nativePersistentContainer;
        }
        else {
            persistentContainer = [[SRGPersistentContainer alloc] initWithFileURL:storeFileURL model:model];
        }
        
        __block BOOL success = YES;
        [persistentContainer srg_loadPersistentStoreWithCompletionHandler:^(NSError * _Nullable error) {
            if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSPersistentStoreIncompatibleVersionHashError) {
                BOOL migrated = [self migratePersistentStoreWithFileURL:storeFileURL];
                if (migrated) {
                    [persistentContainer srg_loadPersistentStoreWithCompletionHandler:^(NSError * _Nullable error) {
                        if (error) {
                            success = NO;
                            SRGUserDataLogError(@"user_data", @"Data store failed to load after migration. Reason: %@", error);
                        }
                    }];
                }
                else {
                    success = NO;
                    SRGUserDataLogError(@"user_data", @"Data store failed to load and no migration found. Reason: %@", error);
                }
            }
            else if (error) {
                success = NO;
                SRGUserDataLogError(@"user_data", @"Data store failed to load. Reason: %@", error);
            }
        }];
        
        if (! success) {
            return nil;
        }
        
        self.dataStore = [[SRGDataStore alloc] initWithPersistentContainer:persistentContainer];
        
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
            SRGUser *user = [SRGUser upsertInManagedObjectContext:managedObjectContext];
            
            // If an account is readily available, immediately bind it.
            NSString *accountUid = identityService.account.uid;
            if (accountUid) {
                [user attachToAccountUid:accountUid];
            }
        } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        NSMutableDictionary<SRGUserDataServiceType, SRGUserDataService *> *services = [NSMutableDictionary dictionary];
        
        NSURL *historyServiceURL = [serviceURL URLByAppendingPathComponent:@"history"];
        services[SRGUserDataServiceTypeHistory] = [[SRGHistory alloc] initWithServiceURL:historyServiceURL identityService:identityService dataStore:self.dataStore];
        
        NSURL *playlistsServiceURL = [serviceURL URLByAppendingPathComponent:@"playlist"];
        services[SRGUserDataServiceTypePlaylists] = [[SRGPlaylists alloc] initWithServiceURL:playlistsServiceURL identityService:identityService dataStore:self.dataStore];
        
        self.services = [services copy];
        
        if (serviceURL && identityService) {
            @weakify(self)
            self.synchronizationTimer = [NSTimer srguserdata_timerWithTimeInterval:60. repeats:YES block:^(NSTimer * _Nonnull timer) {
                @strongify(self)
                [self synchronize];
            }];
            [self synchronize];
        }
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidLogin:)
                                                   name:SRGIdentityServiceUserDidLoginNotification
                                                 object:identityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidLogout:)
                                                   name:SRGIdentityServiceUserDidLogoutNotification
                                                 object:identityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(didUpdateAccount:)
                                                   name:SRGIdentityServiceDidUpdateAccountNotification
                                                 object:identityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(reachabilityDidChange:)
                                                   name:FXReachabilityStatusDidChangeNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationWillEnterForeground:)
                                                   name:UIApplicationWillEnterForegroundNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationDidEnterBackground:)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
    }
    return self;
}

- (void)dealloc
{
    self.synchronizationTimer = nil;
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

- (SRGPlaylists *)playlists
{
    SRGUserDataService *playlist = self.services[SRGUserDataServiceTypePlaylists];
    NSAssert([playlist isKindOfClass:SRGPlaylists.class], @"Playlist service expected");
    return (SRGPlaylists *)playlist;
}

- (void)setSynchronizationTimer:(NSTimer *)synchronizationTimer
{
    [_synchronizationTimer invalidate];
    _synchronizationTimer = synchronizationTimer;
}

#pragma mark Migration

- (BOOL)migratePersistentStoreWithFileURL:(NSURL *)fileURL
{
    NSUInteger fromVersion = s_currentPersistentStoreVersion - 1;
    while (fromVersion > 0) {
        if ([self migratePersistentStoreWithFileURL:fileURL fromVersion:fromVersion]) {
            return YES;
        }
        fromVersion--;
    }
    return NO;
}

- (BOOL)migratePersistentStoreWithFileURL:(NSURL *)fileURL fromVersion:(NSUInteger)fromVersion
{
    NSUInteger toVersion = fromVersion + 1;
    
    NSString *mappingModelFilePath = [NSBundle.srg_userDataBundle pathForResource:[NSString stringWithFormat:@"SRGUserData_v%@_v%@", @(fromVersion), @(toVersion)] ofType:@"cdm"];
    if (! mappingModelFilePath) {
        return NO;
    }
    NSURL *mappingModelFileURL = [NSURL fileURLWithPath:mappingModelFilePath];
    NSMappingModel *mappingModel = [[NSMappingModel alloc] initWithContentsOfURL:mappingModelFileURL];
    
    NSString *sourceModelFilePath = [NSBundle.srg_userDataBundle pathForResource:[NSString stringWithFormat:@"SRGUserData_v%@", @(fromVersion)] ofType:@"mom" inDirectory:@"SRGUserData.momd"];
    if (! sourceModelFilePath) {
        return NO;
    }
    NSURL *sourceModelFileURL = [NSURL fileURLWithPath:sourceModelFilePath];
    NSManagedObjectModel *sourceModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:sourceModelFileURL];
    
    NSString *destinationModelFilePath = [NSBundle.srg_userDataBundle pathForResource:[NSString stringWithFormat:@"SRGUserData_v%@", @(toVersion)] ofType:@"mom" inDirectory:@"SRGUserData.momd"];
    if (! destinationModelFilePath) {
        return NO;
    }
    NSURL *destinationeModelFileURL = [NSURL fileURLWithPath:destinationModelFilePath];
    NSManagedObjectModel *destinationModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:destinationeModelFileURL];
    
    NSString *migratedLastPathComponent = [fileURL.lastPathComponent stringByAppendingString:@"-migrated"];
    NSURL *migratedFileURL = [fileURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:migratedLastPathComponent];
    
    NSMigrationManager *migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel destinationModel:destinationModel];
    BOOL migrated = [migrationManager migrateStoreFromURL:fileURL
                                                     type:NSSQLiteStoreType
                                                  options:nil
                                         withMappingModel:mappingModel
                                         toDestinationURL:migratedFileURL
                                          destinationType:NSSQLiteStoreType
                                       destinationOptions:nil
                                                    error:NULL];
    if (! migrated) {
        return NO;
    }
    
    if (! [NSFileManager.defaultManager replaceItemAtURL:fileURL
                                           withItemAtURL:migratedFileURL
                                          backupItemName:nil
                                                 options:NSFileManagerItemReplacementUsingNewMetadataOnly
                                        resultingItemURL:NULL
                                                   error:NULL]) {
        return NO;
    }
    
    if (toVersion < s_currentPersistentStoreVersion) {
        return [self migratePersistentStoreWithFileURL:fileURL fromVersion:toVersion];
    }
    else {
        return YES;
    }
}

#pragma mark Synchronization

- (void)synchronize
{
    if (self.synchronizing || ! self.serviceURL) {
        return;
    }
    
    if (! self.identityService.loggedIn) {
        return;
    }
    
    self.synchronizing = YES;
    
    SRGUserDataLogInfo(@"user_data", @"Started synchronization");
    
    NSAssert(NSThread.isMainThread, @"Expected to be called on the main thread");
    [NSNotificationCenter.defaultCenter postNotificationName:SRGUserDataDidStartSynchronizationNotification object:self];
    
    __block NSUInteger remainingServiceCount = self.services.count;
    [self.services enumerateKeysAndObjectsUsingBlock:^(SRGUserDataServiceType _Nonnull type, SRGUserDataService * _Nonnull service, BOOL * _Nonnull stop) {
        SRGUserDataLogInfo(@"user_data", @"Started synchronization for service %@", service);
        
        [service synchronizeWithCompletionBlock:^(NSError * _Nullable error) {
            NSCAssert(self.synchronizing, @"Must be synchronizing");
            
            --remainingServiceCount;
            if (remainingServiceCount == 0) {
                [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    SRGUser *user = [SRGUser userInManagedObjectContext:managedObjectContext];
                    user.synchronizationDate = NSDate.date;
                } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
                    self.synchronizing = NO;
                    
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [NSNotificationCenter.defaultCenter postNotificationName:SRGUserDataDidFinishSynchronizationNotification object:self];
                    });
                    
                    SRGUserDataLogInfo(@"user_data", @"Finished synchronization");
                }];
            }
            
            SRGUserDataLogInfo(@"user_data", @"Finished synchronization for service %@", service);
        }];
    }];
}

#pragma mark Notifications

- (void)userDidLogin:(NSNotification *)notification
{
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        [self.services enumerateKeysAndObjectsUsingBlock:^(SRGUserDataServiceType _Nonnull type, SRGUserDataService * _Nonnull service, BOOL * _Nonnull stop) {
            NSArray<SRGUserObject *> *objects = [service userObjectsInManagedObjectContext:managedObjectContext];
            for (SRGUserObject *object in objects) {
                object.dirty = YES;
            }
        }];
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self synchronize];
        });
    }];
}

- (void)userDidLogout:(NSNotification *)notification
{
    [self.dataStore cancelAllBackgroundTasks];
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *mainUser = [SRGUser userInManagedObjectContext:managedObjectContext];
        [mainUser detach];
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        BOOL unexpectedLogout = [notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue];
        [self.services enumerateKeysAndObjectsUsingBlock:^(SRGUserDataServiceType _Nonnull type, SRGUserDataService * _Nonnull service, BOOL * _Nonnull stop) {
            [service cancelSynchronization];
            
            if (! unexpectedLogout) {
                [service clearData];
            }
        }];
    }];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    SRGAccount *account = notification.userInfo[SRGIdentityServiceAccountKey];
    
    [self.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *user = [SRGUser userInManagedObjectContext:managedObjectContext];
        [user attachToAccountUid:account.uid];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:nil];
}

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

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self synchronize];
}

@end
