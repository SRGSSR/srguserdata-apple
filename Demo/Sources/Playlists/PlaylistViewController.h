//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGUserData/SRGUserData.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PlaylistViewController : UITableViewController

- (instancetype)initWithPlaylist:(SRGPlaylist *)playlist;

@end

NS_ASSUME_NONNULL_END

