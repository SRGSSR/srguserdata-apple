//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <XCTest/XCTest.h>

#import <libextobjc/libextobjc.h>
#import <SRGUserData/SRGUserData.h>

@interface DataStoreTestCase : XCTestCase

@end

@implementation DataStoreTestCase

- (void)testMigrationFromV1
{
    NSString *libraryDirectory = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *name = @"UserData-test";
    
    for (NSString *extension in @[ @"sqlite", @"sqlite-shm", @"sqlite-wal"]) {
        NSString *sqliteFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:extension inDirectory:@"Play_DB_v1"];
        NSURL *sqliteFileURL = [NSURL fileURLWithPath:sqliteFilePath];
        NSURL *sqliteDestinationFileURL = [[[NSURL fileURLWithPath:libraryDirectory] URLByAppendingPathComponent:name] URLByAppendingPathExtension:extension];
        [[NSFileManager defaultManager] removeItemAtURL:sqliteDestinationFileURL error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:sqliteFileURL toURL:sqliteDestinationFileURL error:nil];
    }
    
    NSURL *fileURL = [[[NSURL fileURLWithPath:libraryDirectory] URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"sqlite"];
    SRGUserData *userData = [[SRGUserData alloc] initWithIdentityService:nil
                                                       historyServiceURL:[NSURL URLWithString:@"https://history.rts.ch"]
                                                            storeFileURL:fileURL];
    
    // History property is loaded asynchronously
    [self keyValueObservingExpectationForObject:userData keyPath:@keypath(SRGUserData.new, history) handler:^BOOL(SRGUserData * _Nonnull userData, NSDictionary * _Nonnull change) {
        return (userData.history != nil);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *URN = @"urn:rts:video:10085364";
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGHistoryEntry.new, uid), URN];
    SRGHistoryEntry *historyEntry = [userData.history historyEntriesMatchingPredicate:predicate3 sortedWithDescriptors:nil].firstObject;
    
    XCTAssertNotNil(historyEntry);
    XCTAssertTrue(CMTimeCompare(historyEntry.lastPlaybackTime, kCMTimeZero) != 0);
    XCTAssertNotNil([historyEntry valueForKey:@"discarded"]);
    XCTAssertNotNil([historyEntry valueForKey:@"deviceUid"]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNotNil([user valueForKey:@"historyLocalSynchronizationDate"]);
    XCTAssertNotNil([user valueForKey:@"historyServerSynchronizationDate"]);
    XCTAssertNil([user valueForKey:@"accountUid"]);
}

- (void)testMigrationFromV2
{
    NSString *libraryDirectory = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *name = @"UserData-test";
    
    for (NSString *extension in @[ @"sqlite", @"sqlite-shm", @"sqlite-wal"]) {
        NSString *sqliteFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:extension inDirectory:@"Play_DB_v2"];
        NSURL *sqliteFileURL = [NSURL fileURLWithPath:sqliteFilePath];
        NSURL *sqliteDestinationFileURL = [[[NSURL fileURLWithPath:libraryDirectory] URLByAppendingPathComponent:name] URLByAppendingPathExtension:extension];
        [[NSFileManager defaultManager] removeItemAtURL:sqliteDestinationFileURL error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:sqliteFileURL toURL:sqliteDestinationFileURL error:nil];
    }
    
    NSURL *fileURL = [[[NSURL fileURLWithPath:libraryDirectory] URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"sqlite"];
    SRGUserData *userData = [[SRGUserData alloc] initWithIdentityService:nil
                                                       historyServiceURL:[NSURL URLWithString:@"https://history.rts.ch"]
                                                            storeFileURL:fileURL];
    
    // History property is loaded asynchronously
    [self keyValueObservingExpectationForObject:userData keyPath:@keypath(SRGUserData.new, history) handler:^BOOL(SRGUserData * _Nonnull userData, NSDictionary * _Nonnull change) {
        return (userData.history != nil);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *URN = @"urn:rts:video:10085364";
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGHistoryEntry.new, uid), URN];
    SRGHistoryEntry *historyEntry = [userData.history historyEntriesMatchingPredicate:predicate3 sortedWithDescriptors:nil].firstObject;
    
    XCTAssertNotNil(historyEntry);
    XCTAssertTrue(CMTimeCompare(historyEntry.lastPlaybackTime, kCMTimeZero) != 0);
    XCTAssertNotNil([historyEntry valueForKey:@"discarded"]);
    XCTAssertNotNil([historyEntry valueForKey:@"deviceUid"]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNotNil([user valueForKey:@"historyLocalSynchronizationDate"]);
    XCTAssertNotNil([user valueForKey:@"historyServerSynchronizationDate"]);
    XCTAssertNotNil([user valueForKey:@"accountUid"]);
}

@end
