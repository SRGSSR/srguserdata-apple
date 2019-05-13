//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

@interface PreferencesTestCase : UserDataBaseTestCase

@end

@implementation PreferencesTestCase

#pragma mark Setup and tear down

- (void)setUp
{
    [super setUp];
    
    [self setupForOfflineOnly];
}

#pragma mark Tests

- (void)testString
{
    [self.userData.preferences setString:@"x" forKeyPath:@"a.b.c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringForKeyPath:@"a.b.c" inDomain:@"test"], @"x");
}

- (void)testNumber
{
    [self.userData.preferences setNumber:@1012 forKeyPath:@"a.b.c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences numberForKeyPath:@"a.b.c" inDomain:@"test"], @1012);
}

- (void)testRemoval
{
    [self.userData.preferences setString:@"x" forKeyPath:@"a.b.c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringForKeyPath:@"a.b.c" inDomain:@"test"], @"x");
    
    [self.userData.preferences removeObjectForKeyPath:@"a.b.c" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringForKeyPath:@"a.b.c" inDomain:@"test"]);
}

@end
