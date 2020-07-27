//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserDataService.h"

#import "SRGDataStore.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"

@import libextobjc;

@interface SRGUserDataService ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic, weak) SRGUserData *userData;

@end

@implementation SRGUserDataService

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL userData:(SRGUserData *)userData
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        self.userData = userData;
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithServiceURL:[NSURL new] userData:[SRGUserData new]];
}

#pragma mark Subclassing hooks

- (void)prepareDataForInitialSynchronizationWithCompletionBlock:(void (^)(void))completionBlock
{
    completionBlock();
}

- (void)synchronizeWithCompletionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    completionBlock(nil);
}

- (void)cancelSynchronization
{}

- (void)clearData
{}

@end
