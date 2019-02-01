//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

API_DEPRECATED_WITH_REPLACEMENT("Use NSPersistentContainer instead", ios(9.0, 10.0))
@interface SRGModelManager : NSObject

- (instancetype)initWithName:(NSString *)name directory:(NSString *)directory model:(NSManagedObjectModel *)model;

@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly) NSManagedObjectContext *backgroundManagedObjectContext;

@end

NS_ASSUME_NONNULL_END
