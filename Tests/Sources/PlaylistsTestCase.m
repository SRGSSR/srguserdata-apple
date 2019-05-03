//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGPlaylists+Private.h"

#import <libextobjc/libextobjc.h>

@interface PlaylistsTestCase : UserDataBaseTestCase

@end

@implementation PlaylistsTestCase

#pragma mark Helpers

- (NSArray<NSString *> *)addPlaylistNames:(NSArray<NSString *> *)names
{
    __block NSMutableArray<NSString *> *addedUids = NSMutableArray.array;
    __block NSInteger expectedSavedNotifications = names.count;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertNotNil(notification.userInfo[SRGPlaylistsUidsKey]);
        if (notification.userInfo[SRGPlaylistsPreviousUidsKey]) {
            NSMutableSet<NSString *> *uids = [notification.userInfo[SRGPlaylistsUidsKey] mutableCopy];
            NSSet<NSString *> *previousUids = notification.userInfo[SRGPlaylistsPreviousUidsKey];
            [uids minusSet:previousUids];
            [addedUids addObjectsFromArray:uids.allObjects];
            expectedSavedNotifications -= uids.count;
        }
        return (expectedSavedNotifications == 0);
    }];
    
    for (NSString *name in names) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
        
        [self.userData.playlists savePlaylistWithName:name uid:nil completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
            XCTAssertNil(error);
            XCTAssertNotNil(uid);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    return addedUids.copy;
}

- (void)addPlaylistEntryUids:(NSArray<NSString *> *)uids toPlaylistUid:(NSString *)playlistUid
{
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:playlistUid];
    XCTAssertNotNil(playlist);
    
    NSMutableSet<NSString *> *expectedSavedNotifications = [NSSet setWithArray:uids].mutableCopy;
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertNotNil(notification.userInfo[SRGPlaylistEntriesUidsKey]);
        if (notification.userInfo[SRGPlaylistEntriesPreviousUidsKey]) {
            NSMutableSet<NSString *> *uids = [notification.userInfo[SRGPlaylistEntriesUidsKey] mutableCopy];
            NSSet<NSString *> *previousUids = notification.userInfo[SRGPlaylistEntriesPreviousUidsKey];
            [uids minusSet:previousUids];
            [expectedSavedNotifications minusSet:uids];
        }
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
        
        [self.userData.playlists saveEntryWithUid:uid inPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)waitForDefaultPlaylistInsertion
{
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlists.count, 0);
    
    // Automatically inserted after initialization
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], NSSet.set);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], [NSSet setWithObject:SRGPlaylistUidWatchLater]);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

#pragma mark Setup and tear down

- (void)setUp
{
    [super setUp];
    
    [self setupForOfflineOnly];
    [self waitForDefaultPlaylistInsertion];
}

#pragma mark Tests

- (void)testDefaultPlaylists
{
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:SRGPlaylistUidWatchLater];
    
    XCTAssertEqualObjects(playlist.uid, SRGPlaylistUidWatchLater);
    XCTAssertEqual(playlist.type, SRGPlaylistTypeWatchLater);
    XCTAssertFalse(playlist.discarded);
}

- (void)testAddPlaylist
{
    __block NSString *addedUid = nil;
    NSString *name = @"Playlist 1234";
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSSet<NSString *> *uids = [NSSet setWithObjects:SRGPlaylistUidWatchLater, addedUid, nil];
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], uids);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], [NSSet setWithObject:SRGPlaylistUidWatchLater]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
    
    [self.userData.playlists savePlaylistWithName:name uid:nil completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(uid);
        addedUid = uid;
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists.count, 2);
}

- (void)testAddPlaylists
{
    NSArray<NSString *> *names = @[@"Playlist 12", @"Playlist 34", @"Playlist 56", @"Playlist 78", @"Playlist 90"];
    
    __block NSInteger expectedSavedNotifications = names.count;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertNotNil(notification.userInfo[SRGPlaylistsUidsKey]);
        if (notification.userInfo[SRGPlaylistsPreviousUidsKey]) {
            NSMutableSet<NSString *> *uids = [notification.userInfo[SRGPlaylistsUidsKey] mutableCopy];
            NSSet<NSString *> *previousUids = notification.userInfo[SRGPlaylistsPreviousUidsKey];
            [uids minusSet:previousUids];
            expectedSavedNotifications -= uids.count;
        }
        return (expectedSavedNotifications == 0);
    }];
    
    for (NSString *name in names) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
        
        [self.userData.playlists savePlaylistWithName:name uid:nil completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
            XCTAssertNil(error);
            XCTAssertNotNil(uid);
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

- (void)testAddPlaylistWithSameName
{
    NSString *name = @"Playlist 1234";
    
    NSUInteger numberOfAdditions = 5;
    __block NSUInteger expectedSavedNotifications = numberOfAdditions;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertNotNil(notification.userInfo[SRGPlaylistsUidsKey]);
        if (notification.userInfo[SRGPlaylistsPreviousUidsKey]) {
            NSMutableSet<NSString *> *uids = [notification.userInfo[SRGPlaylistsUidsKey] mutableCopy];
            NSSet<NSString *> *previousUids = notification.userInfo[SRGPlaylistsPreviousUidsKey];
            [uids minusSet:previousUids];
            expectedSavedNotifications -= uids.count;
        }
        return (expectedSavedNotifications == 0);
    }];
    
    for (NSUInteger i = 0; i < numberOfAdditions; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
        
        [self.userData.playlists savePlaylistWithName:name uid:nil completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
            XCTAssertNil(error);
            XCTAssertNotNil(uid);
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

- (void)testUpdatePlaylist
{
    NSString *name = @"Playlist 1234";
    NSString *uid = [self addPlaylistNames:@[name]].firstObject;
    
    NSString *updatedName = @"Playlist 4321";
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist updated"];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertNotNil(notification.userInfo[SRGPlaylistsUidsKey]);
        XCTAssertNil(notification.userInfo[SRGPlaylistsPreviousUidsKey]);
        return YES;
    }];
    
    [self.userData.playlists savePlaylistWithName:updatedName uid:uid completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:uid];
    
    XCTAssertEqualObjects(playlist.uid, uid);
    XCTAssertEqual(playlist.type, SRGPlaylistTypeStandard);
    XCTAssertEqualObjects(playlist.name, updatedName);
    XCTAssertFalse(playlist.discarded);
}

- (void)testUpdateWatchLaterPlaylist
{
    NSString *updatedName = @"Playlist WL";
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist updated"];
    
    [self.userData.playlists savePlaylistWithName:updatedName uid:SRGPlaylistUidWatchLater completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:SRGPlaylistUidWatchLater];
    
    XCTAssertEqualObjects(playlist.uid, SRGPlaylistUidWatchLater);
    XCTAssertEqual(playlist.type, SRGPlaylistTypeWatchLater);
    XCTAssertNotEqualObjects(playlist.name, updatedName);
    XCTAssertFalse(playlist.discarded);
}

- (void)testPlaylistWithUid
{
    NSString *name = @"Playlist 1234";
    NSString *uid = [self addPlaylistNames:@[name]].firstObject;
    
    SRGPlaylist *playlist1 = [self.userData.playlists playlistWithUid:uid];
    
    XCTAssertEqualObjects(playlist1.uid, uid);
    XCTAssertEqual(playlist1.type, SRGPlaylistTypeStandard);
    XCTAssertEqualObjects(playlist1.name, name);
    XCTAssertFalse(playlist1.discarded);
    
    SRGPlaylist *playlist2 = [self.userData.playlists playlistWithUid:@"notFound"];
    
    XCTAssertNil(playlist2);
}

- (void)testPlaylistWithUidAsynchronously
{
    NSString *name = @"Playlist 1234";
    NSString *addedUid = [self addPlaylistNames:@[name]].firstObject;
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:addedUid completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqualObjects(playlist.uid, addedUid);
        XCTAssertEqual(playlist.type, SRGPlaylistTypeStandard);
        XCTAssertEqualObjects(playlist.name, name);
        XCTAssertFalse(playlist.discarded);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"notFound" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertNil(playlist);
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylistsMatchingEmptyPredicateEmptySortDescriptor
{
    NSArray<SRGPlaylist *> *playlists1 = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertNotNil(playlists1);
    XCTAssertEqual(playlists1.count, 1);
    
    NSArray<NSString *> *names = @[@"Playlist 12", @"Playlist 34", @"Playlist 56", @"Playlist 78", @"Playlist 90"];
    NSArray<NSString *> *uids = [[self addPlaylistNames:names] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistUidWatchLater];
    
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
    
    NSArray<NSString *> *names = @[@"Playlist 12", @"Playlist 34", @"Playlist 56", @"Playlist 78", @"Playlist 90"];
    NSArray<NSString *> *uids = [[self addPlaylistNames:names] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistUidWatchLater];
    
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
    NSArray<NSString *> *names = @[@"Playlist 12", @"Playlist 34", @"Playlist 56", @"Playlist 78", @"Playlist 90"];
    NSArray<NSString *> *uids = [self addPlaylistNames:names];
    NSArray<NSString *> *resultUids = [[uids sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] arrayByAddingObject:SRGPlaylistUidWatchLater];
    NSArray<NSString *> *resultByDateUids = [@[SRGPlaylistUidWatchLater] arrayByAddingObjectsFromArray:uids];
    
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
    XCTAssertEqualObjects(queryUids4, @[uids[3]]);
    
    NSString *queryUid = uids[1];
    NSPredicate *predicate5 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylist.new, uid), queryUid];
    NSArray<SRGPlaylist *> *playlists5 = [self.userData.playlists playlistsMatchingPredicate:predicate5 sortedWithDescriptors:nil];
    
    XCTAssertEqual(playlists5.count, 1);
    SRGPlaylist *playlist = playlists5.firstObject;
    XCTAssertEqualObjects(playlist.uid, queryUid);
    XCTAssertFalse(playlist.discarded);
    
    NSPredicate *predicate6 = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@", @keypath(SRGPlaylist.new, name), @"1", @keypath(SRGPlaylist.new, name), @"9"];
    NSSortDescriptor *sortDescriptor6 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, date) ascending:YES];
    NSArray<SRGPlaylist *> *playlists6 = [self.userData.playlists playlistsMatchingPredicate:predicate6 sortedWithDescriptors:@[sortDescriptor6]];
    
    NSArray<NSString *> *expectedQueryUids6 = @[uids[0], uids[4]];
    XCTAssertEqual(playlists6.count, expectedQueryUids6.count);
    NSArray<NSString *> *queryUids6 = [playlists6 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(queryUids6, expectedQueryUids6);
}

- (void)testPlaylistsMatchingPredicatesOrSortDescriptorsAsynchronously
{
    NSArray<NSString *> *names = @[@"Playlist 12", @"Playlist 34", @"Playlist 56", @"Playlist 78", @"Playlist 90"];
    NSArray<NSString *> *uids = [self addPlaylistNames:names];
    NSArray<NSString *> *resultUids = [[uids sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] arrayByAddingObject:SRGPlaylistUidWatchLater];
    NSArray<NSString *> *resultByDateUids = [@[SRGPlaylistUidWatchLater] arrayByAddingObjectsFromArray:uids];
    
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
        XCTAssertEqualObjects(queryUids4,@[uids[3]]);
        [expectation4 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation5 = [self expectationWithDescription:@"Playlists fetched"];
    
    NSString *queryUid = uids[1];
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
    
    NSPredicate *predicate6 = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@", @keypath(SRGPlaylist.new, name), @"1", @keypath(SRGPlaylist.new, name), @"9"];
    NSSortDescriptor *sortDescriptor6 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, date) ascending:YES];
    [self.userData.playlists playlistsMatchingPredicate:predicate6 sortedWithDescriptors:@[sortDescriptor6] completionBlock:^(NSArray<SRGPlaylist *> * _Nonnull playlists6, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        NSArray<NSString *> *expectedQueryUids6 = @[uids[0], uids[4]];
        XCTAssertEqual(playlists6.count, expectedQueryUids6.count);
        NSArray<NSString *> *queryUids6 = [playlists6 valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(queryUids6, expectedQueryUids6);
        [expectation6 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testDiscardPlaylists
{
    NSArray<NSString *> *names = @[@"Playlist 12", @"Playlist 34", @"Playlist 56", @"Playlist 78", @"Playlist 90"];
    NSArray<NSString *> *uids = [self addPlaylistNames:names];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistUidWatchLater];
    
    NSArray<NSString *> *discardedUids = @[uids[0], uids[4]];
    NSArray<NSString *> *remainingUids = @[uids[1], uids[2], uids[3], SRGPlaylistUidWatchLater];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], [NSSet setWithArray:remainingUids]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], [NSSet setWithArray:resultUids]);
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
    NSArray<NSString *> *names = @[@"Playlist 12", @"Playlist 34", @"Playlist 56", @"Playlist 78", @"Playlist 90"];
    NSArray<NSString *> *uids = [[self addPlaylistNames:names] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistUidWatchLater];
    
    NSArray<NSString *> *discardedUids = @[uids[0], uids[4]];
    NSArray<NSString *> *remainingUids = @[uids[1], uids[2], uids[3], SRGPlaylistUidWatchLater];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], [NSSet setWithArray:remainingUids]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], [NSSet setWithArray:resultUids]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:[discardedUids arrayByAddingObject:SRGPlaylistUidWatchLater] completionBlock:^(NSError * _Nonnull error) {
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
    NSArray<NSString *> *names = @[@"Playlist 12", @"Playlist 34", @"Playlist 56", @"Playlist 78", @"Playlist 90"];
    NSArray<NSString *> *uids = [[self addPlaylistNames:names] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistUidWatchLater];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], [NSSet setWithObject:SRGPlaylistUidWatchLater]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], [NSSet setWithArray:resultUids]);
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
    
    NSArray<SRGPlaylistEntry *> *entries = [self.userData.playlists entriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(entries.count, 0);
    
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
    NSString *playlistUid = SRGPlaylistUidWatchLater;
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:playlistUid];
    XCTAssertNotNil(playlist);
    
    NSString *uid = @"1234";
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], [NSSet setWithObject:uid]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesPreviousUidsKey], NSSet.set);
        return YES;
    }];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entry added"];
    
    [self.userData.playlists saveEntryWithUid:uid inPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entry not added"];
    
    [self.userData.playlists saveEntryWithUid:uid inPlaylistWithUid:@"notFound" completionBlock:^(NSError * _Nullable error) {
        XCTAssertEqualObjects(error.domain, SRGUserDataErrorDomain);
        XCTAssertEqual(error.code, SRGUserDataErrorNotFound);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testFetchEntriesFromPlaylist
{
    NSString *uid = @"1234";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
    
    [self.userData.playlists saveEntryWithUid:uid inPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlists entriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries1.count, 1);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlists entriesInPlaylistWithUid:@"notFound" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertNil(playlistEntries2);
}

- (void)testFetchEntriesFromPlaylistAsynchronously
{
    NSString *uid = @"1234";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
    
    [self.userData.playlists saveEntryWithUid:uid inPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entry fetched"];
    
    [self.userData.playlists entriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertEqual(playlistEntries.count, 1);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist entry fetched"];
    
    [self.userData.playlists entriesInPlaylistWithUid:@"notFound" matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertNil(playlistEntries);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testAddEntriesToPlaylist
{
    NSString *playlistUid = SRGPlaylistUidWatchLater;
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:playlistUid];
    XCTAssertNotNil(playlist);
    
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    
    NSMutableSet<NSString *> *expectedSavedNotifications = [NSMutableSet setWithArray:uids];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertNotNil(notification.userInfo[SRGPlaylistEntriesUidsKey]);
        if (notification.userInfo[SRGPlaylistEntriesPreviousUidsKey]) {
            NSMutableSet<NSString *> *uids = [notification.userInfo[SRGPlaylistEntriesUidsKey] mutableCopy];
            NSSet<NSString *> *previousUids = notification.userInfo[SRGPlaylistEntriesPreviousUidsKey];
            [uids minusSet:previousUids];
            [expectedSavedNotifications minusSet:uids];
        }
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
        
        [self.userData.playlists saveEntryWithUid:uid inPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists entriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 5);
}

- (void)testAddSameEntriesToPlaylist
{
    NSString *playlistUid = SRGPlaylistUidWatchLater;
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:playlistUid];
    XCTAssertNotNil(playlist);
    
    NSString *uid = @"1234";
    
    NSUInteger numberOfAdditions = 5;
    __block NSUInteger expectedSavedNotifications = numberOfAdditions;
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], [NSSet setWithObject:uid]);
        if (expectedSavedNotifications == numberOfAdditions) {
            XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesPreviousUidsKey], NSSet.set);
        }
        else {
            XCTAssertNil(notification.userInfo[SRGPlaylistEntriesPreviousUidsKey]);
        }
        expectedSavedNotifications -= 1;
        return (expectedSavedNotifications == 0);
    }];
    
    for (NSUInteger i = 0; i < numberOfAdditions; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
        
        [self.userData.playlists saveEntryWithUid:uid inPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists entriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 1);
}

- (void)testRemovePlaylistEntries
{
    NSString *name = @"Playlist 1234";
    NSString *playlistUid = [self addPlaylistNames:@[name]].firstObject;
    NSArray<NSString *> *resultPlaylistUids = @[playlistUid, SRGPlaylistUidWatchLater];
    
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    [self addPlaylistEntryUids:uids toPlaylistUid:SRGPlaylistUidWatchLater];
    
    [self addPlaylistEntryUids:uids toPlaylistUid:playlistUid];
    
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:playlistUid];
    XCTAssertNotNil(playlist);
    
    NSArray<NSString *> *removedUids = @[@"12", @"90"];
    NSArray<NSString *> *remainingUids = @[@"34", @"56", @"78"];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey],  [NSSet setWithArray:remainingUids]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesPreviousUidsKey], [NSSet setWithArray:uids]);
        return YES;
    }];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entries removed"];
    
    [self.userData.playlists discardEntriesWithUids:removedUids fromPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlists entriesInPlaylistWithUid:playlistUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries1.count, 3);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlists entriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries2.count, 5);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries3 = [self.userData.playlists entriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries3.count, 8);
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entries removed"];
    
    [self.userData.playlists discardEntriesWithUids:nil fromPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries4 = [self.userData.playlists entriesInPlaylistWithUid:playlistUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries4.count, 3);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries5 = [self.userData.playlists entriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries5.count, 0);
    XCTAssertNotNil(playlistEntries5);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries6 = [self.userData.playlists entriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries6.count, 3);
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *playlistsPreviousUidsKey = @[playlistUid, SRGPlaylistUidWatchLater];
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], [NSSet setWithArray:playlistsPreviousUidsKey]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], [NSSet setWithObject:SRGPlaylistUidWatchLater]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[ playlistUid ] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries7 = [self.userData.playlists entriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries7.count, 0);
}

- (void)testPlaylistEntriesMigrationToWatchLaterPlaylist
{
    NSString *playlistUid = SRGPlaylistUidWatchLater;
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:playlistUid];
    XCTAssertNotNil(playlist);
    
    NSDate *date = NSDate.date;
    NSArray<NSDictionary *> *migrations = @[ @{ @"itemId" : @"90",
                                                @"date" : @(round((date.timeIntervalSince1970 - 2) * 1000.)) },
                                             @{ @"itemId" : @"78",
                                                @"date" : @(round((date.timeIntervalSince1970 - 4) * 1000.)) },
                                             @{ @"itemId" : @"56",
                                                @"date" : @(round((date.timeIntervalSince1970 - 6) * 1000.)) },
                                             @{ @"itemId" : @"34",
                                                @"date" : @(round((date.timeIntervalSince1970 - 8) * 1000.)) },
                                             @{ @"itemId" : @"12",
                                                @"date" : @(round((date.timeIntervalSince1970 - 10) * 1000.)) } ];
    
    NSMutableSet<NSString *> *expectedSavedNotifications = [NSMutableSet setWithArray:[migrations valueForKey:@"itemId"]];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:playlist handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSMutableSet<NSString *> *uids = [notification.userInfo[SRGPlaylistEntriesUidsKey] mutableCopy];
        NSSet<NSString *> *previousUids = notification.userInfo[SRGPlaylistEntriesPreviousUidsKey];
        [uids minusSet:previousUids];
        [expectedSavedNotifications minusSet:uids];
        return (expectedSavedNotifications.count == 0);
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entries added"];
    
    [self.userData.playlists saveEntryDictionaries:migrations toPlaylistUid:SRGPlaylistUidWatchLater withCompletionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGUserObject.new, date) ascending:NO];
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists entriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:@[ sortDescriptor ]];
    XCTAssertEqual(playlistEntries.count, 5);
    XCTAssertEqualObjects([playlistEntries valueForKey:@keypath(SRGPlaylistEntry.new, uid)], [migrations valueForKey:@"itemId"]);
}

@end
