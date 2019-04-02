//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylistEntry.h"

#import "SRGUser.h"
#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>

@interface SRGUserObject ()

@property (nonatomic, copy) NSString *name;
@property (nonatomic) BOOL system;

@end

@implementation SRGPlaylistEntry

@dynamic name;
@dynamic system;

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
