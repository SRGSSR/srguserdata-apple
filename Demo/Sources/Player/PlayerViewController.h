//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlayerPlaylist.h"

#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(tvos(9.0)) API_UNAVAILABLE(ios)
OBJC_EXPORT SRGLetterboxViewController *LetterboxPlayerViewController(NSString * _Nullable URN, CMTime time, PlayerPlaylist * _Nullable playerPlaylist);

API_UNAVAILABLE(tvos)
@interface PlayerViewController : UIViewController

- (instancetype)initWithURN:(nullable NSString *)URN time:(CMTime)time playerPlaylist:(nullable PlayerPlaylist *)playerPlaylist;

@end

NS_ASSUME_NONNULL_END
