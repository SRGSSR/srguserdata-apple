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

/**
 *  Replacement for the buggy `-expectationForSingleNotification:object:handler:`, catching notifications only once.
 *  See http://openradar.appspot.com/radar?id=4976563959365632.
 */
- (XCTestExpectation *)expectationForSingleNotification:(NSNotificationName)notificationName object:(nullable id)objectToObserve handler:(nullable XCNotificationExpectationHandler)handler;

/**
 *  Expectation fulfilled after some given time interval (in seconds), calling the optionally provided handler. Can
 *  be useful for ensuring nothing unexpected occurs during some time
 */
- (XCTestExpectation *)expectationForElapsedTimeInterval:(NSTimeInterval)timeInterval withHandler:(nullable void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END
