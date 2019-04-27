//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGUserData/SRGUserData.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRGUserData (Tests)

/**
 *  Call to force user data synchronization.
 */
- (void)synchronize;

@end

/**
 *  A token associated with a test user (playsrgtests+userdata1@gmail.com).
 */
OBJC_EXPORT NSString * const TestToken;

/**
 *  The user identifier for the test user (playsrgtests+userdata1@gmail.com).
 */
OBJC_EXPORT NSString * const TestAccountUid;

/**
 *  The URL of the history service for tests.
 */
OBJC_EXPORT NSURL *TestHistoryServiceURL(void);

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
 *  Login a test user (with `TestToken` as token).
 */
- (void)login;

/**
 *  Login a test user, perform an initial synchronization and wait until it finishes.
 */
- (void)loginAndWaitForInitalSynchronization;

/**
 *  Logout the current user.
 */
- (void)logout;

@end

/**
 *  Test data creation on the remote user data service.
 */
@interface UserDataBaseTestCase (TestData)

/**
 *  Insert a number of test history entries with name `name_<index>`. Wait until all have been inserted.
 */
- (void)insertRemoteTestHistoryEntriesWithName:(NSString *)name count:(NSUInteger)count;

/**
 *  Delete the remote history entry having the specified identifier. Wait until deletion is successful.
 */
- (void)deleteRemoteHistoryEntryWithUid:(NSString *)uid;

@end

NS_ASSUME_NONNULL_END
