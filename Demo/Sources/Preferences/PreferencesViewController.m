//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PreferencesViewController.h"

#import "SRGUserData_demo-Swift.h"

#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>

static NSNumberFormatter *PreferencesNumberFormatter(void)
{
    static dispatch_once_t s_onceToken;
    static NSNumberFormatter *s_numberFormatter;
    dispatch_once(&s_onceToken, ^{
        s_numberFormatter = [[NSNumberFormatter alloc] init];
        s_numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    });
    return s_numberFormatter;
}

@interface PreferencesViewController ()

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *domain;

@property (nonatomic) NSArray *keys;
@property (nonatomic) NSDictionary *dictionary;

@end

@implementation PreferencesViewController

#pragma mark Object lifecycle

- (instancetype)initWithPath:(NSString *)path inDomain:(NSString *)domain
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    PreferencesViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.path = path;
    viewController.domain = domain;
    return viewController;
}

#pragma mark Getters and setters

- (NSString *)title
{
    return self.path.lastPathComponent ?: NSLocalizedString(@"Preferences", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(preferencesDidChange:)
                                               name:SRGPreferencesDidChangeNotification
                                             object:SRGUserData.currentUserData.preferences];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addPreference:)];
}

#pragma mark Data

- (void)refresh
{
    self.dictionary = [SRGUserData.currentUserData.preferences dictionaryAtPath:self.path inDomain:self.domain];
    
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
    static NSString * const kCellIdentifier = @"PreferenceCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (! cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellIdentifier];
    }
    return cell;
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *key = self.keys[indexPath.row];
    cell.textLabel.text = key;

    id value = self.dictionary[key];
    if ([value isKindOfClass:NSString.class]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"String: %@", nil), value];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    else if ([value isKindOfClass:NSNumber.class]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Number: %@", nil), [PreferencesNumberFormatter() stringFromNumber:value]];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    else if ([value isKindOfClass:NSDictionary.class]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Dictionary", nil)];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    else {
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *key = self.keys[indexPath.row];
    
    id value = self.dictionary[key];
    
    if ([value isKindOfClass:NSString.class]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Edit string", nil)
                                                                                 message:nil
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Value", nil);
        }];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *string = [alertController.textFields.lastObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            
            NSString *subpath = [self.path stringByAppendingPathComponent:key] ?: key;
            [SRGUserData.currentUserData.preferences setString:string atPath:subpath inDomain:self.domain];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    else if ([value isKindOfClass:NSNumber.class]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Edit number", nil)
                                                                                 message:nil
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Value", nil);
        }];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *value = [alertController.textFields.lastObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSNumber *number = [PreferencesNumberFormatter() numberFromString:value];
            
            NSString *subpath = [self.path stringByAppendingPathComponent:key] ?: key;
            [SRGUserData.currentUserData.preferences setNumber:number atPath:subpath inDomain:self.domain];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    else if ([value isKindOfClass:NSDictionary.class]) {
        NSString *subpath = [self.path stringByAppendingPathComponent:key] ?: key;
        PreferencesViewController *preferencesViewController = [[PreferencesViewController alloc] initWithPath:subpath inDomain:self.domain];
        [self.navigationController pushViewController:preferencesViewController animated:YES];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *key = self.keys[indexPath.row];
        NSString *subpath = [self.path stringByAppendingPathComponent:key] ?: key;
        [SRGUserData.currentUserData.preferences removeObjectAtPath:subpath inDomain:self.domain];
    }
}

#pragma mark Actions

- (void)addPreference:(id)sender
{
    UIAlertController *alertController1 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add setting", nil)
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"String", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *alertController2 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add string", nil)
                                                                                  message:nil
                                                                           preferredStyle:UIAlertControllerStyleAlert];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Key", nil);
        }];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Value", nil);
        }];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *key = [alertController2.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (key.length != 0) {
                NSString *subpath = [self.path stringByAppendingPathComponent:key] ?: key;
                NSString *string = [alertController2.textFields.lastObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                [SRGUserData.currentUserData.preferences setString:string atPath:subpath inDomain:self.domain];
            }
        }]];
        [self presentViewController:alertController2 animated:YES completion:nil];
    }]];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Number", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *alertController2 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add number", nil)
                                                                                  message:nil
                                                                           preferredStyle:UIAlertControllerStyleAlert];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Key", nil);
        }];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Value", nil);
            textField.keyboardType = UIKeyboardTypeNumberPad;
        }];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *key = [alertController2.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (key.length != 0) {
                NSString *value = [alertController2.textFields.lastObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                NSNumber *number = [PreferencesNumberFormatter() numberFromString:value];
                
                NSString *subpath = [self.path stringByAppendingPathComponent:key] ?: key;
                [SRGUserData.currentUserData.preferences setNumber:number atPath:subpath inDomain:self.domain];
            }
        }]];
        [self presentViewController:alertController2 animated:YES completion:nil];
    }]];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dictionary", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *alertController2 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add setting dictionary", nil)
                                                                                  message:nil
                                                                           preferredStyle:UIAlertControllerStyleAlert];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Key", nil);
        }];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *key = [alertController2.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (key.length != 0) {
                NSString *subpath = [self.path stringByAppendingPathComponent:key] ?: key;
                [SRGUserData.currentUserData.preferences setDictionary:@{} atPath:subpath inDomain:self.domain];
            }
        }]];
        [self presentViewController:alertController2 animated:YES completion:nil];
    }]];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController1 animated:YES completion:nil];
}

#pragma mark Notifications

- (void)preferencesDidChange:(NSNotification *)notification
{
    [self refresh];
}

@end
