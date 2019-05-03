//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import <libextobjc/libextobjc.h>

@interface HistoryTestCase : UserDataBaseTestCase

@end

@implementation HistoryTestCase

#pragma mark Helpers

- (void)addUids:(NSArray<NSString *> *)uids
{
    NSMutableSet<NSString *> *expectedSavedNotifications = [NSSet setWithArray:uids].mutableCopy;
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertNotNil(notification.userInfo[SRGHistoryUidsKey]);
        NSMutableSet<NSString *> *uids = [notification.userInfo[SRGHistoryUidsKey] mutableCopy];
        NSSet<NSString *> *previousUids = notification.userInfo[SRGHistoryPreviousUidsKey];
        [uids minusSet:previousUids];
        NSSet<NSString *> *changedUids = [uids copy];
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryChangedUidsKey], changedUids);
        
        [expectedSavedNotifications minusSet:changedUids];
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        CMTime time = CMTimeMakeWithSeconds(uid.integerValue, NSEC_PER_SEC);
        XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
        
        [self.userData.history saveHistoryEntryWithUid:uid lastPlaybackTime:time deviceUid:@"Test device" completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

#pragma mark Setup and tear down

- (void)setUp
{
    [super setUp];
    
    [self setupForOfflineOnly];
}

#pragma mark Tests

- (void)testEmptyInitialization
{
    XCTAssertNotNil(self.userData.history);
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries.count, 0);
}

- (void)testSaveHistoryEntry
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    
    NSString *deviceUid = @"Test device";
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryChangedUidsKey],  [NSSet setWithObject:uid]);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryUidsKey], [NSSet setWithObject:uid]);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryPreviousUidsKey], NSSet.set);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryWithUid:uid lastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testSaveHistoryEntries
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    NSString *deviceUid = @"Test device";
    
    NSMutableSet<NSString *> *expectedSavedNotifications = [NSSet setWithArray:uids].mutableCopy;
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertNotNil(notification.userInfo[SRGHistoryUidsKey]);
        if (notification.userInfo[SRGHistoryPreviousUidsKey]) {
            NSMutableSet<NSString *> *uids = [notification.userInfo[SRGHistoryUidsKey] mutableCopy];
            NSSet<NSString *> *previousUids = notification.userInfo[SRGHistoryPreviousUidsKey];
            [uids minusSet:previousUids];
            [expectedSavedNotifications minusSet:uids];
        }
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        CMTime time = CMTimeMakeWithSeconds(uid.integerValue, NSEC_PER_SEC);
        XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
        
        [self.userData.history saveHistoryEntryWithUid:uid lastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    id historyDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"History must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:historyDidChangeObserver];
    }];
}

- (void)testSaveSameHistoryEntry
{
    NSString *uid = @"1234";
    NSString *deviceUid = @"Test device";
    
    NSUInteger numberOfSaves = 5;
    __block NSUInteger expectedSavedNotifications = numberOfSaves;
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryUidsKey], [NSSet setWithObject:uid]);
        if (expectedSavedNotifications == numberOfSaves) {
            XCTAssertEqualObjects(notification.userInfo[SRGHistoryPreviousUidsKey], NSSet.set);
        }
        else {
            XCTAssertEqualObjects(notification.userInfo[SRGHistoryPreviousUidsKey], [NSSet setWithObject:uid]);
        }
        expectedSavedNotifications -= 1;
        return (expectedSavedNotifications == 0);
    }];
    
    for (NSUInteger i = 0; i < numberOfSaves; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
        
        [self.userData.history saveHistoryEntryWithUid:uid lastPlaybackTime:CMTimeMakeWithSeconds(i, NSEC_PER_SEC) deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    id historyDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"History must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:historyDidChangeObserver];
    }];
}

- (void)testHistoryEntryWithUid
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    
    NSString *deviceUid = @"Test device";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryWithUid:uid lastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    SRGHistoryEntry *historyEntry1 = [self.userData.history historyEntryWithUid:uid];
    
    XCTAssertEqualObjects(historyEntry1.uid, uid);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry1.lastPlaybackTime, ==, time));
    XCTAssertEqualObjects(historyEntry1.deviceUid, deviceUid);
    XCTAssertFalse(historyEntry1.discarded);
    
    SRGHistoryEntry *historyEntry2 = [self.userData.history historyEntryWithUid:@"notFound"];
    
    XCTAssertNil(historyEntry2);
}

- (void)testHistoryEntryWithUidAsynchronously
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    
    NSString *deviceUid = @"Test device";
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryWithUid:uid lastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntryWithUid:uid completionBlock:^(SRGHistoryEntry * _Nullable historyEntry, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqualObjects(historyEntry.uid, uid);
        XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, time));
        XCTAssertEqualObjects(historyEntry.deviceUid, deviceUid);
        XCTAssertFalse(historyEntry.discarded);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntryWithUid:@"notFound" completionBlock:^(SRGHistoryEntry * _Nullable historyEntry, NSError * _Nullable error) {
        XCTAssertNil(historyEntry);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntriesMatchingEmptyPredicateEmptySortDescriptor
{
    NSArray<SRGHistoryEntry *> *historyEntries1 = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertNotNil(historyEntries1);
    XCTAssertEqual(historyEntries1.count, 0);
    
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self addUids:uids];
    
    NSArray<SRGHistoryEntry *> *historyEntries2 = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries2.count, uids.count);
    
    NSArray<NSString *> *queryUids2 = [historyEntries2 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids2, [[uids reverseObjectEnumerator] allObjects]);
}

- (void)testHistoryEntriesMatchingEmptyPredicateEmptySortDescriptorAsynchronously
{
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"History entries fetched"];
    
    [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries1, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNotNil(historyEntries1);
        XCTAssertEqual(historyEntries1.count, 0);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self addUids:uids];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"History entries fetched"];
    
    [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries2, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(historyEntries2.count, uids.count);
        
        NSArray<NSString *> *queryUids2 = [historyEntries2 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(queryUids2, [[uids reverseObjectEnumerator] allObjects]);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntriesMatchingPredicatesOrSortDescriptors
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self addUids:uids];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:YES];
    NSArray<SRGHistoryEntry *> *historyEntries1 = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor1]];
    
    XCTAssertEqual(historyEntries1.count, uids.count);
    NSArray<NSString *> *queryUids1 = [historyEntries1 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids1, uids);
    
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, uid) ascending:YES];
    NSArray<SRGHistoryEntry *> *historyEntries2 = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor2]];
    
    XCTAssertEqual(historyEntries2.count, uids.count);
    NSArray<NSString *> *queryUids2 = [historyEntries2 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids2, uids);
    
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSArray<SRGHistoryEntry *> *historyEntries3 = [self.userData.history historyEntriesMatchingPredicate:predicate3 sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries3.count, uids.count);
    NSArray<NSString *> *queryUids3 = [historyEntries3 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids3, [[uids reverseObjectEnumerator] allObjects]);
    
    NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGHistoryEntry.new, deviceUid), @"Test device"];
    NSArray<SRGHistoryEntry *> *historyEntries4 = [self.userData.history historyEntriesMatchingPredicate:predicate4 sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries4.count, uids.count);
    NSArray<NSString *> *queryUids4 = [historyEntries4 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids4, [[uids reverseObjectEnumerator] allObjects]);
    
    NSString *queryUid = @"34";
    NSPredicate *predicate5 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGHistoryEntry.new, uid), queryUid];
    NSArray<SRGHistoryEntry *> *historyEntries5 = [self.userData.history historyEntriesMatchingPredicate:predicate5 sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries5.count, 1);
    SRGHistoryEntry *historyEntry = historyEntries5.firstObject;
    XCTAssertEqualObjects(historyEntry.uid, queryUid);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, CMTimeMakeWithSeconds(queryUid.integerValue, NSEC_PER_SEC)));
    XCTAssertEqualObjects(historyEntry.deviceUid, @"Test device");
    XCTAssertFalse(historyEntry.discarded);
    
    NSPredicate *predicate6 = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@", @keypath(SRGHistoryEntry.new, uid), @"1", @keypath(SRGHistoryEntry.new, uid), @"9"];
    NSSortDescriptor *sortDescriptor6 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:YES];
    NSArray<SRGHistoryEntry *> *historyEntries6 = [self.userData.history historyEntriesMatchingPredicate:predicate6 sortedWithDescriptors:@[sortDescriptor6]];
    
    NSArray<NSString *> *expectedQueryUids6 = @[@"12", @"90"];
    XCTAssertEqual(historyEntries6.count, expectedQueryUids6.count);
    NSArray<NSString *> *queryUids6 = [historyEntries6 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids6, expectedQueryUids6);
    
    NSPredicate *predicate7 = [NSPredicate predicateWithFormat:@"%K < 60", @keypath(SRGHistoryEntry.new, lastPlaybackPosition)];
    NSSortDescriptor *sortDescriptor7 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<SRGHistoryEntry *> *historyEntries7 = [self.userData.history historyEntriesMatchingPredicate:predicate7 sortedWithDescriptors:@[sortDescriptor7]];
    
    NSArray<NSString *> *expectedQueryUids7 = @[@"56", @"34", @"12"];
    XCTAssertEqual(historyEntries7.count, expectedQueryUids7.count);
    NSArray<NSString *> *queryUids7 = [historyEntries7 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids7, expectedQueryUids7);
}

- (void)testHistoryEntriesMatchingPredicatesOrSortDescriptorsAsynchronously
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self addUids:uids];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"History entries fetched"];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:YES];
    [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor1] completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries1, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(historyEntries1.count, uids.count);
        NSArray<NSString *> *queryUids1 = [historyEntries1 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(queryUids1, uids);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"History entries fetched"];
    
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, uid) ascending:YES];
    [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor2] completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries2, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(historyEntries2.count, uids.count);
        NSArray<NSString *> *queryUids2 = [historyEntries2 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(queryUids2, uids);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"History entries fetched"];
    
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    [self.userData.history historyEntriesMatchingPredicate:predicate3 sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries3, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(historyEntries3.count, uids.count);
        NSArray<NSString *> *queryUids3 = [historyEntries3 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(queryUids3, [[uids reverseObjectEnumerator] allObjects]);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"History entries fetched"];
    
    NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"%K == 'Test device'", @keypath(SRGHistoryEntry.new, deviceUid)];
    [self.userData.history historyEntriesMatchingPredicate:predicate4 sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries4, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(historyEntries4.count, uids.count);
        NSArray<NSString *> *queryUids4 = [historyEntries4 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(queryUids4, [[uids reverseObjectEnumerator] allObjects]);
        [expectation4 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation5 = [self expectationWithDescription:@"History entries fetched"];
    
    NSString *queryUid = @"34";
    NSPredicate *predicate5 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGHistoryEntry.new, uid), queryUid];
    [self.userData.history historyEntriesMatchingPredicate:predicate5 sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries5, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(historyEntries5.count, 1);
        SRGHistoryEntry *historyEntry = historyEntries5.firstObject;
        XCTAssertEqualObjects(historyEntry.uid, queryUid);
        XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, CMTimeMakeWithSeconds(queryUid.integerValue, NSEC_PER_SEC)));
        XCTAssertEqualObjects(historyEntry.deviceUid, @"Test device");
        XCTAssertFalse(historyEntry.discarded);
        [expectation5 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation6 = [self expectationWithDescription:@"History entries fetched"];
    
    NSPredicate *predicate6 = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@", @keypath(SRGHistoryEntry.new, uid), @"1", @keypath(SRGHistoryEntry.new, uid), @"9"];
    NSSortDescriptor *sortDescriptor6 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:YES];
    [self.userData.history historyEntriesMatchingPredicate:predicate6 sortedWithDescriptors:@[sortDescriptor6] completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries6, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        NSArray<NSString *> *expectedQueryUids6 = @[@"12", @"90"];
        XCTAssertEqual(historyEntries6.count, expectedQueryUids6.count);
        NSArray<NSString *> *queryUids6 = [historyEntries6 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(queryUids6, expectedQueryUids6);
        [expectation6 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation7 = [self expectationWithDescription:@"History entries fetched"];
    
    NSPredicate *predicate7 = [NSPredicate predicateWithFormat:@"%K < 60", @keypath(SRGHistoryEntry.new, lastPlaybackPosition)];
    NSSortDescriptor *sortDescriptor7 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    [self.userData.history historyEntriesMatchingPredicate:predicate7 sortedWithDescriptors:@[sortDescriptor7] completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries7, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        NSArray<NSString *> *expectedQueryUids7 = @[@"56", @"34", @"12"];
        XCTAssertEqual(historyEntries7.count, expectedQueryUids7.count);
        NSArray<NSString *> *queryUids7 = [historyEntries7 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(queryUids7, expectedQueryUids7);
        [expectation7 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testDiscardHistoryEntries
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self addUids:uids];
    
    NSArray<NSString *> *discardedUids = @[@"12", @"90"];
    NSArray<NSString *> *remainingUids = @[@"34", @"56", @"78"];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryChangedUidsKey], [NSSet setWithArray:discardedUids]);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryUidsKey], [NSSet setWithArray:remainingUids]);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryPreviousUidsKey], [NSSet setWithArray:uids]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History discarded"];
    
    [self.userData.history discardHistoryEntriesWithUids:discardedUids completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(historyEntries.count, 3);
    
    id historyDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"History must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:historyDidChangeObserver];
    }];
}

- (void)testDiscardAllHistoryEntries
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self addUids:uids];
    
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryChangedUidsKey], [NSSet setWithArray:uids]);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryUidsKey], NSSet.set);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryPreviousUidsKey], [NSSet setWithArray:uids]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History discarded"];
    
    [self.userData.history discardHistoryEntriesWithUids:nil completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(historyEntries.count, 0);
    
    id historyDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGHistoryDidChangeNotification object:self.userData.history queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"History must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:historyDidChangeObserver];
    }];
}

@end
