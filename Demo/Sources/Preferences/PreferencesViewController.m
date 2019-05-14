//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PreferencesViewController.h"

#import "NSDateFormatter+Demo.h"
#import "SRGUserData_demo-Swift.h"

#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>

@interface PreferencesViewController ()

@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, copy) NSString *domain;

@property (nonatomic) NSArray *keys;
@property (nonatomic) NSDictionary *dictionary;

@end

@implementation PreferencesViewController

#pragma mark Object lifecycle

- (instancetype)initWithKeyPath:(NSString *)keyPath inDomain:(NSString *)domain
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    PreferencesViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.keyPath = keyPath;
    viewController.domain = domain;
    return viewController;
}

#pragma mark Getters and setters

- (NSString *)title
{
    return self.keyPath.lastPathComponent ?: NSLocalizedString(@"Preferences", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    
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
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"PreferenceCell"];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addPreference:)];
    
    [self updateNavigationBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self refresh];
}

#pragma mark UI

- (void)updateNavigationBar
{
    if (! SRGIdentityService.currentIdentityService.loggedIn) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Login", nil)
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(login:)];
    }
    else {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Account", nil)
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(showAccount:)];
    }
}

- (void)updateTitleSectionHeader
{
    [self.tableView reloadData];
}

#pragma mark Data

- (void)refresh
{
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
    }
    
    self.dictionary = [SRGUserData.currentUserData.preferences dictionaryForKeyPath:self.keyPath inDomain:self.domain];
    
    NSArray<NSString *> *keys = [self.dictionary.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.tableView reloadDataAnimatedWithOldObjects:self.keys newObjects:keys section:0 updateData:^{
        self.keys = keys;
    }];
}

#pragma mark UITableViewDataSourceProtocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.keys.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:@"PreferenceCell"];
}

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

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.textLabel.text = self.keys[indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // TODO:
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *key = self.keys[indexPath.row];
        NSString *keyPath = [self.keyPath stringByAppendingString:key] ?: key;
        [SRGUserData.currentUserData.preferences removeObjectForKeyPath:keyPath inDomain:self.domain];
    }
}

#pragma mark Actions

- (void)login:(id)sender
{
    [SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
}

- (void)showAccount:(id)sender
{
    [SRGIdentityService.currentIdentityService showAccountView];
}

- (void)refresh:(id)sender
{
    [self refresh];
}

- (void)addPreference:(id)sender
{
    UIAlertController *alertController1 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add setting", nil)
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"String", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *keyPath = [self.keyPath stringByAppendingString:NSUUID.UUID.UUIDString] ?: NSUUID.UUID.UUIDString;
        NSInteger random = arc4random() % 1000;
        [SRGUserData.currentUserData.preferences setString:@(random).stringValue forKeyPath:keyPath inDomain:self.domain];
    }]];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Number", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *keyPath = [self.keyPath stringByAppendingString:NSUUID.UUID.UUIDString] ?: NSUUID.UUID.UUIDString;
        NSInteger random = arc4random() % 1000;
        [SRGUserData.currentUserData.preferences setNumber:@(random) forKeyPath:keyPath inDomain:self.domain];
    }]];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Level", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *alertController2 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add setting level", nil)
                                                                                  message:nil
                                                                           preferredStyle:UIAlertControllerStyleAlert];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Name", nil);
        }];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *name = [alertController2.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (name.length != 0) {
                NSString *keyPath = [self.keyPath stringByAppendingString:name] ?: name;
                [SRGUserData.currentUserData.preferences setDictionary:@{} forKeyPath:keyPath inDomain:self.domain];
            }
        }]];
        [self presentViewController:alertController2 animated:YES completion:nil];
    }]];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController1 animated:YES completion:nil];
}

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
