//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferenceChangelogEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRGPreferenceChangelog : NSObject

- (instancetype)initForPreferencesFileWithURL:(NSURL *)preferencesFileURL;

@property (nonatomic, readonly) NSArray<SRGPreferenceChangelogEntry *> *entries;

- (void)addEntry:(SRGPreferenceChangelogEntry *)entry;
- (void)removeEntry:(SRGPreferenceChangelogEntry *)entry;

- (void)removeAllEntries;

@end

@interface SRGPreferenceChangelog (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
