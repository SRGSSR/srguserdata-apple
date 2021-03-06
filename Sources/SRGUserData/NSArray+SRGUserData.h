//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (SRGUserData)

/**
 *  Return the receiver, from which objects from the specified array have been removed.
 */
- (NSArray *)srguserdata_arrayByRemovingObjectsInArray:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
