//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SettingsViewController.h"

#import <SRGIdentity/SRGIdentity.h>

@implementation SettingsViewController

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"Settings", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"SettingCell"];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didLogin:)
                                               name:SRGIdentityServiceUserDidLoginNotification
                                             object:SRGIdentityService.currentIdentityService];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didLogout:)
                                               name:SRGIdentityServiceUserDidLogoutNotification
                                             object:SRGIdentityService.currentIdentityService];
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:@"SettingCell"];
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (! SRGIdentityService.currentIdentityService.loggedIn) {
        cell.textLabel.text = NSLocalizedString(@"Login", nil);
    }
    else {
#if TARGET_OS_IOS
        cell.textLabel.text = NSLocalizedString(@"Account", nil);
#else
        cell.textLabel.text = NSLocalizedString(@"Logout", nil);
#endif
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (! SRGIdentityService.currentIdentityService.loggedIn) {
        [SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
    }
    else {
#if TARGET_OS_IOS
        [SRGIdentityService.currentIdentityService showAccountView];
#else
        [SRGIdentityService.currentIdentityService logout];
#endif
    }
}

#pragma mark Notifications

- (void)didLogin:(NSNotification *)notification
{
    [self.tableView reloadData];
}

- (void)didLogout:(NSNotification *)notification
{
    [self.tableView reloadData];
}

@end
