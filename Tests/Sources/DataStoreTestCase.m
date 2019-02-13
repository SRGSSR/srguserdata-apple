//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "TestData+CoreDataModel.h"
#import "UserDataBaseTestCase.h"

// Private headers
#import "SRGDataStore.h"

@interface DataStoreTestCase : UserDataBaseTestCase

@end

@implementation DataStoreTestCase

#pragma mark Helpers

- (SRGDataStore *)testDataStoreFromPackage:(NSString *)package
{
    NSString *modelFilePath = [[NSBundle bundleForClass:self.class] pathForResource:@"TestData" ofType:@"momd"];
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
    
    return [[SRGDataStore alloc] initWithPersistentContainer:persistentContainer];
}

#pragma mark Tests

- (void)testSuccessfulCreation
{
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    XCTAssertNotNil(dataStore);
}

- (void)testSuccessfulCreationFromExistingFile
{
    SRGDataStore *dataStore = [self testDataStoreFromPackage:@"TestData_1"];
    XCTAssertNotNil(dataStore);
}

- (void)testMainThreadReadTask
{
    SRGDataStore *dataStore = [self testDataStoreFromPackage:@"TestData_1"];
    NSArray<Person *> *persons = [dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertTrue(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    }];
    XCTAssertEqual(persons.count, 1);
    XCTAssertEqualObjects(persons.firstObject.name, @"Boris");
}

- (void)testBackgroundReadTask
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Read"];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:@"TestData_1"];
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertTrue([result isKindOfClass:Person.class]);
        
        Person *person = result;
        XCTAssertEqualObjects(person.name, @"Boris");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3. handler:nil];
}

- (void)testBackgroundWriteTask
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Write"];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        person.name = @"James";
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3. handler:nil];
    
    NSArray<Person *> *persons = [dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertTrue(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    }];
    XCTAssertEqual(persons.count, 1);
    
    Person *person = persons.firstObject;
    XCTAssertEqualObjects(person.name, @"James");
}

- (void)testTaskOrder
{
    
}

- (void)testBackgroundReadTaskCancellation
{
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:@"TestData_1"];
    
    NSString *readTask1 = [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result) {
        XCTFail(@"Must not be called when a task has been cancelled");
    }];
    [dataStore cancelBackgroundTaskWithHandle:readTask1];
    
    NSString *readTask2 = [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result) {
        XCTFail(@"Must not be called when a task has been cancelled");
    }];
    [dataStore cancelBackgroundTaskWithHandle:readTask2];
    
    NSString *readTask3 = [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result) {
        XCTFail(@"Must not be called when a task has been cancelled");
    }];
    [dataStore cancelBackgroundTaskWithHandle:readTask3];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testReadWriteReadSerialTasks
{
    
}

- (void)testBackgroundWriteTaskCancellation
{
    
}

- (void)testGlobalCancellation
{
    
}

- (void)testCancelExecutedTask
{
    
}

- (void)testHeavyMulutithreadedActivity
{
    
}

- (void)testFromBackgroundThreads
{
    
}

@end
