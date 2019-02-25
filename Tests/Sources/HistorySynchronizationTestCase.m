//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGHistoryRequest.h"

#import <SRGIdentity/SRGIdentity.h>

@interface SRGIdentityService (Private)

- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@property (nonatomic, readonly, copy) NSString *identifier;

@end

@interface SRGHistory (Private)

- (void)synchronize;

@end

// Logout with playsrgtests+userdata1@gmail.com
static NSString * const TestSessionToken = @"s%3AO38TTzK5Mo9DK3LON2U4J0XF8u06MEme.JG0EAm1fsSNS8sDVmvtYRiCKqXqZE0Tdm7Q2NWlDy0U";

static NSURL *TestWebserviceURL(void)
{
    return [NSURL URLWithString:@"https://api.srgssr.local"];
}

static NSURL *TestWebsiteURL(void)
{
    return [NSURL URLWithString:@"https://www.srgssr.local"];
}

static NSURL *HistoryServiceURL(void)
{
    return [NSURL URLWithString:@"https://profil.rts.ch/api/history"];
}

static NSURL *TestLoginCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srguserdata-tests://%@?identity_service=%@&token=%@", TestWebserviceURL().host, identityService.identifier, token];
    return [NSURL URLWithString:URLString];
}

@interface SRGHistorySynchronizationTestCase : UserDataBaseTestCase

@property (nonatomic) SRGRequestQueue *requestQueue;

@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGUserData *userData;

@end

@implementation SRGHistorySynchronizationTestCase

#pragma mark Setup and teardown

- (void)setUp
{
    [self eraseRemoteHistory];
    
    self.identityService = [[SRGIdentityService alloc] initWithWebserviceURL:TestWebserviceURL() websiteURL:TestWebsiteURL()];
 
    // We could mock history services to implement true unit tests, but to be able to catch their possible issues (!),
    // we rather want integration tests. We therefore need to use a test user, simulating login by injecting its
    // session token into the identity service.
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                            historyServiceURL:HistoryServiceURL()
                                              identityService:self.identityService];

    // Wait until the 1st synchronization has been performed (automatic after login)
    [self expectationForNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:nil];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestSessionToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    XCTAssertNotNil(self.identityService.sessionToken);
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

#pragma mark Helpers

- (void)eraseRemoteHistory
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"History cleared"];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:HistoryServiceURL()];
    URLRequest.HTTPMethod = @"DELETE";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", TestSessionToken] forHTTPHeaderField:@"Authorization"];
    [[SRGRequest dataRequestWithURLRequest:URLRequest session:NSURLSession.sharedSession completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)insertRemoteTestHistoryEntriesWithCount:(NSUInteger)count
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Remote entry creation finished"];
    
    self.requestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        if (finished) {
            XCTAssertNil(error);
            [expectation fulfill];
        }
    }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
    
    for (NSUInteger i = 0; i < count; ++i) {
        NSDictionary *JSONDictionary = @{ @"item_id" : [NSString stringWithFormat:@"remote_test_%@", @(i)],
                                          @"device_id" : @"test suite",
                                          @"lastPlaybackPosition" : @(i * 1000.) };
        SRGRequest *request = [SRGHistoryRequest postHistoryEntryDictionary:JSONDictionary toServiceURL:HistoryServiceURL() forSessionToken:TestSessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            [self.requestQueue reportError:error];
        }];
        [self.requestQueue addRequest:request resume:YES];
    }
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)insertLocalTestHistoryEntriesWithCount:(NSUInteger)count
{
    for (NSUInteger i = 0; i < count; ++i) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Insertion"];
        
        NSString *uid = [NSString stringWithFormat:@"local_test_%@", @(i)];
        [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:CMTimeMakeWithSeconds(i, NSEC_PER_SEC) deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

#pragma mark Tests

- (void)testEmptyHistorySynchronization
{
    [self expectationForNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:nil];
    [self expectationForNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:nil];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected. The history was empty and still must be");
    }];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:HistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 0);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testHistoryInitialSynchronizationWithExistingRemoteEntries
{
    [self insertRemoteTestHistoryEntriesWithCount:2];
    
    [self expectationForNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:nil];
    [self expectationForNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:nil];
    
    [self expectationForNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 0);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 2);
        return YES;
    }];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:HistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 2);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testHistoryInitialSynchronizationWithExistingLocalEntries
{
    [self insertRemoteTestHistoryEntriesWithCount:2];
    [self insertLocalTestHistoryEntriesWithCount:3];
    
    [self expectationForNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:nil];
    [self expectationForNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:nil];
    
    [self expectationForNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqual([notification.userInfo[SRGHistoryPreviousUidsKey] count], 3);
        XCTAssertEqual([notification.userInfo[SRGHistoryUidsKey] count], 5);
        return YES;
    }];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:HistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(historyEntryDictionaries.count, 5);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testLargeHistory
{
    
}

- (void)testSynchronizationWithNewRemoteEntries
{
    
}

- (void)testSynchronizationWithNoNewRemoteEntries
{
    
}

- (void)testSynchronizationWithNewLocalEntries
{
    
}

- (void)testSynchronizationWithNoNewLocalEntries
{
    
}

- (void)testSynchronizationWithNewLocalAndRemoteEntries
{
    
}

- (void)testLogoutDuringSynchronization
{
    
}

- (void)testLogout
{
    
}

- (void)testSynchronizationWithDeletedLocalEntries
{
    
}

- (void)testSynchronizationWithDeletedRemoteEntries
{
    
}

// Test merge with common entries
// etc.

@end
