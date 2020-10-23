//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGHistoryRequest.h"
#import "SRGUserObject+Private.h"

@import libextobjc;

@interface HistorySynchronizationTestCase : UserDataBaseTestCase

@end

@implementation HistorySynchronizationTestCase

#pragma mark Overrides

- (NSString *)sessionToken
{
    // For playsrgtests+userdata1@gmail.com
    return @"s:t9ipSL-EefFt-FJCqj4KgYikQijCk_Sv.ZPHvjSuP6/wOhc6wEz005NkAv51RlbANspnT2esz/Bo";
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
    
    [self assertLocalHistoryUids:@[]];
    [self assertRemoteHistoryUids:@[]];
}

- (void)testInitialSynchronizationWithExistingRemoteEntries
{
    [self insertRemoteHistoryEntriesWithUids:@[ @"a", @"b" ]];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryUids:@[ @"a", @"b" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b" ]];
}

- (void)testSynchronizationWithoutEntryChanges
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryUids:@[]];
    [self assertRemoteHistoryUids:@[]];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryUids:@[]];
    [self assertRemoteHistoryUids:@[]];
}

- (void)testSynchronizationWithAddedRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemoteHistoryEntriesWithUids:@[ @"a", @"b" ]];
    
    [self assertLocalHistoryUids:@[]];
    [self assertRemoteHistoryUids:@[ @"a", @"b" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryUids:@[ @"a", @"b" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b" ]];
}

- (void)testSynchronizationWithAddedLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalHistoryEntriesWithUids:@[ @"a", @"b" ]];
    
    [self assertLocalHistoryUids:@[ @"a", @"b" ]];
    [self assertRemoteHistoryUids:@[]];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryUids:@[ @"a", @"b" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b" ]];
}

- (void)testSynchronizationWithAddedRemoteAndLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalHistoryEntriesWithUids:@[ @"a", @"b" ]];
    [self insertRemoteHistoryEntriesWithUids:@[ @"b", @"c" ]];
    
    [self assertLocalHistoryUids:@[ @"a", @"b" ]];
    [self assertRemoteHistoryUids:@[ @"b", @"c" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryUids:@[ @"a", @"b", @"c" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b", @"c" ]];
}

- (void)testSynchronizationWithDiscardedLocalEntries
{
    [self insertRemoteHistoryEntriesWithUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryUids:@[ @"a", @"b", @"c", @"d" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self discardLocalHistoryEntriesWithUids:@[ @"a", @"c" ]];
    
    [self assertLocalHistoryUids:@[ @"b", @"d" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryUids:@[ @"b", @"d" ]];
    [self assertRemoteHistoryUids:@[ @"b", @"d" ]];
}

- (void)testSynchronizationWithDiscardedRemoteEntries
{
    [self insertRemoteHistoryEntriesWithUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryUids:@[ @"a", @"b", @"c", @"d" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self discardRemoteHistoryEntriesWithUids:@[ @"a", @"c" ]];
    
    [self assertLocalHistoryUids:@[ @"a", @"b", @"c", @"d" ]];
    [self assertRemoteHistoryUids:@[ @"b", @"d" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryUids:@[ @"b", @"d" ]];
    [self assertRemoteHistoryUids:@[ @"b", @"d" ]];
}

- (void)testSynchronizationWithDiscardedRemoteAndLocalEntries
{
    [self insertRemoteHistoryEntriesWithUids:@[ @"a", @"b", @"c", @"d", @"e" ]];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalHistoryUids:@[ @"a", @"b", @"c", @"d", @"e" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b", @"c", @"d", @"e" ]];
    
    [self discardLocalHistoryEntriesWithUids:@[ @"b", @"c" ]];
    [self discardRemoteHistoryEntriesWithUids:@[ @"c", @"d" ]];
    
    [self assertLocalHistoryUids:@[ @"a", @"d", @"e" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b", @"e" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryUids:@[ @"a", @"e" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"e" ]];
}

// TODO: Disabled. Too intensive for the service.
#if 0
- (void)testLargeHistory
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    NSArray<NSString *> *(^uidsBuilder)(NSUInteger, NSUInteger) = ^(NSUInteger start, NSUInteger end) {
        NSMutableArray<NSString *> *uids = [NSMutableArray array];
        for (NSUInteger i = start; i < end; i++) {
            [uids addObject:@(i).stringValue];
        }
        return uids.copy;
    };
    
    [self insertLocalHistoryEntriesWithUids:uidsBuilder(0, 1000)];
    [self insertRemoteHistoryEntriesWithUids:uidsBuilder(900, 3000)];
    
    [self assertLocalHistoryUids:uidsBuilder(0, 1000)];
    [self assertRemoteHistoryUids:uidsBuilder(900, 3000)];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryUids:uidsBuilder(0, 3000)];
    [self assertRemoteHistoryUids:uidsBuilder(0, 3000)];
}
#endif

- (void)testLogout
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalHistoryEntriesWithUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryEntriesUidsKey], ([NSSet setWithObjects:@"a", @"b", @"c", @"d", nil]));
        return YES;
    }];
    
    [self logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self assertLocalHistoryUids:@[]];
}

- (void)testSynchronizationAfterLogoutDuringSynchronization
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalHistoryEntriesWithUids:@[ @"a", @"b", @"c", @"d" ]];
    [self insertRemoteHistoryEntriesWithUids:@[ @"d", @"e", @"f", @"g" ]];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:nil];
    
    [self synchronize];
    [self logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self assertLocalHistoryUids:@[]];
    
    // Login again and check that synchronization still works
    [self loginAndWaitForInitialSynchronization];
}

- (void)testNoSynchronizationWithoutLoggedInUser
{
    [self setupForAvailableService];
    
    id startObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidStartSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No start notification is expected");
    }];
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryEntriesDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
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

- (void)testNotificationDuringInitialSynchronization
{
    [self insertRemoteHistoryEntriesWithUids:@[ @"a", @"b" ]];
    
    [self setupForAvailableService];
    
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryEntriesUidsKey], ([NSSet setWithObjects:@"a", @"b", nil]));
        return YES;
    }];
    
    [self login];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalHistoryUids:@[ @"a", @"b" ]];
    [self assertRemoteHistoryUids:@[ @"a", @"b" ]];
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
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryEntriesDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
}

- (void)testNotificationsWithDiscardedLocalEntries
{
    [self insertRemoteHistoryEntriesWithUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Changes are notified when entries are marked as being discarded
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryEntriesUidsKey], ([NSSet setWithObjects:@"a", @"c", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discard"];
    
    [self.userData.history discardHistoryEntriesWithUids:@[ @"a", @"c" ] completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // No more changes must be received for the discarded entries when deleted during synchronization
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryEntriesUidsKey], ([NSSet setWithObjects:@"b", @"d", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalHistoryUids:@[ @"b", @"d" ]];
    [self assertRemoteHistoryUids:@[ @"b", @"d" ]];
}

- (void)testNotificationsWithDiscardedRemoteEntries
{
    [self insertRemoteHistoryEntriesWithUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self discardRemoteHistoryEntriesWithUids:@[ @"a", @"c" ]];
    
    // Changes are notified when synchronization occurs with the remote changes
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryEntriesUidsKey], ([NSSet setWithObjects:@"a", @"c", @"b", @"d", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalHistoryUids:@[ @"b", @"d" ]];
    [self assertRemoteHistoryUids:@[ @"b", @"d" ]];
}

- (void)testNonReturnedDiscardedHistoryEntryWithUid
{
    [self insertRemoteHistoryEntriesWithUids:@[ @"a" ]];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Synchronous
    SRGHistoryEntry *historyEntry1 = [self.userData.history historyEntryWithUid:@"a"];
    XCTAssertNotNil(historyEntry1);
    XCTAssertFalse(historyEntry1.discarded);
    
    // Asynchronous
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntryWithUid:@"a" completionBlock:^(SRGHistoryEntry * _Nullable historyEntry, NSError * _Nullable error) {
        XCTAssertNotNil(historyEntry);
        XCTAssertFalse(historyEntry.discarded);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self discardLocalHistoryEntriesWithUids:@[ @"a" ]];
    
    XCTAssertTrue(historyEntry1.discarded);
    
    // Synchronous
    SRGHistoryEntry *historyEntry2 = [self.userData.history historyEntryWithUid:@"a"];
    XCTAssertNil(historyEntry2);
    
    // Asynchronous
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntryWithUid:@"a" completionBlock:^(SRGHistoryEntry * _Nullable historyEntry, NSError * _Nullable error) {
        XCTAssertNil(historyEntry);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self synchronizeAndWait];
    
    // Synchronous
    SRGHistoryEntry *historyEntry3 = [self.userData.history historyEntryWithUid:@"a"];
    XCTAssertNil(historyEntry3);
    
    // Asynchronous
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntryWithUid:@"a" completionBlock:^(SRGHistoryEntry * _Nullable historyEntry, NSError * _Nullable error) {
        XCTAssertNil(historyEntry);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testNonReturnedDiscardedHistoryEntriesWithPredicate
{
    [self insertRemoteHistoryEntriesWithUids:@[ @"a" ]];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Synchronous
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGHistoryEntry.new, uid), @"a"];
    NSArray<SRGHistoryEntry *> *historyEntries1 = [self.userData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil];
    XCTAssertEqual(historyEntries1.count, 1);
    SRGHistoryEntry *historyEntry1 = historyEntries1.firstObject;
    XCTAssertNotNil(historyEntry1);
    XCTAssertFalse(historyEntry1.discarded);
    
    // Asynchronous
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries, NSError * _Nullable error) {
        XCTAssertEqual(historyEntries.count, 1);
        
        SRGHistoryEntry *historyEntry = historyEntries.firstObject;
        XCTAssertNotNil(historyEntry);
        XCTAssertFalse(historyEntry.discarded);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self discardLocalHistoryEntriesWithUids:@[ @"a" ]];
    
    XCTAssertTrue(historyEntry1.discarded);
    
    // Synchronous
    NSArray<SRGHistoryEntry *> *historyEntries2 = [self.userData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil];
    XCTAssertEqual(historyEntries2.count, 0);
    
    // Asynchronous
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries, NSError * _Nullable error) {
        XCTAssertEqual(historyEntries.count, 0);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self synchronizeAndWait];
    
    // Synchronous
    NSArray<SRGHistoryEntry *> *historyEntries3 = [self.userData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil];
    XCTAssertEqual(historyEntries3.count, 0);
    
    // Asynchronous
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries, NSError * _Nullable error) {
        XCTAssertEqual(historyEntries.count, 0);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

@end
