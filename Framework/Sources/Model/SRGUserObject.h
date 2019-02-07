//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Abstract base class for objects supporting synchronization with a remote server.
 */
@interface SRGUserObject : NSManagedObject

/**
 *  The item unique identifier.
 */
@property (nonatomic, readonly, copy, nullable) NSString *uid;

/**
 *  The date at which the entry was updated for the last time.
 */
@property (nonatomic, readonly, copy, nullable) NSDate *date;

/**
 *  `YES` iff the entry has been marked as discarded.
 */
@property (nonatomic, readonly) BOOL discarded;

/**
 *  Set to `YES` to flag the object as requiring a synchronization.
 */
@property (nonatomic) BOOL dirty;

@end

NS_ASSUME_NONNULL_END
