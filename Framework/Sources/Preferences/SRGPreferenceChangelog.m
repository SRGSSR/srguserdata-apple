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

- (void)addEntry:(SRGPreferenceChangelogEntry *)entry
{
    [self.changelogEntries addObject:entry];
    [SRGPreferenceChangelog saveChangelogEntries:self.changelogEntries toFileURL:self.fileURL];
}

- (void)clearData
{
    [NSFileManager.defaultManager removeItemAtURL:self.fileURL error:NULL];
    [self.changelogEntries removeAllObjects];
}

@end
