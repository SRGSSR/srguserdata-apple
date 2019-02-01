//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGModelManager.h"

@interface SRGModelManager ()

@property (nonatomic) NSManagedObjectModel *managedObjectModel;
@property (nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation SRGModelManager

#pragma mark Object creation and destruction

- (instancetype)initWithName:(NSString *)name directory:(NSString *)directory model:(NSManagedObjectModel *)model
{
    if (self = [super init]) {
        self.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        
        NSURL *storeURL = [[[NSURL fileURLWithPath:directory] URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"sqlite"];
        NSPersistentStore *persistentStore = [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                           configuration:nil
                                                                                                     URL:storeURL
                                                                                                 options:@{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                                                                                                            NSInferMappingModelAutomaticallyOption : @"YES" }
                                                                                                   error:NULL];
        NSAssert(persistentStore, @"Persistence store could not be created");
        self.managedObjectContext = [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator];
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
