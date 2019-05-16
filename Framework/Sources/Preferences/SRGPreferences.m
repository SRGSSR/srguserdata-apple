//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferences.h"

#import "SRGPreferenceChangelog.h"
#import "SRGPreferencesRequest.h"
#import "SRGUser+Private.h"
#import "SRGUserData+Private.h"
#import "SRGUserDataLogger.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"

// TODO: - Thread-safety considerations
//       - Should coalesce operations by path / domain (only the last one in the changelog must be kept)
//       - UT: Spaces / slashes / dots in keys + encoding if needed
//       - Add test for SRGPreferencesDidChangeNotification on the main thread.

NSString * const SRGPreferencesDidChangeNotification = @"SRGPreferencesDidChangeNotification";

static NSDictionary *SRGDictionaryMakeImmutable(NSDictionary *dictionary)
{
    if (! dictionary) {
        return nil;
    }
    
    NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull object, BOOL * _Nonnull stop) {
        if ([object isKindOfClass:NSMutableDictionary.class]) {
            mutableDictionary[key] = SRGDictionaryMakeImmutable(object);
        }
        else {
            mutableDictionary[key] = object;
        }
    }];
    return [mutableDictionary copy];
}

static NSDictionary *SRGDictionaryMakeMutable(NSDictionary *dictionary)
{
    if (! dictionary) {
        return nil;
    }
    
    NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull object, BOOL * _Nonnull stop) {
        if ([object isKindOfClass:NSDictionary.class]) {
            mutableDictionary[key] = SRGDictionaryMakeMutable(object);
        }
        else {
            mutableDictionary[key] = object;
        }
    }];
    return mutableDictionary;
}

@interface SRGPreferences ()

@property (nonatomic) NSURL *fileURL;
@property (nonatomic) NSMutableDictionary *dictionary;
@property (nonatomic) SRGPreferenceChangelog *changelog;

@property (nonatomic, weak) SRGRequest *pushRequest;
@property (nonatomic) SRGRequestQueue *requestQueue;

@property (nonatomic) NSURLSession *session;

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

+ (void)savePreferenceDictionary:(NSDictionary *)dictionary toFileURL:(NSURL *)fileURL
{
    NSError *JSONError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
    if (JSONError) {
        SRGUserDataLogError(@"preferences", @"Could not save preferences. Reason %@", JSONError);
        return;
    }
    
    NSError *writeError = nil;
    if (! [data writeToURL:fileURL options:NSDataWritingAtomic error:&writeError]) {
        SRGUserDataLogError(@"preferences", @"Could not save preferences. Reason %@", writeError);
        return;
    }
    
    SRGUserDataLogInfo(@"preferences", @"Preferences successfully saved");
}

+ (NSMutableDictionary *)savedPreferenceDictionaryFromFileURL:(NSURL *)fileURL
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
        SRGUserDataLogError(@"preferences", @"Could not read preferences. Reason %@", JSONError);
        return nil;
    }
    
    if (! [JSONObject isKindOfClass:NSDictionary.class]) {
        SRGUserDataLogError(@"preferences", @"Could not read preferences. The format is invalid");
        return nil;
    }
    
    return JSONObject;
}

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL userData:(SRGUserData *)userData
{
    if (self = [super initWithServiceURL:serviceURL userData:userData]) {
        self.fileURL = [[userData.storeFileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"prefs"];
        self.dictionary = [SRGPreferences savedPreferenceDictionaryFromFileURL:self.fileURL] ?: [NSMutableDictionary dictionary];
        self.changelog = [[SRGPreferenceChangelog alloc] initForPreferencesFileWithURL:self.fileURL];
        
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    }
    return self;
}

#pragma mark Preference management

- (BOOL)hasObjectAtPath:(NSString *)path inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSUInteger i = 0; i < pathComponents.count; ++i) {
        NSString *pathComponent = pathComponents[i];
        id value = dictionary[pathComponent];
        
        if (i == pathComponents.count - 1) {
            return value != nil;
        }
        else {
            if (! [value isKindOfClass:NSDictionary.class]) {
                break;
            }
            dictionary = value;
        }
    }
    return NO;
}

- (void)setObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSUInteger i = 0; i < pathComponents.count; ++i) {
        NSString *pathComponent = pathComponents[i];
        if (i == pathComponents.count - 1) {
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
    
    [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification object:self];
    
    [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            SRGPreferenceChangelogEntry *entry = [SRGPreferenceChangelogEntry changelogEntryWithObject:object atPath:path inDomain:domain];
            [self.changelog addEntry:entry];
        }
    }];
}

- (id)objectAtPath:(NSString *)path inDomain:(NSString *)domain withClass:(Class)cls
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSUInteger i = 0; i < pathComponents.count; ++i) {
        NSString *pathComponent = pathComponents[i];
        id value = dictionary[pathComponent];
        
        if (i == pathComponents.count - 1) {
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
    [self setObject:SRGDictionaryMakeMutable(dictionary) atPath:path inDomain:domain];
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

- (void)removeObjectAtPath:(NSString *)path inDomain:(NSString *)domain
{
    [self setObject:nil atPath:path inDomain:domain];
}

#pragma mark Requests

- (void)pushPreferencesForSessionToken:(NSString *)sessionToken
                   withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    NSArray<SRGPreferenceChangelogEntry *> *entries = self.changelog.entries;
    if (entries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    typedef void (^PushEntryBlock)(SRGPreferenceChangelogEntry *);
    __block __weak PushEntryBlock weakPushEntry = nil;
    
    // The server currently does not support parallel updates reliably (some of them will fail). Serialize them instead.
    // TODO: This should definitely be fixed. A better implementation would just use a request queue (see commit before
    //       the following block was introduced), having a session configuration with max HTTP connections set to 1 for
    //       serialization. Sadly this still seems too fast for the server to handle changes properly.
    // FIXME: Bugs
    //        1) When deleting several items, sometimes requests might repeat endlessly
    PushEntryBlock pushEntry = ^(SRGPreferenceChangelogEntry *entry) {
        PushEntryBlock strongPushEntry = weakPushEntry;
        
        void (^pushCompletionBlock)(NSHTTPURLResponse *, NSError *) = ^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError *error) {
            if (error) {
                completionBlock(error);
                return;
            }
            
            [self.changelog removeEntry:entry];
            
            NSInteger index = [entries indexOfObject:entry];
            if (index < entries.count - 1) {
                SRGPreferenceChangelogEntry *nextEntry = entries[index + 1];
                strongPushEntry(nextEntry);
            }
            else {
                completionBlock(nil);
            }
        };
        
        if (entry.object) {
            SRGRequest *request = [SRGPreferencesRequest putPreferenceWithObject:entry.object atPath:entry.path inDomain:entry.domain toServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:pushCompletionBlock];
            [request resume];
            self.pushRequest = request;
        }
        else {
            SRGRequest *request = [SRGPreferencesRequest deletePreferenceAtPath:entry.path inDomain:entry.domain fromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:pushCompletionBlock];
            [request resume];
            self.pushRequest = request;
        }
    };
    weakPushEntry = pushEntry;
        
    pushEntry(entries.firstObject);
}

- (void)pullPreferencesForSessionToken:(NSString *)sessionToken
                   withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    self.requestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        if (finished) {
            completionBlock(error);
        }
    }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
    
    SRGRequest *domainsRequest = [SRGPreferencesRequest domainsFromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSArray<NSString *> * _Nullable domains, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (error) {
            completionBlock(error);
            return;
        }
        
        if (domains.count != 0) {
            for (NSString *domain in domains) {
                SRGRequest *preferencesRequest = [SRGPreferencesRequest preferencesAtPath:nil inDomain:domain fromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSDictionary * _Nullable dictionary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                    [self.requestQueue reportError:error];
                    
                    if (! error) {
                        self.dictionary[domain] = SRGDictionaryMakeMutable(dictionary);
                        [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
                        [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification object:self];
                    }
                }];
                [self.requestQueue addRequest:preferencesRequest resume:YES];
            }
        }
        else {
            [self.dictionary removeAllObjects];
            [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
            [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification object:self];
        }
    }];
    [self.requestQueue addRequest:domainsRequest resume:YES];
}

#pragma mark Subclassing hooks

- (void)prepareDataForInitialSynchronizationWithCompletionBlock:(void (^)(void))completionBlock
{
    if (! [NSFileManager.defaultManager fileExistsAtPath:self.fileURL.path]) {
        completionBlock();
        return;
    }
    
    NSArray<SRGPreferenceChangelogEntry *> *entries = [SRGPreferenceChangelogEntry changelogEntriesFromPreferenceFileAtURL:self.fileURL];
    [entries enumerateObjectsUsingBlock:^(SRGPreferenceChangelogEntry * _Nonnull entry, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.changelog addEntry:entry];
    }];
    
    completionBlock();
}

- (void)synchronizeWithCompletionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    NSString *sessionToken = self.userData.identityService.sessionToken;
    
    [self pushPreferencesForSessionToken:sessionToken withCompletionBlock:^(NSError *error) {
        if (error) {
            completionBlock(error);
            return;
        }
        
        [self pullPreferencesForSessionToken:sessionToken withCompletionBlock:completionBlock];
    }];
}

- (void)cancelSynchronization
{
    [self.pushRequest cancel];
    [self.requestQueue cancel];
}

- (void)clearData
{
    [NSFileManager.defaultManager removeItemAtURL:self.fileURL error:NULL];
    [self.dictionary removeAllObjects];
    
    [self.changelog removeAllEntries];
    
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
