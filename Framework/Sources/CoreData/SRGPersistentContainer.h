//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  A lightweight `NSPersistentContainer` replacement for iOS 9.
 */
API_DEPRECATED_WITH_REPLACEMENT("Use NSPersistentContainer instead", ios(9.0, 10.0))
@interface SRGPersistentContainer : NSObject

/**
 *  Create an SQLite datastore saved at the specified location, and governed by the model as parameter.
 */
- (instancetype)initWithFileURL:(NSURL *)fileURL model:(NSManagedObjectModel *)model;

/*
 *  Same as `NSPersistentStoreDescription`
 */
@property BOOL shouldMigrateStoreAutomatically;
@property BOOL shouldInferMappingModelAutomatically;

// Load store from the file URL initialisation that have not already been successfully added to the container. The completion handler is called once the store that succeeds or fails.
- (void)loadPersistentStoreWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler;

/**
 *  Contexts.
 *
 *  @discussion : Contexts are created when `loadPersistentStoreWithCompletionHandler:` has been called and returned no error.
 */
@property (nonatomic, readonly, nullable) NSManagedObjectContext *viewContext;
@property (nonatomic, readonly, nullable) NSManagedObjectContext *backgroundManagedObjectContext;

@end

NS_ASSUME_NONNULL_END
