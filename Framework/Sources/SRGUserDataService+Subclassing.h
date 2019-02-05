//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

@interface SRGUserDataService (Subclassing)

- (void)synchronize;

@end

@interface SRGUserDataService (SubclassingHooks)

- (void)synchronizeWithCompletionBlock:(void (^)(void))completionBlock;

- (void)userDidLogin;
- (void)userDidLogout;

- (void)clearDataWithCompletionBlock:(void (^)(void))completionBlock;

@end
