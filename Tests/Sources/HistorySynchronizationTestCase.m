//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import <SRGIdentity/SRGIdentity.h>

@interface SRGIdentityService (Private)

- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@property (nonatomic, readonly, copy) NSString *identifier;

@end

@interface SRGHistory (Private)

- (void)synchronize;

@end

static NSURL *TestWebserviceURL(void)
{
    return [NSURL URLWithString:@"https://api.srgssr.local"];
}

static NSURL *TestWebsiteURL(void)
{
    return [NSURL URLWithString:@"https://www.srgssr.local"];
}

static NSURL *TestLoginCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srguserdata-tests://%@?identity_service=%@&token=%@", TestWebserviceURL().host, identityService.identifier, token];
    return [NSURL URLWithString:URLString];
}

@interface SRGHistorySynchronizationTestCase : UserDataBaseTestCase

@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGUserData *userData;

@end

@implementation SRGHistorySynchronizationTestCase

#pragma mark Setup and teardown

- (void)setUp
{
    self.identityService = [[SRGIdentityService alloc] initWithWebserviceURL:TestWebserviceURL() websiteURL:TestWebsiteURL()];
 
    // We could mock history services to implement true unit tests, but to be able to catch their possible issues (!),
    // we rather want integration tests. We therefore need to use a test user, simulating login by injecting its
    // session token into the identity service.
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                            historyServiceURL:[NSURL URLWithString:@"https://profil.rts.ch/api/history"]
                                              identityService:self.identityService];
    
    // Logout with playsrgtests+userdata1@gmail.com
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, @"s%3AywJ2a0JqEvMOe-rzgZbYqvSeBSg0bb9P.2qChe6iS9BEEf%2FXPTjJ8Nosw2r1JACPRgxyFaXSrz6U")];
    XCTAssertTrue(hasHandledCallbackURL);
    XCTAssertNotNil(self.identityService.sessionToken);
    
    [self expectationForNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    // Reset user history
    [self.userData.history discardHistoryEntriesWithUids:nil completionBlock:^(NSError * _Nonnull error) {
        [self.userData.history synchronize];
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
}

#pragma mark Helpers

- (void)insertRemoteTestHistoryEntries
{
    for (NSInteger i = 1; i <= 10; ++i) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
        [self.userData.history saveHistoryEntryForUid:[NSString stringWithFormat:@"existing_%@", @(i)] withLastPlaybackTime:CMTimeMakeWithSeconds(i, NSEC_PER_SEC) deviceUid:@"UT" completionBlock:^(NSError * _Nonnull error) {
            [expectation fulfill];
        }];
    }
    
    [self expectationForNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
}

#pragma mark Tests

- (void)testEmptyHistorySynchronization
{
    [self expectationForNotification:SRGHistoryDidStartSynchronizationNotification object:self.userData.history handler:nil];
    [self expectationForNotification:SRGHistoryDidFinishSynchronizationNotification object:self.userData.history handler:nil];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No change notification is expected. The history was empty and still is");
    }];
    
    [self.userData.history synchronize];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
}

- (void)testHistoryInitialSynchronizationWithExistingRemoteEntries
{
    [self insertRemoteTestHistoryEntries];
    
    // TODO:
}

- (void)testHistoryInitialSynchronizationWithExistingLocalEntries
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

// etc.

@end
