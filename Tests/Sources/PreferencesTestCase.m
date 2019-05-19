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
    [self.userData.preferences setArray:@[ @"1", @2, @"3" ] atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setArray:@[ @"7", @"6", @"5", @"4" ] atPath:@"path/to/a" inDomain:@"test"];
    
    XCTAssertEqualObjects([self.userData.preferences arrayAtPath:@"a" inDomain:@"test"], (@[ @"1", @2, @"3" ]));
    XCTAssertEqualObjects([self.userData.preferences arrayAtPath:@"path/to/a" inDomain:@"test"], (@[ @"7", @"6", @"5", @"4" ]));
    
    XCTAssertNil([self.userData.preferences arrayAtPath:@"path/to/missing/a" inDomain:@"test"]);
}

- (void)testNoArrayMerge
{
    [self.userData.preferences setArray:@[ @"1", @2, @"3" ] atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setArray:@[ @"4", @"5" ] atPath:@"a" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences arrayAtPath:@"a" inDomain:@"test"], (@[ @"4", @"5" ]));
}

- (void)testUnsupportedArray
{
    [self.userData.preferences setArray:@[ NSDate.date ] atPath:@"path/to/invalid_array" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences arrayAtPath:@"invalid_array" inDomain:@"test"]);
    
    // Since the object was not inserted, intermediate paths must not have been altered either
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path" inDomain:@"test"]);
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path/to" inDomain:@"test"]);
}

- (void)testDictionary
{
    [self.userData.preferences setDictionary:@{ @"A" : @"a",
                                                @"B" : @2,
                                                @"C" : @[ @"a", @2 ],
                                                @"D" : @{ @"A" : @1 } } atPath:@"d" inDomain:@"test"];
    [self.userData.preferences setDictionary:@{ @"C" : @3,
                                                @"D" : @4 } atPath:@"path/to/d" inDomain:@"test"];
    
    XCTAssertEqualObjects([self.userData.preferences dictionaryAtPath:@"d" inDomain:@"test"], (@{ @"A" : @"a",
                                                                                                  @"B" : @2,
                                                                                                  @"C" : @[ @"a", @2 ],
                                                                                                  @"D" : @{ @"A" : @1 } }));
    XCTAssertEqualObjects([self.userData.preferences dictionaryAtPath:@"path/to/d" inDomain:@"test"], (@{ @"C" : @3,
                                                                                                          @"D" : @4 }));
    
    XCTAssertNil([self.userData.preferences arrayAtPath:@"path/to/missing/d" inDomain:@"test"]);
}

- (void)testNoDictionaryMerge
{
    [self.userData.preferences setString:@"x" atPath:@"a/b" inDomain:@"test"];
    [self.userData.preferences setString:@"y" atPath:@"a/c" inDomain:@"test"];
    [self.userData.preferences setDictionary:@{ @"d" : @"z" } atPath:@"a" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences dictionaryAtPath:@"a" inDomain:@"test"], @{ @"d" : @"z" });
}

- (void)testUnsupportedDictionary
{
    [self.userData.preferences setDictionary:@{ @"A" : NSDate.date } atPath:@"path/to/invalid_dictionary" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences dictionaryAtPath:@"invalid_dictionary" inDomain:@"test"]);
    
    // Since the object was not inserted, intermediate paths must not have been altered either
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path" inDomain:@"test"]);
    XCTAssertFalse([self.userData.preferences hasObjectAtPath:@"path/to" inDomain:@"test"]);
}

- (void)testMultipleInsertions
{
    [self.userData.preferences setObjectsAtPaths:@{ @"s" : @"x",
                                                    @"n" : @1,
                                                    @"d" : @{ @"a" : @"y",
                                                              @"b" : @2 },
                                                    @"a" : @[ @1, @"2", @3 ],
                                                    @"o/s" : @"x",
                                                    @"o/n" : @2 } inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences dictionaryAtPath:nil inDomain:@"test"], (@{ @"s" : @"x",
                                                                                                 @"n" : @1,
                                                                                                 @"d" : @{ @"a" : @"y",
                                                                                                           @"b" : @2 },
                                                                                                 @"a" : @[ @1, @"2", @3 ],
                                                                                                 @"o" : @{ @"s" : @"x",
                                                                                                           @"n" : @2 } }));
}

- (void)testMultipleInsertionsWithInvalidObjects
{
    [self.userData.preferences setObjectsAtPaths:@{ @"s" : @"x",
                                                    @"n" : @1,
                                                    @"d" : NSDate.date } inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences dictionaryAtPath:nil inDomain:@"test"], (@{ @"s" : @"x",
                                                                                                 @"n" : @1 }));
}

- (void)testObjectUpdate
{
    [self.userData.preferences setString:@"x" atPath:@"a/b/c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"], @"x");

    [self.userData.preferences setString:@"y" atPath:@"a/b/c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"], @"y");
}

- (void)testImplicitObjectReplacement
{
    [self.userData.preferences setString:@"x" atPath:@"a/b/c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"], @"x");
    
    [self.userData.preferences setString:@"y" atPath:@"a/b" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b" inDomain:@"test"], @"y");
    XCTAssertNil([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"]);
}

- (void)testDomainRootInsertion
{
    [self.userData.preferences setString:@"x" atPath:@"s" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"s" inDomain:@"test"], @"x");
}

- (void)testTypeMismatchOnRead
{
    [self.userData.preferences setString:@"x" atPath:@"s" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences numberAtPath:@"s" inDomain:@"test"]);
    XCTAssertNil([self.userData.preferences arrayAtPath:@"s" inDomain:@"test"]);
    XCTAssertNil([self.userData.preferences dictionaryAtPath:@"s" inDomain:@"test"]);
    
    [self.userData.preferences setNumber:@1012 atPath:@"n" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"n" inDomain:@"test"]);
    XCTAssertNil([self.userData.preferences arrayAtPath:@"n" inDomain:@"test"]);
    XCTAssertNil([self.userData.preferences dictionaryAtPath:@"n" inDomain:@"test"]);
    
    [self.userData.preferences setArray:@[ @1, @2, @3 ] atPath:@"a" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a" inDomain:@"test"]);
    XCTAssertNil([self.userData.preferences numberAtPath:@"a" inDomain:@"test"]);
    XCTAssertNil([self.userData.preferences dictionaryAtPath:@"a" inDomain:@"test"]);
    
    [self.userData.preferences setDictionary:@{ @"A" : @1 } atPath:@"d" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"d" inDomain:@"test"]);
    XCTAssertNil([self.userData.preferences numberAtPath:@"d" inDomain:@"test"]);
    XCTAssertNil([self.userData.preferences arrayAtPath:@"d" inDomain:@"test"]);
}

- (void)testDoubleSlashInPath
{
    [self.userData.preferences setString:@"x" atPath:@"a//b" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a//b" inDomain:@"test"], @"x");
}

- (void)testSameKeysInPath
{
    [self.userData.preferences setString:@"x" atPath:@"a/b/c" inDomain:@"test"];
    [self.userData.preferences setString:@"y" atPath:@"a/b/a" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b/a" inDomain:@"test"], @"y");
}

- (void)testDomainDictionary
{
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setString:@"y" atPath:@"b/c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences dictionaryAtPath:nil inDomain:@"test"], (@{ @"a" : @"x",
                                                                                                 @"b" : @{ @"c" : @"y" }}));
}

- (void)testRemoval
{
    [self.userData.preferences setString:@"x" atPath:@"a/b/c" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"], @"x");
    
    [self.userData.preferences removeObjectsAtPaths:@[@"a/b/c"] inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a/b/c" inDomain:@"test"]);
    
    [self.userData.preferences setString:nil atPath:@"a" inDomain:@"test"];
}

- (void)testSupportedDomains
{
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"aA1$-_"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a" inDomain:@"aA1$-_"], @"x");
}

- (void)testUnsupportedDomains
{
    [self.userData.preferences setString:@"1" atPath:@"a" inDomain:@""];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a" inDomain:@""]);
    
    [self.userData.preferences setString:@"2" atPath:@"a" inDomain:@" "];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a" inDomain:@" "]);
    
    [self.userData.preferences setString:@"3" atPath:@"a" inDomain:@"/"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a" inDomain:@"/"]);
    
    [self.userData.preferences setString:@"4" atPath:@"a" inDomain:@"d/"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a" inDomain:@"d/"]);
    
    [self.userData.preferences setString:@"5" atPath:@"a" inDomain:@"/d"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a" inDomain:@"/d"]);
    
    [self.userData.preferences setString:@"6" atPath:@"a" inDomain:@"/d/"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a" inDomain:@"/d/"]);
    
    [self.userData.preferences setString:@"7" atPath:@"a" inDomain:@"a%20b"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"a" inDomain:@"a%20b"]);
}

- (void)testSupportedPaths
{
    [self.userData.preferences setString:@"x" atPath:@"aA1$-_/bB2$-_" inDomain:@"domain"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"aA1$-_/bB2$-_" inDomain:@"domain"], @"x");
}

- (void)testUnsupportedPaths
{
    [self.userData.preferences setString:@"1" atPath:@"" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"" inDomain:@"test"]);
    
    [self.userData.preferences setString:@"2" atPath:@" " inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@" " inDomain:@"test"]);
    
    [self.userData.preferences setString:@"3" atPath:@"/" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"/" inDomain:@"test"]);
    
    [self.userData.preferences setString:@"4" atPath:@"//" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"//" inDomain:@"test"]);
    
    [self.userData.preferences setString:@"5" atPath:@"a%20b" inDomain:@"test"];
    XCTAssertNil([self.userData.preferences stringAtPath:@"" inDomain:@"test"]);
}

- (void)testPathTrimming
{
    [self.userData.preferences setString:@"x" atPath:@"/a" inDomain:@"domain"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a" inDomain:@"domain"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"/a" inDomain:@"domain"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a/" inDomain:@"domain"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"/a/" inDomain:@"domain"], @"x");
    
    [self.userData.preferences setString:@"x" atPath:@"b/" inDomain:@"domain"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"b" inDomain:@"domain"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"/b" inDomain:@"domain"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"b/" inDomain:@"domain"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"/b/" inDomain:@"domain"], @"x");
    
    [self.userData.preferences setString:@"x" atPath:@"/c/" inDomain:@"domain"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"c" inDomain:@"domain"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"/c" inDomain:@"domain"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"c/" inDomain:@"domain"], @"x");
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"/c/" inDomain:@"domain"], @"x");
}

- (void)testNotificationOnInsertion
{
    [self expectationForSingleNotification:SRGPreferencesDidChangeNotification object:self.userData.preferences handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        return YES;
    }];
    
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testNotificationOnModification
{
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    XCTAssertEqualObjects([self.userData.preferences stringAtPath:@"a" inDomain:@"test"], @"x");
    
    [self expectationForSingleNotification:SRGPreferencesDidChangeNotification object:self.userData.preferences handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        return YES;
    }];
    
    [self.userData.preferences setString:@"xx" atPath:@"a" inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testNotificationOnRemoval
{
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    
    [self expectationForSingleNotification:SRGPreferencesDidChangeNotification object:self.userData.preferences handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        return YES;
    }];
    
    [self.userData.preferences removeObjectsAtPaths:@[@"a"] inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testMultipleNotificationsOnMultipleSingleInsertions
{
    __block NSUInteger changeNotificationCount = 0;
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        ++changeNotificationCount;
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.userData.preferences setString:@"xx" atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setString:@"yy" atPath:@"b" inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTAssertEqual(changeNotificationCount, 2);
}

- (void)testMultipleNotificationsOnMultipleSingleModifications
{
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setString:@"y" atPath:@"b" inDomain:@"test"];
    
    __block NSUInteger changeNotificationCount = 0;
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        ++changeNotificationCount;
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.userData.preferences setString:@"xx" atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setString:@"yy" atPath:@"b" inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTAssertEqual(changeNotificationCount, 2);
}

- (void)testSingleNotificationOnMultipleChanges
{
    __block NSUInteger changeNotificationCount = 0;
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        ++changeNotificationCount;
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.userData.preferences setObjectsAtPaths:@{ @"s" : @"x",
                                                    @"n" : @1 } inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTAssertEqual(changeNotificationCount, 1);
}

- (void)testSingleNotificationOnMultipleRemovals
{
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setString:@"y" atPath:@"b" inDomain:@"test"];
    
    __block NSUInteger changeNotificationCount = 0;
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        ++changeNotificationCount;
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.userData.preferences removeObjectsAtPaths:@[@"a", @"b"] inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTAssertEqual(changeNotificationCount, 1);
}

- (void)testNoNotificationForRemovalOfUnknownObject
{
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    
    __block NSUInteger changeNotificationCount = 0;
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        ++changeNotificationCount;
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.userData.preferences removeObjectsAtPaths:@[@"b"] inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTAssertEqual(changeNotificationCount, 0);
}

- (void)testNoNotificationForModificationWithSameValue
{
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setString:@"y" atPath:@"b" inDomain:@"test"];
    
    __block NSUInteger changeNotificationCount = 0;
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        ++changeNotificationCount;
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setString:@"y" atPath:@"b" inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTAssertEqual(changeNotificationCount, 0);
}

- (void)testNotificationsForChangesInDifferentDomains
{
    __block BOOL changeNotification1Received = NO;
    __block BOOL changeNotification2Received = NO;
    
    [self expectationForSingleNotification:SRGPreferencesDidChangeNotification object:self.userData.preferences handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        
        if ([notification.userInfo[SRGPreferencesDomainsKey] isEqualToSet:[NSSet setWithObject:@"test1"]]) {
            changeNotification1Received = YES;
        }
        else if ([notification.userInfo[SRGPreferencesDomainsKey] isEqualToSet:[NSSet setWithObject:@"test2"]]) {
            changeNotification2Received = YES;
        }
        return changeNotification1Received && changeNotification2Received;
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test1"];
    [self.userData.preferences setString:@"y" atPath:@"b" inDomain:@"test2"];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testNoNotificationForMultipleChangesWithSameValues
{
    [self.userData.preferences setString:@"x" atPath:@"a" inDomain:@"test"];
    [self.userData.preferences setString:@"y" atPath:@"b" inDomain:@"test"];
    
    __block NSUInteger changeNotificationCount = 0;
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        ++changeNotificationCount;
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.userData.preferences setObjectsAtPaths:@{ @"a" : @"x",
                                                    @"b" : @"y" } inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTAssertEqual(changeNotificationCount, 0);
}

- (void)testNoNotificationForMultipleInvalidChanges
{
    __block NSUInteger changeNotificationCount = 0;
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPreferencesDidChangeNotification object:self.userData.preferences queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPreferencesDomainsKey], [NSSet setWithObject:@"test"]);
        ++changeNotificationCount;
    }];
    
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    [self.userData.preferences setObjectsAtPaths:@{ @"s" : NSDate.date,
                                                    @"u" : [NSURL URLWithString:@"http://www.rts.ch/play"] } inDomain:@"test"];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTAssertEqual(changeNotificationCount, 0);
}

// TODO: Add test for complete cleanup of remote prefs
// TODO: Test for addition of same dic from 2 devices, with different items -> must merge
// TODO: Check sync and notifs with a few domains removed remotely, while other ones have been added (one notif with
//       several deleted domains, and other notifs individually for updated domains)

@end
