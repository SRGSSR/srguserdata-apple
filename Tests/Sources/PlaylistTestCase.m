//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import <libextobjc/libextobjc.h>

@interface SRGPlaylistTestCase : UserDataBaseTestCase

@property (nonatomic) SRGUserData *userData;

@end

@implementation SRGPlaylistTestCase

#pragma mark Helpers

- (void)saveUids:(NSArray<NSString *> *)uids
{
    NSMutableArray<NSString *> *expectedSavedNotifications = uids.mutableCopy;
    
    [self expectationForSingleNotification:SRGPlaylistDidChangeNotification object:self.userData.playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistChangedUidsKey];
        [expectedSavedNotifications removeObjectsInArray:uids];
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        NSString *name = [NSString stringWithFormat:@"Playlist %@", uid];
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
        
        [self.userData.playlist savePlaylistEntryForUid:uid withName:name completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

#pragma mark Setup and tear down

- (void)setUp
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil playlistServiceURL:nil identityService:nil];
}

- (void)tearDown
{
    self.userData = nil;
}

#pragma mark Tests

- (void)testEmptyPlaylistInitialization
{
    XCTAssertNotNil(self.userData.playlist);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlistEntries.count, 1);
}

- (void)testWatchLaterEntryWithUid
{
    SRGPlaylistEntry *playlistEntry = [self.userData.playlist playlistEntryWithUid:SRGPlaylistSystemWatchLaterUid];
    
    XCTAssertEqualObjects(playlistEntry.uid, SRGPlaylistSystemWatchLaterUid);
    XCTAssertTrue(playlistEntry.system);
    XCTAssertEqualObjects(playlistEntry.name, SRGPlaylistNameForPlaylistWithUid(SRGPlaylistSystemWatchLaterUid));
    XCTAssertFalse(playlistEntry.discarded);
}

- (void)testSavePlaylistEntry
{
    NSString *uid = @"1234";
    NSString *name = @"Playlist 1234";
    
    [self expectationForSingleNotification:SRGPlaylistDidChangeNotification object:self.userData.playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistChangedUidsKey], @[uid]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistPreviousUidsKey], @[SRGPlaylistSystemWatchLaterUid]);
        NSArray<NSString *> *uids = @[SRGPlaylistSystemWatchLaterUid, uid];
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidsKey], uids);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
    
    [self.userData.playlist savePlaylistEntryForUid:uid withName:name completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlistEntries.count, 2);
}

- (void)testSavePlaylistEntries
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    NSString *nameFormat = @"Playlist %@";

    NSMutableArray<NSString *> *expectedSavedNotifications = uids.mutableCopy;
    
    [self expectationForSingleNotification:SRGPlaylistDidChangeNotification object:self.userData.playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistChangedUidsKey];
        [expectedSavedNotifications removeObjectsInArray:uids];
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        NSString *name = [NSString stringWithFormat:nameFormat, uid];
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
        
        [self.userData.playlist savePlaylistEntryForUid:uid withName:name completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistDidChangeNotification object:self.userData.playlist queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlistEntries.count, 6);
}

- (void)testSaveSamePlaylistEntry
{
    NSString *uid = @"1234";
    NSString *name = @"Playlist 1234";

    NSUInteger numberOfSaves = 5;
    __block NSUInteger expectedSavedNotifications = numberOfSaves;
    
    [self expectationForSingleNotification:SRGPlaylistDidChangeNotification object:self.userData.playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistChangedUidsKey];
        expectedSavedNotifications -= uids.count;
        return (expectedSavedNotifications == 0);
    }];
    
    for (NSUInteger i = 0; i < numberOfSaves; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
        
        [self.userData.playlist savePlaylistEntryForUid:uid withName:name completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistDidChangeNotification object:self.userData.playlist queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlistEntries.count, 2);
}

- (void)testPlaylistEntryWithUid
{
    NSString *uid = @"1234";
    NSString *name = @"Playlist 1234";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
    
    [self.userData.playlist savePlaylistEntryForUid:uid withName:name completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    SRGPlaylistEntry *playlistEntry1 = [self.userData.playlist playlistEntryWithUid:uid];
    
    XCTAssertEqualObjects(playlistEntry1.uid, uid);
    XCTAssertFalse(playlistEntry1.system);
    XCTAssertEqualObjects(playlistEntry1.name, name);
    XCTAssertFalse(playlistEntry1.discarded);
    
    SRGPlaylistEntry *playlistEntry2 = [self.userData.playlist playlistEntryWithUid:@"notFound"];
    
    XCTAssertNil(playlistEntry2);
}

- (void)testPlaylistEntryWithUidAsynchronously
{
    NSString *uid = @"1234";
    NSString *name = @"Playlist 1234";
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entry saved"];
    
    [self.userData.playlist savePlaylistEntryForUid:uid withName:name completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entry fetched"];
    
    [self.userData.playlist playlistEntryWithUid:uid completionBlock:^(SRGPlaylistEntry * _Nullable playlistEntry, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqualObjects(playlistEntry.uid, uid);
        XCTAssertFalse(playlistEntry.system);
        XCTAssertEqualObjects(playlistEntry.name, name);
        XCTAssertFalse(playlistEntry.discarded);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist entry fetched"];
    
    [self.userData.playlist playlistEntryWithUid:@"notFound" completionBlock:^(SRGPlaylistEntry * _Nullable playlistEntry, NSError * _Nullable error) {
        XCTAssertNil(playlistEntry);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylistEntriesMatchingEmptyPredicateEmptySortDescriptor
{
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertNotNil(playlistEntries1);
    XCTAssertEqual(playlistEntries1.count, 1);
    
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self saveUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlistEntries2.count, resultUids.count);
    
    NSArray<NSString *> *queryUids2 = [playlistEntries2 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(queryUids2, [[resultUids reverseObjectEnumerator] allObjects]);
}

- (void)testPlaylistEntriesMatchingEmptyPredicateEmptySortDescriptorAsynchronously
{
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nonnull playlistEntries1, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNotNil(playlistEntries1);
        XCTAssertEqual(playlistEntries1.count, 1);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self saveUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nonnull playlistEntries2, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlistEntries2.count, resultUids.count);
        
        NSArray<NSString *> *queryUids2 = [playlistEntries2 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        XCTAssertEqualObjects(queryUids2, [[resultUids reverseObjectEnumerator] allObjects]);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylistEntriesMatchingPredicatesOrSortDescriptors
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self saveUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    NSArray<NSString *> *resultByDateUids = [@[SRGPlaylistSystemWatchLaterUid] arrayByAddingObjectsFromArray:uids];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, date) ascending:YES];
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor1]];
    
    XCTAssertEqual(playlistEntries1.count, resultByDateUids.count);
    NSArray<NSString *> *queryUids1 = [playlistEntries1 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(queryUids1, resultByDateUids);
    
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, uid) ascending:YES];
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor2]];
    
    XCTAssertEqual(playlistEntries2.count, resultUids.count);
    NSArray<NSString *> *queryUids2 = [playlistEntries2 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(queryUids2, resultUids);
    
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylistEntry.new, discarded)];
    NSArray<SRGPlaylistEntry *> *playlistEntries3 = [self.userData.playlist playlistEntriesMatchingPredicate:predicate3 sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlistEntries3.count, resultUids.count);
    NSArray<NSString *> *queryUids3 = [playlistEntries3 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(queryUids3, [[resultUids reverseObjectEnumerator] allObjects]);
    
    NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, name), @"Playlist 78"];
    NSArray<SRGPlaylistEntry *> *playlistEntries4 = [self.userData.playlist playlistEntriesMatchingPredicate:predicate4 sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlistEntries4.count, 1);
    NSArray<NSString *> *queryUids4 = [playlistEntries4 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(queryUids4, @[@"78"]);
    
    NSString *queryUid = @"34";
    NSPredicate *predicate5 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, uid), queryUid];
    NSArray<SRGPlaylistEntry *> *playlistEntries5 = [self.userData.playlist playlistEntriesMatchingPredicate:predicate5 sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlistEntries5.count, 1);
    SRGPlaylistEntry *playlistEntry = playlistEntries5.firstObject;
    XCTAssertEqualObjects(playlistEntry.uid, queryUid);
    XCTAssertFalse(playlistEntry.discarded);
    
    NSPredicate *predicate6 = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ || %K CONTAINS[cd] %@", @keypath(SRGPlaylistEntry.new, uid), @"1", @keypath(SRGPlaylistEntry.new, uid), @"9"];
    NSSortDescriptor *sortDescriptor6 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, date) ascending:YES];
    NSArray<SRGPlaylistEntry *> *playlistEntries6 = [self.userData.playlist playlistEntriesMatchingPredicate:predicate6 sortedWithDescriptors:@[sortDescriptor6]];
    
    NSArray<NSString *> *expectedQueryUids6 = @[@"12", @"90"];
    XCTAssertEqual(playlistEntries6.count, expectedQueryUids6.count);
    NSArray<NSString *> *queryUids6 = [playlistEntries6 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(queryUids6, expectedQueryUids6);
}

- (void)testPlaylistEntriesMatchingPredicatesOrSortDescriptorsAsynchronously
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self saveUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    NSArray<NSString *> *resultByDateUids = [@[SRGPlaylistSystemWatchLaterUid] arrayByAddingObjectsFromArray:uids];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, date) ascending:YES];
    [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor1] completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nonnull playlistEntries1, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlistEntries1.count, resultByDateUids.count);
        NSArray<NSString *> *queryUids1 = [playlistEntries1 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        XCTAssertEqualObjects(queryUids1, resultByDateUids);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, uid) ascending:YES];
    [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor2] completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nonnull playlistEntries2, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlistEntries2.count, resultUids.count);
        NSArray<NSString *> *queryUids2 = [playlistEntries2 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        XCTAssertEqualObjects(queryUids2, resultUids);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylistEntry.new, discarded)];
    [self.userData.playlist playlistEntriesMatchingPredicate:predicate3 sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nonnull playlistEntries3, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlistEntries3.count, resultUids.count);
        NSArray<NSString *> *queryUids3 = [playlistEntries3 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        XCTAssertEqualObjects(queryUids3, [[resultUids reverseObjectEnumerator] allObjects]);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"%K == 'Playlist 78'", @keypath(SRGPlaylistEntry.new, name)];
    [self.userData.playlist playlistEntriesMatchingPredicate:predicate4 sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nonnull playlistEntries4, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlistEntries4.count, 1);
        NSArray<NSString *> *queryUids4 = [playlistEntries4 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        XCTAssertEqualObjects(queryUids4,@[@"78"]);
        [expectation4 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation5 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    NSString *queryUid = @"34";
    NSPredicate *predicate5 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylistEntry.new, uid), queryUid];
    [self.userData.playlist playlistEntriesMatchingPredicate:predicate5 sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nonnull playlistEntries5, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlistEntries5.count, 1);
        SRGPlaylistEntry *playlistEntry = playlistEntries5.firstObject;
        XCTAssertEqualObjects(playlistEntry.uid, queryUid);
        XCTAssertFalse(playlistEntry.discarded);
        [expectation5 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation6 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    NSPredicate *predicate6 = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ || %K CONTAINS[cd] %@", @keypath(SRGPlaylistEntry.new, uid), @"1", @keypath(SRGPlaylistEntry.new, uid), @"9"];
    NSSortDescriptor *sortDescriptor6 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, date) ascending:YES];
    [self.userData.playlist playlistEntriesMatchingPredicate:predicate6 sortedWithDescriptors:@[sortDescriptor6] completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nonnull playlistEntries6, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        NSArray<NSString *> *expectedQueryUids6 = @[@"12", @"90"];
        XCTAssertEqual(playlistEntries6.count, expectedQueryUids6.count);
        NSArray<NSString *> *queryUids6 = [playlistEntries6 valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        XCTAssertEqualObjects(queryUids6, expectedQueryUids6);
        [expectation6 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testDiscardPlaylistEntries
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self saveUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    NSArray<NSString *> *discardedUids = @[@"12", @"90"];
    NSArray<NSString *> *remainingUids = @[@"34", @"56", @"78", SRGPlaylistSystemWatchLaterUid];
    
    [self expectationForSingleNotification:SRGPlaylistDidChangeNotification object:self.userData.playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistChangedUidsKey]], [NSSet setWithArray:discardedUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistPreviousUidsKey]], [NSSet setWithArray:resultUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistUidsKey]], [NSSet setWithArray:remainingUids]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlist discardPlaylistEntriesWithUids:discardedUids completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 4);
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistDidChangeNotification object:self.userData.playlist queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
}

- (void)testDiscardPlaylistEntriesWithSystemPlaylist
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self saveUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    NSArray<NSString *> *discardedUids = @[@"12", @"90"];
    NSArray<NSString *> *remainingUids = @[@"34", @"56", @"78", SRGPlaylistSystemWatchLaterUid];
    
    [self expectationForSingleNotification:SRGPlaylistDidChangeNotification object:self.userData.playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistChangedUidsKey]], [NSSet setWithArray:discardedUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistPreviousUidsKey]], [NSSet setWithArray:resultUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistUidsKey]], [NSSet setWithArray:remainingUids]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlist discardPlaylistEntriesWithUids:[discardedUids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 4);
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistDidChangeNotification object:self.userData.playlist queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
}

- (void)testDiscardAllPlaylistEntries
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self saveUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    [self expectationForSingleNotification:SRGPlaylistDidChangeNotification object:self.userData.playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistChangedUidsKey]], [NSSet setWithArray:uids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistPreviousUidsKey]], [NSSet setWithArray:resultUids]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidsKey], @[SRGPlaylistSystemWatchLaterUid]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlist discardPlaylistEntriesWithUids:nil completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlist playlistEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 1);
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistDidChangeNotification object:self.userData.playlist queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
}

@end
