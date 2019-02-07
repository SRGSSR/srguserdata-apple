//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObject.h"

#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Entry in the media playback history.
 */
@interface SRGHistoryEntry : SRGUserObject

/**
 *  The playback position which the item was played at.
 */
@property (nonatomic, readonly) CMTime lastPlaybackTime;

/**
 *  An identifier for the device which updated the entry.
 */
// TODO: Rename as deviceUid
@property (nonatomic, readonly, copy, nullable) NSString *deviceName;

@end

NS_ASSUME_NONNULL_END
