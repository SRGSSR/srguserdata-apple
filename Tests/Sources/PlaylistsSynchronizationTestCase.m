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
    
}

#pragma mark Tests

- (void)testEmptySynchronization
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
        XCTFail(@"No change notification is expected. Playlists are empty and still must be");
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:changeObserver];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
    
    [[SRGPlaylistsRequest playlistsFromServiceURL:TestPlaylistsServiceURL() forSessionToken:self.identityService.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(playlistDictionaries.count, 0);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testInitialSynchronizationWithExistingRemoteEntries
{
    
}

- (void)testInitialSynchronizationWithExistingLocalEntries
{
    
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
