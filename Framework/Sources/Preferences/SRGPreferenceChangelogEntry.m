//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferenceChangelogEntry.h"

#import "SRGUserDataLogger.h"

#import <libextobjc/libextobjc.h>

static NSString *SRGPreferenceChangelogEntryTypeName(SRGPreferenceChangelogEntryType type)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary *s_names;
    dispatch_once(&s_onceToken, ^{
        s_names = @{ @(SRGPreferenceChangelogEntryTypeUpsert) : @"upsert",
                     @(SRGPreferenceChangelogEntryTypeDelete) : @"delete",
                     @(SRGPreferenceChangelogEntryTypeNode) : @"node" };
    });
    return s_names[@(type)];
}

@interface SRGPreferenceChangelogEntry ()

@property (nonatomic) SRGPreferenceChangelogEntryType type;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *domain;
@property (nonatomic) id object;

@end

@implementation SRGPreferenceChangelogEntry

#pragma mark Class methods

+ (SRGPreferenceChangelogEntry *)changelogEntryForUpsertAtPath:(NSString *)path inDomain:(NSString *)domain withObject:(id)object
{
    return [[[self class] alloc] initWithType:SRGPreferenceChangelogEntryTypeUpsert forPath:path inDomain:domain withObject:object];
}

+ (SRGPreferenceChangelogEntry *)changelogEntryForDeleteAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return [[[self class] alloc] initWithType:SRGPreferenceChangelogEntryTypeDelete forPath:path inDomain:domain withObject:nil];
}

+ (NSArray<SRGPreferenceChangelogEntry *> *)changelogEntriesFromPreferenceFileAtURL:(NSURL *)fileURL
{
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    if (! data) {
        return nil;
    }
    
    NSError *JSONError = nil;
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&JSONError];
    if (JSONError) {
        SRGUserDataLogError(@"changelog_entry", @"Could not read preference file. Reason %@", JSONError);
        return nil;
    }
    
    if (! [JSONObject isKindOfClass:NSDictionary.class]) {
        SRGUserDataLogError(@"preferences", @"Could not read preference file. The format is invalid");
        return nil;
    }
    
    NSDictionary *JSONDictionary = JSONObject;
    
    NSMutableArray<SRGPreferenceChangelogEntry *> *entries = [NSMutableArray array];
    for (NSString *domain in JSONDictionary) {
        id value = JSONDictionary[domain];
        if (! [value isKindOfClass:NSDictionary.class]) {
            SRGUserDataLogWarning(@"preferences", @"Could not recover entries in the '%@' domain. The format is invalid", domain);
        }
        
        NSArray<SRGPreferenceChangelogEntry *> *domainEntries = [self changelogEntriesForDictionary:value atPath:nil inDomain:domain];
        [entries addObjectsFromArray:domainEntries];
    }
    
    return [entries copy];
}

+ (NSArray<SRGPreferenceChangelogEntry *> *)changelogEntriesForDictionary:(NSDictionary *)dictionary atPath:(NSString *)path inDomain:(NSString *)domain
{
    NSParameterAssert(domain);
    
    NSMutableArray<SRGPreferenceChangelogEntry *> *entries = [NSMutableArray array];
    
    SRGPreferenceChangelogEntry *entry = [[SRGPreferenceChangelogEntry alloc] initWithType:SRGPreferenceChangelogEntryTypeNode forPath:path inDomain:domain withObject:@{}];
    [entries addObject:entry];
    
    for (NSString *key in dictionary) {
        NSString *subpath = path ? [path stringByAppendingPathComponent:key] : key;
        
        id object = dictionary[key];
        if ([object isKindOfClass:NSDictionary.class]) {
            NSArray<SRGPreferenceChangelogEntry *> *subEntries = [self changelogEntriesForDictionary:object atPath:subpath inDomain:domain];
            [entries addObjectsFromArray:subEntries];
        }
        else {
            SRGPreferenceChangelogEntry *subEntry = [[SRGPreferenceChangelogEntry alloc] initWithType:SRGPreferenceChangelogEntryTypeUpsert forPath:subpath inDomain:domain withObject:object];
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
        s_mapping = @{ @keypath(SRGPreferenceChangelogEntry.new, type) : @"type",
                       @keypath(SRGPreferenceChangelogEntry.new, path) : @"path",
                       @keypath(SRGPreferenceChangelogEntry.new, domain) : @"domain",
                       @keypath(SRGPreferenceChangelogEntry.new, object) : @"object" };
    });
    return s_mapping;
}

#pragma mark Object lifecycle

- (instancetype)initWithType:(SRGPreferenceChangelogEntryType)type forPath:(NSString *)path inDomain:(NSString *)domain withObject:(id)object
{
    if (self = [super init]) {
        self.type = type;
        self.path = path;
        self.domain = domain;
        self.object = [object copy];
    }
    return self;
}

#pragma mark Transformers

+ (NSValueTransformer *)typeJSONTransformer
{
    static NSValueTransformer *s_transformer;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_transformer = [NSValueTransformer mtl_valueMappingTransformerWithDictionary:@{ @"upsert" : @(SRGPreferenceChangelogEntryTypeUpsert),
                                                                                         @"delete" : @(SRGPreferenceChangelogEntryTypeDelete),
                                                                                         @"node" : @(SRGPreferenceChangelogEntryTypeNode) }
                                                                         defaultValue:@(SRGPreferenceChangelogEntryTypeUpsert)
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
            SRGPreferenceChangelogEntryTypeName(self.type),
            self.path,
            self.domain,
            self.object];
}

@end
