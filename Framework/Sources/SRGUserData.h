//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <SRGIdentity/SRGIdentity.h>

// Public headers.
#import "SRGDataStore.h"
#import "SRGHistory.h"
#import "SRGHistoryEntry.h"
#import "SRGUser.h"

NS_ASSUME_NONNULL_BEGIN

// Official version number.
FOUNDATION_EXPORT NSString *SRGUserDataMarketingVersion(void);

@interface SRGUserData : NSObject

@property (class, nonatomic, nullable) SRGUserData *currentUserData;

@property (nonatomic, readonly) SRGHistory *history;
@property (nonatomic, readonly) SRGDataStore *store;

// TODO: Configuration object for URLs?
- (instancetype)initWithHistoryServiceURL:(NSURL *)historyServiceURL
                          identityService:(SRGIdentityService *)identityService
                                     name:(NSString *)name
                                directory:(NSString *)directory;

- (void)dissociateWithCompletionBlock:(void (^ _Nullable)(NSError * _Nullable error))completionBlock;
- (void)clearWithCompletionBlock:(void (^ _Nullable)(NSError * _Nullable error))completionBlock;

@end

NS_ASSUME_NONNULL_END
