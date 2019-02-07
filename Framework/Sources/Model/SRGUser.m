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

#pragma mark Helpers

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
