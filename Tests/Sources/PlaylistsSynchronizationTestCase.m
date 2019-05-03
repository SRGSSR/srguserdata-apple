//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGPlaylistsRequest.h"

@interface PlaylistsSynchronizationTestCase : UserDataBaseTestCase

@end

@implementation PlaylistsSynchronizationTestCase

#pragma mark Overrides

- (NSString *)sessionToken
{
    // For playsrgtests+userdata2@gmail.com
    return @"s:zqlZDM1QTjSgCImtircirQr8KOgybQTj.nCgIw2PSk6mhO3ofFhbPErFBD+IGQ0dBcwsJ1lQn5fA";
}

#pragma mark Helpers

- (void)insertLocalTestPlaylistsWithName:(NSString *)name count:(NSUInteger)count entryCount:(NSUInteger)entryCount
{
    // TODO: Insert entries
    for (NSUInteger i = 0; i < count; ++i) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Local insertion"];
        
        NSString *playlistName = [NSString stringWithFormat:@"%@_%@", name, @(i + 1)];
        [self.userData.playlists savePlaylistWithName:playlistName uid:nil completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:100. handler:NULL];
}

- (void)assertLocalPlaylistCount:(NSUInteger)count
{
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlists.count, count);
}

- (void)assertLocalEntryCount:(NSUInteger)count forPlaylistWithUid:(NSString *)playlistUid
{
    NSArray<SRGPlaylistEntry *> *entries = [self.userData.playlists entriesFromPlaylistWithUid:playlistUid matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertNotNil(entries);
    XCTAssertEqual(entries.count, count);
}

#pragma mark Setup and teardown

- (void)setUp
{
    [super setUp];
    
    [self eraseDataAndWait];
    [self logout];
}

#pragma mark Tests

- (void)testSystemPlaylistAvailability
{
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGPlaylistsUidsKey] count] == 1;
    }];
    
    [self setupForOfflineOnly];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlists.count, 1);
    
    SRGPlaylist *playlist = playlists.firstObject;
    XCTAssertEqual(playlist.type, SRGPlaylistTypeWatchLater);
    XCTAssertEqualObjects(playlist.uid, SRGPlaylistUidWatchLater);
}

- (void)testSystemPlaylistAvailabilityAfterLogout
{
    // TODO: Not entirely trivial
#if 0
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistCount:1];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    
    [self logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlists.count, 1);
    
    SRGPlaylist *playlist = playlists.firstObject;
    XCTAssertEqual(playlist.type, SRGPlaylistTypeWatchLater);
    XCTAssertEqualObjects(playlist.uid, SRGPlaylistUidWatchLater);
#endif
}

- (void)testInitialSynchronizationWithoutRemotePlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistCount:1];
    [self assertRemotePlaylistCount:1];
}

- (void)testInitialSynchronizationWithExistingRemotePlaylists
{
    [self insertRemoteTestPlaylistsWithName:@"a" count:4 entryCount:10];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistCount:5];
    [self assertRemotePlaylistCount:5];
}

- (void)testSynchronizationWithoutPlaylistChanges
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistCount:1];
    [self assertRemotePlaylistCount:1];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistCount:1];
    [self assertRemotePlaylistCount:1];
}

- (void)testSynchronizationWithAddedRemotePlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemoteTestPlaylistsWithName:@"a" count:4 entryCount:10];
    
    [self assertLocalPlaylistCount:1];
    [self assertRemotePlaylistCount:5];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistCount:5];
    [self assertRemotePlaylistCount:5];
}

- (void)testSynchronizationWithAddedLocalPlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalTestPlaylistsWithName:@"a" count:3 entryCount:9];
    
    [self assertLocalPlaylistCount:4];
    [self assertRemotePlaylistCount:1];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistCount:4];
    [self assertRemotePlaylistCount:4];
}

- (void)testSynchronizationWithAddedRemoteAndLocalPlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalTestPlaylistsWithName:@"a" count:7 entryCount:8];
    [self insertRemoteTestPlaylistsWithName:@"b" count:9 entryCount:5];
    
    [self assertLocalPlaylistCount:8];
    [self assertRemotePlaylistCount:10];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistCount:17];
    [self assertRemotePlaylistCount:17];
}

- (void)testSynchronizationWithDeletedLocalPlaylists
{
    [self insertRemoteTestPlaylistsWithName:@"a" count:7 entryCount:10];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistCount:8];
    [self assertRemotePlaylistCount:8];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Local deletion"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[@"a_1", @"a_3"] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistCount:6];
    [self assertRemotePlaylistCount:6];
}

- (void)testSynchronizationWithDeletedRemotePlaylists
{
    [self insertRemoteTestPlaylistsWithName:@"a" count:7 entryCount:10];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistCount:8];
    [self assertRemotePlaylistCount:8];
    
    [self deleteRemotePlaylistWithUids:@[ @"a_2", @"a_3" ]];
    
    [self assertRemotePlaylistCount:6];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistCount:6];
    [self assertRemotePlaylistCount:6];
}

- (void)testSynchronizationWithDeletedRemoteAndLocalPlaylists
{
    [self insertRemoteTestPlaylistsWithName:@"a" count:7 entryCount:10];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistCount:8];
    [self assertRemotePlaylistCount:8];
    
    [self deleteRemotePlaylistWithUids:@[ @"a_2", @"a_3" ]];
    
    [self assertRemotePlaylistCount:6];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Local deletion"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[@"a_1", @"a_4"] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistCount:4];
    [self assertRemotePlaylistCount:4];
}

- (void)testPlaylistSynchronizationWithoutEntryChanges
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalEntryCount:0 forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryCount:0 forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalEntryCount:0 forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryCount:0 forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithAddedRemoteEntries
{
    
}

- (void)testPlaylistSynchronizationWithAddedLocalEntries
{
    
}

- (void)testPlaylistSynchronizationWithAddedRemoteAndLocalEntries
{
    
}

- (void)testPlaylistSynchronizationWithDeletedRemoteEntries
{
    
}

- (void)testPlaylistSynchronizationWithDeletedLocalEntries
{
    
}

- (void)testPlaylistSynchronizationWithDeletedRemoteAndLocalEntries
{
    
}

- (void)testLargePlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalTestPlaylistsWithName:@"b" count:80 entryCount:100];
    [self insertRemoteTestPlaylistsWithName:@"a" count:120 entryCount:100];
    
    [self assertLocalPlaylistCount:81];
    [self assertRemotePlaylistCount:121];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistCount:201];
    [self assertRemotePlaylistCount:201];
}

- (void)testAfterLogout
{
    // TODO: Fix -testSystemPlaylistAvailabilityAfterLogout first
#if 0
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalTestPlaylistsWithName:@"b" count:10 entryCount:9];
    
    [self assertLocalPlaylistCount:11];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGHistoryUidsKey] count] == 1;
    }];
    
    [self.identityService logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self assertLocalPlaylistCount:1];
#endif
}

- (void)testSynchronizationAfterLogoutDuringSynchronization
{
    XCTFail(@"Implement");
}

- (void)testSynchronizationWithoutLoggedInUser
{
    [self setupForAvailableService];
    
    id startObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidStartSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No start notification is expected");
    }];
    id finishObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidFinishSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No finish notification is expected");
    }];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqual([notification.userInfo[SRGPlaylistsUidsKey] count], 1);
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:startObserver];
        [NSNotificationCenter.defaultCenter removeObserver:finishObserver];
    }];
}

- (void)testSynchronizationWithUnavailableService
{
    [self setupForUnavailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqual([notification.userInfo[SRGPlaylistsUidsKey] count], 1);
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

@end
