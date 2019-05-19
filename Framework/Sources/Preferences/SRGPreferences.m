//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferences.h"

#import "NSSet+SRGUserData.h"
#import "SRGPreferencesChangelog.h"
#import "SRGPreferencesRequest.h"
#import "SRGUser+Private.h"
#import "SRGUserData+Private.h"
#import "SRGUserDataLogger.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"

NSString * const SRGPreferencesDidChangeNotification = @"SRGPreferencesDidChangeNotification";
NSString * const SRGPreferencesDomainsKey = @"SRGPreferencesDomains";

static NSDictionary *SRGDictionaryMakeImmutableCopy(NSDictionary *dictionary)
{
    if (! dictionary) {
        return nil;
    }
    
    NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull object, BOOL * _Nonnull stop) {
        if ([object isKindOfClass:NSMutableDictionary.class]) {
            mutableDictionary[key] = SRGDictionaryMakeImmutableCopy(object);
        }
        else {
            mutableDictionary[key] = object;
        }
    }];
    return [mutableDictionary copy];
}

static NSDictionary *SRGDictionaryMakeMutableCopy(NSDictionary *dictionary)
{
    if (! dictionary) {
        return nil;
    }
    
    NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull object, BOOL * _Nonnull stop) {
        if ([object isKindOfClass:NSDictionary.class]) {
            mutableDictionary[key] = SRGDictionaryMakeMutableCopy(object);
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
@property (nonatomic) SRGPreferencesChangelog *changelog;

@property (nonatomic, weak) SRGRequest *pushRequest;
@property (nonatomic) SRGRequestQueue *requestQueue;

@property (nonatomic) NSURLSession *session;

@end

@implementation SRGPreferences

#pragma mark Class methods

+ (NSArray<NSString *> *)pathComponentsForPath:(NSString *)path inDomain:(NSString *)domain
{
    NSParameterAssert(domain);
    
    if (domain.length == 0 || [domain containsString:@"/"]) {
        SRGUserDataLogWarning(@"preferences", @"Unsupported domain '%@'", domain);
        return nil;
    }
    
    if ([domain rangeOfCharacterFromSet:NSCharacterSet.URLPathAllowedCharacterSet.invertedSet].location != NSNotFound) {
        SRGUserDataLogWarning(@"preferences", @"Unsupported path '%@'", path);
        return nil;
    }
    
    if (! path) {
        return @[domain];
    }
    
    NSString *trimmedPath = [path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    if (trimmedPath.length == 0) {
        SRGUserDataLogWarning(@"preferences", @"Unsupported path '%@'", path);
        return nil;
    }
    
    if ([trimmedPath rangeOfCharacterFromSet:NSCharacterSet.URLPathAllowedCharacterSet.invertedSet].location != NSNotFound) {
        SRGUserDataLogWarning(@"preferences", @"Unsupported path '%@'", path);
        return nil;
    }
    
    return [@[domain] arrayByAddingObjectsFromArray:trimmedPath.pathComponents];    
}

+ (BOOL)updateDictionary:(NSMutableDictionary *)dictionary withObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain
{
    if (object && ! [object isKindOfClass:NSString.class] && ! [object isKindOfClass:NSNumber.class] && ! [NSJSONSerialization isValidJSONObject:object]) {
        return NO;
    }
    
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    if (! pathComponents) {
        return NO;
    }
    
    NSMutableDictionary *currentDictionary = dictionary;
    for (NSUInteger i = 0; i < pathComponents.count; ++i) {
        NSString *pathComponent = pathComponents[i];
        if (i == pathComponents.count - 1) {
            id currentObject = currentDictionary[pathComponent];
            if ([currentObject isEqual:object]) {
                return NO;
            }
            else {
                currentDictionary[pathComponent] = object;
            }
        }
        else {
            id value = currentDictionary[pathComponent];
            if (! [value isKindOfClass:NSDictionary.class]) {
                currentDictionary[pathComponent] = [NSMutableDictionary dictionary];
            }
            currentDictionary = currentDictionary[pathComponent];
        }
    }
    
    NSMutableDictionary *domainDictionary = dictionary[domain];
    if (domainDictionary.count == 0) {
        dictionary[domain] = nil;
    }
    
    return YES;
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
        self.changelog = [[SRGPreferencesChangelog alloc] initForPreferencesFileWithURL:self.fileURL];
        
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    }
    return self;
}

#pragma mark Preference management

- (BOOL)hasObjectAtPath:(NSString *)path inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    if (! pathComponents) {
        return 0;
    }
    
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
    NSDictionary *previousDictionary = SRGDictionaryMakeImmutableCopy(self.dictionary);
    [SRGPreferences updateDictionary:self.dictionary withObject:object atPath:path inDomain:domain];
    
    if ([self.dictionary isEqualToDictionary:previousDictionary]) {
        return;
    }
    
    [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification
                                                      object:self
                                                    userInfo:@{ SRGPreferencesDomainsKey : [NSSet setWithObject:domain] }];
    
    [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            SRGPreferencesChangelogEntry *entry = [SRGPreferencesChangelogEntry changelogEntryWithObject:object atPath:path inDomain:domain];
            [self.changelog addEntry:entry];
        }
    }];
}

- (id)objectAtPath:(NSString *)path inDomain:(NSString *)domain withClass:(Class)cls
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    if (! pathComponents) {
        return nil;
    }
    
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
    if (array && ! [NSJSONSerialization isValidJSONObject:array]) {
        return;
    }
    [self setObject:array atPath:path inDomain:domain];
}

- (void)setDictionary:(NSDictionary *)dictionary atPath:(NSString *)path inDomain:(NSString *)domain
{
    if (dictionary && ! [NSJSONSerialization isValidJSONObject:dictionary]) {
        return;
    }
    [self setObject:SRGDictionaryMakeMutableCopy(dictionary) atPath:path inDomain:domain];
}

- (void)setObjectsAtPaths:(NSDictionary<NSString *,id> *)objectsAtPaths inDomain:(NSString *)domain
{
    NSDictionary *previousDictionary = SRGDictionaryMakeImmutableCopy(self.dictionary);
    
    NSMutableArray<NSString *> *updatedPaths = [NSMutableArray array];
    [objectsAtPaths enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull path, id  _Nonnull object, BOOL * _Nonnull stop) {
        if ([SRGPreferences updateDictionary:self.dictionary withObject:object atPath:path inDomain:domain]) {
            [updatedPaths addObject:path];
        }
    }];
    
    if ([self.dictionary isEqualToDictionary:previousDictionary]) {
        return;
    }
    
    [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification
                                                      object:self
                                                    userInfo:@{ SRGPreferencesDomainsKey : [NSSet setWithObject:domain] }];
    
    [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            for (NSString *path in updatedPaths) {
                SRGPreferencesChangelogEntry *entry = [SRGPreferencesChangelogEntry changelogEntryWithObject:objectsAtPaths[path] atPath:path inDomain:domain];
                [self.changelog addEntry:entry];
            }
        }
    }];
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
    return SRGDictionaryMakeImmutableCopy([self objectAtPath:path inDomain:domain withClass:NSDictionary.class]);
}

- (void)removeObjectsAtPaths:(NSArray<NSString *> *)paths inDomain:(NSString *)domain
{
    NSDictionary *previousDictionary = SRGDictionaryMakeImmutableCopy(self.dictionary);
    
    NSMutableSet<NSString *> *removedPaths = [NSMutableSet set];
    for (NSString *path in paths) {
        if ([SRGPreferences updateDictionary:self.dictionary withObject:nil atPath:path inDomain:domain]) {
            [removedPaths addObject:path];
        }
    }
    
    if ([self.dictionary isEqualToDictionary:previousDictionary]) {
        return;
    }
    
    [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification
                                                      object:self
                                                    userInfo:@{ SRGPreferencesDomainsKey : [NSSet setWithObject:domain] }];
    
    [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            for (NSString *path in removedPaths) {
                SRGPreferencesChangelogEntry *entry = [SRGPreferencesChangelogEntry changelogEntryWithObject:nil atPath:path inDomain:domain];
                [self.changelog addEntry:entry];
            }
        }
    }];
}

#pragma mark Requests

- (void)pushPreferencesForSessionToken:(NSString *)sessionToken
                   withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    NSArray<SRGPreferencesChangelogEntry *> *entries = self.changelog.entries;
    if (entries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    typedef void (^PushEntryBlock)(SRGPreferencesChangelogEntry *);
    __block __weak PushEntryBlock weakPushEntry = nil;
    
    // TODO: Implementation could / should be simpler. The requests should be serializable by HTTPMaximumConnectionsPerHost
    //       to 1 on the session configuration. Sadly this is not serialized enough for the server which will drop some of
    //       the submitted changes randomly.
    PushEntryBlock pushEntry = ^(SRGPreferencesChangelogEntry *entry) {
        PushEntryBlock strongPushEntry = weakPushEntry;
        
        void (^pushCompletionBlock)(NSHTTPURLResponse *, NSError *) = ^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError *error) {
            if (error) {
                completionBlock(error);
                return;
            }
            
            [self.changelog removeEntry:entry];
            
            NSInteger index = [entries indexOfObject:entry];
            if (index < entries.count - 1) {
                SRGPreferencesChangelogEntry *nextEntry = entries[index + 1];
                strongPushEntry(nextEntry);
            }
            else {
                completionBlock(nil);
            }
        };
        
        if (entry.object) {
            SRGRequest *request = [[SRGPreferencesRequest putPreferenceWithObject:entry.object atPath:entry.path inDomain:entry.domain toServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:pushCompletionBlock] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
            [request resume];
            self.pushRequest = request;
        }
        else {
            SRGRequest *request = [[SRGPreferencesRequest deletePreferenceAtPath:entry.path inDomain:entry.domain fromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:pushCompletionBlock] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
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
    NSSet<NSString *> *previousDomains = [NSSet setWithArray:self.dictionary.allKeys];
    
    self.requestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        if (finished) {
            if (previousDomains.count != 0) {
                [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGPreferencesDomainsKey : previousDomains }];
            }
            completionBlock(error);
        }
    }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
    
    SRGRequest *domainsRequest = [[SRGPreferencesRequest domainsFromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSArray<NSString *> * _Nullable domains, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (error) {
            [self.requestQueue reportError:error];
            return;
        }
        
        NSSet<NSString *> *deletedDomains = [previousDomains srguserdata_setByRemovingObjectsInArray:domains];
        if (deletedDomains.count != 0) {
            for (NSString *domain in deletedDomains) {
                [self.dictionary removeObjectForKey:domain];
            }
            [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
        }
        
        if (domains.count != 0) {
            for (NSString *domain in domains) {
                SRGRequest *preferencesRequest = [SRGPreferencesRequest preferencesAtPath:nil inDomain:domain fromServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSDictionary * _Nullable dictionary, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                    [self.requestQueue reportError:error];
                    
                    if (dictionary && ! [self.dictionary isEqualToDictionary:dictionary]) {
                        self.dictionary[domain] = SRGDictionaryMakeMutableCopy(dictionary);
                        [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
                    }
                }];
                [self.requestQueue addRequest:preferencesRequest resume:YES];
            }
        }
    }] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
    [self.requestQueue addRequest:domainsRequest resume:YES];
}

#pragma mark Subclassing hooks

- (void)prepareDataForInitialSynchronizationWithCompletionBlock:(void (^)(void))completionBlock
{
    if (! [NSFileManager.defaultManager fileExistsAtPath:self.fileURL.path]) {
        completionBlock();
        return;
    }
    
    NSArray<SRGPreferencesChangelogEntry *> *entries = [SRGPreferencesChangelogEntry changelogEntriesFromPreferencesFileAtURL:self.fileURL];
    [entries enumerateObjectsUsingBlock:^(SRGPreferencesChangelogEntry * _Nonnull entry, NSUInteger idx, BOOL * _Nonnull stop) {
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
    NSSet<NSString *> *previousDomains = [NSSet setWithArray:self.dictionary.allKeys];
    
    [NSFileManager.defaultManager removeItemAtURL:self.fileURL error:NULL];
    [self.dictionary removeAllObjects];
    
    [self.changelog removeAllEntries];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification
                                                          object:self
                                                        userInfo:@{ SRGPreferencesDomainsKey : previousDomains }];
    });
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
