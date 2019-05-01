//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGUserData/SRGUserData.h>
#import <XCTest/XCTest.h>

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
 *  Login a test user with SRG Identity, associating it with the provided session token.
 */
- (void)login;

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
- (void)eraseDataAndWait;

@end

/**
 *  History test data creation on the remote user data service.
 */
@interface UserDataBaseTestCase (HistoryTestData)

/**
 *  Insert a number of test history entries with name `<name>_<index>`. Wait until all have been inserted.
 */
- (void)insertRemoteTestHistoryEntriesWithName:(NSString *)name count:(NSUInteger)count;

/**
 *  Delete the remote history entries having the specified identifiers. Wait until deletion is successful.
 */
- (void)deleteRemoteHistoryEntriesWithUids:(NSArray<NSString *> *)uids;

/**
 *  Assert that the number of remote history entries matches an expected value.
 */
- (void)assertRemoteHistoryEntryCount:(NSUInteger)count;

@end

/**
 *  Playlist test data creation on the remote user data service.
 */
@interface UserDataBaseTestCase (PlaylistTestData)

/**
 *  Insert a number of remote playlists with name `<name>_<index>`. For each playlist, inserts a number of entries named
 *  `entry_<index>`. Wait until all have been inserted
 */
- (void)insertRemoteTestPlaylistsWithName:(NSString *)name count:(NSUInteger)count entryCount:(NSUInteger)entryCount;

/**
 *  Delete the remote playlists having the specified identifiers. Wait until deletion is successful.
 */
- (void)deleteRemotePlaylistWithUids:(NSArray<NSString *> *)uids;

/**
 *  Assert that the number of remote playlists matches an expected value.
 */
- (void)assertRemotePlaylistCount:(NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
