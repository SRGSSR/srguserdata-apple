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
 *
 *  @discussion Instances must not be shared among threads.
 */
@interface SRGHistoryEntry : SRGUserObject

/**
 *  The playback position which the item was played at (in seconds).
 */
@property (nonatomic, readonly) double lastPlaybackPosition;

/**
 *  An identifier for the device which updated the entry.
 */
@property (nonatomic, readonly, copy, nullable) NSString *deviceUid;

@end

/**
 *  Transient fields.
 *
 *  @discussion These fields can be used for building filter predicates.
 */
@interface SRGHistoryEntry (Transient)

/**
 *  The playback position which the item was played at (as a `CMTime`).
 */
@property (nonatomic, readonly) CMTime lastPlaybackTime;

@end

NS_ASSUME_NONNULL_END
