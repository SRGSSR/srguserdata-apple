//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSet (SRGUserData)

/**
 *  Return the receiver, to which objects from the specified array have been removed.
 */
- (NSSet *)srguserdata_setByRemovingObjectsInArray:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
