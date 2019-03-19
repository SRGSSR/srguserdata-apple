//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

/**
 *  Framework error constants.
 */
typedef NS_ENUM(NSInteger, SRGUserDataErrorCode) {
    /**
     *  An operation has been cancelled
     */
    SRGUserDataErrorCancelled
};

/**
 *  Common domain for framework errors.
 */
OBJC_EXPORT NSString * const SRGUserDataErrorDomain;
