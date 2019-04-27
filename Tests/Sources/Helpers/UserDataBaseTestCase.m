//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGHistoryRequest.h"

#import <OHHTTPStubs/OHHTTPStubs.h>

@interface SRGIdentityService (Private)

- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@property (nonatomic, readonly, copy) NSString *identifier;

@end

NSString * const TestToken = @"s:t9ipSL-EefFt-FJCqj4KgYikQijCk_Sv.ZPHvjSuP6/wOhc6wEz005NkAv51RlbANspnT2esz/Bo";
NSString * const TestAccountUid = @"1234";

static NSURL *TestServiceURL(void)
{
    return [NSURL URLWithString:@"https://profil.rts.ch/api"];
}

static NSURL *TestWebserviceURL(void)
{
    return [NSURL URLWithString:@"https://api.srgssr.local"];
}

static NSURL *TestWebsiteURL(void)
{
    return [NSURL URLWithString:@"https://www.srgssr.local"];
}

static NSURL *TestDataServiceURL(void)
{
    return [TestServiceURL() URLByAppendingPathComponent:@"data"];
}

static NSURL *TestLoginCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srguserdata-tests://%@?identity_service=%@&token=%@", TestWebserviceURL().host, identityService.identifier, token];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestLogoutCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srguserdata-tests://%@?identity_service=%@&action=log_out", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

NSURL *TestHistoryServiceURL(void)
{
    return [TestServiceURL() URLByAppendingPathComponent:@"history"];
}

@interface UserDataBaseTestCase ()

@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGUserData *userData;

@end

@implementation UserDataBaseTestCase

#pragma mark Store generation

- (NSURL *)URLForStoreFromPackage:(NSString *)package
{
    static NSString * const kStoreName = @"Data";
    
    if (package) {
        for (NSString *extension in @[ @"sqlite", @"sqlite-shm", @"sqlite-wal"]) {
            NSString *sqliteFilePath = [[NSBundle bundleForClass:self.class] pathForResource:kStoreName ofType:extension inDirectory:package];
            if (! [NSFileManager.defaultManager fileExistsAtPath:sqliteFilePath]) {
                continue;
            }
            
            NSURL *sqliteFileURL = [NSURL fileURLWithPath:sqliteFilePath];
            NSURL *sqliteDestinationFileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:package] URLByAppendingPathExtension:extension];
            XCTAssertTrue([NSFileManager.defaultManager replaceItemAtURL:sqliteDestinationFileURL
                                                           withItemAtURL:sqliteFileURL
                                                          backupItemName:nil
                                                                 options:NSFileManagerItemReplacementUsingNewMetadataOnly
                                                        resultingItemURL:NULL
                                                                   error:NULL]);
        }
        
        return [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:package] URLByAppendingPathExtension:@"sqlite"];
    }
    else {
        return [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    }
}

#pragma mark Setup and teardown

- (void)setUp
{
    self.identityService = [[SRGIdentityService alloc] initWithWebserviceURL:TestWebserviceURL() websiteURL:TestWebsiteURL()];
    [self.identityService logout];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqual:TestWebserviceURL().host];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        if ([request.URL.host isEqualToString:TestWebserviceURL().host]) {
            if ([request.URL.path containsString:@"logout"]) {
                return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                   statusCode:204
                                                      headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
            }
            else if ([request.URL.path containsString:@"userinfo"]) {
                NSString *validAuthorizationHeader = [NSString stringWithFormat:@"sessionToken %@", TestToken];
                if ([[request valueForHTTPHeaderField:@"Authorization"] isEqualToString:validAuthorizationHeader]) {
                    NSDictionary<NSString *, id> *account = @{ @"id" : TestAccountUid,
                                                               @"publicUid" : @"1012",
                                                               @"login" : @"test@srgssr.ch",
                                                               @"displayName": @"Test user",
                                                               @"firstName": @"Test user",
                                                               @"lastName": @"SRG",
                                                               @"gender": @"other",
                                                               @"birthdate": @"2001-01-01" };
                    return [[OHHTTPStubsResponse responseWithData:[NSJSONSerialization dataWithJSONObject:account options:0 error:NULL]
                                                       statusCode:200
                                                          headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
                else {
                    return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                       statusCode:401
                                                          headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
            }
        }
        
        // No match, return 404
        return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                           statusCode:404
                                              headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
    }];
}

- (void)tearDown
{
    self.userData = nil;
    self.identityService = nil;
}

#pragma mark Expectations

- (XCTestExpectation *)expectationForSingleNotification:(NSNotificationName)notificationName object:(id)objectToObserve handler:(XCNotificationExpectationHandler)handler
{
    NSString *description = [NSString stringWithFormat:@"Expectation for notification '%@' from object %@", notificationName, objectToObserve];
    XCTestExpectation *expectation = [self expectationWithDescription:description];
    __block id observer = [NSNotificationCenter.defaultCenter addObserverForName:notificationName object:objectToObserve queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        void (^fulfill)(void) = ^{
            [expectation fulfill];
            [NSNotificationCenter.defaultCenter removeObserver:observer];
        };
        
        if (handler) {
            if (handler(notification)) {
                fulfill();
            }
        }
        else {
            fulfill();
        }
    }];
    return expectation;
}

- (XCTestExpectation *)expectationForElapsedTimeInterval:(NSTimeInterval)timeInterval withHandler:(void (^)(void))handler
{
    XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"Wait for %@ seconds", @(timeInterval)]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
        handler ? handler() : nil;
    });
    return expectation;
}

#pragma mark Data

- (void)setupUserDataWithServiceURL:(NSURL *)serviceURL
{
    [self eraseUserData];
    [self logout];
    
    // We could mock history services to implement true unit tests, but to be able to catch their possible issues (!),
    // we rather want integration tests. We therefore need to use a test user, simulating login by injecting its
    // session token into the identity service.
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                                   serviceURL:serviceURL
                                              identityService:self.identityService];
}

- (void)setupForOfflineOnly
{
    [self setupUserDataWithServiceURL:nil];
}

- (void)setupForAvailableService
{
    [self setupUserDataWithServiceURL:TestServiceURL()];
}

- (void)setupForUnavailableService
{
    [self setupUserDataWithServiceURL:[NSURL URLWithString:@"https://missing.service"]];
}

- (void)synchronizeUserData
{
    [self.userData synchronize];
}

// GDPR special endpoint which erases the entire change history, returning the account to a pristine state. This endpoint
// is undocumented but publicly available.
- (void)eraseUserData
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"History cleared"];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:TestDataServiceURL()];
    URLRequest.HTTPMethod = @"DELETE";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", TestToken] forHTTPHeaderField:@"Authorization"];
    [[SRGRequest dataRequestWithURLRequest:URLRequest session:NSURLSession.sharedSession completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)login
{
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:nil];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertNotNil(self.identityService.account);
}

- (void)loginAndWaitForInitalSynchronization
{
    // Wait until the 1st synchronization has been performed (automatic after login)
    [self expectationForSingleNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:nil];
    [self login];
}

- (void)logout
{
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLogoutCallbackURL(self.identityService, TestToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    XCTAssertNil(self.identityService.sessionToken);
}

#pragma mark History

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
    
    [[SRGHistoryRequest postBatchOfHistoryEntryDictionaries:JSONDictionaries toServiceURL:TestHistoryServiceURL() forSessionToken:TestToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)deleteRemoteHistoryEntryWithUid:(NSString *)uid
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"History cleared"];
    
    NSDictionary *JSONDictionary = @{ @"item_id" : uid,
                                      @"device_id" : @"test suite",
                                      @"deleted": @YES };
    [[SRGHistoryRequest postBatchOfHistoryEntryDictionaries:@[JSONDictionary] toServiceURL:TestHistoryServiceURL() forSessionToken:TestToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

@end
