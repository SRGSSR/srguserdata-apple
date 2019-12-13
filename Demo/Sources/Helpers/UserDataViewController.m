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
                                           selector:@selector(didFinishSynchronization:)
                                               name:SRGUserDataDidFinishSynchronizationNotification
                                             object:SRGUserData.currentUserData];
}

#pragma mark UI

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

#pragma mark Notifications

- (void)didLogin:(NSNotification *)notification
{
    [self updateTitleSectionHeader];
}

- (void)didLogout:(NSNotification *)notification
{
    [self updateTitleSectionHeader];
}

- (void)didFinishSynchronization:(NSNotification *)notification
{
    [self updateTitleSectionHeader];
}

@end
