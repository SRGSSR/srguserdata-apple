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
    SRGDataStore *dataStore = [[SRGDataStore alloc] initWithFileURL:storeFileURL model:model];
    XCTAssertNotNil(dataStore);
    return dataStore;
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

- (void)testCreationFailureFromExistingFile
{
    
}

- (void)testMainThreadReadTask
{
    
}

- (void)testBackgroundReadTask
{
    
}

- (void)testBackgroundWriteTask
{
    SRGDataStore *dataStore = [self testDataStoreFromPackage:nil];
    
    [dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(Person.class) inManagedObjectContext:managedObjectContext];
        person.name = @"Boris";
        return YES;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:nil];
}

- (void)testTaskOrder
{
    
}

- (void)testTaskCancellation
{
    
}

- (void)testHeavyActivity
{
    
}

@end
