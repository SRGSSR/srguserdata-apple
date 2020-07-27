//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import SRGUserData;
@import XCTest;

NS_ASSUME_NONNULL_BEGIN

/**
 *  The URL of the history service.
 */
OBJC_EXPORT NSURL *TestHistoryServiceURL(void);

/**
 *  The URL of the playlists service.
 */
OBJC_EXPORT NSURL *TestPlaylistsServiceURL(void);

/**
 *  Base class for user data tests. Provides helpers to create a user data store and to perform remote insertions
 *  or deletions for synchronization test purposes. Setup is reset at the end of each test.
 */
@interface UserDataBaseTestCase : XCTestCase

/**
 *  The identity service available for tests.
 */
@property (nonatomic, readonly) SRGIdentityService *identityService;

/**
 *  The data store to use for tests (if any has been setup).
 */
@property (nonatomic, readonly, nullable) SRGUserData *userData;

/**
 *  Setup and teardown subclassing hooks.
 */
- (void)setUp NS_REQUIRES_SUPER;
- (void)tearDown NS_REQUIRES_SUPER;

@end

/**
 *  Useful expectations.
 */
@interface UserDataBaseTestCase (Expectations)

/**
 *  Replacement for the buggy `-expectationForSingleNotification:object:handler:`, catching notifications only once.
 *  See http://openradar.appspot.com/radar?id=4976563959365632.
 */
- (XCTestExpectation *)expectationForSingleNotification:(NSNotificationName)notificationName object:(nullable id)objectToObserve handler:(nullable XCNotificationExpectationHandler)handler;

/**
 *  Expectation fulfilled after some given time interval (in seconds), calling the optionally provided handler. Can
 *  be useful for ensuring nothing unexpected occurs during some time
 */
- (XCTestExpectation *)expectationForElapsedTimeInterval:(NSTimeInterval)timeInterval withHandler:(nullable void (^)(void))handler;

@end

/**
 *  Data store generation for data-store related tests.
 */
@interface UserDataBaseTestCase (DataStoreGeneration)

/**
 *  Return a file URL for a test empty stored with the specified name.
 *
 *  @param package If a package is provided, files located in the specified test bundle directory will be used to
 *                 initially prepare the store in a known state. If no package is provided, an empty store URL is
 *                 returned.
 */
- (NSURL *)URLForStoreFromPackage:(nullable NSString *)package;

@end

/**
 *  User data setup.
 */
@interface UserDataBaseTestCase (UserDataGeneration)

/**
 *  Setup test conditions for offline mode only.
 */
- (void)setupForOfflineOnly;

/**
 *  Setup test conditions with a valid available user data service.
 */
- (void)setupForAvailableService;

/**
 *  Setup test conditions for an unavailable user data service (404).
 */
- (void)setupForUnavailableService;

@end

/**
 *  Session management.
 */
@interface UserDataBaseTestCase (SessionManagement)

/**
 *  Subclasses must implement this method to provide a meaningful token to associate with the user. By default none
 *  is provided. Attempting to use methods which need a token will fail with a test assertion.
 */
@property (nonatomic, readonly, nullable) NSString *sessionToken;

/**
 *  Trigger a login. Do not wait for the login to be complete.
 */
- (void)login;

/**
 *  Login a test user with SRG Identity, associating it with the provided session token. Wait until login has been made.
 */
- (void)loginAndWait;

/**
 *  Login a test user, perform an initial synchronization and wait until it finishes.
 */
- (void)loginAndWaitForInitialSynchronization;

/**
 *  Logout the current user.
 */
- (void)logout;

/**
 *  Synchronize user data.
 */
- (void)synchronize;

/**
 *  Synchronize user data and wait until the process finishes.
 */
- (void)synchronizeAndWait;

/**
 *  Remotely all data associated with the user whose session token is provided.
 */
- (void)eraseRemoteDataAndWait;

@end

/**
 *  History test data creation on the remote user data service.
 */
@interface UserDataBaseTestCase (HistoryRemoteTestData)

/**
 *  Insert remote history entries with the specified uids. Wait until the operation finishes.
 */
- (void)insertRemoteHistoryEntriesWithUids:(NSArray<NSString *> *)uids;

/**
 *  Discard the remote history entries having the specified identifiers. Wait until deletion is successful.
 */
- (void)discardRemoteHistoryEntriesWithUids:(NSArray<NSString *> *)uids;

/**
 *  Assert that the remote history entries match a specific list (order is ignored).
 */
- (void)assertRemoteHistoryUids:(NSArray<NSString *> *)uids;

@end

/**
 *  History test data creation on the local device.
 */
@interface UserDataBaseTestCase (HistoryLocalTestData)

/**
 *  Insert local history entries with the specified uids. Wait until the operation finishes.
 */
- (void)insertLocalHistoryEntriesWithUids:(NSArray<NSString *> *)uids;

/**
 *  Discard the local history entries having the specified identifiers. Wait until deletion is successful.
 */
- (void)discardLocalHistoryEntriesWithUids:(NSArray<NSString *> *)uids;

/**
 *  Assert that the local history entries match a specific list (order is ignored).
 */
- (void)assertLocalHistoryUids:(NSArray<NSString *> *)uids;

@end

/**
 *  Playlist test data creation on the remote user data service.
 */
@interface UserDataBaseTestCase (PlaylistRemoteTestData)

/**
 *  Insert a remote playlist with the specified identifier. Wait until the operation finishes.
 */
- (void)insertRemotePlaylistWithUid:(NSString *)uid;

/**
 *  Insert a remote playlist entry for a specific playlist. Wait until the operation finishes.
 */
- (void)insertRemotePlaylistEntriesWithUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid;

/**
 *  Discard the remote playlists having the specified identifiers. Wait until the operation finishes.
 */
- (void)discardRemotePlaylistsWithUids:(NSArray<NSString *> *)uids;

/**
 *  Discard remote entries for a specific playlist identifier. Wait until the operation finishes.
 */
- (void)discardRemotePlaylistEntriesWithUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid;

/**
 *  Assert that the the current remote playlist identifiers match a specific list (order is ignored). System playlists
 *  are added automatically to the list of uids (and therefore checked as well).
 */
- (void)assertRemotePlaylistUids:(NSArray<NSString *> *)uids;

/**
 *  Assert that the remote entry identifiers for a specific playlist match a specific list (order is ignored).
 */
- (void)assertRemotePlaylistEntriesUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid;

@end

/**
 *  Playlist test data creation on the local device.
 */
@interface UserDataBaseTestCase (PlaylistLocalTestData)

/**
 *  Insert a local playlist with the specified identifier. Wait until the operation finishes.
 */
- (void)insertLocalPlaylistWithUid:(NSString *)uid;

/**
 *  Insert a local playlist entry for a specific playlist. Wait until the operation finishes.
 */
- (void)insertLocalPlaylistEntriesWithUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid;

/**
 *  Discard the local playlists having the specified identifiers. Wait until the operation finishes.
 */
- (void)discardLocalPlaylistsWithUids:(NSArray<NSString *> *)uids;

/**
 *  Discard local entries for a specific playlist identifier. Wait until the operation finishes.
 */
- (void)discardLocalPlaylistEntriesWithUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid;

/**
 *  Assert that the the current local playlist identifiers match a specific list (order is ignored). System playlists
 *  are added automatically to the list of uids (and therefore checked as well).
 */
- (void)assertLocalPlaylistUids:(NSArray<NSString *> *)uids;

/**
 *  Assert that the local entry identifiers for a specific playlist match a specific list (order is ignored).
 */
- (void)assertLocalPlaylistEntriesUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid;

@end

/**
 *  Preferences test data creation on the remote user data service.
 */
@interface UserDataBaseTestCase (PreferencesRemoteTestData)

/**
 *  Insert a remote preference.
 */
- (void)insertRemotePreferenceWithObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain;

/**
 *  Discard a remote preference.
 */
- (void)discardRemotePreferenceAtPath:(NSString *)path inDomain:(NSString *)domain;

/**
 *  Assert that remote preferences match a specific dictionary.
 */
- (void)assertRemotePreferences:(nullable NSDictionary *)dictionary inDomain:(NSString *)domain;

@end

/**
 *  Preferences test data creation on the local device.
 */
@interface UserDataBaseTestCase (PreferencesLocalTestData)

/**
 *  Insert a local preference.
 */
- (void)insertLocalPreferenceWithObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain;

/**
 *  Discard a local preference.
 */
- (void)discardLocalPreferenceAtPath:(NSString *)path inDomain:(NSString *)domain;

/**
 *  Assert that local preferences match a specific dictionary.
 */
- (void)assertLocalPreferences:(nullable NSDictionary *)dictionary inDomain:(NSString *)domain;

@end

NS_ASSUME_NONNULL_END
