//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  An entry in the preferences change log.
 */
@interface SRGPreferencesChangelogEntry : MTLModel <MTLJSONSerializing>

/**
 *  Create an entry for setting an object at a specific path in a domain. The object might be `nil` for object removal.
 */
+ (SRGPreferencesChangelogEntry *)changelogEntryWithObject:(nullable id)object atPath:(NSString *)path inDomain:(NSString *)domain;

/**
 *  Convert an existing preferences file into a list of equivalent changelog entries. Returns `nil` if the file does not
 *  exist or is invalid.
 */
+ (nullable NSArray<SRGPreferencesChangelogEntry *> *)changelogEntriesFromPreferencesFileAtURL:(NSURL *)fileURL;

/**
 *  Entry properties.
 */
@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly, copy) NSString *domain;
@property (nonatomic, readonly, nullable) id object;

@end

NS_ASSUME_NONNULL_END
