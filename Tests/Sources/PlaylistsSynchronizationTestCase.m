//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGPlaylistsRequest.h"
#import "SRGUserObject+Private.h"

#import <libextobjc/libextobjc.h>

@interface PlaylistsSynchronizationTestCase : UserDataBaseTestCase

@end

@implementation PlaylistsSynchronizationTestCase

#pragma mark Overrides

- (NSString *)sessionToken
{
    // For playsrgtests+userdata2@gmail.com
    return @"s:zqlZDM1QTjSgCImtircirQr8KOgybQTj.nCgIw2PSk6mhO3ofFhbPErFBD+IGQ0dBcwsJ1lQn5fA";
}

#pragma mark Setup and teardown

- (void)setUp
{
    [super setUp];
    
    [self eraseRemoteDataAndWait];
    [self logout];
}

#pragma mark Tests

- (void)testWatchLaterPlaylistAvailability
{
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGPlaylistsUidsKey] containsObject:SRGPlaylistUidWatchLater];
    }];
    
    [self setupForOfflineOnly];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlists.count, 1);
    
    SRGPlaylist *playlist = playlists.firstObject;
    XCTAssertEqual(playlist.type, SRGPlaylistTypeWatchLater);
    XCTAssertEqualObjects(playlist.uid, SRGPlaylistUidWatchLater);
}

- (void)testInitialSynchronizationWithoutRemotePlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[]];
    [self assertRemotePlaylistUids:@[]];
}

- (void)testInitialSynchronizationWithExistingRemotePlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b" ]];
}

- (void)testSynchronizationWithoutPlaylistChanges
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[]];
    [self assertRemotePlaylistUids:@[]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[]];
    [self assertRemotePlaylistUids:@[]];
}

- (void)testSynchronizationWithAddedRemotePlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    
    [self assertLocalPlaylistUids:@[]];
    [self assertRemotePlaylistUids:@[ @"a", @"b" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b" ]];
}

- (void)testSynchronizationWithAddedLocalPlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b" ]];
}

- (void)testSynchronizationWithAddedRemoteAndLocalPlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"c" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c" ]];
}

- (void)testSynchronizationWithDiscardedLocalPlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self discardLocalPlaylistsWithUids:@[ @"a", @"c" ]];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
}

- (void)testSynchronizationWithDiscardedRemotePlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self discardRemotePlaylistsWithUids:@[ @"a", @"c" ]];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
}

- (void)testSynchronizationWithDiscardedRemoteAndLocalPlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    [self insertRemotePlaylistWithUid:@"e"];
    [self insertRemotePlaylistWithUid:@"f"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c", @"d", @"e", @"f" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c", @"d", @"e", @"f" ]];
    
    [self discardLocalPlaylistsWithUids:@[ @"b", @"c" ]];
    [self discardRemotePlaylistsWithUids:@[ @"c", @"d", @"e" ]];
    
    [self assertLocalPlaylistUids:@[ @"a", @"d", @"e", @"f" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"f" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"a", @"f" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"f" ]];
}

- (void)testPlaylistSynchronizationWithoutEntryChanges
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistEntriesUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistEntriesUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithAddedRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemotePlaylistEntriesWithUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalPlaylistEntriesUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithAddedLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistEntriesWithUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithAddedRemoteAndLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistEntriesWithUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self insertRemotePlaylistEntriesWithUids:@[ @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithDiscardedRemoteEntries
{
    [self insertRemotePlaylistEntriesWithUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];

    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
        
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self discardRemotePlaylistEntriesWithUids:@[ @"a", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistEntriesUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithDiscardedLocalEntries
{
    [self insertRemotePlaylistEntriesWithUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self discardLocalPlaylistEntriesWithUids:@[ @"a", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalPlaylistEntriesUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistEntriesUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithDiscardedRemoteAndLocalEntries
{
    [self insertRemotePlaylistEntriesWithUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self discardLocalPlaylistEntriesWithUids:@[ @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self discardRemotePlaylistEntriesWithUids:@[ @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"b", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistEntriesUids:@[ @"a", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemotePlaylistEntriesUids:@[ @"a", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

// TODO: Disabled. Too intensive for the service.
#if 0
- (void)testLargePlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    NSArray<NSString *> *(^uidsBuilder)(NSUInteger, NSUInteger) = ^(NSUInteger start, NSUInteger end) {
        NSMutableArray<NSString *> *uids = [NSMutableArray array];
        for (NSUInteger i = start; i < end; i++) {
            [uids addObject:@(i).stringValue];
        }
        return uids.copy;
    };
    
    for (NSUInteger i = 0; i < 100; ++i) {
        [self insertLocalPlaylistWithUid:@(i).stringValue];
    }
    
    for (NSUInteger i = 50; i < 150; ++i) {
        [self insertRemotePlaylistWithUid:@(i).stringValue];
    }
    
    [self assertLocalPlaylistUids:uidsBuilder(0, 100)];
    [self assertRemotePlaylistUids:uidsBuilder(50, 150)];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:uidsBuilder(0, 150)];
    [self assertRemotePlaylistUids:uidsBuilder(0, 150)];
}
#endif

- (void)testLogout
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    
    [self insertLocalPlaylistEntriesWithUids:@[ @"1", @"2", @"3" ] forPlaylistWithUid:@"a"];
    [self insertLocalPlaylistEntriesWithUids:@[ @"1", @"3", @"5", @"7" ] forPlaylistWithUid:@"b"];
    [self insertLocalPlaylistEntriesWithUids:@[ @"2", @"4" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"b", nil]));
        return YES;
    }];
    
    __block BOOL playlistANotificationReceived = NO;
    __block BOOL playlistBNotificationReceived = NO;
    __block BOOL playlistWatchLaterNotificationReceived = NO;
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        NSString *playlistUid = notification.userInfo[SRGPlaylistUidKey];
        NSSet<NSString *> *playlistEntriesUids = notification.userInfo[SRGPlaylistEntriesUidsKey];
        
        if ([playlistUid isEqualToString:@"a"]) {
            XCTAssertFalse(playlistANotificationReceived);
            XCTAssertEqualObjects(playlistEntriesUids, ([NSSet setWithObjects:@"1", @"2", @"3", nil]));
            
            playlistANotificationReceived = YES;
        }
        else if ([playlistUid isEqualToString:@"b"]) {
            XCTAssertFalse(playlistBNotificationReceived);
            XCTAssertEqualObjects(playlistEntriesUids, ([NSSet setWithObjects:@"1", @"3", @"5", @"7", nil]));
            
            playlistBNotificationReceived = YES;
        }
        else if ([playlistUid isEqualToString:SRGPlaylistUidWatchLater]) {
            XCTAssertFalse(playlistWatchLaterNotificationReceived);
            XCTAssertEqualObjects(playlistEntriesUids, ([NSSet setWithObjects:@"2", @"4", nil]));
            
            playlistWatchLaterNotificationReceived = YES;
        }
        return playlistANotificationReceived && playlistBNotificationReceived && playlistWatchLaterNotificationReceived;
    }];
    
    [self.identityService logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self assertLocalPlaylistUids:@[]];
    [self assertLocalPlaylistEntriesUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testSynchronizationAfterLogoutDuringSynchronization
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    [self insertLocalPlaylistWithUid:@"c"];
    
    [self insertLocalPlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4" ] forPlaylistWithUid:@"a"];
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:nil];
    
    [self synchronize];
    [self logout];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self assertLocalPlaylistUids:@[]];
    
    // Login again and check that synchronization still works
    [self loginAndWaitForInitialSynchronization];
}

- (void)testNoSynchronizationWithoutLoggedInUser
{
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGPlaylistsUidsKey] containsObject:SRGPlaylistUidWatchLater];
    }];
    
    [self setupForAvailableService];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    id startObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidStartSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No start notification is expected");
    }];
    id changeObserver1 = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    id changeObserver2 = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    id finishObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidFinishSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No finish notification is expected");
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:startObserver];
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver1];
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver2];
        [NSNotificationCenter.defaultCenter removeObserver:finishObserver];
    }];
}

- (void)testNotificationDuringInitialSynchronization
{    
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    
    [self insertRemotePlaylistEntriesWithUids:@[ @"1", @"2", @"3" ] forPlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        
        if ([notification.userInfo[SRGPlaylistsUidsKey] isEqual:[NSSet setWithObject:SRGPlaylistUidWatchLater]]) {
            return NO;
        }
        
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"b", nil]));
        return YES;
    }];
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], ([NSSet setWithObjects:@"1", @"2", @"3", nil]));
        return YES;
    }];
    
    [self login];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b" ]];
    
    [self assertLocalPlaylistEntriesUids:@[ @"1", @"2", @"3" ] forPlaylistWithUid:@"a"];
    [self assertRemotePlaylistEntriesUids:@[ @"1", @"2", @"3" ] forPlaylistWithUid:@"a"];
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
    
    id changeObserver1 = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    id changeObserver2 = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected");
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver1];
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver2];
    }];
}

- (void)testNotificationsWithDiscardedLocalEmptyPlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Changes are notified when playlists are marked as being discarded
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"c", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discard"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[ @"a", @"c" ] completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // No more changes must be received for the discarded playlists when deleted during synchronization
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"b", @"d", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
}

- (void)testNotificationsWithDiscardedLocalPlaylistEntries
{
    [self insertRemotePlaylistWithUid:@"a"];
    
    [self insertRemotePlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4", @"5" ] forPlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No playlist change notification is expected");
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidKey], @"a");
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], ([NSSet setWithObjects:@"2", @"4", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist entries discarded"];
    
    [self.userData.playlists discardPlaylistEntriesWithUids:@[ @"2", @"4" ] fromPlaylistWithUid:@"a" completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    [self assertLocalPlaylistUids:@[ @"a" ]];
    [self assertRemotePlaylistUids:@[ @"a" ]];
    
    [self assertLocalPlaylistEntriesUids:@[ @"1", @"3", @"5" ] forPlaylistWithUid:@"a"];
    [self assertRemotePlaylistEntriesUids:@[ @"1", @"2", @"3", @"4", @"5" ] forPlaylistWithUid:@"a"];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistEntriesUids:@[ @"1", @"3", @"5" ] forPlaylistWithUid:@"a"];
    [self assertLocalPlaylistEntriesUids:@[ @"1", @"3", @"5" ] forPlaylistWithUid:@"a"];
}

- (void)testNotificationsWithDiscardedLocalPlaylistsWithEntries
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self insertRemotePlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4", @"5" ] forPlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", nil]));
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidKey], @"a");
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], ([NSSet setWithObjects:@"1", @"2", @"3", @"4", @"5", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[ @"a" ] completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testNotificationsWithDiscardedRemoteEmptyPlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self discardRemotePlaylistsWithUids:@[ @"a", @"c" ]];
    
    // Changes are notified when synchronization occurs with the remote changes
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"b", @"c", @"d", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
}

- (void)testNotificationsWithDiscardedRemotePlaylistEntries
{
    [self insertRemotePlaylistWithUid:@"a"];
    
    [self insertRemotePlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4", @"5" ] forPlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self discardRemotePlaylistEntriesWithUids:@[ @"2", @"4" ] forPlaylistWithUid:@"a"];
    
    // Changes are notified when synchronization occurs with the remote changes
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", nil]));
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidKey], @"a");
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], ([NSSet setWithObjects:@"1", @"2", @"3", @"4", @"5", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPlaylistUids:@[ @"a" ]];
    [self assertRemotePlaylistUids:@[ @"a" ]];
    
    [self assertLocalPlaylistEntriesUids:@[ @"1", @"3", @"5" ] forPlaylistWithUid:@"a"];
    [self assertLocalPlaylistEntriesUids:@[ @"1", @"3", @"5" ] forPlaylistWithUid:@"a"];
}

- (void)testNotificationsWithDiscardedRemotePlaylistsWithEntries
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self insertRemotePlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4", @"5" ] forPlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self discardRemotePlaylistsWithUids:@[ @"a" ]];
    
    // Changes are notified when synchronization occurs with the remote changes
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"b", @"c", @"d", nil]));
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidKey], @"a");
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], ([NSSet setWithObjects:@"1", @"2", @"3", @"4", @"5", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPlaylistUids:@[ @"b", @"c", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"c", @"d" ]];
}

- (void)testNonReturnedDiscardedPlaylistWithUid
{
    [self insertRemotePlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Synchronous
    SRGPlaylist *playlist1 = [self.userData.playlists playlistWithUid:@"a"];
    XCTAssertNotNil(playlist1);
    XCTAssertFalse(playlist1.discarded);
    
    // Asynchronous
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"a" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertNotNil(playlist);
        XCTAssertFalse(playlist.discarded);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self discardLocalPlaylistsWithUids:@[ @"a" ]];
    
    XCTAssertTrue(playlist1.discarded);
    
    // Synchronous
    SRGPlaylist *playlist2 = [self.userData.playlists playlistWithUid:@"a"];
    XCTAssertNil(playlist2);
    
    // Asynchronous
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"a" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertNil(playlist);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self synchronizeAndWait];
    
    // Synchronous
    SRGPlaylist *playlist3 = [self.userData.playlists playlistWithUid:@"a"];
    XCTAssertNil(playlist3);
    
    // Asynchronous
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"a" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertNil(playlist);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testNonReturnedDiscardedPlaylistsWithPredicate
{
    [self insertRemotePlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Synchronous
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGPlaylist.new, uid), @"a"];
    SRGPlaylist *playlist1 = [self.userData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:nil].firstObject;
    XCTAssertNotNil(playlist1);
    XCTAssertFalse(playlist1.discarded);
    
    // Asynchronous
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
        XCTAssertEqual(playlists.count, 1);
        
        SRGPlaylist *playlist = playlists.firstObject;
        XCTAssertNotNil(playlist);
        XCTAssertFalse(playlist.discarded);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self discardLocalPlaylistsWithUids:@[ @"a" ]];
    
    XCTAssertTrue(playlist1.discarded);
    
    // Synchronous
    SRGPlaylist *playlist2 = [self.userData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:nil].firstObject;
    XCTAssertNil(playlist2);
    
    // Asynchronous
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
        XCTAssertEqual(playlists.count, 0);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self synchronizeAndWait];
    
    // Synchronous
    SRGPlaylist *playlist3 = [self.userData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:nil].firstObject;
    XCTAssertNil(playlist3);
    
    // Asynchronous
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylist *> * _Nullable playlists, NSError * _Nullable error) {
        XCTAssertEqual(playlists.count, 0);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testNonReturnedDiscardedPlaylistEntriesForPlaylistWithUid
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistEntriesWithUids:@[ @"1" ] forPlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Synchronous
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries1.count, 1);
    SRGPlaylistEntry *playlistEntry1 = playlistEntries1.firstObject;
    XCTAssertNotNil(playlistEntry1);
    XCTAssertFalse(playlistEntry1.discarded);
    
    // Asynchronous
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertEqual(playlistEntries1.count, 1);
        SRGPlaylistEntry *playlistEntry = playlistEntries1.firstObject;
        XCTAssertNotNil(playlistEntry);
        XCTAssertFalse(playlistEntry.discarded);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self discardLocalPlaylistEntriesWithUids:@[ @"1" ] forPlaylistWithUid:@"a"];
    
    XCTAssertTrue(playlistEntry1.discarded);
    
    // Synchronous
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries2.count, 0);
    
    // Asynchronous
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertEqual(playlistEntries.count, 0);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self synchronizeAndWait];
    
    // Synchronous
    NSArray<SRGPlaylistEntry *> *playlistEntries3 = [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries3.count, 0);
    
    // Asynchronous
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertEqual(playlistEntries.count, 0);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testNonReturnedPlaylistEntriesForDiscardedPlaylistWithUid
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistEntriesWithUids:@[ @"1" ] forPlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Synchronous
    SRGPlaylist *playlist1 = [self.userData.playlists playlistWithUid:@"a"];
    XCTAssertNotNil(playlist1);
    XCTAssertFalse(playlist1.discarded);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries1 = [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries1.count, 1);
    SRGPlaylistEntry *playlistEntry1 = playlistEntries1.firstObject;
    XCTAssertNotNil(playlistEntry1);
    XCTAssertFalse(playlistEntry1.discarded);
    
    // Asynchronous
    XCTestExpectation *expectation11 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"a" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertNotNil(playlist);
        XCTAssertFalse(playlist.discarded);
        [expectation11 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation12 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertEqual(playlistEntries1.count, 1);
        SRGPlaylistEntry *playlistEntry = playlistEntries1.firstObject;
        XCTAssertNotNil(playlistEntry);
        XCTAssertFalse(playlistEntry.discarded);
        [expectation12 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self discardLocalPlaylistsWithUids:@[@"a"]];
    
    XCTAssertTrue(playlist1.discarded);
    XCTAssertTrue(playlistEntry1.discarded);
    
    // Synchronous
    SRGPlaylist *playlist2 = [self.userData.playlists playlistWithUid:@"a"];
    XCTAssertNil(playlist2);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries2 = [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries2.count, 0);
    
    // Asynchronous
    XCTestExpectation *expectation21 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"a" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertNil(playlist);
        [expectation21 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation22 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertEqual(playlistEntries.count, 0);
        [expectation22 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    [self synchronizeAndWait];
    
    // Synchronous
    SRGPlaylist *playlist3 = [self.userData.playlists playlistWithUid:@"a"];
    XCTAssertNil(playlist3);
    
    NSArray<SRGPlaylistEntry *> *playlistEntries3 = [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlistEntries3.count, 0);
    
    // Asynchronous
    XCTestExpectation *expectation31 = [self expectationWithDescription:@"Playlist fetched"];
    
    [self.userData.playlists playlistWithUid:@"a" completionBlock:^(SRGPlaylist * _Nullable playlist, NSError * _Nullable error) {
        XCTAssertNil(playlist);
        [expectation31 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation32 = [self expectationWithDescription:@"Playlist entries fetched"];
    
    [self.userData.playlists playlistEntriesInPlaylistWithUid:@"a" matchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        XCTAssertEqual(playlistEntries.count, 0);
        [expectation32 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

@end
