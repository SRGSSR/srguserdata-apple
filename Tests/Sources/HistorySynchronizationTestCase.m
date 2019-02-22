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
    
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil identityService:self.identityService];
    
    // playsrgtests+userdata1@gmail.com
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, @"s%3AywJ2a0JqEvMOe-rzgZbYqvSeBSg0bb9P.2qChe6iS9BEEf%2FXPTjJ8Nosw2r1JACPRgxyFaXSrz6U")];
    XCTAssertTrue(hasHandledCallbackURL);
    XCTAssertNotNil(self.identityService.sessionToken);
}

#pragma mark Tests

- (void)testEmptyHistoryInitialSynchronization
{
    
}

- (void)testHistoryInitialSynchronization
{
    
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
