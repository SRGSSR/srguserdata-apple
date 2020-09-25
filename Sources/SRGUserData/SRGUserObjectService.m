//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObjectService.h"

#import "SRGUserData+Private.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"
#import "SRGUserObject+Private.h"

@implementation SRGUserObjectService

#pragma mark Overrides

- (void)prepareDataForInitialSynchronizationWithCompletionBlock:(void (^)(void))completionBlock
{
    [self.userData.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGUserObject *> *objects = [self userObjectsInManagedObjectContext:managedObjectContext];
        for (SRGUserObject *object in objects) {
            object.dirty = YES;
        }
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        completionBlock();
    }];
}

#pragma mark Subclassing hooks

- (NSArray<SRGUserObject *> *)userObjectsInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    return @[];
}

@end
