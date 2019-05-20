//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DataViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface UserDataViewController : DataViewController

@end

@interface UserDataViewController (Subclassing)

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section NS_REQUIRES_SUPER;

@end

NS_ASSUME_NONNULL_END
