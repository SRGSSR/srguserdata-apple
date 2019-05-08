//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

// Private headers
#import "SRGUser+Private.h"
#import "SRGUserObject+Private.h"

#import <libextobjc/libextobjc.h>

@interface MigrationTestCase : UserDataBaseTestCase

@end

@implementation MigrationTestCase

#pragma mark Overrides

- (NSString *)sessionToken
{
    // No need for a real token. We just want to be able to stub valid requests, but no real data management request
    // is required by this test suite.
    return @"dummy_token";
}

#pragma mark Setup and teardown

- (void)setUp
{
    [super setUp];
    
    // Databases have been generated for a previously logged in user. Restore the same conditions.
    [self setupForAvailableService];
    [self login];
}

#pragma mark Tests

- (void)testFailingMigration
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_invalid"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:nil];
    XCTAssertNil(userData);
}

// Version v1 was in Play 2.8.4 (prod 278), Play 2.8.5 (prod 280), Play 2.8.6 (prod 283), Play 2.8.7 (prod 284)
- (void)testMigrationFromV1
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v1"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:nil];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, dirty)];
    NSSortDescriptor *sortDescriptor3 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate3
                                                                  sortedWithDescriptors:@[sortDescriptor3]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, synchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, historySynchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, accountUid)]);
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return [notification.userInfo[SRGHistoryEntriesUidsKey] containsObject:uid2];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Save history entry"];
    
    [userData.history saveHistoryEntryWithUid:uid2 lastPlaybackTime:kCMTimeZero deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids4 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids4.count, 104);
}

// Version v2 was in Play 2.8.8 (beta 285)
- (void)testMigrationFromV2
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v2"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:nil];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, synchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, historySynchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, accountUid)]);
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return [notification.userInfo[SRGHistoryEntriesUidsKey] containsObject:uid2];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Save history entry"];
    
    [userData.history saveHistoryEntryWithUid:uid2 lastPlaybackTime:kCMTimeZero deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 104);
}

// Version v3 was in Play 2.8.8 (prod 289), Play 2.8.9 (prod 292)
- (void)testMigrationFromV3
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v3"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:self.identityService];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    // No migration from uid (NSInteger) to accountUid (NSString), UserData resets the user with the keychain account.
    XCTAssertNotNil(user);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, synchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, historySynchronizationDate)]);
    XCTAssertEqualObjects([user valueForKey:@keypath(SRGUser.new, accountUid)], @"1234");
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return [notification.userInfo[SRGHistoryEntriesUidsKey] containsObject:uid2];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Save history entry"];
    
    [userData.history saveHistoryEntryWithUid:uid2 lastPlaybackTime:kCMTimeZero deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 104);
}

// Version v4 was in Play 2.8.9 (beta 290), Play 2.8.9 (beta 291)
- (void)testMigrationFromV4
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v4"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:self.identityService];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    // No migration from uid (NSInteger) to accountUid (NSString), UserData resets the user with the keychain account.
    XCTAssertNotNil(user);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, synchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, historySynchronizationDate)]);
    XCTAssertEqualObjects([user valueForKey:@keypath(SRGUser.new, accountUid)], @"1234");
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return [notification.userInfo[SRGHistoryEntriesUidsKey] containsObject:uid2];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Save history entry"];
    
    [userData.history saveHistoryEntryWithUid:uid2 lastPlaybackTime:kCMTimeZero deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 104);
}

// Version v5 was in Play 2.8.10 (beta 293)
- (void)testMigrationFromV5
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v5"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:self.identityService];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, synchronizationDate)]);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, historySynchronizationDate)]);
    XCTAssertEqualObjects([user valueForKey:@keypath(SRGUser.new, accountUid)], @"1234");
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return [notification.userInfo[SRGHistoryEntriesUidsKey] containsObject:uid2];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Save history entry"];
    
    [userData.history saveHistoryEntryWithUid:uid2 lastPlaybackTime:kCMTimeZero deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 104);
}

// Version v6 was in Play 2.9 (prod 297)
- (void)testMigrationFromV6
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v6"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:self.identityService];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, synchronizationDate)]);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, historySynchronizationDate)]);
    XCTAssertEqualObjects([user valueForKey:@keypath(SRGUser.new, accountUid)], @"1234");
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return [notification.userInfo[SRGHistoryEntriesUidsKey] containsObject:uid2];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Save history entry"];
    
    [userData.history saveHistoryEntryWithUid:uid2 lastPlaybackTime:kCMTimeZero deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 104);
}

@end
