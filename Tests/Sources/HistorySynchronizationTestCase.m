//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGHistoryRequest.h"

#import <SRGIdentity/SRGIdentity.h>
#import <SRGNetwork/SRGNetwork.h>

@interface SRGIdentityService (Private)

- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@property (nonatomic, readonly, copy) NSString *identifier;

@end

@interface SRGHistory (Private)

- (void)synchronize;

@end

// Logout with playsrgtests+userdata1@gmail.com
static NSString * const TestValidToken = @"s%3At9ipSL-EefFt-FJCqj4KgYikQijCk_Sv.ZPHvjSuP6%2FwOhc6wEz005NkAv51RlbANspnT2esz%2FBo";

static NSURL *TestWebserviceURL(void)
{
    return [NSURL URLWithString:@"https://hummingbird.rts.ch/api/profile"];
}

static NSURL *TestWebsiteURL(void)
{
    return [NSURL URLWithString:@"https://www.srgssr.local"];
}

static NSURL *TestServiceURL(void)
{
    return [NSURL URLWithString:@"https://profil.rts.ch/api"];
}

static NSURL *TestHistoryServiceURL(void)
{
    return [TestServiceURL() URLByAppendingPathComponent:@"history"];
}

static NSURL *TestDataServiceURL(void)
{
    return [TestServiceURL() URLByAppendingPathComponent:@"data"];
}

static NSURL *TestLoginCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srguserdata-tests://%@?identity_service=%@&token=%@", @"hummingbird.rts.ch/api/profile", identityService.identifier, token];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestLogoutCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srguserdata-tests://%@?identity_service=%@&action=log_out", @"hummingbird.rts.ch/api/profile", identityService.identifier];
    return [NSURL URLWithString:URLString];
}

@interface SRGHistorySynchronizationTestCase : UserDataBaseTestCase

@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGUserData *userData;

@end

@implementation SRGHistorySynchronizationTestCase

#pragma mark Helpers

- (void)setupUserDataWithHistoryServiceURL:(NSURL *)historyServiceURL
{
    [self eraseRemoteHistory];
    
    self.identityService = [[SRGIdentityService alloc] initWithWebserviceURL:TestWebserviceURL() websiteURL:TestWebsiteURL()];
    [self logout];
    
    // We could mock history services to implement true unit tests, but to be able to catch their possible issues (!),
    // we rather want integration tests. We therefore need to use a test user, simulating login by injecting its
    // session token into the identity service.
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                            historyServiceURL:historyServiceURL
                                              identityService:self.identityService];
}

- (void)login
{
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    XCTAssertNotNil(self.identityService.sessionToken);
}

- (void)loginAndWaitForSynchronization
{
    // Wait until the 1st synchronization has been performed (automatic after login)
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:nil];
    [self expectationForPredicate:[NSPredicate predicateWithBlock:^BOOL(SRGUserData * _Nullable userData, NSDictionary<NSString *,id> * _Nullable bindings) {
        return userData.user.accountUid != nil;
    }] evaluatedWithObject:self.userData handler:nil];
    
    [self login];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)logout
{
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLogoutCallbackURL(self.identityService, TestValidToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    XCTAssertNil(self.identityService.sessionToken);
}

- (void)deleteRemoteHistoryEntryWithUid:(NSString *)uid
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"History cleared"];
    
    NSDictionary *JSONDictionary = @{ @"item_id" : uid,
                                      @"device_id" : @"test suite",
                                      @"deleted": @YES };
    [[SRGHistoryRequest postBatchOfHistoryEntryDictionaries:@[JSONDictionary] toServiceURL:TestHistoryServiceURL() forSessionToken:TestValidToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)insertRemoteTestHistoryEntriesWithName:(NSString *)name count:(NSUInteger)count
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Remote entry creation finished"];
    
    NSMutableArray<NSDictionary *> *JSONDictionaries = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; ++i) {
        NSDictionary *JSONDictionary = @{ @"item_id" : [NSString stringWithFormat:@"%@_%@", name, @(i + 1)],
                                          @"device_id" : @"test suite",
                                          @"lastPlaybackPosition" : @(i * 1000.) };
        [JSONDictionaries addObject:JSONDictionary];
    }
    
    [[SRGHistoryRequest postBatchOfHistoryEntryDictionaries:JSONDictionaries toServiceURL:TestHistoryServiceURL() forSessionToken:TestValidToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)insertLocalTestHistoryEntriesWithName:(NSString *)name count:(NSUInteger)count
{
    for (NSUInteger i = 0; i < count; ++i) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Local insertion"];
        
        NSString *uid = [NSString stringWithFormat:@"%@_%@", name, @(i)];
        [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:CMTimeMakeWithSeconds(i, NSEC_PER_SEC) deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
}

// GDPR special endpoint which erases the entire change history, returning the account to a pristine state. This endpoint
// is undocumented but publicly available.
- (void)eraseRemoteHistory
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"History cleared"];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:TestDataServiceURL()];
    URLRequest.HTTPMethod = @"DELETE";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", TestValidToken] forHTTPHeaderField:@"Authorization"];
    [[SRGRequest dataRequestWithURLRequest:URLRequest session:NSURLSession.sharedSession completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

#pragma mark Tests

- (void)testEmptyHistorySynchronization
{
    [self setupUserDataWithHistoryServiceURL:TestHistoryServiceURL()];
    [self loginAndWaitForSynchronization];
    
    [self expectationForSingleNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected. The history was empty and still must be");
    }];
    
    [self.userData.history synchronize];
    
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

- (void)testHistoryInitialSynchronizationWithExistingRemoteEntries
{
    [self setupUserDataWithHistoryServiceURL:TestHistoryServiceURL()];
    [self loginAndWaitForSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:2];
    
    [self expectationForSingleNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 0);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 2);
        return YES;
    }];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:TestHistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 2);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testHistoryInitialSynchronizationWithExistingLocalEntries
{
    [self setupUserDataWithHistoryServiceURL:TestHistoryServiceURL()];
    [self loginAndWaitForSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:2];
    [self insertLocalTestHistoryEntriesWithName:@"local" count:3];
    
    [self expectationForSingleNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 3);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 5);
        return YES;
    }];
    
    [self.userData.history synchronize];
    
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
    [self setupUserDataWithHistoryServiceURL:TestHistoryServiceURL()];
    [self loginAndWaitForSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:3];
    
    [self expectationForSingleNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 0);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 3);
        return YES;
    }];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self expectationForSingleNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:nil];
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:nil];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 3);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 2);
        return YES;
    }];
    
    [self.userData.history discardHistoryEntriesWithUids:@[@"remote_1"] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [self.userData.history synchronize];
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
    [self setupUserDataWithHistoryServiceURL:TestHistoryServiceURL()];
    [self loginAndWaitForSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:3];
    
    [self expectationForSingleNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 0);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 3);
        return YES;
    }];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self deleteRemoteHistoryEntryWithUid:@"remote_2"];
    
    [self expectationForSingleNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:nil];
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:nil];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 3);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 2);
        return YES;
    }];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testLargeHistory
{
    [self setupUserDataWithHistoryServiceURL:TestHistoryServiceURL()];
    [self loginAndWaitForSynchronization];
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:1000];
    [self insertLocalTestHistoryEntriesWithName:@"local" count:2000];
    
    [self expectationForSingleNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
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
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:TestHistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 3000);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
}

- (void)testSynchronizationAfterLogoutDuringSynchronization
{
    [self setupUserDataWithHistoryServiceURL:TestHistoryServiceURL()];
    [self loginAndWaitForSynchronization];
    
    [self insertRemoteTestHistoryEntriesWithName:@"remote" count:2];
    [self insertLocalTestHistoryEntriesWithName:@"local" count:3];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    
    [self.userData.history synchronize];
    [self logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    // Login again and check that synchronization is still possible
    [self loginAndWaitForSynchronization];
}

- (void)testSynchronizationWithoutLoggedInUser
{
    [self setupUserDataWithHistoryServiceURL:TestHistoryServiceURL()];
    
    id startObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidStartSynchronizationNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No start notification is expected");
    }];
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    id finishObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No finish notification is expected");
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:startObserver];
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
        [NSNotificationCenter.defaultCenter removeObserver:finishObserver];
    }];
}

- (void)testSynchronizationWithUnavailableService
{
    [self setupUserDataWithHistoryServiceURL:[NSURL URLWithString:@"https://missing.service"]];
    [self login];
    
    [self expectationForSingleNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
}

@end
