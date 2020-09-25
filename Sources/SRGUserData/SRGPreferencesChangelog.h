//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferencesChangelogEntry.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Changelog saving non-submitted single changes made to preferences.
 */
@interface SRGPreferencesChangelog : NSObject

/**
 *  Create a change log associated with the specified preference file.
 */
- (instancetype)initForPreferencesFileWithURL:(NSURL *)preferencesFileURL;

/**
 *  Return the current list of non-submitted entries, from the oldest to the most recent one.
 */
@property (nonatomic, readonly) NSArray<SRGPreferencesChangelogEntry *> *entries;

/**
 *  Manage single entries in the changelog.
 */
- (void)addEntry:(SRGPreferencesChangelogEntry *)entry;
- (void)removeEntry:(SRGPreferencesChangelogEntry *)entry;

/**
 *  Erase all entries in the changelog.
 */
- (void)removeAllEntries;

@end

@interface SRGPreferencesChangelog (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
