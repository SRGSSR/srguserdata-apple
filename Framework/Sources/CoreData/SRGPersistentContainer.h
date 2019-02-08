//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Persistent container compatibility protocol.
 */
@protocol SRGPersistentContainer <NSObject>

/**
 *  Load the associated store, calling the provided handler on completion.
 */
- (void)srg_loadPersistentStoreWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler;

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

/**
 *  Compatibility layer with `NSPersistentContainer`.
 */
@interface NSPersistentContainer (SRGPersistentContainerCompatibility) <SRGPersistentContainer>

@end

NS_ASSUME_NONNULL_END
