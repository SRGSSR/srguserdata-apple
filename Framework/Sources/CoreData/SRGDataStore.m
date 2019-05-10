//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGDataStore.h"

#import "NSBundle+SRGUserData.h"
#import "SRGUserDataLogger.h"
#import "SRGUserDataError.h"

@interface SRGDataStore ()

@property (nonatomic) id<SRGPersistentContainer> persistentContainer;

@property (nonatomic) NSOperationQueue *serialOperationQueue;
@property (nonatomic) NSMapTable<NSString *, NSOperation *> *operations;

@property (nonatomic) NSMapTable<NSString *, SRGDataStoreReadCompletionBlock> *readCompletionBlocks;
@property (nonatomic) NSMapTable<NSString *, SRGDataStoreWriteCompletionBlock> *writeCompletionBlocks;

@property (nonatomic) dispatch_queue_t concurrentQueue;

@end

@implementation SRGDataStore

#pragma mark Object lifecycle

- (instancetype)initWithPersistentContainer:(id<SRGPersistentContainer>)persistentContainer
{
    if (self = [super init]) {
        // The main context is for reads only. A merge policy has to be set (default throws errors), here a meaningful
        // one has been picked (store is the reference). This only merges changes from the store or a parent context
        // (there is no parent - child relationship in this implementation). To merge changes from sibling contexts,
        // we still have to register for NSManagedObjectContextDidSaveNotification.
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
        
        self.readCompletionBlocks = [NSMapTable strongToStrongObjectsMapTable];
        self.writeCompletionBlocks = [NSMapTable strongToStrongObjectsMapTable];
        
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
                        completionBlock:(SRGDataStoreReadCompletionBlock)completionBlock
{
    NSString *handle = NSUUID.UUID.UUIDString;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        NSManagedObjectContext *managedObjectContext = self.persistentContainer.newBackgroundContext;
        managedObjectContext.undoManager = nil;
        
        __block id result = nil;
        
        // We don't want to provide a way for a task block being executed to know its operation was cancelled (unlike
        // `NSOperation`s whose subclasses can periodically check for cancellation). This would create additional
        // complexity and not make sense anyway, as tasks should be individually small.
        [managedObjectContext performBlockAndWait:^{
            result = task(managedObjectContext);
            NSCAssert(! managedObjectContext.hasChanges, @"The managed object context must not be altered");
        }];
        
        __block BOOL cancelled = NO;
        dispatch_sync(self.concurrentQueue, ^{
            NSOperation *operation = [self.operations objectForKey:handle];
            cancelled = operation.cancelled;
        });
        
        if (! cancelled) {
            completionBlock ? completionBlock(result, nil) : nil;
        }
        else {
            NSError *error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                                 code:SRGUserDataErrorCancelled
                                             userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The operation has been cancelled", @"Error message returned when an operation has been cancelled") }];
            completionBlock ? completionBlock(nil, error) : nil;
        }
        
        dispatch_barrier_async(self.concurrentQueue, ^{
            [self.operations removeObjectForKey:handle];
            [self.readCompletionBlocks removeObjectForKey:handle];
        });
    }];
    operation.queuePriority = priority;
    
    dispatch_barrier_async(self.concurrentQueue, ^{
        [self.readCompletionBlocks setObject:completionBlock forKey:handle];
        [self.operations setObject:operation forKey:handle];
        [self.serialOperationQueue addOperation:operation];
    });
    
    return handle;
}

- (NSString *)performBackgroundWriteTask:(void (^)(NSManagedObjectContext *managedObjectContext))task
                            withPriority:(NSOperationQueuePriority)priority
                         completionBlock:(SRGDataStoreWriteCompletionBlock)completionBlock;
{
    NSString *handle = NSUUID.UUID.UUIDString;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        // If clients use the API as expected (i.e. do not perform changes in `-performMainThreadReadTask:`, which should
        // be enforced during development), merging behavior setup is not really required for background contexts, as
        // transactions can never be made in parallel. But if this happens for some reason, provide a meaningful
        // setup (context is the reference).
        NSManagedObjectContext *managedObjectContext = self.persistentContainer.newBackgroundContext;
        if (@available(iOS 10, *)) {
            managedObjectContext.automaticallyMergesChangesFromParent = YES;
        }
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        managedObjectContext.undoManager = nil;
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(backgroundManagedObjectContextDidSave:)
                                                   name:NSManagedObjectContextDidSaveNotification
                                                 object:managedObjectContext];
        
        __block NSError *error = nil;
        __block BOOL cancelled = NO;
        
        dispatch_sync(self.concurrentQueue, ^{
            NSOperation *operation = [self.operations objectForKey:handle];
            cancelled = operation.cancelled;
        });
        
        [managedObjectContext performBlockAndWait:^{
            task(managedObjectContext);
            
            if (managedObjectContext.hasChanges) {
                if (cancelled) {
                    [managedObjectContext rollback];
                }
                else if (! [managedObjectContext save:&error]) {
                    [managedObjectContext rollback];
                }
            }
        }];
        
        if (! cancelled) {
            completionBlock ? completionBlock(error) : nil;
        }
        else {
            NSError *error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                                 code:SRGUserDataErrorCancelled
                                             userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The operation has been cancelled", @"Error message returned when an operation has been cancelled") }];
            completionBlock ? completionBlock(error) : nil;
        }
        
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:NSManagedObjectContextDidSaveNotification
                                                    object:managedObjectContext];
        
        dispatch_barrier_async(self.concurrentQueue, ^{
            [self.operations removeObjectForKey:handle];
            [self.writeCompletionBlocks removeObjectForKey:handle];
        });
    }];
    operation.queuePriority = priority;
    
    dispatch_barrier_async(self.concurrentQueue, ^{
        [self.writeCompletionBlocks setObject:completionBlock forKey:handle];
        [self.operations setObject:operation forKey:handle];
        [self.serialOperationQueue addOperation:operation];
    });
    
    return handle;
}

- (void)cancelBackgroundTaskWithHandle:(NSString *)handle
{
    dispatch_barrier_async(self.concurrentQueue, ^{
        // Removal at the end of task execution does not take place for pending tasks. Must remove the entry manually.
        // Tasks being executed will be cleaned up at the end of their execution
        NSOperation *operation = [self.operations objectForKey:handle];
        [operation cancel];
        
        if (! operation.executing) {
            NSError *error = [NSError errorWithDomain:SRGUserDataErrorDomain
                                                 code:SRGUserDataErrorCancelled
                                             userInfo:@{ NSLocalizedDescriptionKey : SRGUserDataLocalizedString(@"The operation has been cancelled", @"Error message returned when an operation has been cancelled") }];
            SRGDataStoreReadCompletionBlock readCompletionBlock = [self.readCompletionBlocks objectForKey:handle];
            if (readCompletionBlock) {
                readCompletionBlock(nil, error);
                [self.readCompletionBlocks removeObjectForKey:handle];
            }
            else {
                SRGDataStoreWriteCompletionBlock writeCompletionBlock = [self.writeCompletionBlocks objectForKey:handle];
                if (writeCompletionBlock) {
                    writeCompletionBlock(error);
                    [self.writeCompletionBlocks removeObjectForKey:handle];
                }
            }
            
            [self.operations removeObjectForKey:handle];
        }
    });
}

- (void)cancelAllBackgroundTasks
{
    for (NSString *handle in [[self.operations copy] keyEnumerator]) {
        [self cancelBackgroundTaskWithHandle:handle];
    }
}

#pragma mark Notifications

- (void)backgroundManagedObjectContextDidSave:(NSNotification *)notification
{
    NSAssert(! NSThread.isMainThread, @"Saves are only made on background contexts and thus notified on background threads");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSManagedObjectContext *viewContext = self.persistentContainer.viewContext;
        if (notification.object != viewContext) {
            [viewContext mergeChangesFromContextDidSaveNotification:notification];
            
            NSError *error = nil;
            if (! [viewContext save:&error]) {
                SRGUserDataLogError(@"store", @"Could not save merged changes into the main context. Reason: %@", error);
            }
        }
    });
}

@end
