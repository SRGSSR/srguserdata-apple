//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGDataStore.h"

#import "NSBundle+SRGUserData.h"
#import "SRGPersistentContainer.h"
#import "SRGUserDataError.h"
#import "SRGUserDataLogger.h"

#import <objc/runtime.h>

static SRGDataStore *s_sharedDataStore;

static NSUInteger s_currentPersistentStoreVersion = 3;

@interface SRGDataStore ()

@property (nonatomic) NSOperationQueue *serialOperationQueue;
@property (nonatomic) id<SRGPersistentContainer> persistentContainer;

@property (nonatomic) NSMapTable<NSString *, NSOperation *> *operations;

@property (nonatomic) dispatch_queue_t concurrentQueue;

@end

@implementation SRGDataStore

#pragma mark Object lifecycle

- (instancetype)initWithFileURL:(NSURL *)fileURL model:(NSManagedObjectModel *)model
{
    if (self = [super init]) {
        if (@available(iOS 10, *)) {
            NSPersistentContainer *persistentContainer = [NSPersistentContainer persistentContainerWithName:fileURL.lastPathComponent managedObjectModel:model];
            
            NSPersistentStoreDescription *persistentStoreDescription = [NSPersistentStoreDescription persistentStoreDescriptionWithURL:fileURL];
            persistentStoreDescription.shouldInferMappingModelAutomatically = NO;
            persistentStoreDescription.shouldMigrateStoreAutomatically = NO;
            persistentContainer.persistentStoreDescriptions = @[ persistentStoreDescription ];
            
            self.persistentContainer = persistentContainer;
        }
        else {
            self.persistentContainer = [[SRGPersistentContainer alloc] initWithFileURL:fileURL model:model];
        }
        
        [self.persistentContainer srg_loadPersistentStoreWithCompletionHandler:^(NSError * _Nullable error) {
            if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSPersistentStoreIncompatibleVersionHashError) {
                BOOL migrated = [self migratePersistentStoreWithFileURL:fileURL];
                if (migrated) {
                    [self.persistentContainer srg_loadPersistentStoreWithCompletionHandler:^(NSError * _Nullable error) {
                        if (error) {
                            SRGUserDataLogError(@"store", @"Data store failed to load after migration. Reason: %@", error);
                        }
                    }];
                }
                else {
                    SRGUserDataLogError(@"store", @"Data store failed to load and no migration found. Reason: %@", error);
                }
            }
            else if (error) {
                SRGUserDataLogError(@"store", @"Data store failed to load. Reason: %@", error);
            }
        }];
        
        // The main context is for reads only. We must therefore always match what has been persisted to the store,
        // thus discarding in-memory versions when background contexts are saved and automatically merged.
        NSManagedObjectContext *viewContext = self.persistentContainer.viewContext;
        if (@available(iOS 10, *)) {
            viewContext.automaticallyMergesChangesFromParent = YES;
        }
        viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;
        viewContext.undoManager = nil;
        
        self.serialOperationQueue = [[NSOperationQueue alloc] init];
        self.serialOperationQueue.maxConcurrentOperationCount = 1;
        
        self.operations = [NSMapTable strongToWeakObjectsMapTable];
        
        self.concurrentQueue = dispatch_queue_create("ch.srgssr.playsrg.SRGDataStore.concurrent", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

#pragma mark Task execution

- (id)performMainThreadReadTask:(id (NS_NOESCAPE ^)(NSManagedObjectContext *managedObjectContext))task
{
    NSAssert(NSThread.isMainThread, @"Must be called from the main thread only");
    
    NSManagedObjectContext *managedObjectContext = self.persistentContainer.viewContext;
    id result = task(managedObjectContext);
    NSAssert(! managedObjectContext.hasChanges, @"The managed object context must not be altered");
    return result;
}

- (NSString *)performBackgroundReadTask:(id (^)(NSManagedObjectContext *managedObjectContext))task
                           withPriority:(NSOperationQueuePriority)priority
                        completionBlock:(void (^)(id result))completionBlock
{
    NSString *handle = NSUUID.UUID.UUIDString;
    
    __block NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        NSManagedObjectContext *managedObjectContext = self.persistentContainer.newBackgroundContext;
        managedObjectContext.undoManager = nil;
        
        __block id result = nil;
        
        [managedObjectContext performBlockAndWait:^{
            result = task(managedObjectContext);
            [self.operations removeObjectForKey:handle];
        }];
        completionBlock ? completionBlock(result) : nil;
    }];
    operation.queuePriority = priority;
    
    dispatch_barrier_async(self.concurrentQueue, ^{
        [self.operations setObject:operation forKey:handle];
        [self.serialOperationQueue addOperation:operation];
    });
    
    return handle;
}

- (NSString *)performBackgroundWriteTask:(BOOL (^)(NSManagedObjectContext *managedObjectContext))task
                            withPriority:(NSOperationQueuePriority)priority
                         completionBlock:(void (^)(NSError *error))completionBlock;
{
    NSString *handle = NSUUID.UUID.UUIDString;
    
    __block NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        // If clients use the API as expected (i.e. do not perform changes in `-performMainThreadReadTask:`, which should
        // be enforced during development), merging behavior setup is not really required for background contexts, as
        // transactions can never be made in parallel. But if this happens for some reason, ignore those changes and keep
        // the in-memory ones.
        NSManagedObjectContext *managedObjectContext = self.persistentContainer.newBackgroundContext;
        if (@available(iOS 10, *)) {
            managedObjectContext.automaticallyMergesChangesFromParent = YES;
        }
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        managedObjectContext.undoManager = nil;
        
        __block BOOL success = NO;
        __block NSError *error = nil;
        
        [managedObjectContext performBlockAndWait:^{
            success = task(managedObjectContext);
            
            if (managedObjectContext.hasChanges) {
                if (! success) {
                    error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                                code:SRGUserDataErrorFailed
                                            userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataNonLocalizedString(@"The task has failed") }];
                    [managedObjectContext rollback];
                }
                else if (operation.cancelled) {
                    error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                                code:SRGUserDataErrorCancelled
                                            userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataNonLocalizedString(@"The task has been cancelled") }];
                    [managedObjectContext rollback];
                }
                else if (! [managedObjectContext save:&error]) {
                    [managedObjectContext rollback];
                }
            }
            dispatch_barrier_async(self.concurrentQueue, ^{
                [self.operations removeObjectForKey:handle];
            });
        }];
        completionBlock ? completionBlock(error) : nil;
    }];
    operation.queuePriority = priority;
    
    dispatch_barrier_async(self.concurrentQueue, ^{
        [self.operations setObject:operation forKey:handle];
        [self.serialOperationQueue addOperation:operation];
    });
    
    return handle;
}

- (void)cancelBackgroundTaskWithHandle:(NSString *)handle
{
    dispatch_sync(self.concurrentQueue, ^{
        NSOperation *operation = [self.operations objectForKey:handle];
        [operation cancel];
    });
    
    dispatch_barrier_async(self.concurrentQueue, ^{
        // Removal at the end of task execution does not take place for pending tasks. Must remove the entry manually.
        [self.operations removeObjectForKey:handle];
    });
}

- (void)cancelAllBackgroundTasks
{
    dispatch_barrier_async(self.concurrentQueue, ^{
        [self.serialOperationQueue cancelAllOperations];
    
        // Removal at the end of task execution does not take place for pending tasks. Must remove entries manually.
        [self.operations removeAllObjects];
    });
}

#pragma mark Migration

- (BOOL)migratePersistentStoreWithFileURL:(NSURL *)fileURL
{
    NSUInteger fromVersion = s_currentPersistentStoreVersion - 1;
    BOOL migrated = NO;
    while (! migrated && fromVersion > 0) {
        migrated = [self migratePersistentStoreWithFileURL:fileURL fromVersion:fromVersion];
        fromVersion--;
    }
    
    return migrated;
}

- (BOOL)migratePersistentStoreWithFileURL:(NSURL *)fileURL fromVersion:(NSUInteger)fromVersion
{
    NSUInteger toVersion = fromVersion + 1;
    
    NSString *mappingModelFilePath = [NSBundle.srg_userDataBundle pathForResource:[NSString stringWithFormat:@"SRGUserData_v%@_v%@", @(fromVersion), @(toVersion)] ofType:@"cdm"];
    if (! mappingModelFilePath) {
        return NO;
    }
    NSURL *mappingModelFileURL = [NSURL fileURLWithPath:mappingModelFilePath];
    NSMappingModel *mappingModel = [[NSMappingModel alloc] initWithContentsOfURL:mappingModelFileURL];
    
    NSString *sourceModelFilePath = [NSBundle.srg_userDataBundle pathForResource:[NSString stringWithFormat:@"SRGUserData_v%@", @(fromVersion)] ofType:@"mom" inDirectory:@"SRGUserData.momd"];
    if (! sourceModelFilePath) {
        return NO;
    }
    NSURL *sourceModelFileURL = [NSURL fileURLWithPath:sourceModelFilePath];
    NSManagedObjectModel *sourceModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:sourceModelFileURL];
    
    NSString *destinationModelFilePath = [NSBundle.srg_userDataBundle pathForResource:[NSString stringWithFormat:@"SRGUserData_v%@", @(toVersion)] ofType:@"mom" inDirectory:@"SRGUserData.momd"];
    if (! destinationModelFilePath) {
        return NO;
    }
    NSURL *destinationeModelFileURL = [NSURL fileURLWithPath:destinationModelFilePath];
    NSManagedObjectModel *destinationModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:destinationeModelFileURL];
    
    NSString *migratedLastPathComponent = [fileURL.lastPathComponent stringByAppendingString:@"-migrated"];
    NSURL *migratedFileURL = [fileURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:migratedLastPathComponent];
    
    NSMigrationManager *migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel destinationModel:destinationModel];
    BOOL migrated = [migrationManager migrateStoreFromURL:fileURL
                                                     type:NSSQLiteStoreType
                                                  options:nil
                                         withMappingModel:mappingModel
                                         toDestinationURL:migratedFileURL
                                          destinationType:NSSQLiteStoreType
                                       destinationOptions:nil
                                                    error:NULL];
    if (migrated) {
        if (! [NSFileManager.defaultManager replaceItemAtURL:fileURL
                                               withItemAtURL:migratedFileURL
                                              backupItemName:nil
                                                     options:NSFileManagerItemReplacementUsingNewMetadataOnly
                                            resultingItemURL:NULL
                                                       error:NULL]) {
            return NO;
        }
        
        if (toVersion < s_currentPersistentStoreVersion) {
            return [self migratePersistentStoreWithFileURL:fileURL fromVersion:toVersion];
        }
        else {
            return YES;
        }
    }
    else {
        return NO;
    }
}

@end
