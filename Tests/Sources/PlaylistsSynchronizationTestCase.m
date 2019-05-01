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

}

- (void)testInitialSynchronizationWithExistingRemoteEntries
{

}

- (void)testSynchronizationWithRemoteEntriesAddedAfterInitialization
{
    
}

- (void)testSynchronizationWithExistingLocalEntries
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

- (void)testAfterLogout
{
    // Check that the default playlists are inserted again
}

@end
