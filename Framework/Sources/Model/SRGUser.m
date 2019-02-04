//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUser.h"

#import "SRGHistoryEntry+CoreDataProperties.h"

@implementation SRGUser

#pragma mark Class methods

+ (SRGUser *)mainUserInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    SRGUser *mainUser = [managedObjectContext executeFetchRequest:fetchRequest error:NULL].firstObject;
    NSAssert(mainUser != nil, @"A main user must always be available");
    return mainUser;
}

#pragma mark Helpers

- (void)detach
{
    self.accountUid = nil;
    self.historyLocalSynchronizationDate = nil;
    self.historyServerSynchronizationDate = nil;
}

@end
