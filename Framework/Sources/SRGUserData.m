//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserData.h"

#import "NSBundle+SRGUserData.h"
#import "SRGDataStore+Private.h"
#import "SRGHistory+Private.h"
#import "SRGHistoryEntry+Private.h"
#import "SRGUser+Private.h"

#import <libextobjc/libextobjc.h>

static SRGUserData *s_currentUserData = nil;

NSString *SRGUserDataMarketingVersion(void)
{
    return NSBundle.srg_userDataBundle.infoDictionary[@"CFBundleShortVersionString"];
}

@interface SRGUserData ()

@property (nonatomic) SRGDataStore *store;
@property (nonatomic) SRGHistory *history;

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

- (instancetype)initWithHistoryServiceURL:(NSURL *)historyServiceURL
                          identityService:(SRGIdentityService *)identityService
                                     name:(NSString *)name
                                directory:(NSString *)directory
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
        self.store = [[SRGDataStore alloc] initWithName:name directory:directory model:model];
        
        [self.store performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(SRGUser.class)];
            SRGUser *mainUser = [managedObjectContext executeFetchRequest:fetchRequest error:NULL].firstObject;
            if (! mainUser) {
                mainUser = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(SRGUser.class) inManagedObjectContext:managedObjectContext];
            }
            return YES;
        } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
            self.history = [[SRGHistory alloc] initWithServiceURL:historyServiceURL identityService:identityService dataStore:self.store];
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

- (void)dissociateWithCompletionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    [self.store cancelAllTasks];
    [self.store performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *mainUser = [SRGUser mainUserInManagedObjectContext:managedObjectContext];
        [mainUser detach];
        return YES;
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock ? completionBlock(error) : nil;
        });
    }];
}

- (void)clearWithCompletionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    __block NSSet<NSString *> *URNs = nil;
    
    [self.store cancelAllTasks];
    
    // TODO: History cleanup should be made in History.m
    [self.store performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *mainUser = [SRGUser mainUserInManagedObjectContext:managedObjectContext];
        if (mainUser) {
            NSArray<SRGHistoryEntry *> *historyEntries = [SRGHistoryEntry historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
            URNs = [historyEntries valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGHistoryEntry.new, mediaURN)]];
            
            [SRGHistoryEntry deleteAllInManagedObjectContext:managedObjectContext];
            [mainUser detach];
        }
        return YES;
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (URNs.count > 0) {
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryURNsKey : URNs.allObjects }];
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidClearNotification
                                                                  object:self
                                                                userInfo:nil];
            }
            completionBlock ? completionBlock(error) : nil;
        });
    }];
}

#pragma mark Notifications

- (void)userDidLogout:(NSNotification *)notification
{
    // TODO: Probably provide several modes for data cleanup on logout
    [self clearWithCompletionBlock:nil];
    
    [self.store performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *mainUser = [SRGUser mainUserInManagedObjectContext:managedObjectContext];
        [mainUser detach];
        return YES;
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:nil];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    SRGAccount *account = notification.userInfo[SRGIdentityServiceAccountKey];
    
    [self.store performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGUser *mainUser = [SRGUser mainUserInManagedObjectContext:managedObjectContext];
        [mainUser attachToAccountUid:account.uid];
        return YES;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:nil];
}

@end
