//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DataViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak, nullable) IBOutlet UITableView *tableView;

@end

@interface DataViewController (Subclassing)

- (void)refresh;
- (void)cancelRefresh;

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView NS_REQUIRES_SUPER;

@end

NS_ASSUME_NONNULL_END
