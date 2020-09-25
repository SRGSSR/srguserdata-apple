//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

@interface PreferencesSynchronizationTestCase : UserDataBaseTestCase

@end

@implementation PreferencesSynchronizationTestCase

#pragma mark Overrides

- (NSString *)sessionToken
{
    // For playsrgtests+userdata3@gmail.com
    return @"s:aAiVxAvpr_S1kvNaEuruZVPc_O_FQuBF.isG5lbLHmxNof6A0JnOEBAu3VdiowIejIQYix8BWKk4";
}

#pragma mark Setup and teardown

- (void)setUp
{
    [super setUp];
    
    [self eraseRemoteDataAndWait];
    [self logout];
}

#pragma mark Tests

- (void)testInitialSynchronizationWithoutRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPreferences:nil inDomain:@"test"];
    [self assertRemotePreferences:nil inDomain:@"test"];
}

- (void)testInitialSynchronizationWithExistingRemoteEntries
{
    [self insertRemotePreferenceWithObject:@"x" atPath:@"a" inDomain:@"test"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPreferences:@{ @"a" : @"x" } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"a" : @"x" } inDomain:@"test"];
}

- (void)testSynchronizationWithoutEntryChanges
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPreferences:nil inDomain:@"test"];
    [self assertRemotePreferences:nil inDomain:@"test"];
    
    [self synchronizeAndWait];
    
    [self assertLocalPreferences:nil inDomain:@"test"];
    [self assertRemotePreferences:nil inDomain:@"test"];
}

- (void)testSynchronizationWithAddedRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemotePreferenceWithObject:@"x" atPath:@"a" inDomain:@"test"];
    
    [self assertLocalPreferences:nil inDomain:@"test"];
    [self assertRemotePreferences:@{ @"a" : @"x" } inDomain:@"test"];
    
    [self synchronizeAndWait];
    
    [self assertLocalPreferences:@{ @"a" : @"x" } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"a" : @"x" } inDomain:@"test"];
}

- (void)testSynchronizationWithAddedLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPreferenceWithObject:@"x" atPath:@"a" inDomain:@"test"];
    
    [self assertLocalPreferences:@{ @"a" : @"x" } inDomain:@"test"];
    [self assertRemotePreferences:nil inDomain:@"test"];
    
    [self synchronizeAndWait];
    
    [self assertLocalPreferences:@{ @"a" : @"x" } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"a" : @"x" } inDomain:@"test"];
}

- (void)testSynchronizationWithAddedRemoteAndLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPreferenceWithObject:@"x1" atPath:@"s1" inDomain:@"test"];
    [self insertLocalPreferenceWithObject:@1 atPath:@"n1" inDomain:@"test"];
    [self insertLocalPreferenceWithObject:@3 atPath:@"c" inDomain:@"test"];
    [self insertLocalPreferenceWithObject:@"y1" atPath:@"d/s1" inDomain:@"test"];
    [self insertLocalPreferenceWithObject:@2 atPath:@"d/n1" inDomain:@"test"];
    [self insertLocalPreferenceWithObject:@4 atPath:@"d/c" inDomain:@"test"];
    
    [self insertRemotePreferenceWithObject:@"x2" atPath:@"s2" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@2 atPath:@"n2" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@7 atPath:@"c" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@"y2" atPath:@"d/s2" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@5 atPath:@"d/n2" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@9 atPath:@"d/c" inDomain:@"test"];
    
    [self assertLocalPreferences:@{ @"s1" : @"x1",
                                    @"n1" : @1,
                                    @"c" : @3,
                                    @"d" : @{ @"s1" : @"y1",
                                              @"n1" : @2,
                                              @"c" : @4 }
                                    } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"s2" : @"x2",
                                     @"n2" : @2,
                                     @"c" : @7,
                                     @"d" : @{ @"s2" : @"y2",
                                               @"n2" : @5,
                                               @"c" : @9 }
                                     } inDomain:@"test"];
    
    [self synchronizeAndWait];
    
    // Local wins for common paths
    [self assertLocalPreferences:@{ @"s1" : @"x1",
                                    @"s2" : @"x2",
                                    @"n1" : @1,
                                    @"n2" : @2,
                                    @"c" : @3,
                                    @"d" : @{ @"s1" : @"y1",
                                              @"s2" : @"y2",
                                              @"n1" : @2,
                                              @"n2" : @5,
                                              @"c" : @4 }
                                    } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"s1" : @"x1",
                                     @"s2" : @"x2",
                                     @"n1" : @1,
                                     @"n2" : @2,
                                     @"c" : @3,
                                     @"d" : @{ @"s1" : @"y1",
                                               @"s2" : @"y2",
                                               @"n1" : @2,
                                               @"n2" : @5,
                                               @"c" : @4 }
                                     } inDomain:@"test"];
}

- (void)testSynchronizationWithDiscardedLocalEntries
{
    [self insertRemotePreferenceWithObject:@"x" atPath:@"a" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@2 atPath:@"b" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@4 atPath:@"c" inDomain:@"test"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPreferences:@{ @"a" : @"x",
                                    @"b" : @2,
                                    @"c" : @4 } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"a" : @"x",
                                     @"b" : @2,
                                     @"c" : @4 } inDomain:@"test"];
    
    [self discardLocalPreferenceAtPath:@"a" inDomain:@"test"];
    [self discardLocalPreferenceAtPath:@"c" inDomain:@"test"];
    
    [self synchronizeAndWait];
    
    [self assertLocalPreferences:@{ @"b" : @2 } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"b" : @2 } inDomain:@"test"];
}

- (void)testSynchronizationWithDiscardedRemoteEntries
{
    [self insertRemotePreferenceWithObject:@"x" atPath:@"a" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@2 atPath:@"b" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@4 atPath:@"c" inDomain:@"test"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPreferences:@{ @"a" : @"x",
                                    @"b" : @2,
                                    @"c" : @4 } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"a" : @"x",
                                     @"b" : @2,
                                     @"c" : @4 } inDomain:@"test"];
    
    [self discardRemotePreferenceAtPath:@"a" inDomain:@"test"];
    [self discardRemotePreferenceAtPath:@"c" inDomain:@"test"];
    
    [self synchronizeAndWait];
    
    [self assertLocalPreferences:@{ @"b" : @2 } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"b" : @2 } inDomain:@"test"];
}

- (void)testSynchronizationWithDiscardedRemoteAndLocalEntries
{
    [self insertRemotePreferenceWithObject:@"x" atPath:@"a" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@2 atPath:@"b" inDomain:@"test"];
    [self insertRemotePreferenceWithObject:@4 atPath:@"c" inDomain:@"test"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPreferences:@{ @"a" : @"x",
                                    @"b" : @2,
                                    @"c" : @4 } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"a" : @"x",
                                     @"b" : @2,
                                     @"c" : @4 } inDomain:@"test"];
    
    [self discardLocalPreferenceAtPath:@"a" inDomain:@"test"];
    [self discardRemotePreferenceAtPath:@"c" inDomain:@"test"];
    
    [self synchronizeAndWait];
    
    [self assertLocalPreferences:@{ @"b" : @2 } inDomain:@"test"];
    [self assertRemotePreferences:@{ @"b" : @2 } inDomain:@"test"];
}

- (void)testLogout
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPreferenceWithObject:@"x" atPath:@"a" inDomain:@"test1"];
    [self insertLocalPreferenceWithObject:@"y" atPath:@"b" inDomain:@"test2"];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    
    [self expectationForSingleNotification:SRGPreferencesDidChangeNotification object:self.userData.preferences handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], ([NSSet setWithObjects:@"test1", @"test2", nil]));
        return YES;
    }];
    
    [self logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self assertLocalPreferences:nil inDomain:@"test1"];
    [self assertLocalPreferences:nil inDomain:@"test2"];
    
    [self assertRemotePreferences:nil inDomain:@"test1"];
    [self assertRemotePreferences:nil inDomain:@"test2"];
}

- (void)testSynchronizationAfterLogoutDuringSynchronization
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPreferenceWithObject:@"x" atPath:@"a" inDomain:@"test1"];
    [self insertLocalPreferenceWithObject:@"y" atPath:@"b" inDomain:@"test2"];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:nil];
    
    [self synchronize];
    [self logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self assertLocalPreferences:nil inDomain:@"test1"];
    [self assertLocalPreferences:nil inDomain:@"test2"];
    
    // Login again and check that synchronization still works
    [self loginAndWaitForInitialSynchronization];
}

- (void)testNoSynchronizationWithoutLoggedInUser
{
    [self setupForAvailableService];
    
    id startObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidStartSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No start notification is expected");
    }];
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    id finishObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidFinishSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No finish notification is expected");
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:startObserver];
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
        [NSNotificationCenter.defaultCenter removeObserver:finishObserver];
    }];
}

- (void)testSynchronizationWithUnavailableService
{
    [self setupForUnavailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
}

- (void)testNotificationDuringInitialSynchronization
{
    [self insertRemotePreferenceWithObject:@"x" atPath:@"a" inDomain:@"test1"];
    [self insertRemotePreferenceWithObject:@"y" atPath:@"b" inDomain:@"test2"];
    
    [self setupForAvailableService];
    
    [self expectationForSingleNotification:SRGPreferencesDidChangeNotification object:self.userData.preferences handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], ([NSSet setWithObjects:@"test1", @"test2", nil]));
        return YES;
    }];
    
    [self login];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPreferences:@{ @"a" : @"x" } inDomain:@"test1"];
    [self assertLocalPreferences:@{ @"b" : @"y" } inDomain:@"test2"];
    
    [self assertRemotePreferences:@{ @"a" : @"x" } inDomain:@"test1"];
    [self assertRemotePreferences:@{ @"b" : @"y" } inDomain:@"test2"];
}

- (void)testNotificationsWithDiscardedLocalEntries
{
    [self insertRemotePreferenceWithObject:@"x" atPath:@"a" inDomain:@"test1"];
    [self insertRemotePreferenceWithObject:@"y" atPath:@"b" inDomain:@"test2"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Changes are notified when preferences are removed locally
    [self expectationForSingleNotification:SRGPreferencesDidChangeNotification object:self.userData.preferences handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], ([NSSet setWithObjects:@"test1", nil]));
        return YES;
    }];
    
    [self.userData.preferences removeObjectsAtPaths:@[@"a"] inDomain:@"test1"];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // No more changes must be received for empty domains when synchronizing
    [self expectationForSingleNotification:SRGPreferencesDidChangeNotification object:self.userData.preferences handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], ([NSSet setWithObjects:@"test2", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPreferences:nil inDomain:@"test1"];
    [self assertLocalPreferences:@{ @"b" : @"y" } inDomain:@"test2"];
    
    [self assertRemotePreferences:nil inDomain:@"test1"];
    [self assertRemotePreferences:@{ @"b" : @"y" } inDomain:@"test2"];
}

- (void)testNotificationsWithDiscardedRemoteEntries
{
    [self insertRemotePreferenceWithObject:@"x" atPath:@"a" inDomain:@"test1"];
    [self insertRemotePreferenceWithObject:@"y" atPath:@"b" inDomain:@"test2"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self discardRemotePreferenceAtPath:@"a" inDomain:@"test1"];
    
    // Changes are notified when synchronization occurs with the remote changes
    [self expectationForSingleNotification:SRGPreferencesDidChangeNotification object:self.userData.preferences handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], ([NSSet setWithObjects:@"test1", @"test2", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPreferences:nil inDomain:@"test1"];
    [self assertLocalPreferences:@{ @"b" : @"y" } inDomain:@"test2"];
    
    [self assertRemotePreferences:nil inDomain:@"test1"];
    [self assertRemotePreferences:@{ @"b" : @"y" } inDomain:@"test2"];
}

@end
