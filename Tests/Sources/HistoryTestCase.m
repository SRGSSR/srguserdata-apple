//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <XCTest/XCTest.h>

#import <SRGUserData/SRGUserData.h>

@interface SRGHistoryTestCase : XCTestCase

@property (nonatomic) SRGUserData *userData;

@end

@implementation SRGHistoryTestCase

#pragma mark Setup and tear down

- (void)setUp
{
    NSString *libraryDirectory = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSURL *fileURL = [[[NSURL fileURLWithPath:libraryDirectory] URLByAppendingPathComponent:self.name] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithIdentityService:nil historyServiceURL:nil storeFileURL:fileURL];
}

- (void)tearDown
{
    self.userData = nil;
    
    NSString *libraryDirectory = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSURL *fileURL = [[[NSURL fileURLWithPath:libraryDirectory] URLByAppendingPathComponent:self.name] URLByAppendingPathExtension:@"sqlite"];
    [NSFileManager.defaultManager removeItemAtURL:fileURL error:NULL];
}

#pragma mark Tests

- (void)testEmptyHistoryInitialization
{
    XCTAssertNotNil(self.userData.history);
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries.count, 0);
}

- (void)testHistorySaveHistoryEntry
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    ;
    NSString *deviceUid = @"Test device";
    
    [self expectationForNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryUidsKey];
        return [uids containsObject:uid];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
        
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntryWithUid
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    ;
    NSString *deviceUid = @"Test device";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    SRGHistoryEntry *historyEntry = [self.userData.history historyEntryWithUid:uid];
    
    XCTAssertEqualObjects(historyEntry.uid, uid);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, time));
    XCTAssertEqualObjects(historyEntry.deviceUid, deviceUid);
}

- (void)testHistoryEntryWithUidAsynchronously
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    ;
    NSString *deviceUid = @"Test device";
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntryWithUid:uid completionBlock:^(SRGHistoryEntry * _Nullable historyEntry) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqualObjects(historyEntry.uid, uid);
        XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, time));
        XCTAssertEqualObjects(historyEntry.deviceUid, deviceUid);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntriesMatchingEmptyPredicateEmptySortedhDescriptor
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    ;
    NSString *deviceUid = @"Test device";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries.count, 1);
    
    SRGHistoryEntry *historyEntry = historyEntries.firstObject;
    
    XCTAssertEqualObjects(historyEntry.uid, uid);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, time));
    XCTAssertEqualObjects(historyEntry.deviceUid, deviceUid);
}

@end
