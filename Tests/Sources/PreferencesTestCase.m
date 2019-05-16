//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

// Private headers
#import "SRGPreferenceChangelogEntry.h"

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
    [self.userData.preferences setString:@"x" atPath:@"a/b/c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"], @"x");
}

- (void)testNumber
{
    [self.userData.preferences setNumber:@1012 atPath:@"a/b/c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences numberAtPath:@"a/b/c" inDomain:@"test"], @1012);
}

- (void)testRemoval
{
    [self.userData.preferences setString:@"x" atPath:@"a/b/c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"], @"x");
    
    [self.userData.preferences removeObjectAtPath:@"a/b/c" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"]);
    
    [self.userData.preferences setString:nil atPath:@"a" inDomain:@"test"];
}

// TODO: Add test where an item with a simple key (e.g. a) is added to a dict with the same key. Such tiny keys
//       are namely statically alloced and can be subtler to test
// TODO: Add test for complete cleanup of remote prefs

@end
