//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylist.h"
#import "SRGPlaylistEntry.h"

#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>

@interface SRGPlaylist ()

@property (nonatomic, copy) NSString *name;
@property (nonatomic) BOOL system;

@property (nonatomic) NSOrderedSet<SRGPlaylistEntry *> *entries;

@end

@implementation SRGPlaylist

@dynamic name;
@dynamic system;

@dynamic entries;

#pragma mark Getters and Setters

- (NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = [[super dictionary] mutableCopy];
    JSONDictionary[@"name"] = self.name;
    JSONDictionary[@"system"] = @(self.system);
    return [JSONDictionary copy];
}

#pragma mark Updates

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    [super updateWithDictionary:dictionary];
    
    self.name = dictionary[@"name"];
    self.system = [dictionary[@"system"] boolValue];
}

@end
