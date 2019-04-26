//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGPlaylists+Private.h"

#import <libextobjc/libextobjc.h>

@interface PlaylistsTestCase : UserDataBaseTestCase

@property (nonatomic) SRGUserData *userData;

@end

@implementation PlaylistsTestCase

#pragma mark Helpers

- (NSArray<NSString *> *)addPlaylistNames:(NSArray<NSString *> *)names
{
    __block NSMutableArray<NSString *> *addedUids = NSMutableArray.array;
    __block NSInteger expectedAddedNotifications = names.count;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistsChangedUidsKey];
        [addedUids addObjectsFromArray:uids];
        expectedAddedNotifications -= uids.count;
        return (expectedAddedNotifications == 0);
    }];
    
    for (NSString *name in names) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
        
        [self.userData.playlists addPlaylistWithName:name completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
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
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:nil];
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
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:SRGPlaylistUidWatchLater];
    
    XCTAssertEqualObjects(playlist.uid, SRGPlaylistUidWatchLater);
    XCTAssertEqual(playlist.type, SRGPlaylistTypeWatchLater);
    XCTAssertEqualObjects(playlist.name, SRGPlaylistNameForPlaylistWithUid(SRGPlaylistUidWatchLater));
    XCTAssertFalse(playlist.discarded);
}

- (void)testAddPlaylist
{
    __block NSString *addedUid = nil;
    NSString *name = @"Playlist 1234";
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsChangedUidsKey], @[addedUid]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], @[SRGPlaylistUidWatchLater]);
        NSArray<NSString *> *uids = @[SRGPlaylistUidWatchLater, addedUid];
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], uids);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
    
    [self.userData.playlists addPlaylistWithName:name completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
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
    
    __block NSInteger expectedAddedNotifications = names.count;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistsChangedUidsKey];
        expectedAddedNotifications -= uids.count;
        return (expectedAddedNotifications == 0);
    }];
    
    for (NSString *name in names) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
        
        [self.userData.playlists addPlaylistWithName:name completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
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
    __block NSUInteger expectedAddedNotifications = numberOfAdditions;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistsChangedUidsKey];
        expectedAddedNotifications -= uids.count;
        return (expectedAddedNotifications == 0);
    }];
    
    for (NSUInteger i = 0; i < numberOfAdditions; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist saved"];
        
        [self.userData.playlists addPlaylistWithName:name completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
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
    
    [self.userData.playlists updatePlaylistWithUid:uid name:updatedName completionBlock:^(NSError * _Nullable error) {
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
    
    [self.userData.playlists updatePlaylistWithUid:SRGPlaylistUidWatchLater name:updatedName completionBlock:^(NSError * _Nullable error) {
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
    NSArray<NSString *> *uids = [[self addPlaylistNames:names] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray<NSString *> *resultUids = [uids arrayByAddingObject:SRGPlaylistUidWatchLater];
    
    NSArray<NSString *> *discardedUids = @[uids[0], uids[4]];
    NSArray<NSString *> *remainingUids = @[uids[1], uids[2], uids[3], SRGPlaylistUidWatchLater];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistsChangedUidsKey]], [NSSet setWithArray:discardedUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistsPreviousUidsKey]], [NSSet setWithArray:resultUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistsUidsKey]], [NSSet setWithArray:remainingUids]);
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
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistsChangedUidsKey]], [NSSet setWithArray:discardedUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistsPreviousUidsKey]], [NSSet setWithArray:resultUids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistsUidsKey]], [NSSet setWithArray:remainingUids]);
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
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistsChangedUidsKey]], [NSSet setWithArray:uids]);
        XCTAssertEqualObjects([NSSet setWithArray:notification.userInfo[SRGPlaylistsPreviousUidsKey]], [NSSet setWithArray:resultUids]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], @[SRGPlaylistUidWatchLater]);
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
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsChangedUidsKey], @[SRGPlaylistUidWatchLater]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], @[SRGPlaylistUidWatchLater]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], @[SRGPlaylistUidWatchLater]);
        
        NSDictionary *playlistEntryChanges = notification.userInfo[SRGPlaylistEntryChangesKey];
        XCTAssertNotNil(playlistEntryChanges);
        XCTAssertEqual(playlistEntryChanges.count, 1);
        
        NSDictionary<NSString *, NSArray<NSString *> *> *systemWatchLaterPlaylistEntryChanges = playlistEntryChanges[SRGPlaylistUidWatchLater];
        XCTAssertNotNil(systemWatchLaterPlaylistEntryChanges);
        XCTAssertEqualObjects(systemWatchLaterPlaylistEntryChanges[SRGPlaylistEntryChangedUidsSubKey], @[uid]);
        XCTAssertEqualObjects(systemWatchLaterPlaylistEntryChanges[SRGPlaylistEntryPreviousUidsSubKey], @[]);
        XCTAssertEqualObjects(systemWatchLaterPlaylistEntryChanges[SRGPlaylistEntryUidsSubKey], @[uid]);
        
        return YES;
    }];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entry added"];
    
    [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entry not added"];
    
    [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:@"notFound" completionBlock:^(NSError * _Nullable error) {
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
    
    [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries1.count, 1);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlists entriesFromPlaylistWithUid:@"notFound" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertNil(playlistEntries2);
}

- (void)testFetchEntriesFromPlaylistAsynchronously
{
    NSString *uid = @"1234";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry saved"];
    
    [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entry fetched"];
    
    [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
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
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistEntryChangesKey][SRGPlaylistUidWatchLater][SRGPlaylistEntryChangedUidsSubKey];
        [expectedAddedNotifications removeObjectsInArray:uids];
        return (expectedAddedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
        
        [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 5);
}

- (void)testAddSameEntriesToPlaylist
{
    NSString *uid = @"1234";
    
    NSUInteger numberOfAdditions = 5;
    __block NSUInteger expectedAddedNotifications = numberOfAdditions;
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistEntryChangesKey][SRGPlaylistUidWatchLater][SRGPlaylistEntryChangedUidsSubKey];
        expectedAddedNotifications -= uids.count;
        return (expectedAddedNotifications == 0);
    }];
    
    for (NSUInteger i = 0; i < numberOfAdditions; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
        
        [self.userData.playlists addEntryWithUid:uid toPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
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
    
    NSArray<NSString *> *removedUids = @[@"12", @"90"];
    NSArray<NSString *> *remainingUids = @[@"34", @"56", @"78"];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsChangedUidsKey], @[playlistUid]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], resultPlaylistUids);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], resultPlaylistUids);
        
        NSDictionary *playlistEntryChanges = notification.userInfo[SRGPlaylistEntryChangesKey];
        XCTAssertNotNil(playlistEntryChanges);
        XCTAssertEqual(playlistEntryChanges.count, 1);
        
        NSDictionary<NSString *, NSArray<NSString *> *> *systemWatchLaterPlaylistEntryChanges = playlistEntryChanges[playlistUid];
        XCTAssertNotNil(systemWatchLaterPlaylistEntryChanges);
        XCTAssertEqualObjects([NSSet setWithArray:systemWatchLaterPlaylistEntryChanges[SRGPlaylistEntryChangedUidsSubKey]],  [NSSet setWithArray:removedUids]);
        XCTAssertEqualObjects([NSSet setWithArray:systemWatchLaterPlaylistEntryChanges[SRGPlaylistEntryPreviousUidsSubKey]], [NSSet setWithArray:uids]);
        XCTAssertEqualObjects([NSSet setWithArray:systemWatchLaterPlaylistEntryChanges[SRGPlaylistEntryUidsSubKey]],  [NSSet setWithArray:remainingUids]);
        return YES;
    }];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entries removed"];
    
    [self.userData.playlists removeEntriesWithUids:removedUids fromPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlists entriesFromPlaylistWithUid:playlistUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries1.count, 3);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries2.count, 5);
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entries removed"];
    
    [self.userData.playlists removeEntriesWithUids:nil fromPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries3 = [self.userData.playlists entriesFromPlaylistWithUid:playlistUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries3.count, 3);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries4 = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries4.count, 0);
    XCTAssertNotNil(playlistEntries4);
}

- (void)testRemovePlaylistEntriesForLoggedInUser
{
    XCTFail(@"To be implemented");
}

- (void)testPlaylistEntriesMigrationToWatchLaterPlaylist
{
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
    
    NSMutableArray<NSString *> *expectedAddedNotifications = [[migrations valueForKey:@"itemId"] mutableCopy];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGPlaylistEntryChangesKey][SRGPlaylistUidWatchLater][SRGPlaylistEntryChangedUidsSubKey];
        [expectedAddedNotifications removeObjectsInArray:uids];
        return (expectedAddedNotifications.count == 0);
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entries added"];
    
    [self.userData.playlists saveEntryDictionaries:migrations toPlaylistUid:SRGPlaylistUidWatchLater withCompletionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGUserObject.new, date) ascending:NO];
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists entriesFromPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:@[ sortDescriptor ]];
    XCTAssertEqual(playlistEntries.count, 5);
    XCTAssertEqualObjects([playlistEntries valueForKey:@keypath(SRGPlaylistEntry.new, uid)], [migrations valueForKey:@"itemId"]);
}

@end
