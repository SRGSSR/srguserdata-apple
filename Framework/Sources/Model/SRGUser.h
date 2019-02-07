//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Local user information.
 */
@interface SRGUser : NSManagedObject

/**
 *  The unique identifier of the associated remote account, `nil` if the user is not logged in.
 */
@property (nonatomic, readonly, copy, nullable) NSString *accountUid;

/**
 *  The (device) date at which the history was synchronized for the last time. Can be
 *  used for information purposes.
 *
 *  @discussion `nil` if the user is not logged in.
 */
@property (nonatomic, readonly, nullable) NSDate *historyLocalSynchronizationDate;

@end

NS_ASSUME_NONNULL_END
