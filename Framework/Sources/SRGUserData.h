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

/**
 *  Manages data associated with a user, either offline or logged in using SRG Identity. For logged in users,
 *  playback history is transparently kept synchronized with the corresponding remote service.
 *
 *  Several instances can coexist in an application, though in general one should suffice. This global instance
 *  can be accessed easily from anywhere by assigning it to the `currentUserData` class property.
 */
@interface SRGUserData : NSObject

/**
 *  The instance currently set as shared instance, if any.
 */
@property (class, nonatomic, nullable) SRGUserData *currentUserData;

// TODO: URL conxfiguration object
- (instancetype)initWithIdentityService:(nullable SRGIdentityService *)identityService
                      historyServiceURL:(nullable NSURL *)historyServiceURL
                                   name:(NSString *)name
                              directory:(NSString *)directory;

@property (nonatomic, readonly) SRGUser *user;

@property (nonatomic, readonly, nullable) SRGHistory *history;

// Completion blocks called on background threads
- (void)dissociateWithCompletionBlock:(void (^ _Nullable)(void))completionBlock;
- (void)clearWithCompletionBlock:(void (^ _Nullable)(void))completionBlock;

@end

NS_ASSUME_NONNULL_END
