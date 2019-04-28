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
