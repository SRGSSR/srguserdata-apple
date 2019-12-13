//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataViewController.h"

#import "NSDateFormatter+Demo.h"

#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>

@implementation UserDataViewController

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didLogin:)
                                               name:SRGIdentityServiceUserDidLoginNotification
                                             object:SRGIdentityService.currentIdentityService];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didLogout:)
                                               name:SRGIdentityServiceUserDidLogoutNotification
                                             object:SRGIdentityService.currentIdentityService];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didUpdateAccount:)
                                               name:SRGIdentityServiceDidUpdateAccountNotification
                                             object:SRGIdentityService.currentIdentityService];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didFinishSynchronization:)
                                               name:SRGUserDataDidFinishSynchronizationNotification
                                             object:SRGUserData.currentUserData];
    
    [self updateNavigationBar];
}

#pragma mark UI

- (void)updateNavigationBar
{
    if (self.navigationController.viewControllers.firstObject == self) {
        if (! SRGIdentityService.currentIdentityService.loggedIn) {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Login", nil)
                                                                                     style:UIBarButtonItemStylePlain
                                                                                    target:self
                                                                                    action:@selector(login:)];
        }
        else {
#if TARGET_OS_IOS
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Account", nil)
                                                                                     style:UIBarButtonItemStylePlain
                                                                                    target:self
                                                                                    action:@selector(showAccount:)];
#else
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Logout", nil)
                                                                                     style:UIBarButtonItemStylePlain
                                                                                    target:self
                                                                                    action:@selector(logout:)];
#endif
        }
    }
}

- (void)updateTitleSectionHeader
{
    [self.tableView reloadData];
}

#pragma mark UITableViewDataSource protocol

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (SRGIdentityService.currentIdentityService.loggedIn) {
        NSDate *synchronizationDate = SRGUserData.currentUserData.user.synchronizationDate;
        NSString *synchronizationDateString = synchronizationDate ? [NSDateFormatter.demo_relativeDateAndTimeFormatter stringFromDate:synchronizationDate] : NSLocalizedString(@"Never", nil);
        return [NSString stringWithFormat:NSLocalizedString(@"Last synchronization: %@", nil), synchronizationDateString];
    }
    else {
        return nil;
    }
}

#pragma mark Actions

- (void)login:(id)sender
{
    [SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
}

#if TARGET_OS_IOS

- (void)showAccount:(id)sender
{
    [SRGIdentityService.currentIdentityService showAccountView];
}

#else

- (void)logout:(id)sender
{
    [SRGIdentityService.currentIdentityService logout];
}

#endif

#pragma mark Notifications

- (void)didLogin:(NSNotification *)notification
{
    [self updateTitleSectionHeader];
    [self updateNavigationBar];
}

- (void)didLogout:(NSNotification *)notification
{
    [self updateTitleSectionHeader];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    [self updateNavigationBar];
}

- (void)didFinishSynchronization:(NSNotification *)notification
{
    [self updateTitleSectionHeader];
}

@end
