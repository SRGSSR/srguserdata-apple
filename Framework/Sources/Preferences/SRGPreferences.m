//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferences.h"

#import "SRGPreferenceChangeLogEntry.h"
#import "SRGUser+Private.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"

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

// TODO: - Thread-safety considerations
//       - Serialize change log entries as well
//       - Delete each log entry consumed during sync
//       - Should coalesce operations by keypath / domain (only the last one in the changelog must be kept)

@interface SRGPreferences ()

@property (nonatomic) NSMutableDictionary *dictionary;
@property (nonatomic) NSMutableArray<SRGPreferenceChangeLogEntry *> *changeLogEntries;

@end

@implementation SRGPreferences

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super initWithServiceURL:serviceURL identityService:identityService dataStore:dataStore]) {
        self.dictionary = [self dictionaryFromFile] ?: [NSMutableDictionary dictionary];
        self.changeLogEntries = [NSMutableArray array];
    }
    return self;
}

#pragma mark Serialization

- (void)saveFileFromDictionary:(NSDictionary *)dictionary
{
    NSURL *folderURL = self.dataStore.persistentContainer.srg_fileURL.URLByDeletingPathExtension;
    if (! [NSFileManager.defaultManager fileExistsAtPath:folderURL.path]) {
        [NSFileManager.defaultManager createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
    NSURL *fileURL = [folderURL URLByAppendingPathComponent:@"preferences.json"];
    [data writeToURL:fileURL atomically:YES];
}

- (NSMutableDictionary *)dictionaryFromFile
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
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
}

#pragma mark Preference management

- (void)setObject:(id)object forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [@[domain] arrayByAddingObjectsFromArray:[keyPath componentsSeparatedByString:@"."]];
    
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
    [self saveFileFromDictionary:self.dictionary];
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            SRGPreferenceChangeLogEntry *entry = [SRGPreferenceChangeLogEntry changeLogEntryForUpsertAtKeyPath:keyPath inDomain:domain withObject:object];
            [self.changeLogEntries addObject:entry];
        }
    }];
}

- (id)objectForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain withClass:(Class)cls
{
    NSString *fullKeyPath = keyPath ? [[domain stringByAppendingString:@"."] stringByAppendingString:keyPath] : domain;
    id object = [self.dictionary valueForKeyPath:fullKeyPath];
    return [object isKindOfClass:cls] ? object : nil;
}

- (void)removeObjectForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [@[domain] arrayByAddingObjectsFromArray:[keyPath componentsSeparatedByString:@"."]];
    
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
    [self saveFileFromDictionary:self.dictionary];
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            SRGPreferenceChangeLogEntry *entry = [SRGPreferenceChangeLogEntry changeLogEntryForDeleteAtKeyPath:keyPath inDomain:domain];
            [self.changeLogEntries addObject:entry];
        }
    }];
}

- (NSDictionary *)dictionaryForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    return SRGDictionaryMakeImmutable([self objectForKeyPath:keyPath inDomain:domain withClass:NSDictionary.class]);
}

- (void)setString:(NSString *)string forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    [self setObject:string forKeyPath:keyPath inDomain:domain];
}

- (void)setNumber:(NSNumber *)number forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    [self setObject:number forKeyPath:keyPath inDomain:domain];
}

- (void)setArray:(NSArray *)array forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    [self setObject:array forKeyPath:keyPath inDomain:domain];
}

- (void)setBool:(BOOL)value forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    [self setObject:@(value) forKeyPath:keyPath inDomain:domain];
}

- (void)setInteger:(NSInteger)value forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    [self setObject:@(value) forKeyPath:keyPath inDomain:domain];
}

- (void)setFloat:(float)value forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    [self setObject:@(value) forKeyPath:keyPath inDomain:domain];
}

- (void)setDouble:(double)value forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    [self setObject:@(value) forKeyPath:keyPath inDomain:domain];
}

- (NSString *)stringForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    return [self objectForKeyPath:keyPath inDomain:domain withClass:NSString.class];
}

- (NSNumber *)numberForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    return [self objectForKeyPath:keyPath inDomain:domain withClass:NSNumber.class];
}

- (NSArray *)arrayForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    return [self objectForKeyPath:keyPath inDomain:domain withClass:NSArray.class];
}

- (BOOL)boolForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    return [self numberForKeyPath:keyPath inDomain:domain].boolValue;
}

- (NSInteger)integerForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    return [self numberForKeyPath:keyPath inDomain:domain].integerValue;
}

- (float)floatForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    return [self numberForKeyPath:keyPath inDomain:domain].floatValue;
}

- (double)doubleForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    return [self numberForKeyPath:keyPath inDomain:domain].doubleValue;
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
    
    NSURL *fileURL = [folderURL URLByAppendingPathComponent:@"preferences.json"];
    if (! [NSFileManager.defaultManager fileExistsAtPath:fileURL.path]) {
        return;
    }
    
    [NSFileManager.defaultManager removeItemAtURL:fileURL error:NULL];
    
    [self.dictionary removeAllObjects];
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
