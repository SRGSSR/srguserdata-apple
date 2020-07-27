//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Convenience macro for localized strings associated with the framework.
 */
#define SRGUserDataLocalizedString(key, comment) [SWIFTPM_MODULE_BUNDLE localizedStringForKey:(key) value:@"" table:nil]

@interface NSBundle (SRGUserData)

/**
 *  The framework resource bundle.
 */
@property (class, nonatomic, readonly) NSBundle *srg_userDataBundle;

@end

NS_ASSUME_NONNULL_END
