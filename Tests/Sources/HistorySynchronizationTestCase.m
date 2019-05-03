//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGHistoryRequest.h"

@interface HistorySynchronizationTestCase : UserDataBaseTestCase

@end

@implementation HistorySynchronizationTestCase

#pragma mark Overrides

- (NSString *)sessionToken
{
    // For playsrgtests+userdata1@gmail.com
    return @"s:t9ipSL-EefFt-FJCqj4KgYikQijCk_Sv.ZPHvjSuP6/wOhc6wEz005NkAv51RlbANspnT2esz/Bo";
}

#pragma mark Helpers

- (void)insertLocalHistoryEntriesWithName:(NSString *)name count:(NSUInteger)count
{
    for (NSUInteger i = 0; i < count; ++i) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Local insertion"];
        
        NSString *uid = [NSString stringWithFormat:@"%@_%@", name, @(i + 1)];
        [self.userData.history saveHistoryEntryWithUid:uid lastPlaybackTime:CMTimeMakeWithSeconds(i, NSEC_PER_SEC) deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
}

- (void)assertLocalHistoryEntryCount:(NSUInteger)count
{
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(historyEntries.count, count);
}

#pragma mark Setup and teardown

- (void)setUp
{
    [super setUp];
    
    [self eraseDataAndWait];
    [self logout];
}

#pragma mark Tests

- (void)testInitialSynchronizationWithoutRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryEntryCount:0];
    [self assertRemoteHistoryEntryCount:0];
}

- (void)testInitialSynchronizationWithExistingRemoteEntries
{
    [self insertRemoteHistoryEntriesWithName:@"a" count:2];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryEntryCount:2];
    [self assertRemoteHistoryEntryCount:2];
}

- (void)testSynchronizationWithoutEntryChanges
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryEntryCount:0];
    [self assertRemoteHistoryEntryCount:0];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryEntryCount:0];
    [self assertRemoteHistoryEntryCount:0];
}

- (void)testSynchronizationWithAddedRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemoteHistoryEntriesWithName:@"a" count:4];
    
    [self assertLocalHistoryEntryCount:0];
    [self assertRemoteHistoryEntryCount:4];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryEntryCount:4];
    [self assertRemoteHistoryEntryCount:4];
}

- (void)testSynchronizationWithAddedLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalHistoryEntriesWithName:@"a" count:3];
    
    [self assertLocalHistoryEntryCount:3];
    [self assertRemoteHistoryEntryCount:0];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryEntryCount:3];
    [self assertRemoteHistoryEntryCount:3];
}

- (void)testSynchronizationWithAddedRemoteAndLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalHistoryEntriesWithName:@"a" count:3];
    [self insertRemoteHistoryEntriesWithName:@"b" count:5];
    
    [self assertLocalHistoryEntryCount:3];
    [self assertRemoteHistoryEntryCount:5];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryEntryCount:8];
    [self assertRemoteHistoryEntryCount:8];
}

- (void)testSynchronizationWithDeletedLocalEntries
{
    [self insertRemoteHistoryEntriesWithName:@"a" count:3];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryEntryCount:3];
    [self assertRemoteHistoryEntryCount:3];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Local deletion"];
    
    [self.userData.history discardHistoryEntriesWithUids:@[@"a_1", @"a_3"] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryEntryCount:1];
    [self assertRemoteHistoryEntryCount:1];
}

- (void)testSynchronizationWithDeletedRemoteEntries
{
    [self insertRemoteHistoryEntriesWithName:@"a" count:3];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryEntryCount:3];
    [self assertRemoteHistoryEntryCount:3];
    
    [self deleteRemoteHistoryEntriesWithUids:@[ @"a_2", @"a_3" ]];
    
    [self assertRemoteHistoryEntryCount:1];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryEntryCount:1];
    [self assertRemoteHistoryEntryCount:1];
}

- (void)testSynchronizationWithDeletedRemoteAndLocalEntries
{
    [self insertRemoteHistoryEntriesWithName:@"a" count:5];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryEntryCount:5];
    [self assertRemoteHistoryEntryCount:5];
    
    [self deleteRemoteHistoryEntriesWithUids:@[ @"a_2", @"a_3" ]];
    
    [self assertRemoteHistoryEntryCount:3];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Local deletion"];
    
    [self.userData.history discardHistoryEntriesWithUids:@[@"a_1", @"a_4"] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryEntryCount:1];
    [self assertRemoteHistoryEntryCount:1];
}

- (void)testLargeHistory
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemoteHistoryEntriesWithName:@"a" count:1000];
    [self insertLocalHistoryEntriesWithName:@"b" count:2000];
    
    [self assertRemoteHistoryEntryCount:1000];
    [self assertLocalHistoryEntryCount:2000];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryEntryCount:3000];
    [self assertRemoteHistoryEntryCount:3000];
}

- (void)testAfterLogout
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalHistoryEntriesWithName:@"a" count:10];
    
    [self assertLocalHistoryEntryCount:10];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGHistoryUidsKey] count] == 0;
    }];
    
    [self.identityService logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self assertLocalHistoryEntryCount:0];
}

- (void)testSynchronizationAfterLogoutDuringSynchronization
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemoteHistoryEntriesWithName:@"a" count:2];
    [self insertLocalHistoryEntriesWithName:@"b" count:3];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:nil];
    
    [self synchronize];
    [self logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    // Login again and check that synchronization still works
    [self loginAndWaitForInitialSynchronization];
}

- (void)testSynchronizationWithoutLoggedInUser
{
    [self setupForAvailableService];
    
    id startObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidStartSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No start notification is expected");
    }];
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
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
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
}

@end
