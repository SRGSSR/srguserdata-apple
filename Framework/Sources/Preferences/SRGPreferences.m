//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferences.h"

#import "SRGPreferenceChangelogEntry.h"
#import "SRGUser+Private.h"
#import "SRGUserDataLogger.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"

// TODO: - Thread-safety considerations
//       - Serialize change log entries as well
//       - Delete each log entry consumed during sync
//       - Should coalesce operations by path / domain (only the last one in the changelog must be kept)
//       - UT: Spaces / slashes / dots in keys + encoding if needed

NSString * const SRGPreferencesDidChangeNotification = @"SRGPreferencesDidChangeNotification";

static NSDictionary *SRGDictionaryMakeImmutable(NSDictionary *dictionary)
{
    NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull object, BOOL * _Nonnull stop) {
        if ([object isKindOfClass:NSMutableDictionary.class]) {
            mutableDictionary[key] = [object copy];
        }
        else {
            mutableDictionary[key] = object;
        }
    }];
    return [mutableDictionary copy];
}

@interface SRGPreferences ()

@property (nonatomic) NSMutableDictionary *dictionary;
@property (nonatomic) NSMutableArray<SRGPreferenceChangelogEntry *> *changelogEntries;

@end

@implementation SRGPreferences

#pragma mark Class methods

+ (NSArray<NSString *> *)pathComponentsForPath:(NSString *)path inDomain:(NSString *)domain
{
    NSParameterAssert(domain);
    
    NSArray<NSString *> *pathComponents = path.pathComponents;
    if (pathComponents) {
        return [@[domain] arrayByAddingObjectsFromArray:pathComponents];
    }
    else {
        return @[domain];
    }
}

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super initWithServiceURL:serviceURL identityService:identityService dataStore:dataStore]) {
        self.dictionary = [self savedPreferenceDictionary] ?: [NSMutableDictionary dictionary];
        self.changelogEntries = [self savedChangelogEntries] ?: [NSMutableArray array];
    }
    return self;
}

#pragma mark Serialization

- (void)savePreferenceDictionary:(NSDictionary *)dictionary
{
    NSURL *folderURL = self.dataStore.persistentContainer.srg_fileURL.URLByDeletingPathExtension;
    if (! [NSFileManager.defaultManager fileExistsAtPath:folderURL.path]) {
        [NSFileManager.defaultManager createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    NSError *JSONError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
    if (JSONError) {
        SRGUserDataLogError(@"preferences", @"Could not save preferences. Reason %@", JSONError);
        return;
    }
    
    NSURL *fileURL = [folderURL URLByAppendingPathComponent:@"preferences.json"];
    [data writeToURL:fileURL atomically:YES];
}

- (NSMutableDictionary *)savedPreferenceDictionary
{
    NSURL *folderURL = self.dataStore.persistentContainer.srg_fileURL.URLByDeletingPathExtension;
    if (! [NSFileManager.defaultManager fileExistsAtPath:folderURL.path]) {
        return nil;
    }
    
    NSURL *fileURL = [folderURL URLByAppendingPathComponent:@"preferences.json"];
    if (! [NSFileManager.defaultManager fileExistsAtPath:fileURL.path]) {
        return nil;
    }
    
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    
    NSError *JSONError = nil;
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&JSONError];
    if (JSONError) {
        SRGUserDataLogError(@"preferences", @"Could not read preferences. Reason %@", JSONError);
        return nil;
    }
    
    if (! [JSONObject isKindOfClass:NSDictionary.class]) {
        SRGUserDataLogError(@"preferences", @"Could not read preferences. The format is invalid");
        return nil;
    }
    
    return JSONObject;
    
}

- (void)saveChangelogEntries:(NSArray<SRGPreferenceChangelogEntry *> *)changelogEntries
{
    NSURL *folderURL = self.dataStore.persistentContainer.srg_fileURL.URLByDeletingPathExtension;
    if (! [NSFileManager.defaultManager fileExistsAtPath:folderURL.path]) {
        [NSFileManager.defaultManager createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    NSError *adapterError = nil;
    NSArray *JSONArray = [MTLJSONAdapter JSONArrayFromModels:changelogEntries error:&adapterError];
    if (adapterError) {
        SRGUserDataLogError(@"preferences", @"Could not save changelog. Reason %@", adapterError);
        return;
    }
    
    NSError *JSONError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:JSONArray options:0 error:&JSONError];
    if (JSONError) {
        SRGUserDataLogError(@"preferences", @"Could not save changelog. Reason %@", JSONError);
        return;
    }
    
    NSURL *fileURL = [folderURL URLByAppendingPathComponent:@"changes.json"];
    [data writeToURL:fileURL atomically:YES];
}

- (NSMutableArray<SRGPreferenceChangelogEntry *> *)savedChangelogEntries
{
    NSURL *folderURL = self.dataStore.persistentContainer.srg_fileURL.URLByDeletingPathExtension;
    if (! [NSFileManager.defaultManager fileExistsAtPath:folderURL.path]) {
        return nil;
    }
    
    NSURL *fileURL = [folderURL URLByAppendingPathComponent:@"changes.json"];
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

#pragma mark Preference management

- (void)setObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSString *pathComponent in pathComponents) {
        if (pathComponent == pathComponents.lastObject) {
            dictionary[pathComponent] = object;
        }
        else {
            id value = dictionary[pathComponent];
            if (! value) {
                dictionary[pathComponent] = [NSMutableDictionary dictionary];
            }
            else if (! [value isKindOfClass:NSDictionary.class]) {
                return;
            }
            dictionary = dictionary[pathComponent];
        }
    }
    
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification object:self];
    
    [self savePreferenceDictionary:self.dictionary];
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            SRGPreferenceChangelogEntry *entry = [SRGPreferenceChangelogEntry changelogEntryForUpsertAtPath:path inDomain:domain withObject:object];
            [self.changelogEntries addObject:entry];
            [self saveChangelogEntries:self.changelogEntries];
        }
    }];
}

- (id)objectAtPath:(NSString *)path inDomain:(NSString *)domain withClass:(Class)cls
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSString *pathComponent in pathComponents) {
        id value = dictionary[pathComponent];
        
        if (pathComponent == pathComponents.lastObject) {
            return [value isKindOfClass:cls] ? value : nil;
        }
        else {
            if (! [value isKindOfClass:NSDictionary.class]) {
                break;
            }
            
            dictionary = value;
        }
    }
    return nil;
}

- (void)removeObjectAtPath:(NSString *)path inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSString *pathComponent in pathComponents) {
        if (pathComponent == pathComponents.lastObject) {
            [dictionary removeObjectForKey:pathComponent];
        }
        else {
            id value = dictionary[pathComponent];
            if (! [value isKindOfClass:NSDictionary.class]) {
                return;
            }
        }
        dictionary = dictionary[pathComponent];
    }
    
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification object:self];
    
    [self savePreferenceDictionary:self.dictionary];
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            SRGPreferenceChangelogEntry *entry = [SRGPreferenceChangelogEntry changelogEntryForDeleteAtPath:path inDomain:domain];
            [self.changelogEntries addObject:entry];
            [self saveChangelogEntries:self.changelogEntries];
        }
    }];
}

- (void)setString:(NSString *)string atPath:(NSString *)path inDomain:(NSString *)domain
{
    [self setObject:string atPath:path inDomain:domain];
}

- (void)setNumber:(NSNumber *)number atPath:(NSString *)path inDomain:(NSString *)domain
{
    [self setObject:number atPath:path inDomain:domain];
}

- (void)setArray:(NSArray *)array atPath:(NSString *)path inDomain:(NSString *)domain
{
    [self setObject:array atPath:path inDomain:domain];
}

- (void)setDictionary:(NSDictionary *)dictionary atPath:(NSString *)path inDomain:(NSString *)domain
{
    [self setObject:[dictionary mutableCopy] atPath:path inDomain:domain];
}

- (NSString *)stringAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return [self objectAtPath:path inDomain:domain withClass:NSString.class];
}

- (NSNumber *)numberAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return [self objectAtPath:path inDomain:domain withClass:NSNumber.class];
}

- (NSArray *)arrayAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return [self objectAtPath:path inDomain:domain withClass:NSArray.class];
}

- (NSDictionary *)dictionaryAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return SRGDictionaryMakeImmutable([self objectAtPath:path inDomain:domain withClass:NSDictionary.class]);
}

#pragma mark Subclassing hooks

- (void)synchronizeWithCompletionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    completionBlock(nil);
}

- (void)cancelSynchronization
{
    
}

- (void)clearData
{
    NSURL *folderURL = self.dataStore.persistentContainer.srg_fileURL.URLByDeletingPathExtension;
    if (! [NSFileManager.defaultManager fileExistsAtPath:folderURL.path]) {
        return;
    }
    
    [NSFileManager.defaultManager removeItemAtURL:folderURL error:NULL];
    
    [self.dictionary removeAllObjects];
    
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification object:self];
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; dictionary = %@>",
            [self class],
            self,
            self.dictionary];
}

@end
