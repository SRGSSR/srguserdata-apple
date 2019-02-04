//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <SRGIdentity/SRGIdentity.h>

// Official version number.
FOUNDATION_EXPORT NSString *SRGUserDataMarketingVersion(void);

// Public headers.
// TODO:

@interface SRGUserData : NSObject

@property (class, nonatomic, nullable) SRGUserData *currentUserData;

// TODO: Configuration object for URLs?
- (instancetype)initWithHistoryServiceURL:(NSURL *)historyServiceURL
                          identityService:(SRGIdentityService *)identityService
                                     name:(NSString *)name
                                directory:(NSString *)directory;

- (nullable id)performMainThreadReadTask:(id _Nullable (NS_NOESCAPE ^)(NSManagedObjectContext *managedObjectContext))task;
- (NSString *)performBackgroundReadTask:(id _Nullable (^)(NSManagedObjectContext *managedObjectContext))task
                           withPriority:(NSOperationQueuePriority)priority
                        completionBlock:(void (^)(id _Nullable result))completionBlock;

- (void)dissociateWithCompletionBlock:(void (^ _Nullable)(NSError * _Nullable error))completionBlock;
- (void)clearWithCompletionBlock:(void (^ _Nullable)(NSError * _Nullable error))completionBlock;

@end
