//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRGPreferences : SRGUserDataService

- (void)setString:(NSString *)string atPath:(NSString *)path inDomain:(NSString *)domain;
- (void)setNumber:(NSNumber *)number atPath:(NSString *)path inDomain:(NSString *)domain;
- (void)setArray:(NSArray *)array atPath:(NSString *)path inDomain:(NSString *)domain;
- (void)setDictionary:(NSDictionary *)dictionary atPath:(NSString *)path inDomain:(NSString *)domain;

- (nullable NSString *)stringAtPath:(NSString *)path inDomain:(NSString *)domain;
- (nullable NSNumber *)numberAtPath:(NSString *)path inDomain:(NSString *)domain;
- (nullable NSArray *)arrayAtPath:(NSString *)path inDomain:(NSString *)domain;
- (nullable NSDictionary *)dictionaryAtPath:(nullable NSString *)path inDomain:(NSString *)domain;

- (void)removeObjectAtPath:(NSString *)path inDomain:(NSString *)domain;

@end

NS_ASSUME_NONNULL_END
