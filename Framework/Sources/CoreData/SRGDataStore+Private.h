//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGDataStore.h"

@interface SRGDataStore (Private)

/**
 *  Create an SQLite datastore saved under the specified name (the .sqlite extension will be automatically appended),
 *  stored in the provided directory, and governed by the model as parameter.
 */
- (instancetype)initWithName:(NSString *)name directory:(NSString *)directory model:(NSManagedObjectModel *)model;

/**
 *  Cancel all tasks being executed or pending. Tasks being executed will not be interrupted, rather cancelled and
 *  rollbacked when ending. Pending tasks are simply discarded.
 */
- (void)cancelAllTasks;

@end
