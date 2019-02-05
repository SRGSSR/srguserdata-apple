//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserData.h"

#import "NSBundle+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGHistoryEntry+Private.h"
#import "SRGUser+Private.h"
#import "SRGUserDataService+Subclassing.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>

static SRGUserData *s_currentUserData = nil;

NSString *SRGUserDataMarketingVersion(void)
{
    return NSBundle.srg_userDataBundle.infoDictionary[@"CFBundleShortVersionString"];
}

@interface SRGUserData ()

@property (nonatomic) SRGDataStore *dataStore;
@property (nonatomic) NSArray<SRGUserDataService *> *services;

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
                                   name:(NSString *)name
                              directory:(NSString *)directory
                           configurator:(SRGUserDataServiceConfigurator)configurator
{
    if (self = [super init]) {
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
        self.dataStore = [[SRGDataStore alloc] initWithName:name directory:directory model:model];
        
        [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(SRGUser.class)];
            SRGUser *mainUser = [managedObjectContext executeFetchRequest:fetchRequest error:NULL].firstObject;
            if (! mainUser) {
                mainUser = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(SRGUser.class) inManagedObjectContext:managedObjectContext];
            }
            return YES;
        } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
            self.services = configurator(identityService, self.dataStore);
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

#pragma mark Public methods

- (void)dissociateWithCompletionBlock:(void (^)(void))completionBlock
{
    [self.dataStore cancelAllBackgroundTasks];
    
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *mainUser = [SRGUser mainUserInManagedObjectContext:managedObjectContext];
        [mainUser detach];
        return YES;
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        completionBlock ? completionBlock() : nil;
    }];
}

- (void)clearWithCompletionBlock:(void (^)(void))completionBlock
{
    [self.dataStore cancelAllBackgroundTasks];
    
    dispatch_async(dispatch_queue_create("ch.srgssr.userdata.clear", NULL), ^{
        dispatch_group_t group = dispatch_group_create();
        for (SRGUserDataService *service in self.services) {
            dispatch_group_enter(group);
            [service clearDataWithCompletionBlock:^{
                dispatch_group_leave(group);
            }];
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        [self dissociateWithCompletionBlock:completionBlock];
    });
}

#pragma mark History

- (NSArray<SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return [self.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    }];
}

- (void)historyEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGHistoryEntry *> * _Nonnull))completionBlock
{
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (void)saveHistoryEntryForURN:(NSString *)URN withLastPlaybackTime:(CMTime)lastPlaybackTime deviceName:(NSString *)deviceName completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry upsertWithURN:URN inManagedObjectContext:managedObjectContext];
        historyEntry.lastPlaybackTime = lastPlaybackTime;
        historyEntry.deviceName = deviceName;
        return YES;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryURNsKey : @[ URN ] }];
            });
        }
    }];
}

#pragma mark Notifications

- (void)userDidLogout:(NSNotification *)notification
{
    void (^detachUser)(void) = ^{
        [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
            SRGUser *mainUser = [SRGUser mainUserInManagedObjectContext:managedObjectContext];
            [mainUser detach];
            return YES;
        } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:nil];
    };
    
    BOOL unexpectedLogout = [notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue];
    if (! unexpectedLogout) {
        [self clearWithCompletionBlock:detachUser];
    }
    else {
        detachUser();
    }
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    SRGAccount *account = notification.userInfo[SRGIdentityServiceAccountKey];
    
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *mainUser = [SRGUser mainUserInManagedObjectContext:managedObjectContext];
        [mainUser attachToAccountUid:account.uid];
        return YES;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:nil];
}

@end
