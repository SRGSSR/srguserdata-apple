//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSBundle+SRGUserData.h"

#import "SRGHistory.h"

NSString *SRGUserDataNonLocalizedString(NSString *string)
{
    return string;
}

@implementation NSBundle (SRGUserData)

#pragma mark Class methods

+ (instancetype)srg_userDataBundle
{
    static NSBundle *s_bundle;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        NSString *bundlePath = [[NSBundle bundleForClass:SRGHistory.class].bundlePath stringByAppendingPathComponent:@"SRGUserData.bundle"];
        s_bundle = [NSBundle bundleWithPath:bundlePath];
        NSAssert(s_bundle, @"Please add SRGUserData.bundle to your project resources");
    });
    return s_bundle;
}

@end
