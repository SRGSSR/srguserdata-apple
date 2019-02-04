//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserData.h"

#import "NSBundle+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGHistory.h"
#import "SRGHistoryEntry.h"
#import "SRGUser.h"

#import <libextobjc/libextobjc.h>

static SRGUserData *s_currentUserData = nil;

NSString *SRGUserDataMarketingVersion(void)
{
    return NSBundle.srg_userDataBundle.infoDictionary[@"CFBundleShortVersionString"];
}

@interface SRGUserData ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGDataStore *dataStore;
@property (nonatomic) SRGHistory *history;

@end

@implementation SRGUserData

+ (SRGUserData *)currentUserData
{
    return s_currentUserData;
}

+ (void)setCurrentUserData:(SRGUserData *)currentUserData
{
    s_currentUserData = currentUserData;
}

- (instancetype)initWithServiceURL:(NSURL *)serviceURL
                   identityService:(SRGIdentityService *)identityService
                              name:(NSString *)name
                         directory:(NSString *)directory
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        self.identityService = identityService;
        
        // TODO: Instantiate model
        NSManagedObjectModel *model = nil;
        self.dataStore = [[SRGDataStore alloc] initWithName:name directory:directory model:model];
        
        // TODO: Build from service URL
        NSURL *historyServiceURL = nil;
        self.history = [[SRGHistory alloc] initWithServiceURL:historyServiceURL identityService:self.identityService dataStore:self.dataStore];
    }
    return self;
}

- (void)dissociateWithCompletionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    [self.dataStore cancelAllTasks];
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
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
    
    [self.dataStore cancelAllTasks];
    
    // TODO: History cleanup should be made in history files
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
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

@end
