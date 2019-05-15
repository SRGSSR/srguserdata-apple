//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

// Private headers
#import "SRGPreferenceChangeLogEntry.h"

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

- (void)testMigrationToChangeLog
{
    // TODO: Should be turned into proper tests
    NSArray<SRGPreferenceChangeLogEntry *> *entries1 = [SRGPreferenceChangeLogEntry changeLogEntriesForPreferenceDictionary:@{} inDomain:@"domain"];
    NSLog(@"%@", entries1);
    
    NSArray<SRGPreferenceChangeLogEntry *> *entries2 = [SRGPreferenceChangeLogEntry changeLogEntriesForPreferenceDictionary:@{ @"n" : @1,
                                                                                                                               @"s" : @"hello" } inDomain:@"domain"];
    NSLog(@"%@", entries2);
    
    NSArray<SRGPreferenceChangeLogEntry *> *entries3 = [SRGPreferenceChangeLogEntry changeLogEntriesForPreferenceDictionary:@{ @"n" : @1,
                                                                                                                               @"s" : @"lev1",
                                                                                                                               @"d" : @{ @"n" : @2,
                                                                                                                                         @"s" : @"lev2" }
                                                                                                                               } inDomain:@"domain"];
    NSLog(@"%@", entries3);
}

@end
