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

- (void)waitForDefaultPlaylistInsertion
{
    // Automatically inserted after initialization
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
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

- (void)testSavePlaylist
{
    __block NSString *generatedUid = nil;
 
    // Insertion, no uid specified (a new uid is generated)
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGPlaylistsUidsKey] count], 1);
        generatedUid = [notification.userInfo[SRGPlaylistsUidsKey] anyObject];
        XCTAssertNotNil(generatedUid);
        return YES;
    }];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist saved"];
 
    [self.userData.playlists savePlaylistWithName:@"A" uid:nil completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        XCTAssertEqualObjects(uid, generatedUid);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    SRGPlaylist *playlist1 = [self.userData.playlists playlistWithUid:generatedUid];
    XCTAssertEqualObjects(playlist1.name, @"A");
    
    // Update of existing entry
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], [NSSet setWithObject:generatedUid]);
        XCTAssertNotNil(generatedUid);
        return YES;
    }];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist saved"];
    
    [self.userData.playlists savePlaylistWithName:@"AA" uid:generatedUid completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTAssertEqualObjects(playlist1.name, @"AA");
    
    // New entry with assigned uid
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], [NSSet setWithObject:@"b"]);
        XCTAssertNotNil(generatedUid);
        return YES;
    }];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist saved"];
    
    [self.userData.playlists savePlaylistWithName:@"B" uid:@"b" completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        XCTAssertEqualObjects(uid, @"b");
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testUpdateWatchLaterPlaylist
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist updated"];
    
    NSString *name = @"New name";
    
    [self.userData.playlists savePlaylistWithName:name uid:SRGPlaylistUidWatchLater completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqualObjects(error.domain, SRGUserDataErrorDomain);
        XCTAssertEqual(error.code, SRGUserDataErrorForbidden);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    SRGPlaylist *playlist = [self.userData.playlists playlistWithUid:SRGPlaylistUidWatchLater];
    
    XCTAssertEqualObjects(playlist.uid, SRGPlaylistUidWatchLater);
    XCTAssertEqual(playlist.type, SRGPlaylistTypeWatchLater);
    XCTAssertNotEqualObjects(playlist.name, name);
    XCTAssertFalse(playlist.discarded);
}

- (void)testPlaylistWithUid
{
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist inserted"];
    
    [self.userData.playlists savePlaylistWithName:@"A" uid:@"a" completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Synchronous
    SRGPlaylist *playlist1 = [self.userData.playlists playlistWithUid:@"a"];
    
    XCTAssertEqualObjects(playlist1.uid, @"a");
    XCTAssertEqual(playlist1.type, SRGPlaylistTypeStandard);
    XCTAssertEqualObjects(playlist1.name, @"A");
    XCTAssertFalse(playlist1.discarded);
    
    SRGPlaylist *playlist2 = [self.userData.playlists playlistWithUid:@"b"];
    XCTAssertNil(playlist2);
    
    // Asynchronous
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"a" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        XCTAssertEqualObjects(playlist.uid, @"a");
        XCTAssertEqual(playlist.type, SRGPlaylistTypeStandard);
        XCTAssertEqualObjects(playlist.name, @"A");
        XCTAssertFalse(playlist.discarded);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"b" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(playlist);
        XCTAssertNil(error);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylists
{
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    [self insertLocalPlaylistWithUid:@"c"];
    
    // Synchronous
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(uids, (@[ SRGPlaylistUidWatchLater, @"c", @"b", @"a" ]));
    
    // Asynchronous
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlists fetched"];
    
    [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        
        NSArray<NSString *> *uids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(uids, (@[ SRGPlaylistUidWatchLater, @"c", @"b", @"a" ]));
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylistsMatchingPredicate
{
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    [self insertLocalPlaylistWithUid:@"c"];
    [self insertLocalPlaylistWithUid:@"d"];
    
    // Synchronous
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", @keypath(SRGPlaylist.new, uid), @[ @"c", @"d" ]];
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"d", @"c" ]));
    
    // Asynchronous
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlists fetched"];
    
    [self.userData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        
        NSArray<NSString *> *uids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(uids, (@[ @"d", @"c" ]));
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylistsWithSortDescriptor
{
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    [self insertLocalPlaylistWithUid:@"c"];
    [self insertLocalPlaylistWithUid:@"d"];
    
    // Synchronous
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, uid) ascending:YES];
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor]];
    NSArray<NSString *> *uids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"a", @"b", @"c", @"d", SRGPlaylistUidWatchLater ]));
    
    // Asynchronous
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlists fetched"];
    
    [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor] completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        
        NSArray<NSString *> *uids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
        XCTAssertEqualObjects(uids, (@[ @"a", @"b", @"c", @"d", SRGPlaylistUidWatchLater ]));
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testDiscardPlaylists
{
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    [self insertLocalPlaylistWithUid:@"c"];
    [self insertLocalPlaylistWithUid:@"d"];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"b", @"c", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[ @"a", @"b", @"c" ] completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(uids, (@[ SRGPlaylistUidWatchLater, @"d" ]));
}

- (void)testDiscardNonExistingPlaylist
{
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No change must be received");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[ @"k" ] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
}

- (void)testDiscardDefaultPlaylist
{
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No change must be received");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[ SRGPlaylistUidWatchLater ] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(uids, (@[ SRGPlaylistUidWatchLater ]));
}

- (void)testDiscardAllPlaylists
{
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    [self insertLocalPlaylistWithUid:@"c"];
    [self insertLocalPlaylistWithUid:@"d"];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"b", @"c", @"d", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:nil completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects(uids, (@[ SRGPlaylistUidWatchLater ]));
}

- (void)testSaveNewEntryInPlaylist
{
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidKey], SRGPlaylistUidWatchLater);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], [NSSet setWithObject:@"1"]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
    
    [self.userData.playlists savePlaylistEntryWithUid:@"1" inPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testSaveEntryInSeveralPlaylists
{
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Insert"];
    
    [self.userData.playlists savePlaylistEntryWithUid:@"1" inPlaylistWithUid:@"a" completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Insert"];
    
    [self.userData.playlists savePlaylistEntryWithUid:@"1" inPlaylistWithUid:@"b" completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocaPlaylistEntriesUids:@[@"1"] forPlaylistWithUid:@"a"];
    [self assertLocaPlaylistEntriesUids:@[@"1"] forPlaylistWithUid:@"b"];
}

- (void)testSaveExistingEntryInPlaylist
{
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistEntriesWithUids:@[ @"1" ] forPlaylistWithUid:@"a"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
    
    [self.userData.playlists savePlaylistEntryWithUid:@"1" inPlaylistWithUid:@"a" completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 1);
    XCTAssertEqualObjects(playlistEntries.firstObject.uid, @"1");
}

- (void)testSaveExistingEntryInDefaultPlaylist
{
    [self insertLocalPlaylistEntriesWithUids:@[ @"1" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry added"];
    
    [self.userData.playlists savePlaylistEntryWithUid:@"1" inPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries.count, 1);
    XCTAssertEqualObjects(playlistEntries.firstObject.uid, @"1");
}

- (void)testSaveEntryInNonExistingPlaylist
{
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No change must be received");
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entry not added"];
    
    [self.userData.playlists savePlaylistEntryWithUid:@"1" inPlaylistWithUid:@"not_found" completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqualObjects(error.domain, SRGUserDataErrorDomain);
        XCTAssertEqual(error.code, SRGUserDataErrorNotFound);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
}

- (void)testPlaylistEntriesInPlaylist
{
    [self insertLocalPlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    // Synchronous
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"1", @"2", @"3", @"4" ]));
    
    // Asynchronous
    XCTestExpectation *expectation = [self expectationWithDescription:@"Entries fetched"];
    
    [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        
        NSArray<NSString *> *uids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        XCTAssertEqualObjects(uids, (@[ @"1", @"2", @"3", @"4" ]));
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylistEntriesInPlaylistMatchingPredicate
{
    [self insertLocalPlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    // Synchronous
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", @keypath(SRGPlaylistEntry.new, uid), @[ @"2", @"3" ]];
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:predicate sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"2", @"3" ]));
    
    // Asynchronous
    XCTestExpectation *expectation = [self expectationWithDescription:@"Entries fetched"];
    
    [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:predicate sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        
        NSArray<NSString *> *uids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        XCTAssertEqualObjects(uids, (@[ @"2", @"3" ]));
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testPlaylistEntriesInPlaylistWithSortDescriptor
{
    [self insertLocalPlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    // Synchronous
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, date) ascending:NO];
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:@[sortDescriptor]];
    NSArray<NSString *> *uids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"4", @"3", @"2", @"1" ]));
    
    // Asynchronous
    XCTestExpectation *expectation = [self expectationWithDescription:@"Entries fetched"];
    
    [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:@[sortDescriptor] completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        
        NSArray<NSString *> *uids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        XCTAssertEqualObjects(uids, (@[ @"4", @"3", @"2", @"1" ]));
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testDiscardPlaylistEntriesInPlaylist
{
    [self insertLocalPlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4", @"5" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidKey], SRGPlaylistUidWatchLater);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], ([NSSet setWithObjects:@"3", @"4", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Entries discarded"];
    
    [self.userData.playlists discardPlaylistEntriesWithUids:@[ @"3", @"4" ] fromPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"1", @"2", @"5" ]));
}

- (void)testDiscardNonExistingPlaylistEntryInPlaylist
{
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No change must be received");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Entries discarded"];
    
    [self.userData.playlists discardPlaylistEntriesWithUids:@[ @"k" ] fromPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
}

- (void)testDiscardAllPlaylistEntriesInPlaylist
{
    [self insertLocalPlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4", @"5" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidKey], SRGPlaylistUidWatchLater);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], ([NSSet setWithObjects:@"1", @"2", @"3", @"4", @"5", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Entries discarded"];
    
    [self.userData.playlists discardPlaylistEntriesWithUids:nil fromPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(uids, @[]);
}

- (void)testPlaylistEntriesMigrationToWatchLaterPlaylist
{
    NSDate *date = NSDate.date;
    NSArray<NSDictionary *> *migrations = @[ @{ @"itemId" : @"1",
                                                @"date" : @(round((date.timeIntervalSince1970 - 2) * 1000.)) },
                                             @{ @"itemId" : @"2",
                                                @"date" : @(round((date.timeIntervalSince1970 - 4) * 1000.)) },
                                             @{ @"itemId" : @"3",
                                                @"date" : @(round((date.timeIntervalSince1970 - 6) * 1000.)) },
                                             @{ @"itemId" : @"4",
                                                @"date" : @(round((date.timeIntervalSince1970 - 8) * 1000.)) },
                                             @{ @"itemId" : @"5",
                                                @"date" : @(round((date.timeIntervalSince1970 - 10) * 1000.)) } ];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entries added"];
    
    [self.userData.playlists savePlaylistEntryDictionaries:migrations toPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"5", @"4", @"3", @"2", @"1" ]));
}

@end
