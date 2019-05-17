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

- (void)testBools
{
    XCTAssertEqual([NSNumber numberWithBool:YES], (void *)kCFBooleanTrue);
    XCTAssertEqual([NSNumber numberWithBool:NO], (void *)kCFBooleanFalse);
}

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
// TODO: Test for addition of same dic from 2 devices, with different items -> must merge
// TODO: Decide and test behavior for insertion at path where one of the components already exist and does not
//       point to a dictionary (currently: does nothing). Should insertion methods return a BOOL / error?
//       - UT: Spaces / slashes / dots in keys + encoding if needed
//       - Add test for SRGPreferencesDidChangeNotification on the main thread.
// TODO: Test storage of non-JSON serializable settings (e.g. with an NSDate)

@end
