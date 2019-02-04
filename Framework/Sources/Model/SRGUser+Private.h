//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRGUser (Private)

@property (nonatomic, copy, nullable) NSString *accountUid;
@property (nonatomic, nullable) NSDate *historyLocalSynchronizationDate;
@property (nonatomic, nullable) NSDate *historyServerSynchronizationDate;

- (void)detach;

@end

NS_ASSUME_NONNULL_END
