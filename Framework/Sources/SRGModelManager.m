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

- (instancetype)initWithModelFileName:(NSString *)modelFileName
                             inBundle:(NSBundle *)bundle
                   withStoreDirectory:(NSString *)storeDirectory
{
    NSParameterAssert(modelFileName);
    NSParameterAssert(storeDirectory);
    
    if (self = [super init]) {
        self.managedObjectModel = [self managedObjectModelFromModelFileName:modelFileName inBundle:bundle];
        if (! self.managedObjectModel) {
            return nil;
        }
        
        self.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        
        NSString *storeFilePath = [[storeDirectory stringByAppendingPathComponent:modelFileName] stringByAppendingPathExtension:@"sqlite"];
        NSPersistentStore *persistentStore = [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                   configuration:nil
                                                                                             URL:[NSURL fileURLWithPath:storeFilePath]
                                                                                                 options:@{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                                                                                                            NSInferMappingModelAutomaticallyOption : @"YES" }
                                                                                           error:NULL];
        if (! persistentStore) {
            return nil;
        }
        
        self.managedObjectContext = [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator];
        if (! self.managedObjectContext) {
            return nil;
        }
    }
    return self;
}

#pragma mark Helpers

- (NSManagedObjectModel *)managedObjectModelFromModelFileName:(NSString *)modelFileName inBundle:(NSBundle *)bundle
{
    if (! bundle) {
        bundle = [NSBundle mainBundle];
    }
    
    NSString *modelFilePath = [bundle pathForResource:modelFileName ofType:@"momd"];
    if (! modelFilePath) {
        return nil;
    }
    
    NSURL *modelFileURL = [NSURL fileURLWithPath:modelFilePath];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:modelFileURL];
}

- (NSManagedObjectContext *)managedObjectContextForPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator;
    
    return managedObjectContext;
}

#pragma mark Duplication

- (SRGModelManager *)duplicate
{
    // Duplicate the context, the rest is the same
    SRGModelManager *modelManager = [[[self class] alloc] init];
    modelManager.managedObjectContext = [self managedObjectContextForPersistentStoreCoordinator:self.persistentStoreCoordinator];
    modelManager.managedObjectModel = self.managedObjectModel;
    modelManager.persistentStoreCoordinator = self.persistentStoreCoordinator;
    
    return modelManager;
}

@end
