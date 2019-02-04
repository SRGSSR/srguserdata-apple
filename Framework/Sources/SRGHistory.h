//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <SRGIdentity/SRGIdentity.h>

#import "SRGDataStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notification sent when the history changes. Use the `SRGHistoryURNsKey` to retrieve the updated URNs from the
 *  notification `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGHistoryDidChangeNotification;                    // Notification name.
OBJC_EXPORT NSString * const SRGHistoryURNsKey;                                  // Key to access the updated URNs as an `NSArray` of `NSString` objects.

/**
 *  Notification sent when history synchronization has started.
 */
OBJC_EXPORT NSString * const SRGHistoryDidStartSynchronizationNotification;

/**
 *  Notification sent when history synchronization has finished.
 */
OBJC_EXPORT NSString * const SRGHistoryDidFinishSynchronizationNotification;

/**
 *  Notification sent when the history has been cleared.
 */
OBJC_EXPORT NSString * const SRGHistoryDidClearNotification;

/**
 *  Service for history and playback resume.
 *
 *  @discussion Though similar methods exist on `SRGHistoryEntry`, use `SRGHistory` as the main entry point for local history
 *              updates.
 */
@interface SRGHistory : NSObject

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore;

// TODO: Public methods for deletion / batch deletion

@end

NS_ASSUME_NONNULL_END
