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
    return @"s:-x_mq2NAW6fUWD-hPXat-GEPXlA5rKMJ.y5Bjc81UhkfvlVzBiWIcxyPhu7DgvsxR8tggplFtdHg";
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
    
    [self.identityService logout];
    
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

// TODO: Add test for complete cleanup of remote prefs
// TODO: Test for addition of same dic from 2 devices, with different items -> must merge
// TODO: Check sync and notifs with a few domains removed remotely, while other ones have been added (one notif with
//       several deleted domains, and other notifs individually for updated domains)

@end
