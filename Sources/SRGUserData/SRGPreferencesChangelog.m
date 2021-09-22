//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferencesChangelog.h"

#import "SRGUserDataLogger.h"

@interface SRGPreferencesChangelog ()

@property (nonatomic) NSURL *fileURL;
@property (nonatomic) NSArray<SRGPreferencesChangelogEntry *> *changelogEntries;

@end

@implementation SRGPreferencesChangelog

#pragma mark Class methods

+ (void)saveChangelogEntries:(NSArray<SRGPreferencesChangelogEntry *> *)changelogEntries toFileURL:(NSURL *)fileURL
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

+ (NSArray<SRGPreferencesChangelogEntry *> *)savedChangelogEntriesFromFileURL:(NSURL *)fileURL
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
    NSArray<SRGPreferencesChangelogEntry *> *entries = [MTLJSONAdapter modelsOfClass:SRGPreferencesChangelogEntry.class fromJSONArray:JSONObject error:&adapterError];
    if (adapterError) {
        SRGUserDataLogError(@"preferences", @"Could not read changelog. Reason: %@", adapterError);
        return nil;
    }
    
    return entries;
}

#pragma mark Object lifecycle

- (instancetype)initForPreferencesFileWithURL:(NSURL *)preferencesFileURL
{
    if (self = [super init]) {
        self.fileURL = [preferencesFileURL URLByAppendingPathExtension:@"changes"];
        self.changelogEntries = [SRGPreferencesChangelog savedChangelogEntriesFromFileURL:self.fileURL] ?: [NSArray array];
    }
    return self;
}

#pragma mark Getters and setters

- (NSArray<SRGPreferencesChangelogEntry *> *)entries
{
    return self.changelogEntries.copy;
}

#pragma mark Changelog management

- (void)addEntry:(SRGPreferencesChangelogEntry *)entry
{
    // TODO: Could be optimized. Some operations (e.g. a deletion followed by an insertion) could namely be coalesced
    //       into a single operation, reducing the number of operations to be submitted afterwards.
    self.changelogEntries = [self.changelogEntries arrayByAddingObject:entry];
    [SRGPreferencesChangelog saveChangelogEntries:self.changelogEntries toFileURL:self.fileURL];
}

- (void)removeEntry:(SRGPreferencesChangelogEntry *)entry
{
    self.changelogEntries = [self.changelogEntries mtl_arrayByRemovingObject:entry];
    [SRGPreferencesChangelog saveChangelogEntries:self.changelogEntries toFileURL:self.fileURL];
}

- (void)removeAllEntries
{
    [NSFileManager.defaultManager removeItemAtURL:self.fileURL error:NULL];
    self.changelogEntries = @[];
}

@end
