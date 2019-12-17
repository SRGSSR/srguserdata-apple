//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSSet+SRGUserData.h"

@implementation NSSet (SRGUserData)

#pragma mark Public methods

- (NSSet *)srguserdata_setByRemovingObjectsInArray:(NSArray *)array
{
    NSMutableSet *mutableSet = self.mutableCopy;
    [mutableSet minusSet:[NSSet setWithArray:array]];
    return mutableSet.copy;
}

@end
