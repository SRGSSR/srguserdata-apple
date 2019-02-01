//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SRGUserDataErrorCode) {
    SRGUserDataErrorFailed,
    SRGUserDataErrorCancelled
};

/**
 *  Common domain for user data errors.
 */
OBJC_EXPORT NSString * const SRGUserDataErrorDomain;

NS_ASSUME_NONNULL_END
