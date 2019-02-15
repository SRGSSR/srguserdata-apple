//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PlayerViewController : UIViewController

- (instancetype)initWithURN:(nullable NSString *)URN time:(CMTime)time;

@end

NS_ASSUME_NONNULL_END
