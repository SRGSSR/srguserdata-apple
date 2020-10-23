//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSBundle+SRGUserData.h"

@implementation NSBundle (SRGUserData)

#pragma mark Class methods

+ (instancetype)srg_userDataBundle
{
    return SWIFTPM_MODULE_BUNDLE;
}

@end
