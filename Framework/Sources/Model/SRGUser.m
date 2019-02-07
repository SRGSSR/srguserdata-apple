//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUser.h"

@interface SRGUser ()

@property (nonatomic, copy, nullable) NSString *accountUid;
@property (nonatomic, nullable) NSDate *historyLocalSynchronizationDate;
@property (nonatomic, nullable) NSDate *historyServerSynchronizationDate;

@end

@implementation SRGUser

@dynamic accountUid;
@dynamic historyLocalSynchronizationDate;
@dynamic historyServerSynchronizationDate;

#pragma mark Class methods

+ (SRGUser *)userInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    return [managedObjectContext executeFetchRequest:fetchRequest error:NULL].firstObject;
}

+ (SRGUser *)upsertInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    SRGUser *user = [SRGUser userInManagedObjectContext:managedObjectContext];
    if (! user) {
        user = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(SRGUser.class) inManagedObjectContext:managedObjectContext];
    }
    return user;
}

#pragma mark Account binding

- (void)attachToAccountUid:(NSString *)accountUid
{
    if (! [self.accountUid isEqualToString:accountUid]) {
        self.historyLocalSynchronizationDate = nil;
        self.historyServerSynchronizationDate = nil;
    }
    self.accountUid = accountUid;
}

- (void)detach
{
    self.accountUid = nil;
}

@end
