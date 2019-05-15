//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferenceChangelog.h"

#import "SRGUserDataLogger.h"

@interface SRGPreferenceChangelog ()

@property (nonatomic) NSURL *fileURL;
@property (nonatomic) NSMutableArray<SRGPreferenceChangelogEntry *> *changelogEntries;

@end

@implementation SRGPreferenceChangelog

#pragma mark Class methods

+ (void)saveChangelogEntries:(NSArray<SRGPreferenceChangelogEntry *> *)changelogEntries toFileURL:(NSURL *)fileURL
{
    NSError *adapterError = nil;
    NSArray *JSONArray = [MTLJSONAdapter JSONArrayFromModels:changelogEntries error:&adapterError];
    if (adapterError) {
        SRGUserDataLogError(@"preference_changelog", @"Could not save changelog. Reason %@", adapterError);
        return;
    }
    
    NSError *JSONError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:JSONArray options:0 error:&JSONError];
    if (JSONError) {
        SRGUserDataLogError(@"preference_changelog", @"Could not save changelog. Reason %@", JSONError);
        return;
    }
    
    NSError *writeError = nil;
    if (! [data writeToURL:fileURL options:NSDataWritingAtomic error:&writeError]) {
        SRGUserDataLogError(@"preference_changelog", @"Could not save changelog. Reason %@", writeError);
        return;
    }
    
    SRGUserDataLogInfo(@"preference_changelog", @"Changelog successfully saved");
}

+ (NSMutableArray<SRGPreferenceChangelogEntry *> *)savedChangelogEntriesFromFileURL:(NSURL *)fileURL
{
    if (! [NSFileManager.defaultManager fileExistsAtPath:fileURL.path]) {
        return nil;
    }
    
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    if (! data) {
        return nil;
    }
    
    NSError *JSONError = nil;
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&JSONError];
    if (JSONError) {
        SRGUserDataLogError(@"preferences", @"Could not read changelog. Reason %@", JSONError);
        return nil;
    }
    
    if (! [JSONObject isKindOfClass:NSArray.class]) {
        SRGUserDataLogError(@"preferences", @"Could not read changelog. The format is invalid");
        return nil;
    }
    
    NSError *adapterError = nil;
    NSArray<SRGPreferenceChangelogEntry *> *entries = [MTLJSONAdapter modelsOfClass:SRGPreferenceChangelogEntry.class fromJSONArray:JSONObject error:&adapterError];
    if (adapterError) {
        SRGUserDataLogError(@"preferences", @"Could not read changelog. Reason: %@", adapterError);
        return nil;
    }
    
    return [entries mutableCopy];
}

#pragma mark Object lifecycle

- (instancetype)initForPreferencesFileWithURL:(NSURL *)preferencesFileURL
{
    if (self = [super init]) {
        self.fileURL = [preferencesFileURL URLByAppendingPathExtension:@"changes"];
        self.changelogEntries = [SRGPreferenceChangelog savedChangelogEntriesFromFileURL:self.fileURL] ?: [NSMutableArray array];
    }
    return self;
}

#pragma mark Getters and setters

- (NSArray<SRGPreferenceChangelogEntry *> *)entries
{
    return [self.changelogEntries copy];
}

#pragma mark Changelog management

- (void)addEntry:(SRGPreferenceChangelogEntry *)entry
{
    // TODO: Edit the changelog to discard older entries which are replaced with the new one, e.g.
    //         - delete of a path already upserted in the changelog makes the older entries useless
    //         - deletion of a path should cleanup entries in its subtree
    //         - etc.
    [self.changelogEntries addObject:entry];
    [SRGPreferenceChangelog saveChangelogEntries:self.changelogEntries toFileURL:self.fileURL];
}

- (void)removeEntry:(SRGPreferenceChangelogEntry *)entry
{
    [self.changelogEntries removeObject:entry];
    [SRGPreferenceChangelog saveChangelogEntries:self.changelogEntries toFileURL:self.fileURL];
}

- (void)removeAllEntries
{
    [NSFileManager.defaultManager removeItemAtURL:self.fileURL error:NULL];
    [self.changelogEntries removeAllObjects];
}

@end
