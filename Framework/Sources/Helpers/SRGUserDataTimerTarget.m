//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataTimerTarget.h"

@interface SRGUserDataTimerTarget ()

@property (nonatomic, copy) void (^block)(NSTimer *);

@end

@implementation SRGUserDataTimerTarget

#pragma mark Object lifecycle

- (instancetype)initWithBlock:(void (^)(NSTimer * _Nonnull))block
{
    if (self = [super init]) {
        self.block = block;
    }
    return self;
}

#pragma mark Public methods

- (void)fire:(NSTimer *)timer
{
    self.block ? self.block(timer) : nil;
}

@end
