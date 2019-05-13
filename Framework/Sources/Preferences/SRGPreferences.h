//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRGPreferences : SRGUserDataService

- (NSDictionary *)preferencesInDomain:(NSString *)domain;

- (void)setString:(NSString *)string forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (void)setNumber:(NSNumber *)number forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (void)setArray:(NSArray *)array forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;

- (void)setBool:(BOOL)value forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (void)setInteger:(BOOL)value forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (void)setFloat:(BOOL)value forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (void)setDouble:(BOOL)value forKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;

- (NSString *)stringForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (NSNumber *)numberForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (NSArray *)arrayForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;

- (BOOL)boolForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (NSInteger)integerForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (float)floatForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;
- (double)doubleForKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;

@end

NS_ASSUME_NONNULL_END
