//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGIdentity/SRGIdentity.h>

// Public headers.
#import "SRGHistory.h"
#import "SRGHistoryEntry.h"
#import "SRGPlaylist.h"
#import "SRGPlaylists.h"
#import "SRGUser.h"
#import "SRGUserDataError.h"
#import "SRGUserDataService.h"
#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

// TODO:
// 0) Proper completion block calls (synchronize with counter)
// 1) Have global sync notifications? (yes! with error info & emitter = service). Add UT (+ check error)
// 2) Replace sync method with two hooks pull / push returning errors? If possible, then return unauthorization
//    errors once at the top level
// 3) push / pull also for history data
// 4) UT
// 5) Refactor: Inherit from SRGUserObject. Remove tests now redundant.
// 6) Introduce mapping at SRGUserObject level (instead of uidKey)?

// Official version number.
FOUNDATION_EXPORT NSString *SRGUserDataMarketingVersion(void);

/**
 *  Notification sent when global synchronization has started.
 */
OBJC_EXPORT NSString * const SRGUserDataDidStartSynchronizationNotification;

/**
 *  Notification sent when global synchronization has finished.
 */
OBJC_EXPORT NSString * const SRGUserDataDidFinishSynchronizationNotification;

/**
 *  Manages data associated with a user. An identity service and service endpoints can be optionally provided, so that
 *  logged in users can synchronize their data with their account.
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
 *  Create a user data repository. The repository can be used to store data on device. Provided it is setup appropriately,
 *  logged in users can keep their data synchronized with their account.
 *
 *  @param storeFileURL    The file URL where the data is locally stored.
 *  @param serviceURL      The URL of the service with which user data can be synchronized. If none is provided, no user
 *                         data synchronization is made.
 *  @param identityService The service which identities can be retrieved from. If none, no data synchronization will
 *                         occur.
 */
- (nullable instancetype)initWithStoreFileURL:(NSURL *)storeFileURL
                                   serviceURL:(nullable NSURL *)serviceURL
                              identityService:(nullable SRGIdentityService *)identityService;

/**
 *  The user to which the data belongs. Might be offline or bound to a remote account.
 */
@property (nonatomic, readonly) SRGUser *user;

/**
 *  Access to the user playback history.
 */
@property (nonatomic, readonly) SRGHistory *history;

/**
 *  Access to the user playlists.
 */
@property (nonatomic, readonly) SRGPlaylists *playlists;

@end

NS_ASSUME_NONNULL_END
