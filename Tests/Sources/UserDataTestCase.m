//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

@interface UserDataTestCase : UserDataBaseTestCase

@end

@implementation UserDataTestCase

#pragma mark Tests

- (void)testFirstInstance
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil identityService:nil];
    XCTAssertNotNil(userData);
    XCTAssertNotNil(userData.user);
    XCTAssertNotNil(userData.history);
}

- (void)testFirstInstanceWithHistoryServiceURL
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    NSURL *historyServiceURL = [NSURL URLWithString:@"https://missing.service"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:historyServiceURL identityService:nil];
    XCTAssertNotNil(userData);
    XCTAssertNotNil(userData.user);
    XCTAssertNotNil(userData.history);
}

- (void)testFirstInstanceWithIdentityService
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    SRGIdentityService *identityService = [[SRGIdentityService alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://missing.webservice"] websiteURL:[NSURL URLWithString:@"https://missing.websiteurl"]];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil identityService:identityService];
    XCTAssertNotNil(userData);
    XCTAssertNotNil(userData.user);
    XCTAssertNotNil(userData.history);
}

- (void)testFirstInstanceWithHistoryServiceURLAndIdentityService
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    NSURL *historyServiceURL = [NSURL URLWithString:@"https://missing.service"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:historyServiceURL identityService:nil];
    XCTAssertNotNil(userData);
    XCTAssertNotNil(userData.user);
    XCTAssertNotNil(userData.history);
}

@end
