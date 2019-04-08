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

// Official version number.
FOUNDATION_EXPORT NSString *SRGUserDataMarketingVersion(void);

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
 *  @param storeFileURL        The file URL where the data is locally stored.
 *  @param identityService     The service which identities can be retrieved from. If none, no data synchronization will
 *                             occur.
 *  @param historyServiceURL   The URL of the service with which local history information can be synchronized. If none
 *                             is provided, no history data synchronization will occur.
 *  @param playlistsServiceURL The URL of the service with which local playlists information can be synchronized. If none
 *                             is provided, no playlist data synchronization will occur.
 */
- (nullable instancetype)initWithStoreFileURL:(NSURL *)storeFileURL
                            historyServiceURL:(nullable NSURL *)historyServiceURL
                          playlistsServiceURL:(nullable NSURL *)playlistsServiceURL
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
