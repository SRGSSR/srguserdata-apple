//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import CoreData;
@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Persistent container compatibility protocol.
 */
@protocol SRGPersistentContainer <NSObject>

/**
 *  Load the associated store, calling the provided handler on completion.
 */
- (void)srg_loadPersistentStoreWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;

/**
 *  The file URL where the persistent container stores its data.
 */
@property (nonatomic, readonly) NSURL *srg_fileURL;

/**
 *  Main thread context.
 */
@property (nonatomic, readonly, nullable) NSManagedObjectContext *viewContext;

/**
 *  New background context
 */
- (NSManagedObjectContext *)newBackgroundContext NS_RETURNS_RETAINED;

@end

/**
 *  A lightweight `NSPersistentContainer` replacement for iOS 9.
 */
API_DEPRECATED_WITH_REPLACEMENT("Use NSPersistentContainer instead", ios(9.0, 10.0))
@interface SRGPersistentContainer : NSObject <SRGPersistentContainer>

/**
 *  Create an SQLite datastore saved at the specified location, and governed by the model as parameter.
 */
- (instancetype)initWithFileURL:(NSURL *)fileURL model:(NSManagedObjectModel *)model;

@end

NS_ASSUME_NONNULL_END
