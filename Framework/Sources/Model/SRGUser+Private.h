//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUser.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Private interface for implementation purposes.
 */
@interface SRGUser (Private)

/**
 *  Return the main user.
 */
+ (nullable SRGUser *)userInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Create or return a main user for update.
 */
+ (SRGUser *)upsertInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

// See `SRGUser.h`
@property (nonatomic, nullable) NSDate *historyLocalSynchronizationDate;
@property (nonatomic, nullable) NSDate *historyServerSynchronizationDate;

/**
 *  Bind a user to a given account.
 */
- (void)attachToAccountUid:(NSString *)accountUid;

/**
 *  Detach the user from its current account, if any.
 */
- (void)detach;

@end

NS_ASSUME_NONNULL_END
