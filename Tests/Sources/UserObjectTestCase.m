//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

// Private headers
#import "NSBundle+SRGUserData.h"
#import "SRGPersistentContainer.h"
#import "SRGUserObject+Private.h"

#import <libextobjc/libextobjc.h>

@interface UserObjectTestCase : UserDataBaseTestCase

@end

@implementation UserObjectTestCase

#pragma mark Helpers

- (id<SRGPersistentContainer>)persistentContainerFromPackage:(NSString *)package
{
    NSString *modelFilePath = [NSBundle.srg_userDataBundle pathForResource:@"SRGUserData" ofType:@"momd"];
    NSURL *modelFileURL = [NSURL fileURLWithPath:modelFilePath];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelFileURL];
    NSURL *storeFileURL = [self URLForStoreFromPackage:package];
    
    id<SRGPersistentContainer> persistentContainer = nil;
    if (@available(iOS 10, *)) {
        NSPersistentContainer *nativePersistentContainer = [NSPersistentContainer persistentContainerWithName:storeFileURL.lastPathComponent managedObjectModel:model];
        nativePersistentContainer.persistentStoreDescriptions = @[ [NSPersistentStoreDescription persistentStoreDescriptionWithURL:storeFileURL] ];
        persistentContainer = nativePersistentContainer;
    }
    else {
        persistentContainer = [[SRGPersistentContainer alloc] initWithFileURL:storeFileURL model:model];
    }
    
    [persistentContainer srg_loadPersistentStoreWithCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
    
    return persistentContainer;
}

#pragma mark Tests

- (void)testObjectsMatchingPredicate
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        NSArray<SRGHistoryEntry *> *historyEntries1 = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:viewContext];
        XCTAssertEqual(historyEntries1.count, 643);
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == 'iPhone XR'", @keypath(SRGHistoryEntry.new, deviceUid)];
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:YES];
        NSArray<SRGHistoryEntry *> *historyEntries2 = [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:@[sortDescriptor] inManagedObjectContext:viewContext];
        XCTAssertEqual(historyEntries2.count, 67);
    }];
}

- (void)testObjectWithUid
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        // Does not exist
        SRGHistoryEntry *historyEntry1 = [SRGHistoryEntry objectWithUid:@"123456" matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertNil(historyEntry1);
        
        // Exists
        SRGHistoryEntry *historyEntry2 = [SRGHistoryEntry upsertWithUid:@"urn:rts:video:9992865" matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry2.uid, @"urn:rts:video:9992865");
    }];
}

- (void)testUpsert
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        // Does not exist
        SRGHistoryEntry *historyEntry1 = [SRGHistoryEntry upsertWithUid:@"123456" matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry1.uid, @"123456");
        
        // Exists
        SRGHistoryEntry *historyEntry2 = [SRGHistoryEntry upsertWithUid:@"urn:rts:video:9992865" matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry2.uid, @"urn:rts:video:9992865");
    }];
}

- (void)testSynchronizeWithInvalidData
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry synchronizeWithDictionary:@{} matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertNil(historyEntry);
    }];
}

- (void)testSynchronizeNewServerEntry
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry synchronizeWithDictionary:@{ @"item_id" : @"123456",
                                                                                      @"date" : @1550134222000,
                                                                                      @"device_id" : @"other_device" } matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry.uid, @"123456");
        XCTAssertEqualObjects(historyEntry.date, [NSDate dateWithTimeIntervalSince1970:1550134222]);
        XCTAssertEqualObjects(historyEntry.deviceUid, @"other_device");
    }];
}

- (void)testSynchronizeNonDirtyLocalEntry
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry synchronizeWithDictionary:@{ @"item_id" : @"urn:rts:video:9992865",
                                                                                      @"date" : @1550134222000,
                                                                                      @"device_id" : @"other_device" } matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry.uid, @"urn:rts:video:9992865");
        XCTAssertEqualObjects(historyEntry.date, [NSDate dateWithTimeIntervalSince1970:1550134222]);
        XCTAssertEqualObjects(historyEntry.deviceUid, @"other_device");
    }];
}

- (void)testSynchronizeOlderDirtyLocalEntry
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry synchronizeWithDictionary:@{ @"item_id" : @"urn:rts:audio:10110418",
                                                                                      @"date" : @1550134222000,
                                                                                      @"device_id" : @"other_device" } matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry.uid, @"urn:rts:audio:10110418");
        XCTAssertEqualObjects(historyEntry.date, [NSDate dateWithTimeIntervalSince1970:1550134222]);
        XCTAssertEqualObjects(historyEntry.deviceUid, @"other_device");
    }];
}

- (void)testSynchronizeMoreRecentDirtyLocalEntry
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry synchronizeWithDictionary:@{ @"item_id" : @"urn:rts:audio:10110418",
                                                                                      @"date" : @1266137422000,
                                                                                      @"device_id" : @"other_device" } matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry.uid, @"urn:rts:audio:10110418");
        XCTAssertNotEqualObjects(historyEntry.date, [NSDate dateWithTimeIntervalSince1970:1266137422]);
        XCTAssertNotEqualObjects(historyEntry.deviceUid, @"other_device");
    }];
}

- (void)testSynchronizeDeletedEntryExistingLocally
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry synchronizeWithDictionary:@{ @"item_id" : @"urn:rts:video:9992865",
                                                                                      @"date" : @1266137422000,
                                                                                      @"device_id" : @"other_device",
                                                                                      @"deleted" : @YES } matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry.uid, @"urn:rts:video:9992865");
        XCTAssertTrue(historyEntry.deleted);
    }];
}

- (void)testSynchronizeDeletedEntryMoreRecentLocally
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry synchronizeWithDictionary:@{ @"item_id" : @"urn:rts:audio:10110418",
                                                                                      @"date" : @1266137422000,
                                                                                      @"device_id" : @"other_device",
                                                                                      @"deleted" : @YES } matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry.uid, @"urn:rts:audio:10110418");
        XCTAssertNotEqualObjects(historyEntry.date, [NSDate dateWithTimeIntervalSince1970:1266137422]);
        XCTAssertNotEqualObjects(historyEntry.deviceUid, @"other_device");
    }];
}

- (void)testDiscardForLoggedOutUser
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedOut"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        // Does not exist
        NSArray<NSString *> *discardedUids1 = [SRGHistoryEntry discardObjectsWithUids:@[@"123456"] matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(discardedUids1, @[]);
        
        // Exist
        NSArray<NSString *> *expectedUids2 = @[@"urn:rts:video:9992865", @"urn:rts:video:9910664"];
        NSArray<NSString *> *discardedUids2 = [SRGHistoryEntry discardObjectsWithUids:@[@"urn:rts:video:9992865", @"urn:rts:video:9910664"] matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects([NSSet setWithArray:discardedUids2], [NSSet setWithArray:expectedUids2]);
        
        // Objects are immediately erased
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", @keypath(SRGHistoryEntry.new, uid), expectedUids2];
        XCTAssertEqual([SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:viewContext].count, 0);
        
        // Mixed
        NSArray<NSString *> *expectedUids3 = @[@"urn:rts:video:9992229", @"urn:rts:video:9996461"];
        NSArray<NSString *> *discardedUids3 = [SRGHistoryEntry discardObjectsWithUids:@[@"urn:rts:video:9992229", @"45678", @"urn:rts:video:9996461", @"urn:rts:video:9910664"] matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects([NSSet setWithArray:discardedUids3], [NSSet setWithArray:expectedUids3]);
    }];
}

- (void)testDiscardForLoggedInUser
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        // Does not exist
        NSArray<NSString *> *discardedUids1 = [SRGHistoryEntry discardObjectsWithUids:@[@"123456"] matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(discardedUids1, @[]);
        
        // Exist
        NSArray<NSString *> *expectedUids2 = @[@"urn:rts:video:9992865", @"urn:rts:video:9910664"];
        NSArray<NSString *> *discardedUids2 = [SRGHistoryEntry discardObjectsWithUids:@[@"urn:rts:video:9992865", @"urn:rts:video:9910664"] matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects([NSSet setWithArray:discardedUids2], [NSSet setWithArray:expectedUids2]);
        
        // Objects still exist, they are only marked for later synchronization
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", @keypath(SRGHistoryEntry.new, uid), expectedUids2];
        XCTAssertEqual([SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:viewContext].count, 2);
        
        // Mixed
        NSArray<NSString *> *expectedUids3 = @[@"urn:rts:video:9992229", @"urn:rts:video:9996461"];
        NSArray<NSString *> *discardedUids3 = [SRGHistoryEntry discardObjectsWithUids:@[@"urn:rts:video:9992229", @"45678", @"urn:rts:video:9996461"] matchingPredicate:nil inManagedObjectContext:viewContext];
        XCTAssertEqualObjects([NSSet setWithArray:discardedUids3], [NSSet setWithArray:expectedUids3]);
    }];
}

- (void)testDeleteAllForLoggedInUser
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        NSArray<SRGHistoryEntry *> *historyEntries1 = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:viewContext];
        XCTAssertNotEqual(historyEntries1.count, 0);
        
        [SRGHistoryEntry deleteAllInManagedObjectContext:viewContext];
        
        NSArray<SRGHistoryEntry *> *historyEntries2 = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:viewContext];
        XCTAssertEqual(historyEntries2.count, 0);
    }];
}

- (void)testDeleteAllForLoggedOutUser
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedOut"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        NSArray<SRGHistoryEntry *> *historyEntries1 = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:viewContext];
        XCTAssertNotEqual(historyEntries1.count, 0);
        
        [SRGHistoryEntry deleteAllInManagedObjectContext:viewContext];
        
        NSArray<SRGHistoryEntry *> *historyEntries2 = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:viewContext];
        XCTAssertEqual(historyEntries2.count, 0);
    }];
}

@end
