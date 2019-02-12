//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGUserData/SRGUserData.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface UserDataBaseTestCase : XCTestCase

/**
 *  Return a file URL for a test empty stored with the specified name.
 *
 *  @param package If a package is provided, files located in the specified test bundle directory will be used to
 *                 initially prepare the store in a known state. If no package is provided, an empty store URL is
 *                 returned.
 */
- (NSURL *)URLForStoreFromPackage:(nullable NSString *)package;

@end

NS_ASSUME_NONNULL_END
