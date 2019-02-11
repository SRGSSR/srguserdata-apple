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
 *  data is transparently kept synchronized with the corresponding remote service.
 *
 *  Several instances of `SRGUserData` can coexist in an application, though in general one should suffice. This
 *  global instance can be accessed easily from anywhere by assigning it to the `currentUserData` class property
 *  first.
 */
@interface SRGUserData : NSObject

/**
 *  The instance currently set as shared instance, if any.
 */
@property (class, nonatomic, nullable) SRGUserData *currentUserData;

/**
 *  Create a user data repository, which optionally can be synced with the specified identity service.
 *
 *  @param storeFileURL The file URL where the data will be stored.
 */
- (instancetype)initWithIdentityService:(nullable SRGIdentityService *)identityService
                      historyServiceURL:(nullable NSURL *)historyServiceURL
                           storeFileURL:(NSURL *)storeFileURL;

/**
 *  The user to which the data belongs. Might be offline or bound to a remote account.
 */
@property (nonatomic, readonly) SRGUser *user;

/**
 *  Access to playback history for the user.
 */
@property (nonatomic, readonly, nullable) SRGHistory *history;

@end

NS_ASSUME_NONNULL_END
