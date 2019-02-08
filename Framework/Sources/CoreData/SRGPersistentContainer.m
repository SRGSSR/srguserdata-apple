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
        
        self.shouldMigrateStoreAutomatically = YES;
        self.shouldInferMappingModelAutomatically = YES;
        
        NSAssert(NSThread.isMainThread, @"Must be instantiated from the main thread");
        self.viewContext = [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return self;
}

- (void)loadPersistentStoreWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    NSAssert(NSThread.isMainThread, @"Must be instantiated from the main thread");

    if (self.persistentStoreCoordinator.persistentStores.count == 0) {
        NSError *error = nil;
        NSPersistentStore *persistentStore = [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                           configuration:nil
                                                                                                     URL:self.fileURL
                                                                                                 options:@{ NSMigratePersistentStoresAutomaticallyOption : @(self.shouldMigrateStoreAutomatically),
                                                                                                            NSInferMappingModelAutomaticallyOption : @(self.shouldInferMappingModelAutomatically) }
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

#pragma mark Helpers

- (NSManagedObjectContext *)managedObjectContextForPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator;
    return managedObjectContext;
}

- (NSManagedObjectContext *)backgroundManagedObjectContext
{
    return (self.viewContext) ? [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator] : nil;
}

@end
