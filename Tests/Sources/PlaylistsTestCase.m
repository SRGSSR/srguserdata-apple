//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import <libextobjc/libextobjc.h>

@interface SRGPlaylistsTestCase : UserDataBaseTestCase

@property (nonatomic) SRGUserData *userData;

@end

@implementation SRGPlaylistsTestCase

#pragma mark Helpers

- (void)savePlaylistUids:(NSArray<NSString *> *)uids
{
    NSMutableArray<NSString *> *expectedSavedNotifications = uids.mutableCopy;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistChangedUidsKey];
        [expectedSavedNotifications removeObjectsInArray:uids];
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        NSString *name = [NSString stringWithFormat:@"Playlist %@", uid];
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
        
        [self.userData.playlists savePlaylistForUid:uid withName:name completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)addPlaylistEntryUids:(NSArray<NSString *> *)uids toPlaylistUid:(NSString *)playlistUid
{
    NSMutableArray<NSString *> *expectedAddedNotifications = uids.mutableCopy;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistEntryChangesKey][playlistUid][SRGPlaylistEntryChangedUidsSubKey];
        [expectedAddedNotifications removeObjectsInArray:uids];
        return (expectedAddedNotifications.count == 0);
        return YES;
    }];
    
    for (NSString *uid in uids) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
        
        [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
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
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil playlistsServiceURL:nil identityService:nil];
}

- (void)tearDown
{
    self.userData = nil;
}

#pragma mark Tests

- (void)testEmptyPlaylistInitialization
{
    XCTAssertNotNil(self.userData.playlists);
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists.count, 1);
}

- (void)testWatchLaterEntryWithUid
{
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:SRGPlaylistSystemWatchLaterUid];
    
    XCTAssertEqualObjects(playlist.uid, SRGPlaylistSystemWatchLaterUid);
    XCTAssertTrue(playlist.system);
    XCTAssertEqualObjects(playlist.name, SRGPlaylistNameForPlaylistWithUid(SRGPlaylistSystemWatchLaterUid));
    XCTAssertFalse(playlist.discarded);
}

- (void)testSavePlaylist
{
    NSString *uid = @"1234";
    NSString *name = @"Playlist 1234";
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistChangedUidsKey], @[uid]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistPreviousUidsKey], @[SRGPlaylistSystemWatchLaterUid]);
        NSArray<NSString *> *uids = @[SRGPlaylistSystemWatchLaterUid, uid];
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidsKey], uids);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
    
    [self.userData.playlists savePlaylistForUid:uid withName:name completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists.count, 2);
}

- (void)testSavePlaylists
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    NSString *nameFormat = @"Playlist %@";
    
    NSMutableArray<NSString *> *expectedSavedNotifications = uids.mutableCopy;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistChangedUidsKey];
        [expectedSavedNotifications removeObjectsInArray:uids];
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        NSString *name = [NSString stringWithFormat:nameFormat, uid];
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
        
        [self.userData.playlists savePlaylistForUid:uid withName:name completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists.count, 6);
}

- (void)testSaveSamePlaylist
{
    NSString *uid = @"1234";
    NSString *name = @"Playlist 1234";
    
    NSUInteger numberOfSaves = 5;
    __block NSUInteger expectedSavedNotifications = numberOfSaves;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistChangedUidsKey];
        expectedSavedNotifications -= uids.count;
        return (expectedSavedNotifications == 0);
    }];
    
    for (NSUInteger i = 0; i < numberOfSaves; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
        
        [self.userData.playlists savePlaylistForUid:uid withName:name completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists.count, 2);
}

- (void)testPlaylistWithUid
{
    NSString *uid = @"1234";
    NSString *name = @"Playlist 1234";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
    
    [self.userData.playlists savePlaylistForUid:uid withName:name completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    SRGPlaylist *playlist1 = [self.userData.playlists playlistWithUid:uid];
    
    XCTAssertEqualObjects(playlist1.uid, uid);
    XCTAssertFalse(playlist1.system);
    XCTAssertEqualObjects(playlist1.name, name);
    XCTAssertFalse(playlist1.discarded);
    
    SRGPlaylist *playlist2 = [self.userData.playlists playlistWithUid:@"notFound"];
    
    XCTAssertNil(playlist2);
}

- (void)testPlaylistWithUidAsynchronously
{
    NSString *uid = @"1234";
    NSString *name = @"Playlist 1234";
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist saved"];
    
    [self.userData.playlists savePlaylistForUid:uid withName:name completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:uid completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqualObjects(playlist.uid, uid);
        XCTAssertFalse(playlist.system);
        XCTAssertEqualObjects(playlist.name, name);
        XCTAssertFalse(playlist.discarded);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"notFound" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertNil(playlist);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylistsMatchingEmptyPredicateEmptySortDescriptor
{
    NSArray<SRGPlaylist *> *playlists1 = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertNotNil(playlists1);
    XCTAssertEqual(playlists1.count, 1);
    
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self savePlaylistUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    NSArray<SRGPlaylist *> *playlists2 = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists2.count, resultUids.count);
    
    NSArray<NSString *> *queryUids2 = [playlists2 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(queryUids2, [[resultUids reverseObjectEnumerator] allObjects]);
}

- (void)testPlaylistsMatchingEmptyPredicateEmptySortDescriptorAsynchronously
{
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlists fetched"];
    
    [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nonnull playlists1, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNotNil(playlists1);
        XCTAssertEqual(playlists1.count, 1);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self savePlaylistUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlists fetched"];
    
    [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nonnull playlists2, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlists2.count, resultUids.count);
        
        NSArray<NSString *> *queryUids2 = [playlists2 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(queryUids2, [[resultUids reverseObjectEnumerator] allObjects]);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylistsMatchingPredicatesOrSortDescriptors
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self savePlaylistUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    NSArray<NSString *> *resultByDateUids = [@[SRGPlaylistSystemWatchLaterUid] arrayByAddingObjectsFromArray:uids];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, date) ascending:YES];
    NSArray<SRGPlaylist *> *playlists1 = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor1]];
    
    XCTAssertEqual(playlists1.count, resultByDateUids.count);
    NSArray<NSString *> *queryUids1 = [playlists1 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(queryUids1, resultByDateUids);
    
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, uid) ascending:YES];
    NSArray<SRGPlaylist *> *playlists2 = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor2]];
    
    XCTAssertEqual(playlists2.count, resultUids.count);
    NSArray<NSString *> *queryUids2 = [playlists2 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(queryUids2, resultUids);
    
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylist.new, discarded)];
    NSArray<SRGPlaylist *> *playlists3 = [self.userData.playlists playlistsMatchingPredicate:predicate3 sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists3.count, resultUids.count);
    NSArray<NSString *> *queryUids3 = [playlists3 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(queryUids3, [[resultUids reverseObjectEnumerator] allObjects]);
    
    NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylist.new, name), @"Playlist 78"];
    NSArray<SRGPlaylist *> *playlists4 = [self.userData.playlists playlistsMatchingPredicate:predicate4 sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists4.count, 1);
    NSArray<NSString *> *queryUids4 = [playlists4 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(queryUids4, @[@"78"]);
    
    NSString *queryUid = @"34";
    NSPredicate *predicate5 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylist.new, uid), queryUid];
    NSArray<SRGPlaylist *> *playlists5 = [self.userData.playlists playlistsMatchingPredicate:predicate5 sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists5.count, 1);
    SRGPlaylist *playlist = playlists5.firstObject;
    XCTAssertEqualObjects(playlist.uid, queryUid);
    XCTAssertFalse(playlist.discarded);
    
    NSPredicate *predicate6 = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ || %K CONTAINS[cd] %@", @keypath(SRGPlaylist.new, uid), @"1", @keypath(SRGPlaylist.new, uid), @"9"];
    NSSortDescriptor *sortDescriptor6 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, date) ascending:YES];
    NSArray<SRGPlaylist *> *playlists6 = [self.userData.playlists playlistsMatchingPredicate:predicate6 sortedWithDescriptors:@[sortDescriptor6]];
    
    NSArray<NSString *> *expectedQueryUids6 = @[@"12", @"90"];
    XCTAssertEqual(playlists6.count, expectedQueryUids6.count);
    NSArray<NSString *> *queryUids6 = [playlists6 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(queryUids6, expectedQueryUids6);
}

- (void)testPlaylistsMatchingPredicatesOrSortDescriptorsAsynchronously
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self savePlaylistUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    NSArray<NSString *> *resultByDateUids = [@[SRGPlaylistSystemWatchLaterUid] arrayByAddingObjectsFromArray:uids];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlists fetched"];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, date) ascending:YES];
    [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor1] completionBlock:^(NSArray<SRGPlaylist *> * _Nonnull playlists1, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlists1.count, resultByDateUids.count);
        NSArray<NSString *> *queryUids1 = [playlists1 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(queryUids1, resultByDateUids);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlists fetched"];
    
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, uid) ascending:YES];
    [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor2] completionBlock:^(NSArray<SRGPlaylist *> * _Nonnull playlists2, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlists2.count, resultUids.count);
        NSArray<NSString *> *queryUids2 = [playlists2 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(queryUids2, resultUids);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlists fetched"];
    
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylist.new, discarded)];
    [self.userData.playlists playlistsMatchingPredicate:predicate3 sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nonnull playlists3, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlists3.count, resultUids.count);
        NSArray<NSString *> *queryUids3 = [playlists3 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(queryUids3, [[resultUids reverseObjectEnumerator] allObjects]);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"Playlists fetched"];
    
    NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"%K == 'Playlist 78'", @keypath(SRGPlaylist.new, name)];
    [self.userData.playlists playlistsMatchingPredicate:predicate4 sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nonnull playlists4, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlists4.count, 1);
        NSArray<NSString *> *queryUids4 = [playlists4 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(queryUids4,@[@"78"]);
        [expectation4 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation5 = [self expectationWithDescription:@"Playlists fetched"];
    
    NSString *queryUid = @"34";
    NSPredicate *predicate5 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylist.new, uid), queryUid];
    [self.userData.playlists playlistsMatchingPredicate:predicate5 sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nonnull playlists5, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqual(playlists5.count, 1);
        SRGPlaylist *playlist = playlists5.firstObject;
        XCTAssertEqualObjects(playlist.uid, queryUid);
        XCTAssertFalse(playlist.discarded);
        [expectation5 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation6 = [self expectationWithDescription:@"Playlists fetched"];
    
    NSPredicate *predicate6 = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ || %K CONTAINS[cd] %@", @keypath(SRGPlaylist.new, uid), @"1", @keypath(SRGPlaylist.new, uid), @"9"];
    NSSortDescriptor *sortDescriptor6 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, date) ascending:YES];
    [self.userData.playlists playlistsMatchingPredicate:predicate6 sortedWithDescriptors:@[sortDescriptor6] completionBlock:^(NSArray<SRGPlaylist *> * _Nonnull playlists6, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        NSArray<NSString *> *expectedQueryUids6 = @[@"12", @"90"];
        XCTAssertEqual(playlists6.count, expectedQueryUids6.count);
        NSArray<NSString *> *queryUids6 = [playlists6 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(queryUids6, expectedQueryUids6);
        [expectation6 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testDiscardPlaylists
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self savePlaylistUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    NSArray<NSString *> *discardedUids = @[@"12", @"90"];
    NSArray<NSString *> *remainingUids = @[@"34", @"56", @"78", SRGPlaylistSystemWatchLaterUid];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistChangedUidsKey]], [NSSet setWithArray:discardedUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistPreviousUidsKey]], [NSSet setWithArray:resultUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistUidsKey]], [NSSet setWithArray:remainingUids]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:discardedUids completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlists.count, 4);
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
}

- (void)testDiscardPlaylistsWithSystemPlaylist
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self savePlaylistUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    NSArray<NSString *> *discardedUids = @[@"12", @"90"];
    NSArray<NSString *> *remainingUids = @[@"34", @"56", @"78", SRGPlaylistSystemWatchLaterUid];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistChangedUidsKey]], [NSSet setWithArray:discardedUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistPreviousUidsKey]], [NSSet setWithArray:resultUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistUidsKey]], [NSSet setWithArray:remainingUids]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:[discardedUids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlists.count, 4);
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
}

- (void)testDiscardAllPlaylists
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self savePlaylistUids:uids];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistSystemWatchLaterUid];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistChangedUidsKey]], [NSSet setWithArray:uids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistPreviousUidsKey]], [NSSet setWithArray:resultUids]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidsKey], @[SRGPlaylistSystemWatchLaterUid]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:nil completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlists.count, 1);
    
    id playlistDidChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"Playlist must not send more did change notifications.");
    }];
    
    [self expectationForElapsedTimeInterval:2. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:playlistDidChangeObserver];
    }];
}

- (void)testAddEntryToPlaylist
{
    NSString *uid = @"1234";
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistChangedUidsKey], @[SRGPlaylistSystemWatchLaterUid]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistPreviousUidsKey], @[SRGPlaylistSystemWatchLaterUid]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidsKey], @[SRGPlaylistSystemWatchLaterUid]);
        
        NSDictionary *playlistEntryChanges = notification.userInfo[SRGPlaylistEntryChangesKey];
        XCTAssertNotNil(playlistEntryChanges);
        XCTAssertEqual(playlistEntryChanges.count, 1);
        
        NSDictionary *systemWatchLaterPlaylistEntryChanges = playlistEntryChanges[SRGPlaylistSystemWatchLaterUid];
        XCTAssertNotNil(systemWatchLaterPlaylistEntryChanges);
        XCTAssertEqualObjects(systemWatchLaterPlaylistEntryChanges[SRGPlaylistEntryChangedUidsSubKey], @[uid]);
        XCTAssertEqualObjects(systemWatchLaterPlaylistEntryChanges[SRGPlaylistEntryPreviousUidsSubKey], @[]);
        XCTAssertEqualObjects(systemWatchLaterPlaylistEntryChanges[SRGPlaylistEntryUidsSubKey], @[uid]);
        
        return YES;
    }];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entry added"];
    
    [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistSystemWatchLaterUid completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entry not added"];
    
    [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:@"notFound" completionBlock:^(NSError * _Nullable error) {
        XCTAssertEqualObjects(error.domain, SRGUserDataErrorDomain);
        XCTAssertEqual(error.code, SRGUserDataErrorPlaylistNotFound);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testFetchEntriesFromPlaylist
{
    NSString *uid = @"1234";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
    
    [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistSystemWatchLaterUid completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistSystemWatchLaterUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries1.count, 1);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlists entriesFromPlaylistWithUid:@"notFound" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertNil(playlistEntries2);
}

- (void)testFetchEntriesFromPlaylistAsynchronously
{
    NSString *uid = @"1234";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
    
    [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistSystemWatchLaterUid completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entry fetched"];
    
    [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistSystemWatchLaterUid matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertEqual(playlistEntries.count, 1);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist entry fetched"];
    
    [self.userData.playlists entriesFromPlaylistWithUid:@"notFound" matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertNil(playlistEntries);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testAddEntriesToPlaylist
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    
    NSMutableArray<NSString *> *expectedAddedNotifications = uids.mutableCopy;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistEntryChangesKey][SRGPlaylistSystemWatchLaterUid][SRGPlaylistEntryChangedUidsSubKey];
        [expectedAddedNotifications removeObjectsInArray:uids];
        return (expectedAddedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
        
        [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistSystemWatchLaterUid completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistSystemWatchLaterUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 5);
}

- (void)testAddSameEntriesToPlaylist
{
    NSString *uid = @"1234";
    
    NSUInteger numberOfAdditions = 5;
    __block NSUInteger expectedAddedNotifications = numberOfAdditions;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistEntryChangesKey][SRGPlaylistSystemWatchLaterUid][SRGPlaylistEntryChangedUidsSubKey];
        expectedAddedNotifications -= uids.count;
        return (expectedAddedNotifications == 0);
    }];
    
    for (NSUInteger i = 0; i < numberOfAdditions; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
        
        [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistSystemWatchLaterUid completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistSystemWatchLaterUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 1);
}

- (void)testRemovePlaylistEntries
{
    NSString *playlistUid = @"1234";
    
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self addPlaylistEntryUids:uids toPlaylistUid:SRGPlaylistSystemWatchLaterUid];
    
    [self savePlaylistUids:@[playlistUid]];
    [self addPlaylistEntryUids:uids toPlaylistUid:playlistUid];
    
    NSArray<NSString *> *removedUids = @[@"12", @"90"];
    NSArray<NSString *> *remainingUids = @[@"34", @"56", @"78"];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entries removed"];
    
    [self.userData.playlists removeEntriesWithUids:removedUids fromPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlists entriesFromPlaylistWithUid:playlistUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries1.count, 3);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistSystemWatchLaterUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries2.count, 5);
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entries removed"];
    
    [self.userData.playlists removeEntriesWithUids:nil fromPlaylistWithUid:SRGPlaylistSystemWatchLaterUid completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries3 = [self.userData.playlists entriesFromPlaylistWithUid:playlistUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries3.count, 3);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries4 = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistSystemWatchLaterUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries4.count, 0);
    XCTAssertNotNil(playlistEntries4);
}


@end
