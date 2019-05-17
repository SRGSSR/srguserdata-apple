//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferencesChangelogEntry.h"

#import "SRGUserDataLogger.h"

#import <libextobjc/libextobjc.h>

@interface SRGPreferencesChangelogEntry ()

@property (nonatomic) id object;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *domain;

@end

@implementation SRGPreferencesChangelogEntry

#pragma mark Class methods

+ (SRGPreferencesChangelogEntry *)changelogEntryWithObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain
{
    return [[[self class] alloc] initWithObject:object atPath:path inDomain:domain];
}

+ (NSArray<SRGPreferencesChangelogEntry *> *)changelogEntriesFromPreferencesFileAtURL:(NSURL *)fileURL
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
    
    NSMutableArray<SRGPreferencesChangelogEntry *> *entries = [NSMutableArray array];
    for (NSString *domain in JSONDictionary) {
        id value = JSONDictionary[domain];
        if (! [value isKindOfClass:NSDictionary.class]) {
            SRGUserDataLogWarning(@"preferences", @"Could not recover entries in the '%@' domain. The format is invalid", domain);
        }
        
        NSArray<SRGPreferencesChangelogEntry *> *domainEntries = [self changelogEntriesForDictionary:value atPath:nil inDomain:domain];
        [entries addObjectsFromArray:domainEntries];
    }
    
    return [entries copy];
}

+ (NSArray<SRGPreferencesChangelogEntry *> *)changelogEntriesForDictionary:(NSDictionary *)dictionary atPath:(NSString *)path inDomain:(NSString *)domain
{
    NSParameterAssert(domain);
    
    NSMutableArray<SRGPreferencesChangelogEntry *> *entries = [NSMutableArray array];
    
    for (NSString *key in dictionary) {
        NSString *subpath = path ? [path stringByAppendingPathComponent:key] : key;
        
        id object = dictionary[key];
        if ([object isKindOfClass:NSDictionary.class]) {
            NSArray<SRGPreferencesChangelogEntry *> *subEntries = [self changelogEntriesForDictionary:object atPath:subpath inDomain:domain];
            [entries addObjectsFromArray:subEntries];
        }
        else {
            SRGPreferencesChangelogEntry *subEntry = [[SRGPreferencesChangelogEntry alloc] initWithObject:object atPath:subpath inDomain:domain];
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
        s_mapping = @{ @keypath(SRGPreferencesChangelogEntry.new, object) : @"object",
                       @keypath(SRGPreferencesChangelogEntry.new, path) : @"path",
                       @keypath(SRGPreferencesChangelogEntry.new, domain) : @"domain" };
    });
    return s_mapping;
}

#pragma mark Object lifecycle

- (instancetype)initWithObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain
{
    if (self = [super init]) {
        self.object = object;
        self.path = path;
        self.domain = domain;
    }
    return self;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; object = %@; path = %@; domain: %@>",
            [self class],
            self,
            self.object,
            self.path,
            self.domain];
}

@end
