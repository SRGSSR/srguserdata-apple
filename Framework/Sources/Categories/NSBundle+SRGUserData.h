//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Convenience macro for localized strings associated with the framework.
 */
#define SRGUserDataLocalizedString(key, comment) [NSBundle.srg_userDataBundle localizedStringForKey:(key) value:@"" table:nil]

/**
 *  Use to avoid user-facing text analyzer warnings.
 *
 *  See https://clang-analyzer.llvm.org/faq.html.
 */
__attribute__((annotate("returns_localized_nsstring")))
OBJC_EXPORT NSString *SRGUserDataNonLocalizedString(NSString *string);

@interface NSBundle (SRGUserData)

/**
 *  The framework resource bundle.
 */
@property (class, nonatomic, readonly) NSBundle *srg_userDataBundle;

@end

NS_ASSUME_NONNULL_END
