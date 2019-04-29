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
        [self.userData.playlists addPlaylistWithName:playlistName completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:100. handler:NULL];
}

#pragma mark Setup and teardown

- (void)setUp
{
    [super setUp];
    
    [self eraseData];
    [self logout];
    [self setupForOfflineOnly];
}

#pragma mark Tests

- (void)testSystemPlaylistSynchronization
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    
    [self expectationForSingleNotification:SRGPlaylistsDidStartSynchronizationNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGPlaylistsDidFinishSynchronizationNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForElapsedTimeInterval:5. withHandler:nil];
    id changeObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGPlaylistsDidChangeNotification object:self.userData.playlists queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No change notification is expected. No user-created playlist exist");
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
    
    [[SRGPlaylistsRequest playlistsFromServiceURL:TestPlaylistsServiceURL() forSessionToken:self.identityService.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(playlistDictionaries.count, 1);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testInitialSynchronizationWithExistingRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    [self insertRemoteTestPlaylistsWithName:@"remote" count:2 entryCount:3];
    
    [self expectationForSingleNotification:SRGPlaylistsDidStartSynchronizationNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGPlaylistsDidFinishSynchronizationNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGPlaylistsPreviousUidsKey] count], 1);
        XCTAssertEqual([notification.userInfo[SRGPlaylistsChangedUidsKey] count], 2);
        XCTAssertEqual([notification.userInfo[SRGPlaylistsUidsKey] count], 3);
        return YES;
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
    
    [[SRGPlaylistsRequest playlistsFromServiceURL:TestPlaylistsServiceURL() forSessionToken:self.identityService.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(playlistDictionaries.count, 3);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testInitialSynchronizationWithExistingLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitalSynchronization];
    [self insertRemoteTestPlaylistsWithName:@"remote" count:2 entryCount:3];
    [self insertLocalTestPlaylistsWithName:@"local" count:4 entryCount:4];
    
    [self expectationForSingleNotification:SRGPlaylistsDidStartSynchronizationNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGPlaylistsDidFinishSynchronizationNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual([notification.userInfo[SRGPlaylistsPreviousUidsKey] count], 5);
        XCTAssertEqual([notification.userInfo[SRGPlaylistsChangedUidsKey] count], 6);
        XCTAssertEqual([notification.userInfo[SRGPlaylistsUidsKey] count], 7);
        return YES;
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
    
    [[SRGPlaylistsRequest playlistsFromServiceURL:TestPlaylistsServiceURL() forSessionToken:self.identityService.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(playlistDictionaries.count, 7);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testSynchronizationWithDeletedLocalEntries
{
    
}

- (void)testSynchronizationWithDeletedRemoteEntries
{
    
}

- (void)testLargePlaylists
{
    
}

- (void)testSynchronizationAfterLogoutDuringSynchronization
{
    
}

- (void)testSynchronizationWithoutLoggedInUser
{
    
}

- (void)testSynchronizationWithUnavailableService
{
    
}

@end
