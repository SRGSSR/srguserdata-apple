//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <SRGIdentity/SRGIdentity.h>

// Public headers.

// TODO: Hide completely
#import "SRGDataStore.h"

#import "SRGHistory.h"
#import "SRGHistoryEntry.h"
#import "SRGUser.h"
#import "SRGUserDataService.h"
#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

// Official version number.
FOUNDATION_EXPORT NSString *SRGUserDataMarketingVersion(void);

typedef NSArray<SRGUserDataService *> * (^SRGUserDataServiceConfigurator)(SRGIdentityService *identityService, SRGDataStore *dataStore);

@interface SRGUserData : NSObject

@property (class, nonatomic, nullable) SRGUserData *currentUserData;

- (instancetype)initWithIdentityService:(SRGIdentityService *)identityService
                                   name:(NSString *)name
                              directory:(NSString *)directory
                           configurator:(SRGUserDataServiceConfigurator)configurator;

@property (nonatomic, readonly) SRGDataStore *dataStore;

// Completion blocks called on background threads
- (void)dissociateWithCompletionBlock:(void (^ _Nullable)(void))completionBlock;
- (void)clearWithCompletionBlock:(void (^ _Nullable)(void))completionBlock;

@end

@interface SRGUserData (History)

- (NSArray<__kindof SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                                                   sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors;

- (void)historyEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                  sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                        completionBlock:(void (^)(NSArray<SRGHistoryEntry *> *historyEntries))completionBlock;

- (void)saveHistoryEntryForURN:(NSString *)URN
      withLastPlaybackPosition:(CMTime)lastPlaybackPosition
                    deviceName:(nullable NSString *)deviceName
               completionBlock:(nullable void (^)(NSError *error))completionBlock;

@end

NS_ASSUME_NONNULL_END
