//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGDataStore.h"

@interface SRGDataStore ()

@property (nonatomic) id<SRGPersistentContainer> persistentContainer;

@property (nonatomic) NSOperationQueue *serialOperationQueue;
@property (nonatomic) NSMapTable<NSString *, NSOperation *> *operations;

@property (nonatomic) dispatch_queue_t concurrentQueue;

@end

@implementation SRGDataStore

#pragma mark Object lifecycle

- (instancetype)initWithPersistentContainer:(id<SRGPersistentContainer>)persistentContainer
{
    if (self = [super init]) {
        // The main context is for reads only. We must therefore always match what has been persisted to the store,
        // thus discarding in-memory versions when background contexts are saved and automatically merged.
        NSManagedObjectContext *viewContext = persistentContainer.viewContext;
        if (@available(iOS 10, *)) {
            viewContext.automaticallyMergesChangesFromParent = YES;
        }
        viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;
        viewContext.undoManager = nil;
        
        self.persistentContainer = persistentContainer;
        
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
        
        // We don't want to provide a way for a task block being executed to know its operation was cancelled (unlike
        // `NSOperation`s whose subclasses can periodically check for cancellation). This would create additional
        // complexity and not make sense anyway, as tasks should be individually small.
        [managedObjectContext performBlockAndWait:^{
            result = task(managedObjectContext);
            [self.operations removeObjectForKey:handle];
        }];
        
        if (! operation.cancelled) {
            completionBlock ? completionBlock(result) : nil;
        }
    }];
    operation.queuePriority = priority;
    
    dispatch_barrier_async(self.concurrentQueue, ^{
        [self.operations setObject:operation forKey:handle];
        [self.serialOperationQueue addOperation:operation];
    });
    
    return handle;
}

- (NSString *)performBackgroundWriteTask:(void (^)(NSManagedObjectContext *managedObjectContext))task
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
        
        __block NSError *error = nil;
        
        [managedObjectContext performBlockAndWait:^{
            task(managedObjectContext);
            
            if (managedObjectContext.hasChanges) {
                if (operation.cancelled) {
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
        
        if (! operation.cancelled) {
            completionBlock ? completionBlock(error) : nil;
        }
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

@end
