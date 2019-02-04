//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUser.h"

#import "SRGHistoryEntry+CoreDataProperties.h"

#import <SRGIdentity/SRGIdentity.h>

@implementation SRGUser

#pragma mark Class methods

+ (void)setupMainUserWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSString *className = NSStringFromClass(self);
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:className];
    SRGUser *mainUser = [managedObjectContext executeFetchRequest:fetchRequest error:NULL].firstObject;
    if (! mainUser) {
        mainUser = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:managedObjectContext];
    }
}

+ (SRGUser *)mainUserInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    SRGUser *mainUser = [managedObjectContext executeFetchRequest:fetchRequest error:NULL].firstObject;
    NSAssert(mainUser != nil, @"A main user must always be available");
    return mainUser;
}

#pragma mark Lifecycle

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // TODO: Remove coupling with current identity service!
    self.accountUid = SRGIdentityService.currentIdentityService.account.uid;
}

#pragma mark Helpers

- (void)detach
{
    self.accountUid = nil;
    self.historyLocalSynchronizationDate = nil;
    self.historyServerSynchronizationDate = nil;
}

@end
