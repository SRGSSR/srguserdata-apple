//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGHistoryRequest.h"
#import "SRGPlaylistsRequest.h"
#import "SRGPreferencesRequest.h"
#import "SRGUserObject+Private.h"

#import <libextobjc/libextobjc.h>
#import <OHHTTPStubs/OHHTTPStubs.h>

@interface SRGUserData (TestsPrivate)

- (void)synchronize;

@end

@interface SRGIdentityService (Private)

- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@property (nonatomic, readonly, copy) NSString *identifier;

@end

static NSURL *TestServiceURL(void)
{
    return [NSURL URLWithString:@"https://profil.rts.ch/api"];
}

static NSURL *TestWebserviceURL(void)
{
    return [NSURL URLWithString:@"https://api.srgssr.local"];
}

static NSURL *TestWebsiteURL(void)
{
    return [NSURL URLWithString:@"https://www.srgssr.local"];
}

static NSURL *TestDataServiceURL(void)
{
    return [TestServiceURL() URLByAppendingPathComponent:@"data"];
}

static NSURL *TestLoginCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srguserdata-tests://%@?identity_service=%@&token=%@", TestWebserviceURL().host, identityService.identifier, token];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestLogoutCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srguserdata-tests://%@?identity_service=%@&action=log_out", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

NSURL *TestHistoryServiceURL(void)
{
    return [TestServiceURL() URLByAppendingPathComponent:@"history"];
}

NSURL *TestPlaylistsServiceURL(void)
{
    return [TestServiceURL() URLByAppendingPathComponent:@"playlist"];
}

NSURL *TestPreferencesServiceURL(void)
{
    return [TestServiceURL() URLByAppendingPathComponent:@"preference"];
}

@interface UserDataBaseTestCase ()

@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGUserData *userData;

@end

@implementation UserDataBaseTestCase

#pragma mark Store generation

- (NSURL *)URLForStoreFromPackage:(NSString *)package
{
    static NSString * const kStoreName = @"Data";
    
    if (package) {
        for (NSString *extension in @[ @"sqlite", @"sqlite-shm", @"sqlite-wal"]) {
            NSString *sqliteFilePath = [[NSBundle bundleForClass:self.class] pathForResource:kStoreName ofType:extension inDirectory:package];
            if (! [NSFileManager.defaultManager fileExistsAtPath:sqliteFilePath]) {
                continue;
            }
            
            NSURL *sqliteFileURL = [NSURL fileURLWithPath:sqliteFilePath];
            NSURL *sqliteDestinationFileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:package] URLByAppendingPathExtension:extension];
            XCTAssertTrue([NSFileManager.defaultManager replaceItemAtURL:sqliteDestinationFileURL
                                                           withItemAtURL:sqliteFileURL
                                                          backupItemName:nil
                                                                 options:NSFileManagerItemReplacementUsingNewMetadataOnly
                                                        resultingItemURL:NULL
                                                                   error:NULL]);
        }
        
        return [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:package] URLByAppendingPathExtension:@"sqlite"];
    }
    else {
        return [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    }
}

#pragma mark Setup and teardown

- (void)setUp
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqual:TestWebserviceURL().host];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        if ([request.URL.host isEqualToString:TestWebserviceURL().host]) {
            if ([request.URL.path containsString:@"logout"]) {
                return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                   statusCode:204
                                                      headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
            }
            else if ([request.URL.path containsString:@"userinfo"]) {
                if (self.sessionToken) {
                    NSDictionary<NSString *, id> *account = @{ @"id" : @"1234",
                                                               @"publicUid" : @"1012",
                                                               @"login" : @"test@srgssr.ch",
                                                               @"displayName": @"Test user",
                                                               @"firstName": @"Test user",
                                                               @"lastName": @"SRG",
                                                               @"gender": @"other",
                                                               @"birthdate": @"2001-01-01" };
                    return [[OHHTTPStubsResponse responseWithData:[NSJSONSerialization dataWithJSONObject:account options:0 error:NULL]
                                                       statusCode:200
                                                          headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
                else {
                    return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                       statusCode:401
                                                          headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
            }
        }
        
        // No match, return 404
        return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                           statusCode:404
                                              headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
    }];
    
    self.identityService = [[SRGIdentityService alloc] initWithWebserviceURL:TestWebserviceURL() websiteURL:TestWebsiteURL()];
    [self.identityService logout];
}

- (void)tearDown
{
    self.userData = nil;
    self.identityService = nil;
}

#pragma mark Expectations

- (XCTestExpectation *)expectationForSingleNotification:(NSNotificationName)notificationName object:(id)objectToObserve handler:(XCNotificationExpectationHandler)handler
{
    NSString *description = [NSString stringWithFormat:@"Expectation for notification '%@' from object %@", notificationName, objectToObserve];
    XCTestExpectation *expectation = [self expectationWithDescription:description];
    __block id observer = [NSNotificationCenter.defaultCenter addObserverForName:notificationName object:objectToObserve queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        void (^fulfill)(void) = ^{
            [expectation fulfill];
            [NSNotificationCenter.defaultCenter removeObserver:observer];
        };
        
        if (handler) {
            if (handler(notification)) {
                fulfill();
            }
        }
        else {
            fulfill();
        }
    }];
    return expectation;
}

- (XCTestExpectation *)expectationForElapsedTimeInterval:(NSTimeInterval)timeInterval withHandler:(void (^)(void))handler
{
    XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"Wait for %@ seconds", @(timeInterval)]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
        handler ? handler() : nil;
    });
    return expectation;
}

#pragma mark Data

- (void)setupWithServiceURL:(NSURL *)serviceURL
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                                   serviceURL:serviceURL
                                              identityService:self.identityService];
}

- (void)setupForOfflineOnly
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                                   serviceURL:nil
                                              identityService:self.identityService];
}

- (void)setupForAvailableService
{
    [self setupWithServiceURL:TestServiceURL()];
}

- (void)setupForUnavailableService
{
    [self setupWithServiceURL:[NSURL URLWithString:@"https://missing.service"]];
}

- (void)synchronizeUserData
{
    [self.userData synchronize];
}

// GDPR special endpoint which erases all user data, returning the account to a pristine state. This endpoin is undocumented
// but publicly available.
- (void)eraseRemoteDataAndWait
{
    XCTAssertNotNil(self.sessionToken);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History cleared"];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:TestDataServiceURL()];
    URLRequest.HTTPMethod = @"DELETE";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", self.sessionToken] forHTTPHeaderField:@"Authorization"];
    [[SRGRequest dataRequestWithURLRequest:URLRequest session:NSURLSession.sharedSession completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (NSString *)sessionToken
{
    return nil;
}

- (void)login
{
    XCTAssertNotNil(self.sessionToken);
        
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, self.sessionToken)];
    XCTAssertTrue(hasHandledCallbackURL);
}

- (void)loginAndWait
{
    XCTAssertNotNil(self.sessionToken);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:nil];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, self.sessionToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertNotNil(self.identityService.account);
}

- (void)loginAndWaitForInitialSynchronization
{
    XCTAssertNotNil(self.sessionToken);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:nil];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:nil];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, self.sessionToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertNotNil(self.identityService.account);
}

- (void)logout
{
    XCTAssertNotNil(self.sessionToken);
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLogoutCallbackURL(self.identityService, self.sessionToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    XCTAssertNil(self.identityService.sessionToken);
}

- (void)synchronize
{
    [self.userData synchronize];
}

- (void)synchronizeAndWait
{
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self.userData synchronize];
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
}

#pragma mark History remote data management

- (void)insertRemoteHistoryEntriesWithUids:(NSArray<NSString *> *)uids
{
    XCTAssertNotNil(self.sessionToken);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    NSMutableArray<NSDictionary *> *JSONDictionaries = [NSMutableArray array];
    for (NSString *uid in uids) {
        NSDictionary *JSONDictionary = @{ @"item_id" : uid,
                                          @"device_id" : @"test suite",
                                          @"lastPlaybackPosition" : @([uids indexOfObject:uid] * 1000.),
                                          @"date" : @(round(NSDate.date.timeIntervalSince1970 * 1000.)) };
        [JSONDictionaries addObject:JSONDictionary];
    }
    
    [[SRGHistoryRequest postBatchOfHistoryEntryDictionaries:JSONDictionaries toServiceURL:TestHistoryServiceURL() forSessionToken:self.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)discardRemoteHistoryEntriesWithUids:(NSArray<NSString *> *)uids
{
    XCTAssertNotNil(self.sessionToken);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    NSMutableArray<NSDictionary *> *dictionaries = [NSMutableArray array];
    for (NSString *uid in uids) {
        NSDictionary *dictionary = @{ @"item_id" : uid,
                                      @"device_id" : @"test suite",
                                      @"deleted" : @YES,
                                      @"date" : @(round(NSDate.date.timeIntervalSince1970 * 1000.)) };
        [dictionaries addObject:dictionary];
    }
    
    [[SRGHistoryRequest postBatchOfHistoryEntryDictionaries:dictionaries.copy toServiceURL:TestHistoryServiceURL() forSessionToken:self.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)assertRemoteHistoryUids:(NSArray<NSString *> *)uids
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"History request"];
    
    [[SRGHistoryRequest historyUpdatesFromServiceURL:TestHistoryServiceURL() forSessionToken:self.identityService.sessionToken afterDate:nil withDeletedEntries:NO session:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        NSArray<NSString *> *remoteUids = [historyEntryDictionaries valueForKeyPath:@"item_id"];
        XCTAssertEqualObjects([NSSet setWithArray:uids], [NSSet setWithArray:remoteUids]);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

#pragma mark History local data management

- (void)insertLocalHistoryEntriesWithUids:(NSArray<NSString *> *)uids
{
    XCTAssertNotNil(self.userData);
    
    for (NSString *uid in uids) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Local insertion"];
        [self.userData.history saveHistoryEntryWithUid:uid lastPlaybackTime:CMTimeMakeWithSeconds([uids indexOfObject:uid], NSEC_PER_SEC) deviceUid:@"User data UT" completionBlock:^(NSError * _Nonnull error) {
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
}

- (void)discardLocalHistoryEntriesWithUids:(NSArray<NSString *> *)uids
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Local deletion"];
    
    [self.userData.history discardHistoryEntriesWithUids:uids completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)assertLocalHistoryUids:(NSArray<NSString *> *)uids
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil];
    NSArray<NSString *> *localUids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects([NSSet setWithArray:uids], [NSSet setWithArray:localUids]);
}

#pragma mark Playlist remote data management

- (void)insertRemotePlaylistWithUid:(NSString *)uid
{
    XCTAssertNotNil(self.sessionToken);
    
    NSDictionary *playlistDictionary = @{ @"businessId" : uid,
                                          @"name" : [NSString stringWithFormat:@"%@ (remote)", uid] };
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
    
    [[SRGPlaylistsRequest postPlaylistDictionary:playlistDictionary toServiceURL:TestPlaylistsServiceURL() forSessionToken:self.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSDictionary * _Nullable playlistDictionary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)insertRemotePlaylistEntriesWithUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid
{
    XCTAssertNotNil(self.sessionToken);
    
    NSMutableArray<NSDictionary *> *playlistEntryDictionaries = [NSMutableArray array];
    for (NSString *uid in uids) {
        NSDictionary *playlistEntryDictionary = @{ @"itemId" : uid,
                                                   @"date" : @(round(NSDate.date.timeIntervalSince1970 * 1000.)) };
        [playlistEntryDictionaries addObject:playlistEntryDictionary];
    }

    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
    
    [[SRGPlaylistsRequest putPlaylistEntryDictionaries:playlistEntryDictionaries.copy forPlaylistWithUid:playlistUid toServiceURL:TestPlaylistsServiceURL() forSessionToken:self.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistEntryDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)discardRemotePlaylistsWithUids:(NSArray<NSString *> *)uids
{
    XCTAssertNotNil(self.sessionToken);
    
    for (NSString *uid in uids) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
        
        [[SRGPlaylistsRequest deletePlaylistWithUid:uid fromServiceURL:TestPlaylistsServiceURL() forSessionToken:self.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }] resume];
    }
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)discardRemotePlaylistEntriesWithUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid
{
    XCTAssertNotNil(self.sessionToken);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
    
    [[SRGPlaylistsRequest deletePlaylistEntriesWithUids:uids forPlaylistWithUid:playlistUid fromServiceURL:TestPlaylistsServiceURL() forSessionToken:self.identityService.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)assertRemotePlaylistUids:(NSArray<NSString *> *)uids
{
    XCTAssertNotNil(self.sessionToken);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
    
    [[SRGPlaylistsRequest playlistsFromServiceURL:TestPlaylistsServiceURL() forSessionToken:self.identityService.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        NSArray<NSString *> *remoteUids = [playlistDictionaries valueForKeyPath:@"businessId"];
        XCTAssertEqualObjects([[NSSet setWithArray:uids] setByAddingObjectsFromArray:@[ SRGPlaylistUidWatchLater ]], [NSSet setWithArray:remoteUids]);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)assertRemotePlaylistEntriesUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid
{
    XCTAssertNotNil(self.sessionToken);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist request"];
    
    [[SRGPlaylistsRequest entriesForPlaylistWithUid:playlistUid fromServiceURL:TestPlaylistsServiceURL() forSessionToken:self.identityService.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSArray<NSDictionary *> * _Nullable playlistEntryDictionaries, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        NSArray<NSString *> *remoteUids = [playlistEntryDictionaries valueForKeyPath:@"itemId"];
        XCTAssertEqualObjects([NSSet setWithArray:uids], [NSSet setWithArray:remoteUids]);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
}

#pragma mark Playlist local data management

- (void)insertLocalPlaylistWithUid:(NSString *)uid
{
    XCTAssertNotNil(self.userData);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Local insertion"];
    
    NSString *name = [NSString stringWithFormat:@"%@ (local)", uid];
    [self.userData.playlists savePlaylistWithName:name uid:uid completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:NULL];
}

- (void)insertLocalPlaylistEntriesWithUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid
{
    XCTAssertNotNil(self.userData);
    
    for (NSString *uid in uids) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"Local insertion"];
        
        [self.userData.playlists savePlaylistEntryWithUid:uid inPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:100. handler:NULL];
}

- (void)discardLocalPlaylistsWithUids:(NSArray<NSString *> *)uids
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Local deletion"];
    
    [self.userData.playlists discardPlaylistsWithUids:uids completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)discardLocalPlaylistEntriesWithUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Local deletion"];
    
    [self.userData.playlists discardPlaylistEntriesWithUids:uids fromPlaylistWithUid:playlistUid completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)assertLocalPlaylistUids:(NSArray<NSString *> *)uids
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylist.new, discarded)];
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:nil];
    NSArray<NSString *> *localUids = [playlists valueForKeyPath:@keypath(SRGPlaylist.new, uid)];
    XCTAssertEqualObjects([[NSSet setWithArray:uids] setByAddingObjectsFromArray:@[ SRGPlaylistUidWatchLater ]], [NSSet setWithArray:localUids]);
}

- (void)assertLocalPlaylistEntriesUids:(NSArray<NSString *> *)uids forPlaylistWithUid:(NSString *)playlistUid
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylistEntry.new, discarded)];
    NSArray<SRGPlaylistEntry *> *playlistEntries = [self.userData.playlists playlistEntriesInPlaylistWithUid:playlistUid matchingPredicate:predicate sortedWithDescriptors:nil];
    NSArray<NSString *> *localUids = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
    XCTAssertEqualObjects([NSSet setWithArray:uids], [NSSet setWithArray:localUids]);
}

#pragma mark Preferences remote data management

- (void)insertRemotePreferenceWithObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain
{
    XCTAssertNotNil(self.sessionToken);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Preferences request"];
    
    [[SRGPreferencesRequest putPreferenceWithObject:object atPath:path inDomain:domain toServiceURL:TestPreferencesServiceURL() forSessionToken:self.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)discardRemotePreferenceAtPath:(NSString *)path inDomain:(NSString *)domain
{
    XCTAssertNotNil(self.sessionToken);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Preferences request"];
    
    [[SRGPreferencesRequest deletePreferenceAtPath:path inDomain:domain fromServiceURL:TestPreferencesServiceURL() forSessionToken:self.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)assertRemotePreferences:(NSDictionary *)dictionary inDomain:(NSString *)domain
{
    XCTAssertNotNil(self.sessionToken);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Preferences request"];
    
    [[SRGPreferencesRequest preferencesAtPath:nil inDomain:domain fromServiceURL:TestPreferencesServiceURL() forSessionToken:self.sessionToken withSession:NSURLSession.sharedSession completionBlock:^(NSDictionary * _Nullable preferencesDictionary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        XCTAssertEqualObjects(dictionary, preferencesDictionary);
        [expectation fulfill];
    }] resume];
    
    [self waitForExpectationsWithTimeout:100. handler:nil];
}

#pragma mark Preferences local data management

- (void)insertLocalPreferenceWithObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain
{
    XCTAssertNotNil(self.userData);
    
    [self.userData.preferences setObjectsAtPaths:@{ path : object } inDomain:domain];
}

- (void)discardLocalPreferenceAtPath:(NSString *)path inDomain:(NSString *)domain
{
    [self.userData.preferences removeObjectsAtPaths:@[path] inDomain:domain];
}

- (void)assertLocalPreferences:(NSDictionary *)dictionary inDomain:(NSString *)domain
{
    NSDictionary *preferencesDictionary = [self.userData.preferences dictionaryAtPath:nil inDomain:domain];
    XCTAssertEqualObjects(dictionary, preferencesDictionary);
}

@end
