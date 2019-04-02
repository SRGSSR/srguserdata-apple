//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistoryEntry.h"

#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>

@interface SRGHistoryEntry ()

@property (nonatomic) double lastPlaybackPosition;
@property (nonatomic, copy) NSString *deviceUid;

@end

@implementation SRGHistoryEntry

@dynamic lastPlaybackPosition;
@dynamic deviceUid;

#pragma mark Getters and Setters

- (CMTime)lastPlaybackTime
{
    return CMTimeMakeWithSeconds(self.lastPlaybackPosition, NSEC_PER_SEC);
}

- (void)setLastPlaybackTime:(CMTime)resumeTime
{
    self.lastPlaybackPosition = CMTimeGetSeconds(resumeTime);
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = [[super dictionary] mutableCopy];
    JSONDictionary[@"device_id"] = self.deviceUid;
    JSONDictionary[@"last_playback_position"] = @(self.lastPlaybackPosition);
    return [JSONDictionary copy];
}

#pragma mark Updates

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    [super updateWithDictionary:dictionary];
    
    self.deviceUid = dictionary[@"device_id"];
    self.lastPlaybackPosition = [dictionary[@"last_playback_position"] doubleValue];
}

@end
