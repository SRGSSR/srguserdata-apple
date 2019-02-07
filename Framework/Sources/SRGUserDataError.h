//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  SRG User Data errors.
 */
typedef NS_ENUM(NSInteger, SRGUserDataErrorCode) {
    /**
     *  An operation failed.
     */
    SRGUserDataErrorFailed,
    /**
     *  An operation was cancelled.
     */
    SRGUserDataErrorCancelled
};

/**
 *  Common domain for SRG User Data errors.
 */
OBJC_EXPORT NSString * const SRGUserDataErrorDomain;

NS_ASSUME_NONNULL_END
