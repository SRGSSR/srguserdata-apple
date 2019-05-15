//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SRGPreferenceChangeLogEntryType) {
    SRGPreferenceChangeLogEntryTypeUpsert,
    SRGPreferenceChangeLogEntryTypeDelete,
    SRGPreferenceChangeLogEntryTypeNode
};

@interface SRGPreferenceChangeLogEntry : MTLModel <MTLJSONSerializing>

+ (SRGPreferenceChangeLogEntry *)changeLogEntryForUpsertAtPath:(NSString *)path inDomain:(NSString *)domain withObject:(id)object;
+ (SRGPreferenceChangeLogEntry *)changeLogEntryForDeleteAtPath:(NSString *)path inDomain:(NSString *)domain;

+ (NSArray<SRGPreferenceChangeLogEntry *> *)changeLogEntriesForPreferenceDictionary:(NSDictionary *)dictionary inDomain:(NSString *)domain;

@end

NS_ASSUME_NONNULL_END
