//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRGPreferenceChangelogEntry : MTLModel <MTLJSONSerializing>

+ (SRGPreferenceChangelogEntry *)changelogEntryWithObject:(nullable id<NSCopying>)object atPath:(NSString *)path inDomain:(NSString *)domain;

+ (nullable NSArray<SRGPreferenceChangelogEntry *> *)changelogEntriesFromPreferenceFileAtURL:(NSURL *)fileURL;

@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly, copy) NSString *domain;
@property (nonatomic, readonly, nullable) id<NSCopying> object;

@end

NS_ASSUME_NONNULL_END
