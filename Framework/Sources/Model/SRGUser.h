//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  User information.
 */
@interface SRGUser : NSManagedObject

/**
 *  The main user of the application.
 */
+ (SRGUser *)mainUserInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@property (nonatomic, readonly, copy, nullable) NSString *accountUid;
@property (nonatomic, readonly, nullable) NSDate *historyLocalSynchronizationDate;

@end

NS_ASSUME_NONNULL_END
