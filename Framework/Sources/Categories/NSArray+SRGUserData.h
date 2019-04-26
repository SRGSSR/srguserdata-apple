//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGUserData/SRGUserData.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (SRGUserData)

/**
 *  Return the receiver, to which objects from the specified array have been removed.
 */
- (NSArray *)srguserdata_arrayByRemovingObjectsInArray:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
