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

- (instancetype)initWithHistoryServiceURL:(NSURL *)historyServiceURL
                          identityService:(SRGIdentityService *)identityService
                                     name:(NSString *)name
                                directory:(NSString *)directory
{
    if (self = [super init]) {
        NSString *modelFilePath = [NSBundle.srg_userDataBundle pathForResource:@"SRGUserData" ofType:@"momd"];
        NSAssert(modelFilePath, @"The model is missing");
        
        NSURL *modelFileURL = [NSURL fileURLWithPath:modelFilePath];
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelFileURL];
        self.dataStore = [[SRGDataStore alloc] initWithName:name directory:directory model:model];
        
        [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
            SRGUser *mainUser = [managedObjectContext executeFetchRequest:SRGUser.fetchRequest error:NULL].firstObject;
            if (! mainUser) {
                mainUser = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(SRGUser.class) inManagedObjectContext:managedObjectContext];
            }
            return YES;
        } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:nil];
        
        self.history = [[SRGHistory alloc] initWithServiceURL:historyServiceURL identityService:identityService dataStore:self.dataStore];
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
