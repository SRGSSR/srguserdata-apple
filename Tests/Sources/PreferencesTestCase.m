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

- (void)testBooleanChecks
{
    XCTAssertEqual([NSNumber numberWithBool:YES], (void *)kCFBooleanTrue);
    XCTAssertEqual([NSNumber numberWithBool:NO], (void *)kCFBooleanFalse);
}

- (void)testHasObject
{
    [self.userData.preferences setString:@"y" atPath:@"path/to/s" inDomain:@"test"];
    XCTAssertTrue([self.userData.preferences hasObjectAtPath:@"path" inDomain:@"test"]);
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"other_path" inDomain:@"test"]);
    XCTAssertTrue([self.userData.preferences hasObjectAtPath:@"path/to" inDomain:@"test"]);
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path/other_to" inDomain:@"test"]);
    XCTAssertTrue([self.userData.preferences hasObjectAtPath:@"path/to/s" inDomain:@"test"]);
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path/to/other_s" inDomain:@"test"]);
}

- (void)testString
{
    [self.userData.preferences setString:@"x" atPath:@"s" inDomain:@"test"];
    [self.userData.preferences setString:@"y" atPath:@"path/to/s" inDomain:@"test"];
    
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"s" inDomain:@"test"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"path/to/s" inDomain:@"test"], @"y");
    
    XCTAssertNil([self.userData.preferences stringAtPath:@"path/to/missing/s" inDomain:@"test"]);
}

- (void)testNumber
{
    [self.userData.preferences setNumber:@1012 atPath:@"n" inDomain:@"test"];
    [self.userData.preferences setNumber:@2024 atPath:@"path/to/n" inDomain:@"test"];
    
    XCTAssertEqualObjects([self.userData.preferences numberAtPath:@"n" inDomain:@"test"], @1012);
    XCTAssertEqualObjects([self.userData.preferences numberAtPath:@"path/to/n" inDomain:@"test"], @2024);
    
    XCTAssertNil([self.userData.preferences stringAtPath:@"path/to/missing/n" inDomain:@"test"]);
}

- (void)testBoolean
{
    [self.userData.preferences setNumber:@YES atPath:@"b" inDomain:@"test"];
    [self.userData.preferences setNumber:@YES atPath:@"path/to/b" inDomain:@"test"];
    
    XCTAssertEqualObjects([self.userData.preferences numberAtPath:@"b" inDomain:@"test"], @YES);
    XCTAssertEqualObjects([self.userData.preferences numberAtPath:@"path/to/b" inDomain:@"test"], @YES);
    
    XCTAssertNil([self.userData.preferences stringAtPath:@"path/to/missing/b" inDomain:@"test"]);
}

- (void)testArray
{
    [self.userData.preferences setArray:@[ @"1", @"2", @"3" ] atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setArray:@[ @"7", @"6", @"5", @"4" ] atPath:@"path/to/a" inDomain:@"test"];
    
    XCTAssertEqualObjects([self.userData.preferences arrayAtPath:@"a" inDomain:@"test"], (@[ @"1", @"2", @"3" ]));
    XCTAssertEqualObjects([self.userData.preferences arrayAtPath:@"path/to/a" inDomain:@"test"], (@[ @"7", @"6", @"5", @"4" ]));
    
    XCTAssertNil([self.userData.preferences arrayAtPath:@"path/to/missing/a" inDomain:@"test"]);
}

- (void)testDictionary
{
    [self.userData.preferences setDictionary:@{ @"A" : @1,
                                                @"B" : @2 } atPath:@"d" inDomain:@"test"];
    [self.userData.preferences setDictionary:@{ @"C" : @3,
                                                @"D" : @4,
                                                @"E" : @5} atPath:@"path/to/d" inDomain:@"test"];
    
    XCTAssertEqualObjects([self.userData.preferences dictionaryAtPath:@"d" inDomain:@"test"], (@{ @"A" : @1,
                                                                                                  @"B" : @2 }));
    XCTAssertEqualObjects([self.userData.preferences dictionaryAtPath:@"path/to/d" inDomain:@"test"], (@{ @"C" : @3,
                                                                                                          @"D" : @4,
                                                                                                          @"E" : @5}));
    
    XCTAssertNil([self.userData.preferences arrayAtPath:@"path/to/missing/d" inDomain:@"test"]);
}

- (void)testInvalidArray
{
    [self.userData.preferences setArray:@[ NSDate.date ] atPath:@"path/to/invalid_array" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences arrayAtPath:@"invalid_array" inDomain:@"test"]);
    
    // Since the object was not inserted, intermediate paths must not have been altered either
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path" inDomain:@"test"]);
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path/to" inDomain:@"test"]);
}

- (void)testInvalidDictionary
{
    [self.userData.preferences setDictionary:@{ @"A" : NSDate.date } atPath:@"path/to/invalid_dictionary" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences dictionaryAtPath:@"invalid_dictionary" inDomain:@"test"]);
    
    // Since the object was not inserted, intermediate paths must not have been altered either
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path" inDomain:@"test"]);
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path/to" inDomain:@"test"]);
}

- (void)testObjectReplacement
{
    
}

- (void)testSameKeysInPath
{
    
}

- (void)testRemoval
{
    [self.userData.preferences setString:@"x" atPath:@"a/b/c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"], @"x");
    
    [self.userData.preferences removeObjectAtPath:@"a/b/c" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"]);
    
    [self.userData.preferences setString:nil atPath:@"a" inDomain:@"test"];
}

- (void)testSpecialCharactersInPaths
{
    // TODO: Test paths beginning with /, containing empty items
}

- (void)testNotifications
{
    
}

// TODO: Add test where an item with a simple key (e.g. a) is added to a dict with the same key. Such tiny keys
//       are namely statically alloced and can be subtler to test
// TODO: Add test for complete cleanup of remote prefs
// TODO: Test for addition of same dic from 2 devices, with different items -> must merge
// TODO: Decide and test behavior for insertion at path where one of the components already exist and does not
//       point to a dictionary (currently: does nothing). Should insertion methods return a BOOL / error?
//       - Add test for SRGPreferencesDidChangeNotification on the main thread. Add domain as key in the user info
//         dictionary. DidChange => Check that the dictionary in the domain has changed. If not, do not broadcast
//         any notification (UT: test if setting the same value)
// TODO: Test storage of non-JSON serializable settings (e.g. with an NSDate)

@end
