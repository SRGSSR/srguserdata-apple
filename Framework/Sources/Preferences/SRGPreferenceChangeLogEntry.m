//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferenceChangeLogEntry.h"

static NSString *SRGPreferenceChangeLogEntryTypeName(SRGPreferenceChangeLogEntryType type)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary *s_names;
    dispatch_once(&s_onceToken, ^{
        s_names = @{ @(SRGPreferenceChangeLogEntryTypeUpsert) : @"upsert",
                     @(SRGPreferenceChangeLogEntryTypeDelete) : @"delete" };
    });
    return s_names[@(type)];
}

@interface SRGPreferenceChangeLogEntry ()

@property (nonatomic) SRGPreferenceChangeLogEntryType type;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, copy) NSString *domain;

@end

@implementation SRGPreferenceChangeLogEntry

#pragma mark Class methods

+ (SRGPreferenceChangeLogEntry *)changeLogEntryForUpsertAtKeyPath:(NSString *)keyPath inDomain:(NSString *)domain withObject:(id)object
{
    return [[[self class] alloc] initWithType:SRGPreferenceChangeLogEntryTypeUpsert forKeyPath:keyPath inDomain:domain withObject:object];
}

+ (SRGPreferenceChangeLogEntry *)changeLogEntryForDeleteAtKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    return [[[self class] alloc] initWithType:SRGPreferenceChangeLogEntryTypeDelete forKeyPath:keyPath inDomain:domain withObject:nil];
}

#pragma mark Object lifecycle

- (instancetype)initWithType:(SRGPreferenceChangeLogEntryType)type forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain withObject:(id)object
{
    if (self = [super init]) {
        self.type = type;
        self.keyPath = keyPath;
        self.domain = domain;
    }
    return self;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; type = %@; keyPath = %@; domain: %@>",
            [self class],
            self,
            SRGPreferenceChangeLogEntryTypeName(self.type),
            self.keyPath,
            self.domain];
}

@end
