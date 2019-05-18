//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notification sent when preferences change. Use the keys below to retrieve detailed information from the notification
 *  `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGPreferencesDidChangeNotification;

/**
 *  Information available for `SRGPreferencesDidChangeNotification`.
 */
OBJC_EXPORT NSString * const SRGPreferencesDomainsKey;                           // Key to access the domains for which changes have been detected, as an `NSSet` of `NSString` objects.

/**
 *  Manages a local cache of user preferences, similar to `NSUserDefaults`. For logged in users, and provided a service
 *  URL has been set when instantiating `SRGUserData`, local and distant preferences are automatically kept in sync.
 *
 *  Preferences are arranged as a tree, whose nodes are identified by paths in the form `path/to/settting`, and whose leafs
 *  store actual preferences. Paths should be constructed using standard `NSString (NSStringPathExtensions)` path-related
 *  extensions.
 *
 *  Preferences are of primitive types string and number. Arrays and dictionaries can also be set, provided they can be
 *  serialized to JSON according to `+[NSJSONSerialization isValidJSONObject:]`.
 *
 *  Preferences are grouped by domain. Applications can define their own domain for their specific needs, while groups of
 *  applications might choose to have a common domain for shared preferences.
 *
 *  You can register for preference update notifications, see above. These will be sent by the `SRGPreferences` instance
 *  itself and received on the main thread.
 */
@interface SRGPreferences : SRGUserDataService

/**
 *  Return `YES` iff an object is available at a specific path in a domain.
 */
- (BOOL)hasObjectAtPath:(NSString *)path inDomain:(NSString *)domain;

/**
 *  Set primitive objects at a specific path in a domain. If set to `nil`, any existing item at this location will be
 *  discarded, no matter its type.
 *
 *  @discussion If a path is specified for which a component already matches an existing leaf, the leaf will be replaced
 *              by a new node and the existing value lost.
 */
- (void)setString:(nullable NSString *)string atPath:(NSString *)path inDomain:(NSString *)domain;
- (void)setNumber:(nullable NSNumber *)number atPath:(NSString *)path inDomain:(NSString *)domain;

/**
 *  Set collection objects at a specific path in a domain. If set to `nil`, any existing item at this location will be
 *  discarded, no matter its type. Arrays and dictionaries must be serializable to JSON, otherwise no change will be
 *  made.
 *
 *  @discussion If a path is specified for which a component already matches an existing leaf, the leaf will be replaced
 *              by a new node and the existing value lost. Note that arrays or dictionaries submitted from two connected
 *              devices will not be merged (the last submitted value wins). If you want to submit content from two
 *              dictionaries and have it merged correctly, use primitive setters above instead.
 */
- (void)setArray:(nullable NSArray *)array atPath:(NSString *)path inDomain:(NSString *)domain;
- (void)setDictionary:(nullable NSDictionary *)dictionary atPath:(NSString *)path inDomain:(NSString *)domain;

/**
 *  Return an object at a specific path in a domain. If no object exists at the specified location, or if the type of
 *  the object does not match, the method returns `nil`.
 */
- (nullable NSString *)stringAtPath:(NSString *)path inDomain:(NSString *)domain;
- (nullable NSNumber *)numberAtPath:(NSString *)path inDomain:(NSString *)domain;
- (nullable NSArray *)arrayAtPath:(NSString *)path inDomain:(NSString *)domain;
- (nullable NSDictionary *)dictionaryAtPath:(nullable NSString *)path inDomain:(NSString *)domain;

/**
 *  Remove objects at the specific paths in a domain. The method does nothing when no object exists at a specified
 *  location.
 */
- (void)removeObjectsAtPaths:(NSArray<NSString *> *)paths inDomain:(NSString *)domain;

@end

NS_ASSUME_NONNULL_END
