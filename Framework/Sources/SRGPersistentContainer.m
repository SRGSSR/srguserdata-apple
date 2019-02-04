//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPersistentContainer.h"

@interface SRGPersistentContainer ()

@property (nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic) NSManagedObjectContext *viewContext;

@end

@implementation SRGPersistentContainer

#pragma mark Object creation and destruction

- (instancetype)initWithName:(NSString *)name directory:(NSString *)directory model:(NSManagedObjectModel *)model
{
    if (self = [super init]) {
        self.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        
        NSURL *storeURL = [[[NSURL fileURLWithPath:directory] URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"sqlite"];
        NSPersistentStore *persistentStore = [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                           configuration:nil
                                                                                                     URL:storeURL
                                                                                                 options:@{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                                                                                                            NSInferMappingModelAutomaticallyOption : @"YES" }
                                                                                                   error:NULL];
        NSAssert(persistentStore, @"Persistence store could not be created");
        NSAssert(NSThread.isMainThread, @"Must be instantiated from the main thread");
        self.viewContext = [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return self;
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
    return [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator];
}

@end
