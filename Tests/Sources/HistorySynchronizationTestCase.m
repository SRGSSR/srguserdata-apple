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

- (void)insertLocalTestHistoryEntriesWithName:(NSString *)name count:(NSUInteger)count
{
    for (NSUInteger i = 0; i < count; ++i) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Local insertion"];
        
        NSString *uid = [NSString stringWithFormat:@"%@_%@", name, @(i + 1)];
        [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:CMTimeMakeWithSeconds(i, NSEC_PER_SEC) deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
}

#pragma mark Setup and teardown

- (void)setUp
{
    [super setUp];
    
    [self eraseData];
    [self logout];
    [self setupForOfflineOnly];
}

#pragma mark Tests

- (void)testEmptySynchronization
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected. The history was empty and still must be");
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:TestHistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 0);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testInitialSynchronizationWithExistingRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:2];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 0);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 2);
        return YES;
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:TestHistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 2);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testInitialSynchronizationWithExistingLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:2];
    [self insertLocalTestHistoryEntriesWithName:@"local" count:3];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 3);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 5);
        return YES;
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:TestHistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 5);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testSynchronizationWithDeletedLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:3];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 0);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 3);
        return YES;
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:nil];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:nil];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 3);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 2);
        return YES;
    }];
    
    [self.userData.history discardHistoryEntriesWithUids:@[@"remote_1"] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [self.userData synchronize];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:TestHistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 2);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testSynchronizationWithDeletedRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:3];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 0);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 3);
        return YES;
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
    
    [self deleteRemoteHistoryEntryWithUid:@"remote_2"];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:nil];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:nil];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 3);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 2);
        return YES;
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
}

- (void)testLargeHistory
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:1000];
    [self insertLocalTestHistoryEntriesWithName:@"local" count:2000];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        
        // The history emits an update after each page insertion. Check that the page size increases with each change
        // before reaching the maximum value.
        static NSUInteger kPullPageSize = 500;
        
        if ([notification.userInfo[SRGHistoryUidsKey] count] == 3000) {
            XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 3000 - kPullPageSize);
            return YES;
        }
        else {
            XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], [notification.userInfo[SRGHistoryPreviousUidsKey] count] + kPullPageSize);
            return NO;
        }
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:TestHistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 3000);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
}

// TODO: This is a general sync test and should be moved to another test suite
- (void)testSynchronizationAfterLogoutDuringSynchronization
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:2];
    [self insertLocalTestHistoryEntriesWithName:@"local" count:3];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:nil];
    
    [self.userData synchronize];
    [self logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    // Login again and check that synchronization still works
    [self loginAndWaitForInitalSynchronization];
}

// TODO: This is a general sync test and should be moved to another test suite
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
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:startObserver];
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
        [NSNotificationCenter.defaultCenter removeObserver:finishObserver];
    }];
}

// TODO: This is a general sync test and should be moved to another test suite
- (void)testSynchronizationWithUnavailableService
{
    [self setupForUnavailableService];
    [self login];
    
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
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
}

@end
