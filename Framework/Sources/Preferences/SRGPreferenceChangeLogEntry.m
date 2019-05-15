//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferenceChangeLogEntry.h"

#import <libextobjc/libextobjc.h>

static NSString *SRGPreferenceChangeLogEntryTypeName(SRGPreferenceChangeLogEntryType type)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary *s_names;
    dispatch_once(&s_onceToken, ^{
        s_names = @{ @(SRGPreferenceChangeLogEntryTypeUpsert) : @"upsert",
                     @(SRGPreferenceChangeLogEntryTypeDelete) : @"delete",
                     @(SRGPreferenceChangeLogEntryTypeNode) : @"node" };
    });
    return s_names[@(type)];
}

@interface SRGPreferenceChangeLogEntry ()

@property (nonatomic) SRGPreferenceChangeLogEntryType type;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *domain;
@property (nonatomic) id object;

@end

@implementation SRGPreferenceChangeLogEntry

#pragma mark Class methods

+ (SRGPreferenceChangeLogEntry *)changeLogEntryForUpsertAtPath:(NSString *)path inDomain:(NSString *)domain withObject:(id)object
{
    return [[[self class] alloc] initWithType:SRGPreferenceChangeLogEntryTypeUpsert forPath:path inDomain:domain withObject:object];
}

+ (SRGPreferenceChangeLogEntry *)changeLogEntryForDeleteAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return [[[self class] alloc] initWithType:SRGPreferenceChangeLogEntryTypeDelete forPath:path inDomain:domain withObject:nil];
}

+ (NSArray<SRGPreferenceChangeLogEntry *> *)changeLogEntriesForPreferenceDictionary:(NSDictionary *)dictionary inDomain:(NSString *)domain
{
    return [self changeLogEntriesForDictionary:dictionary atPath:nil inDomain:domain];
}

+ (NSArray<SRGPreferenceChangeLogEntry *> *)changeLogEntriesForDictionary:(NSDictionary *)dictionary atPath:(NSString *)path inDomain:(NSString *)domain
{
    NSMutableArray<SRGPreferenceChangeLogEntry *> *entries = [NSMutableArray array];
    
    SRGPreferenceChangeLogEntry *entry = [[SRGPreferenceChangeLogEntry alloc] initWithType:SRGPreferenceChangeLogEntryTypeNode forPath:path inDomain:domain withObject:@{}];
    [entries addObject:entry];
    
    for (NSString *key in dictionary.allKeys) {
        NSString *subpath = path ? [path stringByAppendingPathComponent:key] : key;
        
        id object = dictionary[key];
        if ([object isKindOfClass:NSDictionary.class]) {
            NSArray<SRGPreferenceChangeLogEntry *> *subEntries = [self changeLogEntriesForDictionary:object atPath:subpath inDomain:domain];
            [entries addObjectsFromArray:subEntries];
        }
        else {
            SRGPreferenceChangeLogEntry *subEntry = [[SRGPreferenceChangeLogEntry alloc] initWithType:SRGPreferenceChangeLogEntryTypeUpsert forPath:subpath inDomain:domain withObject:object];
            [entries addObject:subEntry];
        }
    }
    
    return [entries copy];
}

#pragma mark MTLJSONSerializing protocol

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    static NSDictionary *s_mapping;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_mapping = @{ @keypath(SRGPreferenceChangeLogEntry.new, type) : @"type",
                       @keypath(SRGPreferenceChangeLogEntry.new, path) : @"path",
                       @keypath(SRGPreferenceChangeLogEntry.new, domain) : @"domain",
                       @keypath(SRGPreferenceChangeLogEntry.new, object) : @"object" };
    });
    return s_mapping;
}

#pragma mark Object lifecycle

- (instancetype)initWithType:(SRGPreferenceChangeLogEntryType)type forPath:(NSString *)path inDomain:(NSString *)domain withObject:(id)object
{
    if (self = [super init]) {
        self.type = type;
        self.path = path;
        self.domain = domain;
        self.object = object;
    }
    return self;
}

#pragma mark Transformers

+ (NSValueTransformer *)typeJSONTransformer
{
    static NSValueTransformer *s_transformer;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_transformer = [NSValueTransformer mtl_valueMappingTransformerWithDictionary:@{ @"upsert" : @(SRGPreferenceChangeLogEntryTypeUpsert),
                                                                                         @"delete" : @(SRGPreferenceChangeLogEntryTypeDelete),
                                                                                         @"node" : @(SRGPreferenceChangeLogEntryTypeNode) }
                                                                         defaultValue:@(SRGPreferenceChangeLogEntryTypeUpsert)
                                                                  reverseDefaultValue:nil];
    });
    return s_transformer;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; type = %@; path = %@; domain: %@; object: %@>",
            [self class],
            self,
            SRGPreferenceChangeLogEntryTypeName(self.type),
            self.path,
            self.domain,
            self.object];
}

@end
