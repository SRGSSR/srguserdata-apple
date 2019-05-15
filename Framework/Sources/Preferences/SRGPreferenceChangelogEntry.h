//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SRGPreferenceChangelogEntryType) {
    SRGPreferenceChangelogEntryTypeUpsert,
    SRGPreferenceChangelogEntryTypeDelete,
    SRGPreferenceChangelogEntryTypeNode
};

@interface SRGPreferenceChangelogEntry : MTLModel <MTLJSONSerializing>

+ (SRGPreferenceChangelogEntry *)changelogEntryForUpsertAtPath:(NSString *)path inDomain:(NSString *)domain withObject:(id)object;
+ (SRGPreferenceChangelogEntry *)changelogEntryForDeleteAtPath:(NSString *)path inDomain:(NSString *)domain;

+ (NSArray<SRGPreferenceChangelogEntry *> *)changelogEntriesForPreferenceDictionary:(NSDictionary *)dictionary inDomain:(NSString *)domain;

@end

NS_ASSUME_NONNULL_END
