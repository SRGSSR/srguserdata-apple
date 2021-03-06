//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylist.h"

#import "SRGPlaylistEntry.h"
#import "SRGUserObject+Subclassing.h"

@import libextobjc;
@import Mantle;

static NSValueTransformer *SRGPlaylistTypeJSONTransformer(void)
{
    static NSValueTransformer *s_transformer;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_transformer = [NSValueTransformer mtl_valueMappingTransformerWithDictionary:@{ @"standard" : @(SRGPlaylistTypeStandard),
                                                                                         @"watch_later" : @(SRGPlaylistTypeWatchLater) }
                                                                         defaultValue:@(SRGPlaylistTypeStandard)
                                                                  reverseDefaultValue:nil];
    });
    return s_transformer;
}

SRGPlaylistUid const SRGPlaylistUidWatchLater = @"watch_later";

@interface SRGPlaylist ()

@property (nonatomic, copy) NSString *name;
@property (nonatomic) SRGPlaylistType type;

@property (nonatomic) NSOrderedSet<SRGPlaylistEntry *> *entries;

@end

@implementation SRGPlaylist

@dynamic name;
@dynamic type;

@dynamic entries;

#pragma mark Overrides

+ (NSArray<NSString *> *)reservedUids
{
    return @[ SRGPlaylistUidWatchLater ];
}

+ (NSString *)uidKey
{
    return @"businessId";
}

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    [super updateWithDictionary:dictionary];
    
    self.name = dictionary[@"name"];
    self.type = [[SRGPlaylistTypeJSONTransformer() transformedValue:dictionary[@"type"]] integerValue];
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = super.dictionary.mutableCopy;
    JSONDictionary[@"name"] = self.name;
    JSONDictionary[@"type"] = [SRGPlaylistTypeJSONTransformer() reverseTransformedValue:@(self.type)];
    return JSONDictionary.copy;
}

@end
