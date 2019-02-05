//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRGUserObject : NSManagedObject

/**
 *  The item unique identifier.
 */
// TODO: Rename as itemUid, maybe simply uid. Update all method prototypes "with URN" accordingly
@property (nonatomic, readonly, copy, nullable) NSString *mediaURN;

/**
 *  The date at which the entry was updated.
 */
@property (nonatomic, readonly, copy, nullable) NSDate *date;

/**
 *  `YES` iff the entry has been marked as discarded.
 */
@property (nonatomic, readonly) BOOL discarded;

// TODO: Hide from view
@property (nonatomic) BOOL dirty;

@end

NS_ASSUME_NONNULL_END
