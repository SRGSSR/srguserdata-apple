//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSArray+SRGUserData.h"

@implementation NSArray (SRGUserData)

- (NSArray *)srguserdata_arrayByRemovingObjectsInArray:(NSArray *)array
{
    NSMutableArray *mutableArray = [self mutableCopy];
    [mutableArray removeObjectsInArray:array];
    return [mutableArray copy];
}

@end
