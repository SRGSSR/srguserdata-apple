//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPersistentContainer.h"

NS_ASSUME_NONNULL_BEGIN

// Block signatures
typedef void (^SRGDataStoreReadCompletionBlock)(id _Nullable result, NSError * _Nullable error);
typedef void (^SRGDataStoreWriteCompletionBlock)(NSError * _Nullable error);

/**
 *  An SQLite data store which ensures safe accesses to the application Core Data layer. In particular, work can be
 *  performed on or off the main thread, without context merging issues. This is achieved by having a single serialized
 *  worker queue process reads and writes in background, while only reads can be performed from the main thread. This
 *  avoids Core Data transaction overlaps (transactions are performed one after the other) and the usual problems related
 *  with context merging.
 *
 *  You should use asynchronous methods when possible. If you want a read to be performed at the same time background
 *  operations are made, you can perform a synchronous read from the main thread. This avoids using a background read
 *  which would have to wait until pending background operations before it have been processed.
 *
 *  Background tasks can be prioritized, but for this mechanism to work efficiently each submitted task should be short
 *  enough so that the worker queue can move on to pending items fast. Tasks submitted to the main thread should also
 *  be lightweight enough to avoid blocking the user interface.
 *
 *  Credits: The strategy implemented by this class was inspired by the following talk: https://vimeo.com/89370886.
 */
@interface SRGDataStore : NSObject

/**
 *  Create an SQLite datastore from the specified persistent container.
 */
- (instancetype)initWithPersistentContainer:(id<SRGPersistentContainer>)persistentContainer;

/**
 *  The persistent container used by the data store.
 */
@property (nonatomic, readonly) id<SRGPersistentContainer> persistentContainer;

/**
 *  Perform a read operation on the main thread. The read should be efficient since slow operations might block the main
 *  thread while performed.
 *
 *  @parameter task The read task to be executed. The main context is provided, on which Core Data operations must be
 *                  performed. A single result can be returned from the task block and will be returned by the method.
 *
 *  @return id The result of the read (e.g. a single object or an array of objects, managed or not). Returned managed
 *             object(s), if any, can be safely used from the calling code, provided its execution remains on the main
 *             thread.
 *
 *  @discussion This method must only be called from the main thread.
 */
- (nullable id)performMainThreadReadTask:(id _Nullable (NS_NOESCAPE ^)(NSManagedObjectContext *managedObjectContext))task;

/**
 *  Enqueue a read operation on the serial queue, with a priority level. Pending tasks with higher priority will be moved
 *  to the front and executed first. The mandatory completion block will be called on completion.
 *
 *  @parameter task             The read task to be executed. The background context is provided, on which Core Data
 *                              operations must be performed. A single result can be returned from the task block and
 *                              will be forwarded to the provided completion block.
 *  @parameter priority         The priority to apply.
 *  @parameter completionBlock  The block to be called on completion. The block is part of the task itself and should
 *                              therefore be lightweight (otherwise use GCD to send time-consuming operations on another
 *                              thread). Beware that if managed objects are returned, they can only be used from within
 *                              the block associated thread, not on another thread you would dispatch work onto.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error.
 *
 *  @discussion This method can be called from any thread.
 */
- (NSString *)performBackgroundReadTask:(id _Nullable (^)(NSManagedObjectContext *managedObjectContext))task
                           withPriority:(NSOperationQueuePriority)priority
                        completionBlock:(SRGDataStoreReadCompletionBlock)completionBlock;

/**
 *  Enqueue a write operation on the serial queue, with a priority level. Pending tasks with higher priority will be
 *  moved to the front and executed first. The optional completion block will be called on completion.
 *
 *  @parameter task             The write task to be executed. The background context is provided, on which Core Data
 *                              operations must be performed. A single success boolean must be returned from the task
 *                              block (failed tasks will be rollbacked).
 *  @parameter priority         The priority to apply.
 *  @parameter completionBlock  The block to be called on completion. The block is part of the task itself and should
 *                              therefore be lightweight, otherwise use GCD to send time-consuming operations on another
 *                              thread.
 *
 *  @return `NSString` An opaque task handle which can be used to cancel it. For cancelled tasks, the completion block
 *                     will be called with an error and the corresponding transaction rollbacked.
 *
 *  @discussion Once the task successfully completes, a save is automaticaly performed. If the save operation fails (e.g.
 *              because of model validation errors), the work is rollbacked automatically and the completion block is
 *              called with corresponding error information.
 *
 *              This method can be called from any thread.
 */
- (NSString *)performBackgroundWriteTask:(void (^)(NSManagedObjectContext *managedObjectContext))task
                            withPriority:(NSOperationQueuePriority)priority
                         completionBlock:(nullable SRGDataStoreWriteCompletionBlock)completionBlock;

/**
 *  Cancel the task with the provided handle, whether it is being executed or pending. A task being executed will not
 *  be interrupted, rather cancelled and rollbacked when ending. A pending task is simply discarded. If the handle is
 *  invalid or if the task has already been executed, the method does nothing.
 */
- (void)cancelBackgroundTaskWithHandle:(NSString *)handle;

/**
 *  Cancel all tasks being executed or pending. Tasks being executed will not be interrupted, rather cancelled and
 *  rollbacked when ending. Pending tasks are simply discarded.
 */
- (void)cancelAllBackgroundTasks;

@end

NS_ASSUME_NONNULL_END
