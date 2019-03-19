//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPersistentContainer.h"

@interface SRGPersistentContainer ()

@property (nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic) NSURL *fileURL;
@property (nonatomic) NSManagedObjectContext *viewContext;

@end

@implementation SRGPersistentContainer

#pragma mark Object creation and destruction

- (instancetype)initWithFileURL:(NSURL *)fileURL model:(NSManagedObjectModel *)model
{
    if (self = [super init]) {
        self.fileURL = fileURL;
        self.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        
        NSAssert(NSThread.isMainThread, @"Must be instantiated from the main thread");
        self.viewContext = [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return self;
}

#pragma mark SRGPersistentContainer protocol

- (void)srg_loadPersistentStoreWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    NSAssert(NSThread.isMainThread, @"Must be instantiated from the main thread");

    if (self.persistentStoreCoordinator.persistentStores.count == 0) {
        NSError *error = nil;
        NSPersistentStore *persistentStore = [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                           configuration:nil
                                                                                                     URL:self.fileURL
                                                                                                 options:@{ NSMigratePersistentStoresAutomaticallyOption : @NO,
                                                                                                            NSInferMappingModelAutomaticallyOption : @NO }
                                                                                                   error:&error];
        if (persistentStore) {
            self.viewContext = [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator];
            completionHandler(nil);
        }
        else {
           completionHandler(error);
        }
    }
}

- (NSManagedObjectContext *)newBackgroundContext
{
    return [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator];
}

#pragma mark Helpers

- (NSManagedObjectContext *)managedObjectContextForPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator;
    return managedObjectContext;
}

@end

@implementation NSPersistentContainer (SRGPersistentContainerCompatibility)

- (void)srg_loadPersistentStoreWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    [self loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription * _Nonnull persistentStoreDescription, NSError * _Nullable error) {
        completionHandler(error);
    }];
}

@end
