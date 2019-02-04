//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DemosViewController.h"

#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>

@interface DemosViewController ()

@end

@implementation DemosViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"Demos", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didLogin:)
                                               name:SRGIdentityServiceUserDidLoginNotification
                                             object:SRGIdentityService.currentIdentityService];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didUpdateAccount:)
                                               name:SRGIdentityServiceDidUpdateAccountNotification
                                             object:SRGIdentityService.currentIdentityService];
    
    [self reloadData];
}
     
#pragma mark User interface

- (void)reloadData
{
    if (! SRGIdentityService.currentIdentityService.loggedIn) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Login", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(login:)];
    }
    else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Logout", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(logout:)];
    }
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

#pragma mark Actions

- (void)login:(id)sender
{
    [SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
}

- (void)logout:(id)sender
{
    [SRGIdentityService.currentIdentityService logout];
}

#pragma mark Notifications

- (void)didLogin:(NSNotification *)notification
{
    [self reloadData];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    [self reloadData];
}

@end
