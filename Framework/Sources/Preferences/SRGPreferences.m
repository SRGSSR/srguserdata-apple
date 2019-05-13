//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferences.h"

#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"

@interface SRGPreferences ()

@property (nonatomic) NSMutableDictionary *dictionary;

@end

@implementation SRGPreferences

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super initWithServiceURL:serviceURL identityService:identityService dataStore:dataStore]) {
        // TODO: Store locally when offline. One file per data store.
        self.dictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark Getters and setters

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

- (id)objectForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain withClass:(Class)cls
{
    NSString *fullKeyPath = [[domain stringByAppendingString:@"."] stringByAppendingString:keyPath];
    id object = [self.dictionary valueForKeyPath:fullKeyPath];
    return [object isKindOfClass:cls] ? object : nil;
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
    [self.dictionary removeAllObjects];
}

@end
