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
 *  The (device) date at which the history was synchronized for the last time. Can be
 *  used for information purposes.
 *
 *  @discussion `nil` if no user is logged (no synchronization).
 */
@property (nonatomic, nullable) NSDate *historyLocalSynchronizationDate;

/**
 *  Server date at which the history was synchronized for the last time.
 *
 *  @discussion `nil` if no user is logged (no synchronization).
 */
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
