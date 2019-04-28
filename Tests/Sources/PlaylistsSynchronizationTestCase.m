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

#pragma mark Helpers

- (void)insertLocalTestPlaylistsWithName:(NSString *)name count:(NSUInteger)count entryCount:(NSUInteger)entryCount
{
    for (NSUInteger i = 0; i < count; ++i) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Local insertion"];
        
        NSString *playlistName = [NSString stringWithFormat:@"%@_%@", name, @(i + 1)];
        [self.userData.playlists addPlaylistWithName:playlistName completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:100. handler:NULL];
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
    
    [self expectationForNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsPreviousUidsKey], @[@"watch_later"]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsChangedUidsKey], @[@"watch_later"]);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], @[@"watch_later"]);
        return YES;
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
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
