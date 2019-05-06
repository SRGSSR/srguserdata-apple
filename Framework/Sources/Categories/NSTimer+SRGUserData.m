//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSTimer+SRGUserData.h"

#import "SRGUserDataTimerTarget.h"

@implementation NSTimer (SRGUserData)

#pragma mark Class methods

+ (NSTimer *)srguserdata_timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer * _Nonnull timer))block
{
    NSTimer *timer = nil;
    
    if (@available(iOS 10, *)) {
        timer = [self timerWithTimeInterval:interval repeats:repeats block:block];
    }
    else {
        // Do not use self as target, since this would lead to subtle issues when the timer is deallocated
        SRGUserDataTimerTarget *target = [[SRGUserDataTimerTarget alloc] initWithBlock:block];
        timer = [self timerWithTimeInterval:interval target:target selector:@selector(fire:) userInfo:nil repeats:repeats];
    }
    
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    return timer;
}

@end
