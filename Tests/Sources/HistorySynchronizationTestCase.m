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

- (void)testLargeHistory
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    NSArray<NSString *> *(^uidsBuilder)(NSUInteger, NSUInteger) = ^(NSUInteger start, NSUInteger end) {
        NSMutableArray<NSString *> *uids = [NSMutableArray array];
        for (NSUInteger i = start; i < end; i++) {
            [uids addObject:@(i).stringValue];
        }
        return [uids copy];
    };
    
    [self insertLocalHistoryEntriesWithUids:uidsBuilder(0, 1000)];
    [self insertRemoteHistoryEntriesWithUids:uidsBuilder(900, 3000)];
    
    [self assertLocalHistoryUids:uidsBuilder(0, 1000)];
    [self assertRemoteHistoryUids:uidsBuilder(900, 3000)];
    
    [self synchronizeAndWait];
    
    [self assertLocalHistoryUids:uidsBuilder(0, 3000)];
    [self assertRemoteHistoryUids:uidsBuilder(0, 3000)];
}

- (void)testAfterLogout
{
    // FIXME:
#if 0
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalHistoryEntriesWithUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self assertLocalHistoryUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGHistoryUidsKey] count] == 0;
    }];
    
    [self.identityService logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self assertLocalHistoryUids:@[]];
#endif
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

- (void)testSynchronizationWithoutLoggedInUser
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

@end
