//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistoryEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRGHistoryEntry (Private)

@property (nonatomic) CMTime lastPlaybackTime;
@property (nonatomic, copy) NSString *deviceName;

@end

NS_ASSUME_NONNULL_END
