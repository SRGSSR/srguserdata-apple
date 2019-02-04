//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <SRGIdentity/SRGIdentity.h>

// Official version number.
FOUNDATION_EXPORT NSString *SRGUserDataMarketingVersion(void);

// Public headers.
#import "SRGHistory.h"

@interface SRGUserData : NSObject

@property (class, nonatomic, nullable) SRGUserData *currentUserData;

- (instancetype)initWithServiceURL:(NSURL *)serviceURL
                   identityService:(SRGIdentityService *)identityService
                              name:(NSString *)name
                         directory:(NSString *)directory;

- (void)dissociateWithCompletionBlock:(void (^ _Nullable)(NSError * _Nullable error))completionBlock;
- (void)clearWithCompletionBlock:(void (^ _Nullable)(NSError * _Nullable error))completionBlock;

@end
