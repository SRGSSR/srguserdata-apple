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
        SRGHistoryEntry *historyEntry1 = [SRGHistoryEntry objectWithUid:@"123456" inManagedObjectContext:viewContext];
        XCTAssertNil(historyEntry1);
        
        // Exists
        SRGHistoryEntry *historyEntry2 = [SRGHistoryEntry upsertWithUid:@"urn:rts:video:9992865" inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry2.uid, @"urn:rts:video:9992865");
    }];
}

- (void)testUpsert
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        // Does not exist
        SRGHistoryEntry *historyEntry1 = [SRGHistoryEntry upsertWithUid:@"123456" inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry1.uid, @"123456");
        
        // Exists
        SRGHistoryEntry *historyEntry2 = [SRGHistoryEntry upsertWithUid:@"urn:rts:video:9992865" inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(historyEntry2.uid, @"urn:rts:video:9992865");
        
        XCTAssertEqualObjects(viewContext.insertedObjects, [NSSet setWithObject:historyEntry1]);
    }];
}

- (void)testSynchronize
{
    
}

- (void)testDiscardLoggedOutUser
{
    
}

- (void)testDiscardLoggedInUser
{
    id<SRGPersistentContainer> persistentContainer = [self persistentContainerFromPackage:@"UserData_DB_loggedIn"];
    
    NSManagedObjectContext *viewContext = persistentContainer.viewContext;
    [viewContext performBlockAndWait:^{
        // Does not exist
        NSArray<NSString *> *discardedUids1 = [SRGHistoryEntry discardObjectsWithUids:@[@"123456"] inManagedObjectContext:viewContext];
        XCTAssertEqualObjects(discardedUids1, @[]);
        
        // Exist
        NSArray<NSString *> *expectedUids2 = @[@"urn:rts:video:9992865", @"urn:rts:video:9910664"];
        NSArray<NSString *> *discardedUids2 = [SRGHistoryEntry discardObjectsWithUids:@[@"urn:rts:video:9992865", @"urn:rts:video:9910664"] inManagedObjectContext:viewContext];
        XCTAssertEqualObjects([NSSet setWithArray:discardedUids2], [NSSet setWithArray:expectedUids2]);
        
        // Mixed
        NSArray<NSString *> *expectedUids3 = @[@"urn:rts:video:9992229", @"urn:rts:video:9996461"];
        NSArray<NSString *> *discardedUids3 = [SRGHistoryEntry discardObjectsWithUids:@[@"urn:rts:video:9992229", @"45678", @"urn:rts:video:9996461", @"urn:rts:video:9910664"] inManagedObjectContext:viewContext];
        XCTAssertEqualObjects([NSSet setWithArray:discardedUids3], [NSSet setWithArray:expectedUids3]);
    }];
}

- (void)testDeleteAll
{
    
}

@end
