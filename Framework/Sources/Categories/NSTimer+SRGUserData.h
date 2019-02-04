//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTimer (SRGUserData)

/**
 *  Create a block-based timer (a feature only available since iOS 10), scheduled with common run loop modes.
 */
+ (NSTimer *)srguserdata_timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block;

@end

NS_ASSUME_NONNULL_END
