//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SRGPersistentContainer <NSObject>

/**
 * Load store from the file URL initialisation that have not already been successfully added to the container.
 * The completion handler is called once the store that succeeds or fails.
 */
- (void)srg_loadPersistentStoreWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler;

/**
 *  Contexts.
 */
@property (nonatomic, readonly, nullable) NSManagedObjectContext *viewContext;
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
