//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <SRGIdentity/SRGIdentity.h>

// Public headers.
#import "SRGHistory.h"
#import "SRGHistoryEntry.h"
#import "SRGUser.h"
#import "SRGUserDataService.h"
#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

// Official version number.
FOUNDATION_EXPORT NSString *SRGUserDataMarketingVersion(void);

@interface SRGUserData : NSObject

@property (class, nonatomic, nullable) SRGUserData *currentUserData;

// TODO: URL configuration object
- (instancetype)initWithIdentityService:(SRGIdentityService *)identityService
                      historyServiceURL:(nullable NSURL *)historyServiceURL
                                   name:(NSString *)name
                              directory:(NSString *)directory;

@property (nonatomic, readonly, nullable) SRGHistory *history;

// Completion blocks called on background threads
- (void)dissociateWithCompletionBlock:(void (^ _Nullable)(void))completionBlock;
- (void)clearWithCompletionBlock:(void (^ _Nullable)(void))completionBlock;

@end

NS_ASSUME_NONNULL_END
