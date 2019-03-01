//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Person.h"
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

- (void)testSuccessfulDataStoreCreation
{
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    XCTAssertNotNil(dataStore);
}

- (void)testSuccessfulDataStoreCreationFromExistingFile
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
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id  _Nullable result, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertTrue([result isKindOfClass:Person.class]);
        XCTAssertNil(error);
        
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

- (void)testTaskOrderWithSamePriorities
{
    // Only a single expectation is required to wait for the last operation to finish (tasks are serialized).
    // occur in sequence.
    XCTestExpectation *expectation = [self expectationWithDescription:@"All operations finished"];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSArray<Person *> * _Nullable persons, NSError * _Nullable error) {
        XCTAssertEqual(persons.count, 0);
        XCTAssertNil(error);
    }];
    
    [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        person.name = @"Kate";
    } withPriority:NSOperationQueuePriorityNormal completionBlock:nil];
    
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSArray<Person *> * _Nullable persons, NSError * _Nullable error) {
        XCTAssertEqual(persons.count, 1);
        XCTAssertNil(error);
    }];
    
    [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        person.name = @"Jade";
    } withPriority:NSOperationQueuePriorityNormal completionBlock:nil];
    
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSArray<Person *> * _Nullable persons, NSError * _Nullable error) {
        XCTAssertEqual(persons.count, 2);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
}

- (void)testTaskOrderWithVariousPriorities
{
    // Only a single expectation is required to wait for the last operation to finish (tasks are serialized).
    XCTestExpectation *expectation = [self expectationWithDescription:@"All operations finished"];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSArray<Person *> * _Nullable persons, NSError * _Nullable error) {
        XCTAssertEqual(persons.count, 0);
        XCTAssertNil(error);
    }];
    
    [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        person.name = @"Maddie";
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:nil];
    
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSArray<Person *> * _Nullable persons, NSError * _Nullable error) {
        XCTAssertEqual(persons.count, 2);
        XCTAssertNil(error);
    }];
    
    [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        person.name = @"Joe";
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:nil];
    
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSArray<Person *> * _Nullable persons, NSError * _Nullable error) {
        XCTAssertEqual(persons.count, 2);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
}

- (void)testBackgroundReadTaskCancellation
{
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Task 1 finished"];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:@"TestData_1"];
    
    NSString *readTask1 = [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation1 fulfill];
    }];
    [dataStore cancelBackgroundTaskWithHandle:readTask1];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Task 2 finished"];
    
    NSString *readTask2 = [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation2 fulfill];
    }];
    [dataStore cancelBackgroundTaskWithHandle:readTask2];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Task 3 finished"];
    
    NSString *readTask3 = [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation3 fulfill];
    }];
    [dataStore cancelBackgroundTaskWithHandle:readTask3];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testBackgroundWriteTaskCancellation
{
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Task 1 finished"];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    
    NSString *writeTask1 = [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        person.name = @"Eva";
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation1 fulfill];
    }];
    [dataStore cancelBackgroundTaskWithHandle:writeTask1];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Task 2 finished"];
    
    NSString *writeTask2 = [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        person.name = @"Jim";
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation2 fulfill];
    }];
    [dataStore cancelBackgroundTaskWithHandle:writeTask2];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Task 3 finished"];
    
    NSString *writeTask3 = [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        person.name = @"Clara";
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation3 fulfill];
    }];
    [dataStore cancelBackgroundTaskWithHandle:writeTask3];
    
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"Task 4 finished"];
    
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSArray<Person *> * _Nullable persons, NSError * _Nullable error) {
        XCTAssertEqual(persons.count, 0);
        XCTAssertNil(error);
        [expectation4 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testBackgroundWriteTaskFailure
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Write finished"];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    
    [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        __unused Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        // No name provided. Entry won't pass validation (see Person.m)
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        XCTAssertEqual(error.domain, @"ch.srgssr.userdata-tests.validation");
        XCTAssertEqual(error.code, 1012);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testGlobalCancellation
{
    [self expectationForElapsedTimeInterval:3. withHandler:nil];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:@"TestData_1"];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Task 1 finished"];
    
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation1 fulfill];
    }];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Task 2 finished"];
    
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation2 fulfill];
    }];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Task 3 finished"];
    
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        XCTAssertFalse(NSThread.isMainThread);
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL].firstObject;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(id _Nullable result, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation3 fulfill];
    }];
    
    [dataStore cancelAllBackgroundTasks];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
}

- (void)testHeavyWriteActivity
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"All operations finished"];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    
    for (NSInteger i = 0; i < 1000; ++i) {
        [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
            Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
            person.name = @(i).stringValue;
        } withPriority:NSOperationQueuePriorityNormal completionBlock:nil];
    }
    
    [dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSArray<Person *> * _Nullable persons, NSError * _Nullable error) {
        XCTAssertEqual(persons.count, 1000);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
}

- (void)testParallelMainThreadReads
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"All operations finished"];
    
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    
    for (NSInteger i = 0; i < 1000; ++i) {
        [dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
            Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
            person.name = @(i).stringValue;
        } withPriority:NSOperationQueuePriorityNormal completionBlock:nil];
    }
    
    while (1) {
        NSArray<Person *> *persons = [dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
            return [managedObjectContext executeFetchRequest:[Person fetchRequest] error:NULL];
        }];
        if (persons.count == 1000) {
            [expectation fulfill];
            break;
        }
    }
    
    [self waitForExpectationsWithTimeout:20. handler:nil];
}

@end
